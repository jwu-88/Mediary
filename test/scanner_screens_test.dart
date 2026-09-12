import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/scanner_screens.dart';

void main() {
  testWidgets('scanner uses a black camera and icon-only controls', (
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
          onClose: () {},
          onCapture: () => captures++,
          bottomNavigationInset: 0,
        ),
      ),
    );

    final background = tester.widget<ColoredBox>(
      find.byKey(const Key('scannerCameraBackground')),
    );
    expect(background.color, Colors.black);
    expect(find.text('Scan Medication'), findsOneWidget);
    expect(find.text('LABEL'), findsNothing);
    expect(find.text('PILL'), findsNothing);
    expect(find.text('BARCODE'), findsNothing);
    expect(find.byKey(const Key('scannerTorchButton')), findsNothing);

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
    expect(find.text('Scan Barcode'), findsOneWidget);
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
          onBack: () => backs++,
          onScanAgain: () => rescans++,
          onAdded: () => additions++,
          bottomNavigationInset: 0,
        ),
      ),
    );

    expect(find.text('Review Medication'), findsOneWidget);
    expect(find.text('Set Your Schedule'), findsOneWidget);

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
}
