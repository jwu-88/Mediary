import 'package:flutter/services.dart';

import 'medication_ocr_result.dart';

const _nativeOcrChannel = MethodChannel('com.mediary/medication_ocr');

Future<MedicationOcrEvidence> recognizeMedicationEvidence(
  Uint8List bytes, {
  String fileName = '',
}) async => MedicationOcrEvidence(
  await recognizeMedicationText(bytes, fileName: fileName),
);

/// uses the platform's native ocr implementation without exposing dart:io to
/// web builds. ios uses apple's vision framework and android uses ml kit
/// through the app's own platform channel. passing bytes keeps this path
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
