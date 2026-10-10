import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/data/medication_catalog_client.dart';
import 'package:mediary/library_screens.dart';
import 'package:mediary/scanner_screens.dart';

class _RecoveringCatalog implements MedicationCatalogClient {
  bool fail = true;
  final queries = <String>[];
  final detailRequests = <String>[];
  static const medication = MedicationCatalogRecord(
    rxcui: 'test-medication',
    name: 'Ibuprofen 200 MG Oral Tablet',
    strength: '200 mg',
    form: 'Tablet',
  );

  @override
  Future<CatalogSearchPage> search(String query) async {
    queries.add(query);
    if (fail) throw const MedicationCatalogException('offline');
    return const CatalogSearchPage(items: [medication], sourceVersion: 'test');
  }

  @override
  Future<MedicationCatalogRecord> getDetails(String rxcui) async {
    detailRequests.add(rxcui);
    if (fail) throw const MedicationCatalogException('offline');
    return medication;
  }
}

void main() {
  testWidgets('library retry repeats the failed search and restores results', (
    tester,
  ) async {
    final catalog = _RecoveringCatalog();
    await tester.pumpWidget(
      MaterialApp(
        home: MedicationLibraryScreen(
          catalogClient: catalog,
          initialQuery: 'ibuprofen',
          bottomPadding: 16,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Catalog unavailable'), findsOneWidget);
    catalog.fail = false;
    final retry = find.byKey(const Key('retryLibrarySearchButton'));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(catalog.queries, ['ibuprofen', 'ibuprofen']);
    expect(find.text('Ibuprofen 200 MG Oral Tablet'), findsOneWidget);
    expect(find.text('Catalog unavailable'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clearing a saved-library error removes the failed filter', (
    tester,
  ) async {
    final catalog = _RecoveringCatalog();
    await tester.pumpWidget(
      MaterialApp(
        home: MedicationLibraryScreen(
          catalogClient: catalog,
          initialSavedMedicationIds: const {'test-medication'},
          bottomPadding: 16,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('savedMedicationsButton')));
    await tester.pumpAndSettle();
    expect(find.text('Catalog unavailable'), findsOneWidget);
    final clear = find.byKey(const Key('clearLibrarySearchButton'));
    await tester.ensureVisible(clear);
    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(find.text('Catalog unavailable'), findsNothing);
    expect(find.text('Search the medication catalog'), findsOneWidget);
    catalog.fail = false;
    final search = find.byKey(const Key('medicationSearchField'));
    await tester.ensureVisible(search);
    await tester.enterText(search, 'ibuprofen');
    await tester.pumpAndSettle();
    expect(find.text('Ibuprofen 200 MG Oral Tablet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved-library retry reloads the failed medications', (
    tester,
  ) async {
    final catalog = _RecoveringCatalog();
    await tester.pumpWidget(
      MaterialApp(
        home: MedicationLibraryScreen(
          catalogClient: catalog,
          initialSavedMedicationIds: const {'test-medication'},
          bottomPadding: 16,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('savedMedicationsButton')));
    await tester.pumpAndSettle();
    catalog.fail = false;
    final retry = find.byKey(const Key('retryLibrarySearchButton'));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(catalog.detailRequests, ['test-medication', 'test-medication']);
    expect(find.text('Ibuprofen 200 MG Oral Tablet'), findsOneWidget);
    expect(find.text('Catalog unavailable'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scan save shows progress and ignores repeated activation', (
    tester,
  ) async {
    var saves = 0;
    final saving = Completer<bool>();
    await tester.pumpWidget(
      MaterialApp(
        home: ScanResultScreen(
          medication: _RecoveringCatalog.medication,
          now: DateTime(2026, 10, 5, 9),
          bottomNavigationInset: 0,
          onScheduleConfirmed: (_) {
            saves++;
            return saving.future;
          },
        ),
      ),
    );
    final save = find.byKey(const Key('addScanResultButton'));
    await tester.tap(save);
    await tester.pump();
    expect(find.text('Adding to Calendar'), findsOneWidget);
    await tester.tap(save);
    await tester.pump();
    expect(saves, 1);
    saving.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Added to Calendar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(320, 640), Size(568, 320)]) {
    testWidgets(
      'detail recovery actions remain reachable with 3x text at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(3)),
              child: child!,
            ),
            home: MedicationDetailScreen(
              medication: _RecoveringCatalog.medication,
              onAddToSchedule: (_, _) async => true,
            ),
          ),
        );
        final add = find.byKey(const Key('addMedicationButton'));
        expect(add.hitTestable(), findsOneWidget);
        await tester.tap(add);
        await tester.pumpAndSettle();
        expect(find.text('Added to My Schedule'), findsOneWidget);
        final sideEffects = find.text('View All');
        await tester.ensureVisible(sideEffects);
        await tester.pumpAndSettle();
        expect(sideEffects.hitTestable(), findsOneWidget);
        await tester.tap(sideEffects);
        await tester.pumpAndSettle();
        final done = find.text('Done');
        await tester.scrollUntilVisible(
          done,
          160,
          scrollable: find.descendant(
            of: find.byKey(const Key('informationPageCommon Side Effects')),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        expect(done.hitTestable(), findsOneWidget);
        await tester.tap(done);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('medicationDetailScrollView')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
