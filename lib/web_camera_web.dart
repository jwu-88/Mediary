import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

web.MediaStream? _cameraStream;
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
          web.MediaStreamConstraints(video: true.toJS, audio: false.toJS),
        )
        .toDart;
    return true;
  } catch (_) {
    _cameraStream = null;
    return false;
  }
}

void stopWebCamera() {
  final stream = _cameraStream;
  _cameraStream = null;
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
      final video = web.HTMLVideoElement()
        ..autoplay = true
        ..muted = true
        ..playsInline = true;
      video.setAttribute('playsinline', 'true');
      video.style.width = '100%';
      video.style.height = '100%';
      video.style.objectFit = 'cover';
      video.style.display = 'block';
      video.style.backgroundColor = '#000000';
      video.style.pointerEvents = 'none';
      _video = video;
      _attachStream();
      return video;
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
    unawaited(video.play().toDart);
  }

  void _detachVideo() {
    final video = _video;
    if (video == null) return;
    video.pause();
    video.srcObject = null;
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
