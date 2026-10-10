// Browser-only validation target. It uses the application's real camera and
// detector adapters; the runner supplies the synthetic browser camera stream.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mediary/medication_scan.dart';
import 'package:mediary/web_camera.dart';

@JS('MediaryCameraProbe')
external set _probe(JSFunction value);

@JS('MediaryCameraProbeReady')
external set _ready(JSBoolean value);

void main() {
  _probe = (() => _captureAndDetect().toJS).toJS;
  runApp(
    const MaterialApp(home: Scaffold(body: WebCameraPreview(active: true))),
  );
  _ready = true.toJS;
}

Future<JSString> _captureAndDetect() async {
  final started = Stopwatch()..start();
  final granted = await requestWebCameraAccess();
  if (!granted) {
    return jsonEncode({
      'cameraGranted': false,
      'captureError': 'camera-unavailable',
      'elapsedMilliseconds': started.elapsedMilliseconds,
    }).toJS;
  }

  Uint8List? bytes;
  for (var attempt = 0; attempt < 50; attempt++) {
    bytes = await captureWebCameraFrame();
    if (bytes != null) break;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  if (bytes == null) {
    return jsonEncode({
      'cameraGranted': true,
      'captureError': 'frame-unavailable',
      'elapsedMilliseconds': started.elapsedMilliseconds,
    }).toJS;
  }

  final captureMilliseconds = started.elapsedMilliseconds;
  final result = await const MedicationOcrDetector().detect(
    MedicationScanRequest(
      source: MedicationScanSource.camera,
      imageUrl: '',
      imageBytes: bytes,
      fileName: 'camera-probe.png',
    ),
  );
  final header = ByteData.sublistView(bytes);
  return jsonEncode({
    'cameraGranted': true,
    'captureError': '',
    'pngSignature': bytes.take(8).toList(),
    'capturedBytes': bytes.length,
    'frameWidth': header.getUint32(16),
    'frameHeight': header.getUint32(20),
    'pngDataUrl': 'data:image/png;base64,${base64Encode(bytes)}',
    'extractedText': result.extractedText,
    'detectedMedicationName': result.detectedMedicationName,
    'confidence': result.confidence,
    'hasError': result.hasError,
    'errorMessage': result.errorMessage,
    'captureMilliseconds': captureMilliseconds,
    'ocrMilliseconds': started.elapsedMilliseconds - captureMilliseconds,
    'elapsedMilliseconds': started.elapsedMilliseconds,
  }).toJS;
}
