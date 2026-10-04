import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/data/medication_catalog_client.dart';
import 'package:mediary/in_app_page.dart';
import 'package:mediary/library_screens.dart';

class _RecoveryCatalogClient implements MedicationCatalogClient {
  final queries = <String>[];

  @override
  Future<CatalogSearchPage> search(String query) async {
    queries.add(query);
    if (query == 'failed') {
      throw const MedicationCatalogException('offline');
    }
    return CatalogSearchPage(
      sourceVersion: 'test',
      items: query == 'ibuprofen'
          ? const [MedicationCatalogRecord(rxcui: '1', name: 'Ibuprofen')]
          : const [],
    );
  }

  @override
  Future<MedicationCatalogRecord> getDetails(String rxcui) async =>
      MedicationCatalogRecord(rxcui: rxcui, name: 'Ibuprofen');
}

// Match the scan fallback's direct pushInAppPage entry. Do not wrap the pushed
// library in Material or Scaffold: its search must work on a standalone route.
void main() {
  for (final size in const [Size(320, 640), Size(568, 320), Size(1440, 900)]) {
    for (final initialQuery in ['', 'unknown', 'failed']) {
      testWidgets('standalone library recovers from "$initialQuery" at $size', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final client = _RecoveryCatalogClient();
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => pushInAppPage<void>(
                    context,
                    builder: (routeContext) => MedicationLibraryScreen(
                      catalogClient: client,
                      initialQuery: initialQuery,
                      bottomPadding: 32,
                      onBack: () => Navigator.of(routeContext).maybePop(),
                    ),
                  ),
                  child: const Text('Search manually'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Search manually'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final search = find.byKey(const Key('medicationSearchField'));
        expect(
          find.ancestor(of: search, matching: find.byType(Material)),
          findsWidgets,
        );
        expect(client.queries, initialQuery.isEmpty ? isEmpty : [initialQuery]);

        if (initialQuery.isNotEmpty) {
          await tester.tap(
            find.byKey(const Key('liquidGlassSearchClearButton')),
          );
          await tester.pumpAndSettle();
          expect(tester.widget<TextField>(search).controller!.text, isEmpty);
        }
        await tester.enterText(search, 'ibuprofen');
        await tester.pumpAndSettle();
        final scrollable = find
            .descendant(
              of: find.byKey(const Key('medicationLibraryScrollView')),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.text('Ibuprofen'),
          120,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();
        expect(find.text('Ibuprofen'), findsOneWidget);
        expect(client.queries.last, 'ibuprofen');
        expect(tester.takeException(), isNull);
        final back = find.byKey(const Key('medicationLibraryBackButton'));
        await tester.scrollUntilVisible(back, -120, scrollable: scrollable);
        await tester.pumpAndSettle();
        await tester.tap(back);
        await tester.pumpAndSettle();
        expect(find.text('Search manually'), findsOneWidget);
      });
    }
  }
}
