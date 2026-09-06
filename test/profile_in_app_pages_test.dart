import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/in_app_page.dart';
import 'package:mediary/liquid_glass_back_button.dart';
import 'package:mediary/profile_screen.dart';

void main() {
  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget buildProfile({Future<void> Function()? onSignOut}) {
    return MaterialApp(
      home: ProfileScreen(
        email: 'jayden@example.com',
        displayName: 'Jayden Wu',
        bottomPadding: 0,
        onSignOut: onSignOut,
      ),
    );
  }

  testWidgets('health report is a routed page and copy feedback is inline', (
    tester,
  ) async {
    usePhoneSize(tester);
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(buildProfile());
    await tester.tap(find.text('Health Report'));
    await tester.pumpAndSettle();

    expect(find.byType(InAppPageScaffold), findsOneWidget);
    expect(find.byKey(const Key('profileInfoPage')), findsOneWidget);
    expect(find.byType(LiquidGlassBackButton), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(find.textContaining('Mediary Health Report'), findsOneWidget);

    await tester.tap(find.byKey(const Key('copyProfileInfoButton')));
    await tester.pumpAndSettle();

    expect(copiedText, contains('Mediary Health Report'));
    expect(find.byKey(const Key('profileInlineFeedback')), findsOneWidget);
    expect(find.text('Health Report copied.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('edit actions use pages and preserve their return values', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(buildProfile());

    await tester.tap(find.byKey(const Key('editProfileButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('profileNameField')),
      'Jayden Reed',
    );
    await tester.tap(find.byKey(const Key('cancelProfileEditButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('discardProfileChangesPage')), findsOneWidget);
    expect(find.byType(InAppPageScaffold), findsOneWidget);
    expect(find.byType(CupertinoAlertDialog), findsNothing);

    await tester.tap(find.byKey(const ValueKey('inAppOption-Keep Editing')));
    await tester.pumpAndSettle();
    expect(find.text('EDITING'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('profileNameField')))
          .controller!
          .text,
      'Jayden Reed',
    );

    await tester.ensureVisible(find.byKey(const Key('addAllergyButton')));
    await tester.tap(find.byKey(const Key('addAllergyButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('addAllergyPage')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('allergyField')), 'Latex');
    await tester.tap(find.byKey(const Key('confirmAddAllergyButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('allergy-Latex')), findsOneWidget);
  });

  testWidgets('profile photo editor is routed with glass back navigation', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(buildProfile());

    await tester.tap(find.byKey(const Key('editProfileButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('changeProfilePhotoButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profilePhotoPage')), findsOneWidget);
    expect(find.byType(InAppPageScaffold), findsOneWidget);
    expect(find.byType(LiquidGlassBackButton), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.byKey(const Key('useProfileInitialsButton')));
    await tester.pumpAndSettle();
    expect(find.text('EDITING'), findsOneWidget);
  });

  testWidgets('profile photo editor rejects insecure image links', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(buildProfile());

    await tester.tap(find.byKey(const Key('editProfileButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('changeProfilePhotoButton')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('profilePhotoUrlField')),
      'http://example.com/photo.jpg',
    );
    await tester.tap(find.byKey(const Key('saveProfilePhotoButton')));
    await tester.pump();

    expect(
      find.text('Use a Mediary Storage or Google profile image link.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('profilePhotoPage')), findsOneWidget);
  });

  testWidgets('failed sign out reports inline without a snackbar', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      buildProfile(onSignOut: () async => throw Exception('failed')),
    );

    final signOut = find.byKey(const Key('accountSignOutButton'));
    await tester.ensureVisible(signOut);
    await tester.tap(signOut);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profileInlineFeedback')), findsOneWidget);
    expect(find.text('Could not sign out. Try again.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });
}
