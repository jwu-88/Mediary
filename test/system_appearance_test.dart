import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/app_theme.dart';
import 'package:mediary/liquid_glass_appearance_selector.dart';
import 'package:mediary/settings_screen.dart';

void main() {
  testWidgets('system appearance follows platform brightness automatically', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 1500);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    final appearanceMode = ValueNotifier(ThemeMode.system);
    addTearDown(appearanceMode.dispose);

    await tester.pumpWidget(
      ValueListenableBuilder<ThemeMode>(
        valueListenable: appearanceMode,
        builder: (context, mode, _) => MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: SettingsScreen(
            embedded: true,
            appearanceMode: mode,
            onAppearanceModeChanged: (value) => appearanceMode.value = value,
            accentColor: AppAccentColor.blue,
            onAccentColorChanged: (_) {},
          ),
        ),
      ),
    );

    expect(appearanceMode.value, ThemeMode.system);
    expect(_settingsBackground(tester), AppColors.lightBackground);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();

    expect(appearanceMode.value, ThemeMode.system);
    expect(_settingsBackground(tester), AppColors.darkBackground);
    expect(
      tester
          .widget<LiquidGlassAppearanceSelector>(
            find.byType(LiquidGlassAppearanceSelector),
          )
          .value,
      ThemeMode.system,
    );

    await tester.tap(find.byKey(const Key('appearanceOptionLight')));
    await tester.pumpAndSettle();

    expect(appearanceMode.value, ThemeMode.light);
    expect(_settingsBackground(tester), AppColors.lightBackground);
  });
}

Color? _settingsBackground(WidgetTester tester) {
  return tester
      .widget<Scaffold>(find.byKey(const Key('settingsScreen')))
      .backgroundColor;
}
