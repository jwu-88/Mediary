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

/// Requests the browser camera stream. On macOS this delegates to the
/// browser's normal camera permission prompt and keeps the stream available
/// for the scanner preview.
Future<bool> requestWebCameraAccess() async {
  if (_cameraStream != null) return true;
  final mediaDevices = web.window.navigator.mediaDevices;
  try {
    _cameraStream = await mediaDevices
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
    return true;
  } catch (_) {
    _cameraStream = null;
    return false;
  }
}

/// Captures the frame currently visible in the active browser preview.
/// A loading, detached, or stopped preview has no usable image yet.
Future<Uint8List?> captureWebCameraFrame() async {
  final video = _activeVideo;
  if (_cameraStream == null ||
      video == null ||
      video.readyState < 2 ||
      video.videoWidth == 0 ||
      video.videoHeight == 0) {
    return null;
  }
  try {
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
    return null;
  }
}

void stopWebCamera() {
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

class _WebCameraPreviewState extends State<WebCameraPreview> {
  late final String _viewType = 'mediary-camera-preview-${_viewCounter++}';
  web.HTMLVideoElement? _video;
  bool _mountedFactory = false;

  @override
  void initState() {
    super.initState();
    _registerView();
    unawaited(_syncCamera());
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
    if (!widget.active) {
      _detachVideo();
      stopWebCamera();
      return;
    }
    if (_cameraStream == null) {
      final granted = await requestWebCameraAccess();
      if (!granted || !mounted) return;
      if (!widget.active) {
        stopWebCamera();
        return;
      }
    }
    _attachStream();
  }

  void _attachStream() {
    final video = _video;
    final stream = _cameraStream;
    if (video == null || stream == null || !widget.active) return;
    video.srcObject = stream;
    _activeVideo = video;
    unawaited(video.play().toDart);
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
