import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/app_theme.dart';
import 'package:mediary/in_app_page.dart';
import 'package:mediary/liquid_glass_back_button.dart';
import 'package:mediary/settings_screen.dart';

void main() {
  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget settings() {
    return MaterialApp(
      home: SettingsScreen(
        appearanceMode: ThemeMode.system,
        onAppearanceModeChanged: (_) {},
        accentColor: AppAccentColor.blue,
        onAccentColorChanged: (_) {},
      ),
    );
  }

  Finder settingsScrollable() {
    return find.descendant(
      of: find.byKey(const Key('settingsScrollView')),
      matching: find.byType(Scrollable),
    );
  }

  testWidgets('settings choices open a routed page with liquid-glass back', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(settings());

    await tester.tap(find.text('Reminder Sound'));
    await tester.pumpAndSettle();

    final routedPage = find.byType(InAppPageScaffold);
    expect(routedPage, findsOneWidget);
    expect(
      find.descendant(
        of: routedPage,
        matching: find.byType(LiquidGlassBackButton),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('inAppOption-Bell')));
    await tester.pumpAndSettle();
    expect(find.text('Bell'), findsOneWidget);
  });

  testWidgets('privacy page does not claim unavailable integrations are on', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(settings());

    await tester.scrollUntilVisible(
      find.text('Privacy Controls'),
      300,
      scrollable: settingsScrollable(),
    );
    await tester.tap(find.text('Privacy Controls'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cameraAccessControl')), findsOneWidget);
    final healthData = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Health Data'),
    );
    final analytics = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Anonymous Analytics'),
    );
    expect(healthData.value, isFalse);
    expect(healthData.onChanged, isNull);
    expect(analytics.value, isFalse);
    expect(analytics.onChanged, isNull);
    expect(find.text('Not connected in this build'), findsOneWidget);
    expect(find.text('No analytics service is installed'), findsOneWidget);
  });

  testWidgets('Apple Health stays disconnected until integration is ready', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(settings());

    await tester.scrollUntilVisible(
      find.text('Apple Health'),
      300,
      scrollable: settingsScrollable(),
    );
    await tester.tap(find.text('Apple Health'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('appleHealthInformationPage')), findsOneWidget);
    expect(find.text('Apple Health is not connected.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('appleHealthDoneButton')));
    await tester.pumpAndSettle();
    expect(find.text('Not connected'), findsOneWidget);
  });
}
