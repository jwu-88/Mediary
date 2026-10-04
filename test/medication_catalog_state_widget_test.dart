import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/add_medication_screen.dart';
import 'package:mediary/data/medication_catalog_client.dart';

class _StateCatalogClient implements MedicationCatalogClient {
  _StateCatalogClient(this.failure);

  final Object? failure;

  @override
  Future<CatalogSearchPage> search(String query) async {
    if (failure != null) throw failure!;
    return const CatalogSearchPage(items: [], sourceVersion: 'test');
  }

  @override
  Future<MedicationCatalogRecord> getDetails(String rxcui) async {
    return MedicationCatalogRecord(rxcui: rxcui, name: 'Medication');
  }
}

class _RecoveringCatalogClient implements MedicationCatalogClient {
  final requests = <String>[];
  final pending = <String, Completer<CatalogSearchPage>>{};
  bool fail = true;

  @override
  Future<CatalogSearchPage> search(String query) async {
    requests.add(query);
    if (query == 'pending') {
      return (pending[query] = Completer<CatalogSearchPage>()).future;
    }
    if (fail) throw const MedicationCatalogException('offline');
    return CatalogSearchPage(
      sourceVersion: 'test',
      items: query == 'unknown'
          ? const []
          : const [MedicationCatalogRecord(rxcui: '1', name: 'Ibuprofen')],
    );
  }

  @override
  Future<MedicationCatalogRecord> getDetails(String rxcui) async =>
      MedicationCatalogRecord(rxcui: rxcui, name: 'Ibuprofen');
}

void main() {
  testWidgets('retry repeats the failed query and permits selection', (
    tester,
  ) async {
    final client = _RecoveringCatalogClient();
    await tester.pumpWidget(
      MaterialApp(home: AddMedicationScreen(catalogClient: client)),
    );
    await tester.enterText(
      find.byKey(const Key('medicationSearchField')),
      'ibuprofen',
    );
    await tester.pumpAndSettle();
    expect(find.text('Catalog unavailable'), findsOneWidget);
    client.fail = false;
    await tester.tap(find.byKey(const Key('retryMedicationSearchButton')));
    await tester.pumpAndSettle();
    expect(client.requests, ['ibuprofen', 'ibuprofen']);
    await tester.tap(find.byKey(const Key('medicationOption_1')));
    await tester.pumpAndSettle();
    expect(find.text('1 Selected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clear resets failed and empty searches before searching again', (
    tester,
  ) async {
    final client = _RecoveringCatalogClient();
    await tester.pumpWidget(
      MaterialApp(home: AddMedicationScreen(catalogClient: client)),
    );
    final search = find.byKey(const Key('medicationSearchField'));
    await tester.enterText(search, 'ibuprofen');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear Search'));
    await tester.pumpAndSettle();
    expect(find.text('Catalog unavailable'), findsNothing);
    expect(find.text('Search the medication catalog'), findsOneWidget);
    expect(tester.widget<TextField>(search).controller!.text, isEmpty);

    client.fail = false;
    await tester.enterText(search, 'unknown');
    await tester.pumpAndSettle();
    expect(find.text('No Medications Found'), findsOneWidget);
    await tester.tap(find.text('Clear Search'));
    await tester.pumpAndSettle();
    await tester.enterText(search, 'ibuprofen');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('medicationOption_1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clearing a pending search ignores its late failure', (
    tester,
  ) async {
    final client = _RecoveringCatalogClient()..fail = false;
    await tester.pumpWidget(
      MaterialApp(home: AddMedicationScreen(catalogClient: client)),
    );
    final search = find.byKey(const Key('medicationSearchField'));
    await tester.enterText(search, 'pending');
    await tester.pump(const Duration(milliseconds: 180));
    await tester.tap(find.byKey(const Key('liquidGlassSearchClearButton')));
    await tester.pump();
    client.pending['pending']!.completeError(
      const MedicationCatalogException('late failure'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Catalog unavailable'), findsNothing);
    expect(find.text('Search the medication catalog'), findsOneWidget);
    await tester.enterText(search, 'ibuprofen');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('medicationOption_1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('live picker starts with an explicit search prompt', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AddMedicationScreen(catalogClient: _StateCatalogClient(null)),
      ),
    );

    expect(find.text('Search the medication catalog'), findsOneWidget);
    expect(find.text('Amoxicillin'), findsNothing);
  });

  testWidgets('live picker renders a no-results state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AddMedicationScreen(catalogClient: _StateCatalogClient(null)),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('medicationSearchField')),
      'unknown',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('No Medications Found'), findsOneWidget);
    expect(find.text('Clear Search'), findsOneWidget);
  });

  testWidgets('live picker distinguishes network and rate-limit errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AddMedicationScreen(
          key: const ValueKey('offline-picker'),
          catalogClient: _StateCatalogClient(
            const MedicationCatalogException('offline'),
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('medicationSearchField')),
      'ibuprofen',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('Catalog unavailable'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: AddMedicationScreen(
          key: const ValueKey('rate-limited-picker'),
          catalogClient: _StateCatalogClient(
            const MedicationCatalogRateLimitException(),
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('medicationSearchField')),
      'ibuprofen',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('Catalog limit reached'), findsOneWidget);
  });
}
