import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/app_controls.dart';
import 'package:mediary/app_theme.dart';
import 'package:mediary/data/mediary_repository.dart';
import 'package:mediary/data/medication_catalog_client.dart';
import 'package:mediary/medication_scan.dart';
import 'package:mediary/scanner_screens.dart';

const _rawAdvil = '''Advil
buprofen Tablets, 200mg__ .
Pain Reliever/ Fever Reducer (NSap)
Drug Fac
Ibuprofen Tablets, 200 mg .
Active ing ent (in each tablet | '1Y
Ibuprofen Tablets, 200 mg
Drug Facts
Active ingredient (in each tablet)
Ibuprofen 200 mg
Uses
Pain Reliever/ Fever Reducer''';
const _advil = MedicationCatalogRecord(
  rxcui: '153010',
  name: 'Ibuprofen 200 MG Oral Tablet [Advil]',
  genericName: 'ibuprofen',
  strength: '200 mg',
  form: 'oral tablet',
);
const _scan = MedicationScanResult(
  imageUrl: '',
  extractedText: _rawAdvil,
  detectedMedicationName: 'Advil',
  confidence: .94,
);

Widget _harness({
  MedicationScanResult result = _scan,
  MedicationCatalogRecord? medication = _advil,
  double textScale = 1,
  Future<String> Function(ScanWrite)? onSave,
  Future<bool> Function(ScanScheduleData)? onSchedule,
  VoidCallback? onAdded,
  VoidCallback? onSearch,
}) => MaterialApp(
  theme: AppTheme.dark,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: ScanResultScreen(
    key: const Key('review'),
    medication: medication,
    scanResult: result,
    onScanReady: onSave,
    onScheduleConfirmed: onSchedule,
    onAdded: onAdded,
    onSearchMedication: onSearch,
    now: DateTime(2026, 10, 11, 8),
    bottomNavigationInset: 0,
  ),
);

