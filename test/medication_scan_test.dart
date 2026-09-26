import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/data/medication_catalog_client.dart';
import 'package:mediary/medication_scan.dart';

void main() {
  test(
    'sample detector returns the deterministic medication label fixture',
    () async {
      const detector = SampleMedicationScanDetector();

      final result = await detector.detect(
        const MedicationScanRequest.sample(),
      );

      expect(result.imageUrl, MedicationScanRequest.sampleImageUrl);
      expect(result.detectedMedicationName, 'Amoxicillin');
      expect(result.extractedText, contains('500 mg capsule'));
      expect(result.extractedText, contains('every 8 hours'));
      expect(result.confidence, .98);
      expect(result.hasError, isFalse);
    },
  );

  test(
    'selected photo bytes are carried to the scan result for preview',
    () async {
      const detector = SampleMedicationScanDetector();
      final bytes = Uint8List.fromList([1, 2, 3]);

      final result = await detector.detect(
        MedicationScanRequest.fromImage(
          imageBytes: bytes,
          fileName: 'label.jpg',
        ),
      );

      expect(result.imageUrl, isEmpty);
      expect(result.imageBytes, same(bytes));
      expect(result.detectedMedicationName, 'Amoxicillin');
    },
  );

  test('matches a detected generic name to an RxNorm product variant', () {
    final match = matchMedicationCatalogRecord('Amoxicillin', const [
      MedicationCatalogRecord(
        rxcui: '723',
        name: 'Amoxicillin 500 MG Oral Capsule',
        genericName: 'amoxicillin',
        strength: '500 mg',
        form: 'capsule',
      ),
    ]);

    expect(match?.rxcui, '723');
  });

  test('recognizes Advil from OCR text before catalog verification', () {
    expect(
      detectMedicationName('ADVIL\nIbuprofen 200 mg tablets\nPain reliever'),
      'Advil',
    );
    expect(detectMedicationName('ADVI1 200 mg tablets'), 'Advil');
  });

  test('does not invent a medication name from instruction text', () {
    expect(detectMedicationName('Take two tablets with water'), isNull);
  });

  test('does not apply the known Advil fixture to unrelated bytes', () async {
    const detector = MedicationOcrDetector();

    final result = await detector.detect(
      MedicationScanRequest.fromImage(
        imageBytes: Uint8List.fromList([1, 2, 3, 4]),
        fileName: 'unrelated.png',
      ),
    );

    expect(result.detectedMedicationName, isEmpty);
    expect(result.confidence, 0);
    expect(result.hasError, isTrue);
  });
}
