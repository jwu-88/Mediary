import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/profile_screen.dart';

void main() {
  Widget buildAccount({
    VoidCallback? onBack,
    Future<void> Function()? onSignOut,
  }) {
    return MaterialApp(
      home: ProfileScreen(
        email: 'jayden@example.com',
        displayName: 'Jayden Wu',
        pageTitle: 'Account',
        bottomPadding: 0,
        onBack: onBack,
        onSignOut: onSignOut,
      ),
    );
  }

  testWidgets('account contains identity and health information only', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildAccount());

    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Jayden Wu'), findsOneWidget);
    expect(find.text('jayden@example.com'), findsOneWidget);
    expect(find.text('Health Details'), findsOneWidget);
    expect(find.text('3 active'), findsOneWidget);
    expect(find.text('Care Team'), findsOneWidget);
    expect(find.text('Health Report'), findsOneWidget);
    expect(find.text('Emergency Profile'), findsOneWidget);

    expect(find.text('App Preferences'), findsNothing);
    expect(find.text('Dose Reminders'), findsNothing);
    expect(find.text('Privacy & Data'), findsNothing);
    expect(find.byKey(const Key('profileAccountButton')), findsNothing);
    expect(find.byKey(const Key('accountSignOutButton')), findsNothing);
  });

  testWidgets('in-page liquid glass back button invokes callback', (
    tester,
  ) async {
    var backCount = 0;
    await tester.pumpWidget(buildAccount(onBack: () => backCount += 1));

    expect(find.byKey(const Key('accountBackButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('accountBackButton')));
    await tester.pump();
    expect(backCount, 1);
  });

  testWidgets('sign out is separated, conditional, and functional', (
    tester,
  ) async {
    var signOutCount = 0;
    await tester.pumpWidget(
      buildAccount(onSignOut: () async => signOutCount += 1),
    );

    final signOut = find.byKey(const Key('accountSignOutButton'));
    await tester.ensureVisible(signOut);
    await tester.pumpAndSettle();
    expect(signOut, findsOneWidget);

    await tester.tap(signOut);
    await tester.pumpAndSettle();
    expect(signOutCount, 1);
  });
}
