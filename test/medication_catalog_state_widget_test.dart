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

void main() {
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
