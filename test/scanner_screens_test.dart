import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/data/medication_catalog_client.dart';
import 'package:mediary/medication_scan.dart';
import 'package:mediary/scanner_screens.dart';

void main() {
  testWidgets('scanner uses a black camera and platform controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var captures = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MedicationScannerScreen(
          accessState: ScannerAccessState.granted,
          onRequestAccess: () async {},
          onCapture: () async {
            captures++;
          },
          bottomNavigationInset: 0,
        ),
      ),
    );

    final background = tester.widget<ColoredBox>(
      find.byKey(const Key('scannerCameraBackground')),
    );
    expect(background.color, Colors.black);
    expect(find.text('Scan Medication'), findsNothing);
    expect(find.text('LABEL'), findsNothing);
    expect(find.text('PILL'), findsNothing);
    expect(find.text('BARCODE'), findsNothing);
    expect(find.byKey(const Key('scannerTorchButton')), findsNothing);
    expect(find.byKey(const Key('scannerScanFrame')), findsNothing);
    expect(find.byKey(const Key('closeScannerButton')), findsNothing);
    expect(find.byKey(const Key('pasteScannerImageButton')), findsNothing);
    if (kIsWeb) {
      expect(find.text('Choose Photo'), findsOneWidget);
      expect(find.text('Capture'), findsOneWidget);
      expect(find.text('Scan Barcode'), findsOneWidget);
    }

    final cameraSurface = tester.widget<DecoratedBox>(
      find.byKey(const Key('scannerCameraPanel')),
    );
    final cameraDecoration = cameraSurface.decoration as BoxDecoration;
    expect(cameraDecoration.border, isNotNull);
    expect(cameraDecoration.border!.top.width, closeTo(.8, .01));

    final cameraPanel = tester.getRect(
      find.byKey(const Key('scannerCameraPanel')),
    );
    expect(cameraPanel.center.dx, closeTo(201, 1));
    expect(cameraPanel.bottom, lessThanOrEqualTo(874));

    await tester.tap(find.byKey(const Key('scannerBarcodeButton')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Scan Barcode'), findsNothing);
    expect(find.text('Center the barcode'), findsNothing);

    await tester.tap(find.byKey(const Key('openScannerPhotosButton')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(captures, 1);
  });

  testWidgets('scan result actions update state and call navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var backs = 0;
    var rescans = 0;
    var additions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ScanResultScreen(
          medication: const MedicationCatalogRecord(
            rxcui: '723',
            name: 'Amoxicillin',
            strength: '500 mg',
            form: 'capsule',
          ),
          onBack: () => backs++,
          onScanAgain: () => rescans++,
          onAdded: () => additions++,
          bottomNavigationInset: 0,
        ),
      ),
    );

    expect(find.text('Review Medication'), findsOneWidget);
    expect(find.text('SET YOUR SCHEDULE'), findsOneWidget);

    await tester.tap(find.text('1 capsule'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 capsules'));
    await tester.pumpAndSettle();
    expect(find.text('2 capsules'), findsOneWidget);

    await tester.tap(find.byKey(const Key('addScanResultButton')));
    await tester.pump();
    expect(find.text('Added to Calendar'), findsOneWidget);
    expect(additions, 1);

    await tester.tap(find.byKey(const Key('scanAgainButton')));
    await tester.tap(find.byKey(const Key('scanResultBackButton')));
    expect(rescans, 1);
    expect(backs, 1);
  });

  testWidgets('scan result uses uppercase section subtitles', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ScanResultScreen(
          medication: const MedicationCatalogRecord(
            rxcui: '723',
            name: 'Ibuprofen 200 MG Oral Capsule [Advil]',
            genericName: 'ibuprofen',
            strength: '200 mg',
            form: 'capsule',
            route: 'oral',
            indications: ['Temporary relief of minor aches and pains.'],
            warnings: ['May cause an allergic reaction.'],
          ),
          scanResult: const MedicationScanResult(
            imageUrl: '',
            extractedText: 'Advil (ibuprofen) 200 mg tablet',
            detectedMedicationName: 'Advil',
            confidence: .99,
          ),
          bottomNavigationInset: 0,
        ),
      ),
    );

    expect(find.text('CATALOG MATCH'), findsOneWidget);
    expect(find.text('200 MG · CAPSULE'), findsOneWidget);
    expect(find.text('DETECTED LABEL TEXT'), findsOneWidget);
    expect(find.text('99% CONFIDENCE'), findsOneWidget);
    expect(find.text('MEDICATION INFORMATION'), findsOneWidget);
    expect(find.text('GENERIC NAME'), findsOneWidget);
    expect(find.text('COMMON USES'), findsOneWidget);
    expect(find.text('WARNINGS'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('scanResultScrollView')),
      const Offset(0, -1000),
    );
    await tester.pump();
    expect(find.text('SET YOUR SCHEDULE'), findsOneWidget);
  });

  testWidgets('choose photo uses the gallery callback instead of capture', (
    tester,
  ) async {
    var captures = 0;
    var photoSelections = 0;
    var photoSourcePrompts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MedicationScannerScreen(
          accessState: ScannerAccessState.granted,
          onRequestAccess: () async {},
          onCapture: () async {
            captures++;
          },
          onChoosePhoto: () async {
            photoSelections++;
          },
          onChoosePhotoOptions: () async {
            photoSourcePrompts++;
          },
          bottomNavigationInset: 0,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('openScannerPhotosButton')));
    await tester.pump(const Duration(milliseconds: 600));

    expect(photoSelections, 0);
    expect(captures, 0);
    expect(photoSourcePrompts, 1);
  });

  testWidgets('camera permission view offers alternate scan options', (
    tester,
  ) async {
    var alternativesOpened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MedicationScannerScreen(
          accessState: ScannerAccessState.denied,
          onRequestAccess: () async {},
          onCapture: () async {},
          onUseOtherScanOptions: () async {
            alternativesOpened++;
          },
          bottomNavigationInset: 0,
        ),
      ),
    );

    expect(find.byKey(const Key('cameraNoAccessButton')), findsOneWidget);
    await tester.tap(find.byKey(const Key('cameraNoAccessButton')));
    await tester.pump();
    expect(alternativesOpened, 1);
  });

  testWidgets('a rejected schedule stays retryable', (tester) async {
    var additions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ScanResultScreen(
          medication: const MedicationCatalogRecord(
            rxcui: '723',
            name: 'Amoxicillin',
            strength: '500 mg',
            form: 'capsule',
          ),
          onScheduleConfirmed: (_) async => false,
          onAdded: () => additions++,
          bottomNavigationInset: 0,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('addScanResultButton')));
    await tester.pump();
    expect(find.text('Add to Calendar'), findsOneWidget);
    expect(find.text('Added to Calendar'), findsNothing);
    expect(additions, 0);
  });
}
