import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/app_theme.dart';
import 'package:mediary/main.dart';

void main() {
  testWidgets('denied camera dialog keeps content and actions usable at 3x', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(3)),
          child: child!,
        ),
        home: AuthenticatedHome(
          email: 'person@example.com',
          cameraPermissionRequester: () async => CameraAccessState.denied,
          useSidebarNavigation: false,
        ),
      ),
    );
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('cameraAlternativeChoosePhotoButton')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(
      find.byKey(const Key('cameraAlternativeOkButton')),
    );
    await tester.tap(find.byKey(const Key('cameraAlternativeOkButton')));
    await tester.pumpAndSettle();
    expect(find.text('Camera access unavailable'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
