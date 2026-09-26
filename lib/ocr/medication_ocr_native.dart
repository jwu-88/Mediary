import 'dart:typed_data';

import 'package:flutter/services.dart';

const _nativeOcrChannel = MethodChannel('com.mediary/medication_ocr');

/// Uses the platform's native OCR implementation without exposing dart:io to
/// web builds. iOS uses Apple's Vision framework and Android uses ML Kit
/// through the app's own platform channel. Passing bytes keeps this path
/// compatible with both photo-library and clipboard images.
Future<String> recognizeMedicationText(
  Uint8List bytes, {
  String fileName = '',
}) async {
  final text = await _nativeOcrChannel.invokeMethod<String>('recognize', {
    'bytes': bytes,
    'fileName': fileName,
  });
  return text ?? '';
}
