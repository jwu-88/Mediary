import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/add_medication_screen.dart';
import 'package:mediary/data/medication_catalog_client.dart';

class _FakeCatalogClient implements MedicationCatalogClient {
  final requests = <String>[];
  final responses = <String, CatalogSearchPage>{};

  @override
  Future<CatalogSearchPage> search(String query) async {
    requests.add(query);
    return responses[query] ??
        CatalogSearchPage(items: const [], sourceVersion: 'test');
  }

  @override
  Future<MedicationCatalogRecord> getDetails(String rxcui) async {
    return MedicationCatalogRecord(rxcui: rxcui, name: 'Medication');
  }
}

void main() {
  testWidgets('debounces catalog searches and stores the selected RxCUI', (
    tester,
  ) async {
    final client = _FakeCatalogClient()
      ..responses['metformin'] = const CatalogSearchPage(
        sourceVersion: 'test-version',
        items: [
          MedicationCatalogRecord(
            rxcui: '6809',
            name: 'Metformin 500 MG Oral Tablet',
            genericName: 'metformin',
            strength: '500 mg',
            form: 'Tablet',
          ),
        ],
      );
    await tester.pumpWidget(
      MaterialApp(home: AddMedicationScreen(catalogClient: client)),
    );

    await tester.enterText(
      find.byKey(const Key('medicationSearchField')),
      'metformin',
    );
    await tester.pump(const Duration(milliseconds: 299));
    expect(client.requests, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(client.requests, ['metformin']);
    expect(find.text('Metformin 500 MG Oral Tablet'), findsOneWidget);

    await tester.tap(find.byKey(const Key('medicationOption_6809')));
    await tester.pump();
    expect(find.text('1 Selected'), findsOneWidget);
  });

  testWidgets('a stale catalog response cannot replace a newer search', (
    tester,
  ) async {
    final pending = <String, Completer<CatalogSearchPage>>{};
    final client = _FakeCatalogClient();
    client.responses['ibuprofen'] = const CatalogSearchPage(
      sourceVersion: 'test',
      items: [MedicationCatalogRecord(rxcui: '1', name: 'Ibuprofen')],
    );
    final delayed = _DelayedCatalogClient(pending, client);
    await tester.pumpWidget(
      MaterialApp(home: AddMedicationScreen(catalogClient: delayed)),
    );

    await tester.enterText(
      find.byKey(const Key('medicationSearchField')),
      'metformin',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
      find.byKey(const Key('medicationSearchField')),
      'ibuprofen',
    );
    await tester.pump(const Duration(milliseconds: 300));
    pending['ibuprofen']!.complete(client.responses['ibuprofen']!);
    await tester.pump();
    pending['metformin']!.complete(
      const CatalogSearchPage(
        sourceVersion: 'test',
        items: [MedicationCatalogRecord(rxcui: '2', name: 'Metformin')],
      ),
    );
    await tester.pump();
    expect(find.text('Ibuprofen'), findsOneWidget);
    expect(find.text('Metformin'), findsNothing);
  });
}

class _DelayedCatalogClient implements MedicationCatalogClient {
  _DelayedCatalogClient(this.pending, this.delegate);

  final Map<String, Completer<CatalogSearchPage>> pending;
  final _FakeCatalogClient delegate;

  @override
  Future<CatalogSearchPage> search(String query) {
    return (pending[query] = Completer<CatalogSearchPage>()).future;
  }

  @override
  Future<MedicationCatalogRecord> getDetails(String rxcui) =>
      delegate.getDetails(rxcui);
}
