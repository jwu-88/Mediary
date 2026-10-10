import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/app_controls.dart';
import 'package:mediary/medication_scan.dart';

final medicationScanFixture = MedicationScanRequest(
  source: MedicationScanSource.camera,
  imageUrl: '',
  imageBytes: base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAACAAAAAwCAYAAABwrHhvAAAAN0lEQVR4nO3OIQEAAAgDMJIQjDgUhxg3E/Or3rmkEhAQEBAQEBAQEBAQEBAQEBAQEBAQEBBIBx4aW9amL5ZQlQAAAABJRU5ErkJggg==',
  ),
  fileName: 'camera-test.png',
);

Future<void> confirmCameraPhoto(WidgetTester tester) async {
  final use = find.byKey(const Key('useCameraPhotoButton'));
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    if (tester.widget<AppButton>(use).onPressed != null) break;
  }
  expect(tester.widget<AppButton>(use).onPressed, isNotNull);
  await tester.ensureVisible(use);
  await tester.pumpAndSettle();
  await tester.tap(use);
  await tester.pumpAndSettle();
}

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
