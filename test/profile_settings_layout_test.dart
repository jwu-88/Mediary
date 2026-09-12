import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/profile_screen.dart';

void main() {
  testWidgets('account content uses one left-aligned scrolling page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          email: 'jayden@example.com',
          displayName: 'Jayden Wu',
          bottomPadding: 0,
        ),
      ),
    );

    final title = find.byKey(const Key('profilePageTitle'));
    final healthTitle = find.byKey(const Key('profileHealthDetailsTitle'));
    final scrollView = find.byKey(const Key('profileScrollView'));

    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Your Profile'), findsNothing);
    expect(find.ancestor(of: title, matching: scrollView), findsOneWidget);
    expect(tester.getTopLeft(title).dx, tester.getTopLeft(healthTitle).dx);

    final avatarRect = tester.getRect(
      find.byKey(const Key('changeProfilePhotoButton')),
    );
    final nameLeft = tester.getTopLeft(find.byKey(const Key('profileName'))).dx;
    expect(nameLeft - avatarRect.right, inInclusiveRange(8, 16));

    expect(find.text('Health Details'), findsOneWidget);
    expect(find.text('O+'), findsOneWidget);
    expect(find.text('None recorded'), findsOneWidget);
    expect(find.text('0 active'), findsOneWidget);
    expect(find.text('Care Team'), findsOneWidget);
    expect(find.text('Health Report'), findsOneWidget);
    expect(find.text('Emergency Profile'), findsOneWidget);

    expect(find.text('Dose Reminders'), findsNothing);
    expect(find.text('Privacy & Data'), findsNothing);
    expect(find.text('App Preferences'), findsNothing);
  });
}