Future<void> _reveal(WidgetTester tester, Finder target) async {
  final scroll = find
      .descendant(
        of: find.byKey(const Key('scanResultScrollView')),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(target, 140, scrollable: scroll);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final scenario in [
      (const Size(320, 640), 1.0),
      (const Size(320, 640), 3.0),
      (const Size(430, 932), 1.0),
      (const Size(568, 320), 3.0),
      (const Size(1440, 900), 1.0),
      (const Size(1440, 900), 3.0),
    ]) {
      testWidgets(
        'label facts and original text remain usable on $platform at ${scenario.$1} with ${scenario.$2}x text',
        (tester) async {
          tester.view.physicalSize = scenario.$1;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(_harness(textScale: scenario.$2));
          await tester.pumpAndSettle();
          await _reveal(tester, find.text('153010'));
          expect(find.text('153010'), findsOneWidget);
          final name = find.byKey(const Key('scanLabelName'));
          await _reveal(tester, name);
          expect(
            find.descendant(of: name, matching: find.text('Advil')),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byKey(const Key('scanLabelIngredients')),
              matching: find.text('Ibuprofen'),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byKey(const Key('scanLabelStrength')),
              matching: find.text('200 mg'),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byKey(const Key('scanLabelForm')),
              matching: find.text('Tablet'),
            ),
            findsOneWidget,
          );
          expect(find.byKey(const Key('scanOriginalTextPanel')), findsNothing);
          final toggle = find.byKey(const Key('scanLabelTextToggle'));
          await _reveal(tester, toggle);
          expect(tester.getSize(toggle).height, greaterThanOrEqualTo(44));
          await tester.tap(toggle);
          await tester.pumpAndSettle();
          final panel = find.byKey(const Key('scanOriginalTextPanel'));
          expect(tester.getSize(panel).height, lessThanOrEqualTo(240));
          expect(
            tester.widget<SelectableText>(find.byType(SelectableText)).data,
            _rawAdvil,
          );
          await _reveal(tester, toggle);
          await tester.tap(toggle);
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('scanOriginalTextPanel')), findsNothing);
          await _reveal(tester, find.text('1 tablet'));
          expect(find.text('1 capsule'), findsNothing);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(platform),
      );
    }
  }

  testWidgets('high name confidence never automatically expands noisy OCR', (
    tester,
  ) async {
    final text = List.filled(300, _rawAdvil).join('\n');
    final writes = <ScanWrite>[];
    await tester.pumpWidget(
      _harness(
        result: MedicationScanResult(
          imageUrl: '',
          extractedText: text,
          detectedMedicationName: 'Advil',
          confidence: .94,
        ),
        onSave: (scan) async {
          writes.add(scan);
          return 'scan-id';
        },
      ),
    );
    await tester.pumpAndSettle();
    await _reveal(tester, find.byKey(const Key('scanExtractedTextCard')));
    expect(find.byType(SelectableText), findsNothing);
    expect(writes.single.extractedText, text);
    expect(writes.single.confidence, .94);
    expect(writes.single.status, 'complete');
  });

  for (final conflict in [
    'Ibuprofen 400 mg tablets',
    'Ibuprofen 200 mg capsules',
  ]) {
    testWidgets(
      'catalog conflict $conflict requires manual review instead of scheduling',
      (tester) async {
        var schedules = 0;
        var searches = 0;
        final writes = <ScanWrite>[];
        await tester.pumpWidget(
          _harness(
            result: MedicationScanResult(
              imageUrl: '',
              extractedText: 'Advil\n$conflict',
              detectedMedicationName: 'Advil',
              confidence: .99,
            ),
            onSave: (scan) async {
              writes.add(scan);
              return 'conflict';
            },
            onSchedule: (_) async {
              schedules++;
              return true;
            },
            onSearch: () => searches++,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('MANUAL REVIEW REQUIRED'), findsOneWidget);
        expect(find.text('CATALOG MATCH'), findsNothing);
        expect(find.text('Not confirmed'), findsOneWidget);
        expect(writes.single.status, 'needsReview');
        final button = find.byKey(const Key('addScanResultButton'));
        expect(
          tester.widget<AppButton>(button).label,
          'Search RxNorm to confirm',
        );
        await tester.tap(button);
        await tester.pump();
        expect(schedules, 0);
        expect(searches, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'empty or failed OCR provides recovery without inventing label facts',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          medication: null,
          result: const MedicationScanResult(
            imageUrl: '',
            extractedText: '',
            detectedMedicationName: '',
            confidence: 0,
            errorMessage: 'Retake the photo.',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _reveal(tester, find.byKey(const Key('scanLabelReviewMessage')));
      expect(find.text('Retake the photo.'), findsOneWidget);
      expect(find.byKey(const Key('scanLabelTextToggle')), findsNothing);
      expect(find.text('SET YOUR SCHEDULE'), findsNothing);
      expect(find.text('RxNorm'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a new scan refreshes label facts and closes the original-text panel',
    (tester) async {
      await tester.pumpWidget(_harness());
      final toggle = find.byKey(const Key('scanLabelTextToggle'));
      await _reveal(tester, toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('scanOriginalTextPanel')), findsOneWidget);
      const next = MedicationScanResult(
        imageUrl: '',
        extractedText: 'Tylenol\nAcetaminophen 500mg capsules',
        detectedMedicationName: 'Tylenol',
        confidence: .94,
      );
      const medication = MedicationCatalogRecord(
        rxcui: 'next',
        name: 'Tylenol',
        genericName: 'acetaminophen',
        strength: '500mg',
        form: 'capsule',
      );
      await tester.pumpWidget(_harness(result: next, medication: medication));
      await tester.pumpAndSettle();
      await _reveal(tester, find.byKey(const Key('scanLabelName')));
      expect(
        find.descendant(
          of: find.byKey(const Key('scanLabelName')),
          matching: find.text('Tylenol'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('scanOriginalTextPanel')), findsNothing);
      await _reveal(tester, find.text('1 capsule'));
      expect(find.text('1 tablet'), findsNothing);
    },
  );

  testWidgets(
    'equivalent catalog rebuilds preserve the selected dose and avoid duplicate scan saves',
    (tester) async {
      final writes = <ScanWrite>[];
      Future<String> save(ScanWrite scan) async {
        writes.add(scan);
        return 'id';
      }

      await tester.pumpWidget(_harness(onSave: save));
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('1 tablet'));
      await tester.tap(find.text('1 tablet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2 tablets'));
      await tester.pumpAndSettle();
      final equivalent = MedicationCatalogRecord(
        rxcui: _advil.rxcui,
        name: _advil.name,
        genericName: _advil.genericName,
        strength: _advil.strength,
        form: _advil.form,
      );
      await tester.pumpWidget(_harness(medication: equivalent, onSave: save));
      await tester.pumpAndSettle();
      expect(find.text('2 tablets'), findsOneWidget);
      expect(writes, hasLength(1));
    },
  );

  testWidgets(
    'a late save for an earlier scan cannot mark the next scan as saved',
    (tester) async {
      final firstSave = Completer<String>();
      final writes = <ScanWrite>[];
      Future<String> save(ScanWrite scan) {
        writes.add(scan);
        return writes.length == 1
            ? firstSave.future
            : Future.value('second-id');
      }

      await tester.pumpWidget(_harness(onSave: save));
      await tester.pump();
      const next = MedicationScanResult(
        imageUrl: '',
        extractedText: 'Qzxv',
        detectedMedicationName: '',
        confidence: .25,
      );
      await tester.pumpWidget(
        _harness(result: next, medication: null, onSave: save),
      );
      firstSave.complete('first-id');
      await tester.pumpAndSettle();
      expect(writes, hasLength(2));
      expect(writes.last.extractedText, 'Qzxv');
      expect(writes.last.id, isNull);
      expect(writes.last.status, 'needsReview');
    },
  );

  testWidgets('catalog confirmation updates the same photo record', (
    tester,
  ) async {
    final writes = <ScanWrite>[];
    Future<String> save(ScanWrite scan) async {
      writes.add(scan);
      return 'same-photo';
    }

    await tester.pumpWidget(_harness(medication: null, onSave: save));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_harness(onSave: save));
    await tester.pumpAndSettle();
    expect(writes.map((scan) => scan.status), ['needsReview', 'complete']);
    expect(writes.last.id, 'same-photo');
  });

  for (final score in [double.nan, double.infinity, -.5, 1.5]) {
    testWidgets(
      'malformed confidence $score does not crash review or store an invalid value',
      (tester) async {
        final writes = <ScanWrite>[];
        await tester.pumpWidget(
          _harness(
            result: MedicationScanResult(
              imageUrl: '',
              extractedText: _rawAdvil,
              detectedMedicationName: 'Advil',
              confidence: score,
            ),
            onSave: (scan) async {
              writes.add(scan);
              return 'id';
            },
          ),
        );
        await tester.pumpAndSettle();
        expect(writes.single.confidence, inInclusiveRange(0, 1));
        expect(writes.single.confidence.isFinite, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
