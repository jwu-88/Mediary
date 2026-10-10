import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

web.MediaStream? _cameraStream;
web.HTMLVideoElement? _activeVideo;
int _viewCounter = 0;
int _cameraGeneration = 0;
Future<bool>? _pendingCameraAccess;

/// Requests the browser camera stream. On macOS this delegates to the
/// browser's normal camera permission prompt and keeps the stream available
/// for the scanner preview.
Future<bool> requestWebCameraAccess() {
  if (_cameraStream != null) return Future.value(true);
  final pending = _pendingCameraAccess;
  if (pending != null) return pending;
  final request = _requestCameraStream(_cameraGeneration);
  _pendingCameraAccess = request;
  unawaited(
    request.whenComplete(() {
      if (identical(_pendingCameraAccess, request)) _pendingCameraAccess = null;
    }),
  );
  return request;
}

Future<bool> _requestCameraStream(int generation) async {
  final mediaDevices = web.window.navigator.mediaDevices;
  try {
    final stream = await mediaDevices
        .getUserMedia(
          web.MediaStreamConstraints(
            video: web.MediaTrackConstraints(
              width: web.ConstrainULongRange(ideal: 1920),
              height: web.ConstrainULongRange(ideal: 1080),
              facingMode: web.ConstrainDOMStringParameters(
                ideal: 'environment'.toJS,
              ),
            ),
            audio: false.toJS,
          ),
        )
        .toDart;
    // Permission can finish after retake, navigation, or disposal. A stale
    // request must release its tracks instead of reviving a hidden camera.
    if (generation != _cameraGeneration) {
      stream.getTracks().toDart.forEach((track) => track.stop());
      return false;
    }
    _cameraStream = stream;
    return true;
  } catch (_) {
    if (generation == _cameraGeneration) _cameraStream = null;
    return false;
  }
}

/// Waits for a visible live frame without encoding an unused image.
Future<bool> waitForWebCameraFrame({
  Duration timeout = const Duration(seconds: 3),
}) async {
  final deadline = DateTime.now().add(timeout);
  do {
    final video = _activeVideo;
    if (_cameraStream != null &&
        video != null &&
        video.isConnected &&
        !video.paused &&
        video.readyState >= 2 &&
        video.videoWidth > 0 &&
        video.videoHeight > 0) {
      return true;
    }
    if (!DateTime.now().isBefore(deadline)) {
      return false;
    }
    await Future<void>.delayed(const Duration(milliseconds: 16));
  } while (DateTime.now().isBefore(deadline));
  return false;
}

/// Captures the displayed frame, optionally pausing the preview at the shutter.
Future<Uint8List?> captureWebCameraFrame({bool freezePreview = false}) async {
  final video = _activeVideo;
  if (_cameraStream == null ||
      video == null ||
      video.readyState < 2 ||
      video.videoWidth == 0 ||
      video.videoHeight == 0) {
    return null;
  }
  try {
    if (freezePreview) video.pause();
    final canvas = web.HTMLCanvasElement()
      ..width = video.videoWidth
      ..height = video.videoHeight;
    final context = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    context.drawImage(video, 0, 0);
    final dataUrl = canvas.toDataURL('image/png');
    final separator = dataUrl.indexOf(',');
    if (separator < 0) return null;
    return base64Decode(dataUrl.substring(separator + 1));
  } catch (_) {
    if (freezePreview && identical(_activeVideo, video)) {
      unawaited(video.play().toDart.then<void>((_) {}, onError: (Object _) {}));
    }
    return null;
  }
}

void stopWebCamera() {
  _cameraGeneration++;
  _pendingCameraAccess = null;
  final stream = _cameraStream;
  _cameraStream = null;
  _activeVideo = null;
  stream?.getTracks().toDart.forEach((track) => track.stop());
}

class WebCameraPreview extends StatefulWidget {
  const WebCameraPreview({super.key, required this.active});

  final bool active;

  @override
  State<WebCameraPreview> createState() => _WebCameraPreviewState();
}

class _WebCameraPreviewState extends State<WebCameraPreview>
    with WidgetsBindingObserver {
  late final String _viewType = 'mediary-camera-preview-${_viewCounter++}';
  web.HTMLVideoElement? _video;
  bool _mountedFactory = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground =
        lifecycle != AppLifecycleState.hidden &&
        lifecycle != AppLifecycleState.paused &&
        lifecycle != AppLifecycleState.detached;
    WidgetsBinding.instance.addObserver(this);
    _registerView();
    unawaited(_syncCamera());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      unawaited(_syncCamera());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _foreground = false;
      _detachVideo();
      stopWebCamera();
    }
  }

  @override
  void didUpdateWidget(covariant WebCameraPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) unawaited(_syncCamera());
  }

  void _registerView() {
    if (_mountedFactory) return;
    _mountedFactory = true;
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final wrapper = web.HTMLDivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.display = 'block'
        ..style.overflow = 'hidden'
        ..style.borderRadius = '28px'
        ..style.backgroundColor = '#000000'
        ..style.pointerEvents = 'none';
      final video = web.HTMLVideoElement()
        ..autoplay = true
        ..muted = true
        ..playsInline = true;
      video.setAttribute('playsinline', 'true');
      video.style.width = '100%';
      video.style.height = '100%';
      // Show the full camera feed instead of cropping the sides to fill the
      // wide desktop preview. The surrounding camera panel supplies the
      // rounded frame and black letterbox area when aspect ratios differ.
      video.style.objectFit = 'contain';
      video.style.objectPosition = 'center center';
      video.style.borderRadius = '0';
      video.style.display = 'block';
      video.style.backgroundColor = '#000000';
      video.style.pointerEvents = 'none';
      wrapper.append(video);
      _video = video;
      _attachStream();
      return wrapper;
    });
  }

  Future<void> _syncCamera() async {
    if (!widget.active || !_foreground) {
      _detachVideo();
      stopWebCamera();
      return;
    }
    if (_cameraStream == null) {
      final granted = await requestWebCameraAccess();
      if (!granted || !mounted) return;
      if (!widget.active || !_foreground) {
        stopWebCamera();
        return;
      }
    }
    _attachStream();
  }

  void _attachStream() {
    final video = _video;
    final stream = _cameraStream;
    if (video == null || stream == null || !widget.active || !_foreground) {
      return;
    }
    video.srcObject = stream;
    _activeVideo = video;
    unawaited(video.play().toDart.then<void>((_) {}, onError: (Object _) {}));
  }

  void _detachVideo() {
    final video = _video;
    if (video == null) return;
    video.pause();
    video.srcObject = null;
    if (identical(_activeVideo, video)) _activeVideo = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detachVideo();
    stopWebCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.expand();
    return HtmlElementView(viewType: _viewType);
  }
}
