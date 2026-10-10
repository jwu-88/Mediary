import 'dart:typed_data';

import 'medication_ocr_result.dart';

Future<MedicationOcrEvidence> recognizeMedicationEvidence(
  Uint8List bytes, {
  String fileName = '',
}) async => MedicationOcrEvidence(
  await recognizeMedicationText(bytes, fileName: fileName),
);

Future<String> recognizeMedicationText(
  Uint8List bytes, {
  String fileName = '',
}) async {
  return '';
}
