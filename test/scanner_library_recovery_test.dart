import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/data/medication_catalog_client.dart';
import 'package:mediary/library_screens.dart';
import 'package:mediary/liquid_glass_back_button.dart';
import 'package:mediary/main.dart';
import 'package:mediary/medication_scan.dart';

import 'support/medication_scan_fixture.dart';

class _Detector implements MedicationScanDetector {
  _Detector(this.name);
  final String name;

  @override
  Future<MedicationScanResult> detect(MedicationScanRequest request) async =>
      MedicationScanResult(
        imageUrl: '',
        extractedText: name,
        detectedMedicationName: name,
        confidence: name.isEmpty ? 0 : .8,
      );
}

class _Catalog implements MedicationCatalogClient {
  final queries = <String>[];
  final details = <String>[];

  static const unrelated = MedicationCatalogRecord(
    rxcui: 'plain-claritin',
    name: 'Loratadine 10 MG Oral Tablet [Claritin]',
    genericName: 'loratadine',
  );
  static const correct = MedicationCatalogRecord(
    rxcui: 'claritin-d',
    name: 'Claritin-D 24 Hour',
    genericName: 'loratadine / pseudoephedrine',
  );

  @override
  Future<CatalogSearchPage> search(String query) async {
    queries.add(query);
    return CatalogSearchPage(
      items: query == 'manual clarification' ? [correct] : [unrelated],
      sourceVersion: 'test',
    );
  }

  @override
  Future<MedicationCatalogRecord> getDetails(String rxcui) async {
    details.add(rxcui);
    return rxcui == correct.rxcui ? correct : unrelated;
  }
}

void main() {
  for (final size in [const Size(402, 874), const Size(1440, 900)]) {
    testWidgets('failed scan opens working database search at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final catalog = _Catalog();
      await tester.pumpWidget(
        MaterialApp(
          home: AuthenticatedHome(
            email: 'test@example.com',
            cameraCapture: () async => medicationScanFixture,
            scanDetector: _Detector(''),
            catalogClient: catalog,
            useSidebarNavigation: size.width > 800,
            cameraPermissionRequester: () async => CameraAccessState.granted,
          ),
        ),
      );
      if (size.width > 800) {
        // The collapsed sidebar exposes the icon, not the expanded label.
        await tester.tapAt(
          Offset(
            38,
            tester.getCenter(find.byKey(const Key('webNavItem-2'))).dy,
          ),
        );
      } else {
        await tester.tap(find.text('Scan'));
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('captureMedicationButton')));
      await tester.pumpAndSettle();
      await confirmCameraPhoto(tester);
      await tester.ensureVisible(find.byKey(const Key('addScanResultButton')));
      await tester.tap(find.byKey(const Key('addScanResultButton')));
      await tester.pumpAndSettle();
      expect(find.byType(MedicationLibraryScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      final search = find.descendant(
        of: find.byType(MedicationLibraryScreen),
        matching: find.byType(TextField),
      );
      await tester.enterText(search, 'manual clarification');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(catalog.queries, contains('manual clarification'));
      expect(find.text('Claritin-D 24 Hour'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(LiquidGlassBackButton).last);
      await tester.pumpAndSettle();
      expect(find.text('Review Medication'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('a lone unrelated catalog result never confirms a scan', (
    tester,
  ) async {
    final catalog = _Catalog();
    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticatedHome(
          email: 'test@example.com',
          cameraCapture: () async => medicationScanFixture,
          scanDetector: _Detector('Claritin-D'),
          catalogClient: catalog,
          cameraPermissionRequester: () async => CameraAccessState.granted,
        ),
      ),
    );
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('captureMedicationButton')));
    await tester.pumpAndSettle();
    await confirmCameraPhoto(tester);
    expect(catalog.queries, ['Claritin-D']);
    expect(catalog.details, isEmpty);
    expect(find.text('MANUAL REVIEW REQUIRED'), findsOneWidget);
    expect(find.text('Search RxNorm to confirm'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
