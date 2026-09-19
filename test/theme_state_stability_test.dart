import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/app_theme.dart';
import 'package:mediary/main.dart';

void main() {
  testWidgets(
    'changing appearance keeps Settings mounted at the same scroll offset',
    (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const _AppearanceHarness());
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      final settingsScrollView = find.byKey(const Key('settingsScrollView'));
      final appearanceRow = find.byKey(const Key('appearanceSettingRow'));
      await tester.ensureVisible(appearanceRow);
      await tester.pumpAndSettle();

      final nestedScrollable = find.descendant(
        of: settingsScrollView,
        matching: find.byType(Scrollable),
      );
      double scrollOffset() =>
          tester.state<ScrollableState>(nestedScrollable).position.pixels;

      final offsetBeforeChange = scrollOffset();
      expect(offsetBeforeChange, greaterThan(0));

      await tester.tap(appearanceRow);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('inAppOption-Dark')));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(const Key('settingsScreen')), findsOneWidget);
      expect(scrollOffset(), closeTo(offsetBeforeChange, 10));

      await tester.pump(AppTheme.transitionDuration * .5);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(scrollOffset(), closeTo(offsetBeforeChange, 10));

      await tester.pumpAndSettle();
      expect(find.text('Dark'), findsOneWidget);
      expect(scrollOffset(), closeTo(offsetBeforeChange, 10));
    },
  );
}

class _AppearanceHarness extends StatefulWidget {
  const _AppearanceHarness();

  @override
  State<_AppearanceHarness> createState() => _AppearanceHarnessState();
}

class _AppearanceHarnessState extends State<_AppearanceHarness> {
  ThemeMode _mode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _mode,
      themeAnimationDuration: AppTheme.transitionDuration,
      themeAnimationCurve: AppTheme.transitionCurve,
      builder: (context, child) =>
          AppThemeTransitionSurface(child: child ?? const SizedBox.shrink()),
      home: AuthenticatedHome(
        email: 'person@example.com',
        appearanceMode: _mode,
        onAppearanceModeChanged: (mode) => setState(() => _mode = mode),
        accentColor: AppAccentColor.blue,
        onAccentColorChanged: (_) {},
        useSidebarNavigation: false,
      ),
    );
  }
}
