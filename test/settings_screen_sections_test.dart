import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/app_theme.dart';
import 'package:mediary/settings_screen.dart';

void main() {
  testWidgets('embedded settings uses an in-page title and grouped sections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var accountOpenCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          embedded: true,
          bottomPadding: 144,
          appearanceMode: ThemeMode.system,
          onAppearanceModeChanged: (_) {},
          accentColor: AppAccentColor.blue,
          onAccentColorChanged: (_) {},
          accountDisplayName: 'Jayden Wu',
          accountEmail: 'jayden@example.com',
          onOpenAccount: () => accountOpenCount += 1,
        ),
      ),
    );

    final scrollView = find.byKey(const Key('settingsScrollView'));
    final settingsList = find.descendant(
      of: scrollView,
      matching: find.byType(ListView),
    );
    final title = find.byKey(const Key('settingsPageTitle'));
    expect(find.byType(AppBar), findsNothing);
    expect(find.ancestor(of: title, matching: scrollView), findsOneWidget);
    expect(
      tester.getTopLeft(title).dx,
      tester.getTopLeft(find.text('Reminders')).dx,
    );
    expect(
      tester.widget<ListView>(settingsList).padding,
      const EdgeInsets.fromLTRB(16, 2, 16, 144),
    );

    final account = find.byKey(const Key('settingsAccountGroup'));
    expect(
      find.descendant(of: account, matching: find.text('Jayden Wu')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: account, matching: find.text('jayden@example.com')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('settingsAccountRow')));
    expect(accountOpenCount, 1);
  });

  testWidgets('every control appears in its intended settings subsection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          embedded: true,
          appearanceMode: ThemeMode.system,
          onAppearanceModeChanged: (_) {},
          accentColor: AppAccentColor.blue,
          onAccentColorChanged: (_) {},
          accountEmail: 'jayden@example.com',
          onOpenAccount: () {},
          onSignOut: () async {},
        ),
      ),
    );

    void expectRows(String groupKey, List<String> labels) {
      final group = find.byKey(Key(groupKey));
      expect(group, findsOneWidget);
      for (final label in labels) {
        expect(
          find.descendant(of: group, matching: find.text(label)),
          findsOneWidget,
        );
      }
    }

    expectRows('settingsRemindersGroup', [
      'Dose Notifications',
      'Follow-Up Alert',
      'Reminder Sound',
    ]);
    expectRows('settingsAppPreferencesGroup', ['Language', 'Units']);
    expectRows('settingsAppearanceGroup', [
      'Light',
      'Dark',
      'System',
      'Accent Color',
      'Blue',
    ]);
    expectRows('settingsConnectedAppsGroup', ['Apple Health']);
    expectRows('settingsPrivacyGroup', ['Privacy Controls', 'Export My Data']);

    expect(
      find.descendant(
        of: find.byKey(const Key('settingsAppPreferencesGroup')),
        matching: find.text('Appearance'),
      ),
      findsNothing,
    );
    expect(find.text('Dark Appearance'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('settingsPrivacyGroup')),
        matching: find.text('Apple Health'),
      ),
      findsNothing,
    );
    expect(find.byKey(const Key('settingsSignOutButton')), findsNothing);
  });
}
