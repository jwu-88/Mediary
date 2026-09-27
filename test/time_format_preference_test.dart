import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/app_theme.dart';
import 'package:mediary/main.dart';
import 'package:mediary/settings_screen.dart';
import 'package:mediary/time_formatting.dart';

void main() {
  testWidgets('authenticated settings propagates the selected format', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = TimeDisplayFormat.twelveHour;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticatedHome(
          email: 'person@example.com',
          useSidebarNavigation: false,
          timeDisplayFormat: selected,
          onTimeDisplayFormatChanged: (value) => selected = value,
        ),
      ),
    );

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('timeFormatSettingRow')));
    await tester.tap(find.byKey(const Key('timeFormatSettingRow')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    await tester.tap(find.byKey(const Key('inAppOption-24-hour')));
    await tester.pumpAndSettle();

    expect(selected, TimeDisplayFormat.twentyFourHour);
  });

  testWidgets('settings can switch to 24-hour time', (tester) async {
    String? savedKey;
    Object? savedValue;
    var selected = TimeDisplayFormat.twelveHour;

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          embedded: true,
          appearanceMode: ThemeMode.system,
          onAppearanceModeChanged: (_) {},
          accentColor: AppAccentColor.blue,
          onAccentColorChanged: (_) {},
          timeDisplayFormat: selected,
          onTimeDisplayFormatChanged: (value) => selected = value,
          onPreferenceChanged: (key, value) async {
            savedKey = key;
            savedValue = value;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('timeFormatSettingRow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('inAppOption-24-hour')));
    await tester.pumpAndSettle();

    expect(selected, TimeDisplayFormat.twentyFourHour);
    expect(savedKey, 'timeFormat');
    expect(savedValue, '24-hour');
    expect(find.text('24-hour'), findsOneWidget);
  });

  testWidgets('time format stays selected when persistence is unavailable', (
    tester,
  ) async {
    var selected = TimeDisplayFormat.twelveHour;
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          embedded: true,
          appearanceMode: ThemeMode.system,
          onAppearanceModeChanged: (_) {},
          accentColor: AppAccentColor.blue,
          onAccentColorChanged: (_) {},
          onTimeDisplayFormatChanged: (value) => selected = value,
          onPreferenceChanged: (_, _) async {
            throw StateError('Firestore rules have not been deployed');
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('timeFormatSettingRow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('inAppOption-24-hour')));
    await tester.pumpAndSettle();

    expect(selected, TimeDisplayFormat.twentyFourHour);
    expect(find.text('24-hour'), findsOneWidget);
  });
}
