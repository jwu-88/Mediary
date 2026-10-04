import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/data/medication_catalog_client.dart';
import 'package:mediary/medication_scan.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  test('recognizes Claritin from a detailed OTC label', () {
    expect(
      detectMedicationName(
        'CLARITIN\nLoratadine 10 mg tablet\n24-hour non-drowsy allergy relief',
      ),
      'Claritin',
    );
  });

  group('Claritin formulation extraction', () {
    for (final text in [
      'Claritin-D',
      'CLARITIN–D 24 HOUR',
      'Claritin\n-\nD\n24 hour',
      'Claritin D 12 hour',
      'ClaritinD',
      'Claritin-D12',
      'ClaritinD24',
      'Clari tin - D',
      'Claritin - D-24',
      'C1aritln-D',
      'Clarltin-D',
      'laritin-D',
      'Loratadine 10 mg\nPseudoephedrine sulfate 240 mg\nClaritin-D',
      'Claritin-D\nLoratadine 10 mg\nPseudoephedrine sulfate 240 mg',
      'Claritin\nLoratadine 10 mg\nPseudoephedrine sulfate 240 mg',
    ]) {
      test(
        'preserves the D formulation in ${text.replaceAll('\n', ' / ')}',
        () {
          expect(detectMedicationName(text), 'Claritin-D');
        },
      );
    }

    test('strongest complete variant wins throughout merged photo OCR', () {
      const text =
          'C Ia 1tin D\n'
          'pseudoephedrine subq...240 mg/nasal decongestant\n'
          'loratadine 10 mg/antihistamine\n'
          'Claritin-D\n24 HOUR\n'
          'Claritin-';

      expect(detectMedicationName(text), 'Claritin-D');
      expect(
        detectMedicationName('laritin-p\nloratidine\n$text'),
        'Claritin-D',
      );
    });

    test('keeps both ingredients when the brand is unreadable', () {
      expect(
        detectMedicationName(
          'Non-Drowsy\npseudoephedrine sulfate 240 mg\n'
          'loratadine 10 mg / antihistamine',
        ),
        'Loratadine / Pseudoephedrine',
      );
      expect(
        detectMedicationName('Lorata-\ndine 10 mg\nPseudoephe-\ndrine 240 mg'),
        'Loratadine / Pseudoephedrine',
      );
      expect(
        detectMedicationName('loratidine 10 mg / pseudoephedr1ne 240 mg'),
        'Loratadine / Pseudoephedrine',
      );
    });

    test('does not infer a decongestant from plain Claritin', () {
      for (final text in [
        'Claritin',
        'Claritin 24 hour\nLoratadine 10 mg',
        'Claritin\nAllergy + Congestion\nNasal decongestant',
        'Claritin\nDo not take with pseudoephedrine',
        'Claritin\nContains no pseudoephedrine',
        'Claritin\nInactive ingredients: pseudoephedrine',
      ]) {
        expect(detectMedicationName(text), 'Claritin', reason: text);
      }
    });

    test('does not silently discard an unreadable formulation suffix', () {
      for (final text in [
        'Claritin-',
        'Claritin-\nLoratadine 10 mg',
        'Claritin-X',
        'laritin-p\nloratidine 10 mg',
      ]) {
        expect(detectMedicationName(text), isNull, reason: text);
      }
    });

    test('conflicting product brands require manual identification', () {
      expect(detectMedicationName('Advil\nClaritin-D'), isNull);
    });
  });

  group('formulation-safe catalog matching', () {
    const plain = MedicationCatalogRecord(
      rxcui: 'plain',
      name: 'Claritin 10 MG Oral Tablet',
      genericName: 'loratadine',
    );
    const twentyFourHour = MedicationCatalogRecord(
      rxcui: '1242391',
      name: 'Claritin-D 10 MG / 240 MG 24HR Extended Release Oral Tablet',
      genericName: 'loratadine / pseudoephedrine sulfate',
    );
    const twelveHour = MedicationCatalogRecord(
      rxcui: '1242406',
      name: 'Claritin-D 5 MG / 120 MG 12HR Extended Release Oral Tablet',
      genericName: 'loratadine / pseudoephedrine sulfate',
    );

    test(
      'plain Claritin rejects D variants even when they are the only hit',
      () {
        expect(
          matchMedicationCatalogRecord('Claritin', [twentyFourHour]),
          isNull,
        );
        expect(
          matchMedicationCatalogRecord('Loratadine', [twelveHour]),
          isNull,
        );
        expect(
          matchMedicationCatalogRecord('Claritin', [
            twentyFourHour,
            plain,
          ])?.rxcui,
          'plain',
        );
      },
    );

    test('Claritin-D never falls back to a plain brand or ingredient', () {
      expect(matchMedicationCatalogRecord('Claritin-D', [plain]), isNull);
      expect(
        matchMedicationCatalogRecord('Loratadine / Pseudoephedrine', [plain]),
        isNull,
      );
      expect(
        matchMedicationCatalogRecord('Claritin-D', [
          plain,
          twentyFourHour,
        ])?.rxcui,
        '1242391',
      );
    });

    test('combination evidence is checked across all catalog fields', () {
      const misleadingSynonym = MedicationCatalogRecord(
        rxcui: 'combination',
        name: 'Claritin-D 24 Hour',
        genericName: 'loratadine',
        synonym: 'Claritin',
      );
      expect(
        matchMedicationCatalogRecord('Claritin', [misleadingSynonym]),
        isNull,
      );
      expect(
        matchMedicationCatalogRecord('Claritin-D', [misleadingSynonym])?.rxcui,
        'combination',
      );
    });

    test('supports compact 12 and 24 brand variants', () {
      for (final name in ['Claritin-D12', 'ClaritinD24', 'Claritin-D-24']) {
        expect(
          matchMedicationCatalogRecord('Claritin-D', [
            MedicationCatalogRecord(rxcui: 'd', name: name),
          ])?.rxcui,
          'd',
          reason: name,
        );
      }
    });

    test('both ingredients allow a generic combination catalog record', () {
      const generic = MedicationCatalogRecord(
        rxcui: 'generic',
        name:
            'Pseudoephedrine sulfate 240 MG / Loratadine 10 MG '
            'Extended Release Oral Tablet',
      );
      expect(
        matchMedicationCatalogRecord('Claritin-D', [generic])?.rxcui,
        'generic',
      );
      expect(
        matchMedicationCatalogRecord('Loratadine / Pseudoephedrine', [
          generic,
        ])?.rxcui,
        'generic',
      );
      expect(
        matchMedicationCatalogRecord('Loratadine / Pseudoephedrine', const [
          MedicationCatalogRecord(rxcui: 'brand-only', name: 'Claritin-D'),
        ])?.rxcui,
        'brand-only',
      );
    });

    test('a different combination or a stray D token is not equivalent', () {
      for (final name in [
        'Loratadine / Phenylephrine Oral Tablet',
        'Pseudoephedrine 240 MG Oral Tablet',
        'Loratadine / Pseudoephedrine / Acetaminophen Oral Tablet',
        'Vitamin D / Loratadine [Claritin]',
      ]) {
        expect(
          matchMedicationCatalogRecord('Claritin-D', [
            MedicationCatalogRecord(rxcui: 'unrelated', name: name),
          ]),
          isNull,
          reason: name,
        );
      }
    });

    test('24-hour OCR context selects the actual photo product', () {
      expect(
        matchMedicationCatalogRecord(
          'Claritin-D',
          [twelveHour, twentyFourHour],
          extractedText:
              'Claritin-D 24 HOUR\npseudoephedrine subq...240 mg/nasal '
              'decongestant\nloratadine 10 mg/antihistamine',
        )?.rxcui,
        '1242391',
      );
    });

    test(
      '12-hour OCR context does not select the alphabetically first product',
      () {
        expect(
          matchMedicationCatalogRecord(
            'Claritin-D',
            [twentyFourHour, twelveHour],
            extractedText:
                'Claritin D 12 hour\nLoratadine 5 mg\nPseudoephedrine 120 mg',
          )?.rxcui,
          '1242406',
        );
      },
    );

    test(
      'readable strengths distinguish variants when hours are unreadable',
      () {
        expect(
          matchMedicationCatalogRecord(
            'Loratadine / Pseudoephedrine',
            [twentyFourHour, twelveHour],
            extractedText: 'Loratadine 5 mg\nPseudoephedrine sulfate 120 mg',
          )?.rxcui,
          '1242406',
        );
        expect(
          matchMedicationCatalogRecord('Claritin-D', [
            twelveHour,
          ], extractedText: 'Loratadine 10 mg\nPseudoephedrine sulfate 240 mg'),
          isNull,
        );
      },
    );

    test('explicit duration rejects an incompatible lone D product', () {
      expect(
        matchMedicationCatalogRecord('Claritin-D24', [twelveHour]),
        isNull,
      );
      expect(
        matchMedicationCatalogRecord('Claritin-D', [
          twentyFourHour,
        ], extractedText: '12-hour Claritin-D'),
        isNull,
      );
    });

    test('brand-only text does not infer 24-hour duration or strength', () {
      expect(
        matchMedicationCatalogRecord('Claritin-D', [twelveHour])?.rxcui,
        '1242406',
      );
      expect(
        matchMedicationCatalogRecord('Claritin-D', [
          twelveHour,
        ], extractedText: 'Claritin-D\nAllergy + Congestion')?.rxcui,
        '1242406',
      );
    });
  });

  group('OCR name confidence', () {
    const channel = MethodChannel('com.mediary/medication_ocr');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var text = '';

    setUp(() {
      messenger.setMockMethodCallHandler(channel, (_) async => text);
    });
    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    Future<MedicationScanResult> scan(String value) {
      text = value;
      return const MedicationOcrDetector().detect(
        MedicationScanRequest.fromImage(
          imageBytes: Uint8List.fromList([9, 8, 7]),
          fileName: 'unhashed-photo.jpg',
        ),
      );
    }

    test('complete variant outranks earlier fuzzy and generic OCR', () async {
      final result = await scan(
        'laritin-p\nloratidine\nPseudoephedrine\nClaritin-D\nClaritin-',
      );
      expect(result.detectedMedicationName, 'Claritin-D');
      expect(result.confidence, .94);
      expect(result.hasError, isFalse);
    });

    test(
      'fuzzy names have lower confidence than literal known brands',
      () async {
        final exact = await scan('Claritin-D');
        final fuzzy = await scan('laritin-D');
        expect(fuzzy.detectedMedicationName, 'Claritin-D');
        expect(fuzzy.confidence, lessThan(exact.confidence));
        expect(fuzzy.confidence, lessThan(.9));
      },
    );

    test(
      'literal unknown text remains low confidence for catalog verification',
      () async {
        final result = await scan('Qzxv label');
        expect(result.detectedMedicationName, 'Qzxv label');
        expect(result.confidence, lessThan(.5));
        expect(
          matchMedicationCatalogRecord(result.detectedMedicationName, const [
            MedicationCatalogRecord(rxcui: 'plain', name: 'Claritin'),
          ]),
          isNull,
        );
      },
    );

    test(
      'incomplete suffix and empty OCR retain uncertain or error results',
      () async {
        final ambiguous = await scan('laritin-p');
        expect(ambiguous.detectedMedicationName, isEmpty);
        expect(ambiguous.confidence, .25);
        final empty = await scan('');
        expect(empty.detectedMedicationName, isEmpty);
        expect(empty.confidence, 0);
        expect(empty.hasError, isTrue);
      },
    );
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
