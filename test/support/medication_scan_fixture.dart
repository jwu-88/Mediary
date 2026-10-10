import 'package:mediary/medication_scan.dart';

const medicationScanFixture = MedicationScanRequest(
  source: MedicationScanSource.camera,
  imageUrl: '',
);

class FixtureMedicationScanDetector implements MedicationScanDetector {
  const FixtureMedicationScanDetector();

  @override
  Future<MedicationScanResult> detect(MedicationScanRequest request) async =>
      MedicationScanResult(
        imageUrl: request.imageUrl,
        imageBytes: request.imageBytes,
        extractedText:
            'Amoxicillin 500 mg capsule. Take 1 capsule every 8 hours.',
        detectedMedicationName: 'Amoxicillin',
        confidence: .98,
      );
}
