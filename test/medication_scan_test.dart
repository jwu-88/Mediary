import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/data/medication_catalog_client.dart';
import 'package:mediary/medication_scan.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  group('Benadryl camera labels', () {
    test('reads brand and ingredient with common OCR substitutions', () {
      for (final text in [
        'Benadryl\nALLERGY\nDiphenhydramine HCl 25 mg',
        'Benadry1\nALLERGY',
        'Bena dryl\nALLERGY',
        // Actual Tesseract output from the supplied dim, tilted camera feed.
        'LDCIId( ) |\nl ALLERGY\n'
            '= D|ph(=nhydramme HCI 25mg | Anlahvstamlne\n'
            'Dlphenhydramme HCI 25mg | Anhhnstamlne\n'
            'Benadry! |\n_x ALLERGY |\nenadry!| |\n'
            'wipnennhydramine HCI 25mg | Antihistamine\nULTRATABS',
      ]) {
        expect(detectMedicationName(text), 'Benadryl', reason: text);
      }
      expect(
        detectMedicationName('ALLERGY\nDiphenhydramine HCl 25 mg'),
        'Diphenhydramine',
      );
      expect(
        detectMedicationName('D1phenhydramine HCl 25 mg'),
        'Diphenhydramine',
      );
    });

    test('camera fragments and symptoms never become medication names', () {
      for (final text in [
        '_— M——\n& ALLERGY\nP anhcnhydmmme HCl 25 mg | Anhhlstamme',
        'ALLERGY\nSneezing\nItchy, Watery Eyes\nULTRATABS',
        'M---\ni\no\n&\ny S\n>',
        'Allergy tablets',
        'Antihistamine 25 mg',
      ]) {
        expect(detectMedicationName(text), isNull, reason: text);
      }
    });

    test('generic Benadryl ingredient excludes combination catalog hits', () {
      expect(
        matchMedicationCatalogRecord('Diphenhydramine', const [
          MedicationCatalogRecord(
            rxcui: 'combo',
            name: 'Diphenhydramine / Phenylephrine [Benadryl]',
          ),
        ]),
        isNull,
      );
      expect(
        matchMedicationCatalogRecord('Benadryl', const [
          MedicationCatalogRecord(
            rxcui: 'combo',
            name: 'Diphenhydramine / Phenylephrine [Benadryl]',
          ),
        ]),
        isNull,
      );
      expect(
        matchMedicationCatalogRecord('Excedrin Migraine', const [
          MedicationCatalogRecord(
            rxcui: 'unknown-formula',
            name: 'Pyrilamine / Doxylamine Oral Tablet',
            synonym: 'Excedrin Migraine',
          ),
        ]),
        isNull,
      );
    });

    test('readable strength ranks the matching Benadryl product first', () {
      expect(
        matchMedicationCatalogRecord('Benadryl', const [
          MedicationCatalogRecord(
            rxcui: 'small',
            name: 'Diphenhydramine 12.5 MG Oral Tablet [Benadryl]',
          ),
          MedicationCatalogRecord(
            rxcui: 'adult',
            name: 'Diphenhydramine 25 MG Oral Tablet [Benadryl]',
          ),
        ], extractedText: 'Benadry! |\nHCl 25mg | Antihistamine')?.rxcui,
        'adult',
      );
    });

    test('unfamiliar names need readable product evidence', () {
      expect(
        detectMedicationName('Fexofenadine 180 mg tablets'),
        'Fexofenadine',
      );
      expect(detectMedicationName('Fexofenadine tablets'), 'Fexofenadine');
      expect(detectMedicationName('Qzxv label'), isNull);
    });
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

  group('Excedrin cylindrical labels', () {
    test(
      'one compressed migraine letter needs an independently read brand',
      () {
        for (final text in [
          'EXCEDRIN\nMGRAINE RELIEF',
          'EXCEDRIN\nMIGRA1NE RELIEF',
        ]) {
          expect(detectMedicationName(text), 'Excedrin Migraine', reason: text);
        }
        for (final text in [
          'MGRAINE RELIEF',
          'MIGRA1NE RELIEF',
          'EXCEDRIN\nMGRAIN RELIEF',
          'EXCEDRIN\nM1GRA1NE RELIEF',
          'EXCEDRIN\nFor migraines',
          'EXCEDRIN\nMGRAINE RELIEF\nTENSION HEADACHE',
          'EXCEDRIN\nMIGRA1NE RELIEF\nASPIRIN FREE',
          'Do not take with EXCEDRIN MGRAINE RELIEF',
        ]) {
          expect(detectMedicationName(text), isNull, reason: text);
        }
      },
    );

    test('recognizes readable formulations across wrapped and skewed text', () {
      for (final text in [
        'EXCEDRIN\nMIGRAINE RELIEF',
        'EXCEDR1N\nMIGRAINE RELIEF\nAcetaminophen 250 mg',
        'Ex cedrin\nMigraine\nAspirin 250 mg\nCaffeine 65 mg',
        'XCEDRIN\nMIGRAINE RELIEF\nAcetaminophen 250 mg\n'
            'Aspirin 250 mg\nCaffeine 65 mg',
      ]) {
        expect(detectMedicationName(text), 'Excedrin Migraine', reason: text);
      }
      expect(
        detectMedicationName('EXCEDRIN\nEXTRA STRENGTH'),
        'Excedrin Extra Strength',
      );
      expect(
        detectMedicationName(
          'EXCEDRIN\nTENSION HEADACHE\nAcetaminophen 500 mg\nCaffeine 65 mg',
        ),
        'Excedrin Tension Headache',
      );
    });

    test('keeps every ingredient when the brand is unreadable', () {
      expect(
        detectMedicationName(
          'Acetaminophen 250 mg\nAspirin 250 mg\nCaffeine 65 mg',
        ),
        'Acetaminophen / Aspirin / Caffeine',
      );
      expect(
        detectMedicationName('Acetaminophen 500 mg\nCaffe1ne 65 mg'),
        'Acetaminophen / Caffeine',
      );
      expect(
        detectMedicationName(
          'EXCEDRIN\nAcetaminophen 250 mg\nAspirin 250 mg\nCaffeine 65 mg',
        ),
        'Excedrin',
      );
    });

    test(
      'an incomplete brand or conflicting formula requires manual review',
      () {
        for (final text in [
          'EXCEDRIN',
          'EXCEDRIN\nPain reliever\n24 caplets',
          'EXCEDRIN\nAcetaminophen 500 mg\nCaffeine 65 mg',
          'EXCEDRIN\nMIGRAINE\nTENSION HEADACHE',
          'EXCEDRIN\nTENSION HEADACHE\nAspirin 250 mg',
          'EXCEDRIN\nMIGRAINE\nPhenylephrine 10 mg',
          'EXCEDRIN MIGRAINE\nADVIL 200 mg',
          'Do not take with Excedrin Migraine',
          'Compare to Excedrin Migraine',
          'Inactive ingredients: caffeine',
        ]) {
          expect(detectMedicationName(text), isNull, reason: text);
        }
      },
    );
  });

  group('Excedrin catalog formulation safety', () {
    const migraine = MedicationCatalogRecord(
      rxcui: '209468',
      name:
          'Acetaminophen 250 MG / Aspirin 250 MG / Caffeine 65 MG '
          'Oral Tablet [Excedrin]',
    );
    const tension = MedicationCatalogRecord(
      rxcui: '404172',
      name:
          'Acetaminophen 500 MG / Caffeine 65 MG '
          'Oral Tablet [Excedrin Tension Headache]',
    );

    test('known variants match their complete generic formula', () {
      for (final query in [
        'Excedrin Migraine',
        'Excedrin Extra Strength',
        'Acetaminophen / Aspirin / Caffeine',
      ]) {
        expect(
          matchMedicationCatalogRecord(query, [tension, migraine])?.rxcui,
          '209468',
          reason: query,
        );
        expect(
          matchMedicationCatalogRecord(query, [tension]),
          isNull,
          reason: query,
        );
      }
      expect(
        matchMedicationCatalogRecord('Excedrin Tension Headache', [
          migraine,
          tension,
        ])?.rxcui,
        '404172',
      );
      expect(
        matchMedicationCatalogRecord('Acetaminophen / Caffeine', [
          migraine,
          tension,
        ])?.rxcui,
        '404172',
      );
    });

    test('a plain brand needs complete ingredient evidence before selection', () {
      expect(matchMedicationCatalogRecord('Excedrin', [migraine]), isNull);
      expect(matchMedicationCatalogRecord('Excedrin', [tension]), isNull);
      expect(
        matchMedicationCatalogRecord(
          'Excedrin',
          [tension, migraine],
          extractedText:
              'EXCEDRIN\nAcetaminophen 250 mg\nAspirin 250 mg\nCaffeine 65 mg',
        )?.rxcui,
        '209468',
      );
      expect(
        matchMedicationCatalogRecord(
          'Excedrin',
          [migraine],
          extractedText: 'Do not take with acetaminophen, aspirin, or caffeine',
        ),
        isNull,
      );
    });

    test('repeated strengths stay attached to the correct ingredient', () {
      const wrongDose = MedicationCatalogRecord(
        rxcui: 'wrong-dose',
        name:
            'Acetaminophen 250 MG / Aspirin 500 MG / Caffeine 65 MG '
            'Oral Tablet [Excedrin]',
      );
      const reassignedDose = MedicationCatalogRecord(
        rxcui: 'reassigned-dose',
        name:
            'Acetaminophen 65 MG / Aspirin 250 MG / Caffeine 250 MG '
            'Oral Tablet [Excedrin]',
      );
      const label =
          'Excedrin Migraine\nAcetaminophen 250 mg\nAspirin 250 mg\nCaffeine 65 mg';
      for (final record in [wrongDose, reassignedDose]) {
        expect(
          matchMedicationCatalogRecord('Excedrin Migraine', [
            record,
          ], extractedText: label),
          isNull,
        );
      }
      expect(
        matchMedicationCatalogRecord('Excedrin Migraine', [
          wrongDose,
          reassignedDose,
          migraine,
        ], extractedText: label)?.rxcui,
        '209468',
      );
      expect(
        matchMedicationCatalogRecord('Excedrin Migraine', [
          migraine,
        ], extractedText: '$label\nAcetaminophen 500 mg'),
        isNull,
      );
    });

    test('a shortened brand synonym cannot conceal another ingredient', () {
      expect(
        matchMedicationCatalogRecord('Excedrin Migraine', const [
          MedicationCatalogRecord(
            rxcui: 'different-formula',
            name: 'Acetaminophen / Aspirin / Caffeine / Phenylephrine',
            synonym: 'Excedrin Migraine',
          ),
        ]),
        isNull,
      );
    });

    test('unknown active ingredients cannot disappear from a formula', () {
      expect(
        matchMedicationCatalogRecord('Excedrin Tension Headache', const [
          MedicationCatalogRecord(
            rxcui: 'midol',
            name:
                'Acetaminophen 500 MG / Caffeine 60 MG / '
                'Pyrilamine Maleate 15 MG Oral Tablet [Midol Complete]',
          ),
        ]),
        isNull,
      );
      expect(
        matchMedicationCatalogRecord('Benadryl', const [
          MedicationCatalogRecord(
            rxcui: 'extra-ingredient',
            name: 'Diphenhydramine / Pyrilamine Oral Tablet [Benadryl]',
          ),
        ]),
        isNull,
      );
    });

    test('a brand synonym cannot conceal missing aspirin in the formula', () {
      for (final record in const [
        MedicationCatalogRecord(
          rxcui: 'wrong-name',
          name: 'Acetaminophen 500 MG / Caffeine 65 MG Oral Tablet',
          synonym: 'Excedrin Migraine',
        ),
        MedicationCatalogRecord(
          rxcui: 'wrong-generic',
          name: 'Excedrin Migraine',
          genericName: 'acetaminophen / caffeine',
        ),
      ]) {
        expect(
          matchMedicationCatalogRecord('Excedrin Migraine', [record]),
          isNull,
        );
      }
    });

    test(
      'brand-only records and concentration denominators stay supported',
      () {
        expect(
          matchMedicationCatalogRecord('Excedrin Migraine', const [
            MedicationCatalogRecord(rxcui: 'brand', name: 'Excedrin Migraine'),
          ])?.rxcui,
          'brand',
        );
        expect(
          matchMedicationCatalogRecord('Benadryl', const [
            MedicationCatalogRecord(
              rxcui: 'liquid',
              name: 'Diphenhydramine 12.5 MG / 5 ML Oral Solution [Benadryl]',
            ),
          ])?.rxcui,
          'liquid',
        );
      },
    );
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
        matchMedicationCatalogRecord('Claritin-D', [misleadingSynonym]),
        isNull,
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

    test(
      'selected photo uses OCR evidence and keeps its original preview',
      () async {
        final bytes = Uint8List.fromList([1, 2, 3]);
        MethodCall? ocrCall;
        messenger.setMockMethodCallHandler(channel, (call) async {
          ocrCall = call;
          return 'Metformin 500 mg tablet';
        });

        final result = await const MedicationOcrDetector().detect(
          MedicationScanRequest.fromImage(
            imageBytes: bytes,
            fileName: 'advil.jpg',
          ),
        );

        expect(ocrCall?.method, 'recognize');
        expect((ocrCall?.arguments as Map)['bytes'], orderedEquals(bytes));
        expect((ocrCall?.arguments as Map)['fileName'], 'advil.jpg');
        expect(result.imageUrl, isEmpty);
        expect(result.imageBytes, same(bytes));
        expect(result.extractedText, 'Metformin 500 mg tablet');
        expect(result.detectedMedicationName, 'Metformin');
        expect(result.hasError, isFalse);
      },
    );

    test('complete variant outranks earlier fuzzy and generic OCR', () async {
      final result = await scan(
        'laritin-p\nloratidine\nPseudoephedrine\nClaritin-D\nClaritin-',
      );
      expect(result.detectedMedicationName, 'Claritin-D');
      expect(result.confidence, .94);
      expect(result.hasError, isFalse);
    });

    test('a corrected Excedrin formulation retains uncertainty', () async {
      final exact = await scan('EXCEDRIN\nMIGRAINE RELIEF');
      for (final text in [
        'EXCEDRIN\nMGRAINE RELIEF',
        'EXCEDRIN\nMIGRA1NE RELIEF',
      ]) {
        final fuzzy = await scan(text);
        expect(fuzzy.detectedMedicationName, 'Excedrin Migraine');
        expect(fuzzy.confidence, lessThan(exact.confidence));
        expect(fuzzy.confidence, lessThan(.9));
        expect(fuzzy.hasError, isFalse);
      }
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
      'unfamiliar product names remain low confidence for catalog verification',
      () async {
        final result = await scan('Fexofenadine 180 mg tablets');
        expect(result.detectedMedicationName, 'Fexofenadine');
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
      'noisy camera text asks for a retake instead of naming fragments',
      () async {
        final result = await scan('_— M——\nALLERGY\nULTRATABS');
        expect(result.detectedMedicationName, isEmpty);
        expect(result.hasError, isTrue);
        expect(result.errorMessage, contains('Retake'));
        expect(result.extractedText, contains('ALLERGY'));
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

  test(
    'unreadable image returns an error instead of a fixed medication result',
    () async {
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
    },
  );
}
