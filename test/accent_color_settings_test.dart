import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/app_theme.dart';
import 'package:mediary/in_app_page.dart';
import 'package:mediary/main.dart';

void main() {
  testWidgets('blue is default and changing accent updates the app theme', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final accent = ValueNotifier(AppAccentColor.blue);
    addTearDown(accent.dispose);

    await tester.pumpWidget(
      ValueListenableBuilder<AppAccentColor>(
        valueListenable: accent,
        builder: (context, value, _) => MaterialApp(
          theme: AppTheme.lightFor(value),
          darkTheme: AppTheme.darkFor(value),
          themeMode: ThemeMode.light,
          home: AuthenticatedHome(
            email: 'person@example.com',
            appearanceMode: ThemeMode.light,
            onAppearanceModeChanged: (_) {},
            accentColor: value,
            onAccentColorChanged: (selection) => accent.value = selection,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(accent.value, AppAccentColor.blue);
    expect(find.byKey(const Key('accentColorSettingRow')), findsOneWidget);
    expect(find.text('Blue'), findsOneWidget);
    expect(_appPrimary(tester), AppAccentColor.blue.light);

    await tester.tap(find.byKey(const Key('accentColorSettingRow')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('inAppOption-Purple')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('inAppOption-Purple')));
    await tester.pumpAndSettle();

    expect(accent.value, AppAccentColor.purple);
    expect(find.text('Purple'), findsOneWidget);
    expect(find.byType(InAppPageScaffold), findsOneWidget);
    expect(
      find.byKey(const ValueKey('inAppOptionCheck-Purple')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

    await tester.tap(find.byTooltip('Back from Accent Color'));
    await tester.pumpAndSettle();
    expect(_appPrimary(tester), AppAccentColor.purple.light);
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(const Key('liquidGlassTabIcon-Settings')),
              matching: find.byType(Icon),
            ),
          )
          .color,
      AppAccentColor.purple.light,
    );
  });
}

Color _appPrimary(WidgetTester tester) {
  return tester
      .widget<MaterialApp>(find.byType(MaterialApp))
      .theme!
      .colorScheme
      .primary;
}
