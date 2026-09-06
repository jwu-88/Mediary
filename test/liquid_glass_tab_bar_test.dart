import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/app_theme.dart';
import 'package:mediary/liquid_glass_tab_bar.dart';

void main() {
  testWidgets('light navigation uses a transparent bordered glass surface', (
    tester,
  ) async {
    await _pumpTabBar(tester);

    final surface = tester.widget<Container>(
      find.byKey(const Key('liquidGlassTabBar')),
    );
    final decoration = surface.decoration! as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;
    final border = decoration.border! as Border;

    expect(surface.constraints!.maxHeight, 64);
    expect(decoration.borderRadius, BorderRadius.circular(32));
    expect(gradient.colors.every((color) => color.a < 1), isTrue);
    expect(border.top, border.right);
    expect(border.right, border.bottom);
    expect(border.bottom, border.left);
    expect(border.top.width, 1);
    expect(border.top.color.a, greaterThan(.75));
    expect(find.byType(BackdropFilter), findsNWidgets(2));
  });

  testWidgets('selected lens is a translucent accent gradient', (tester) async {
    await _pumpTabBar(tester);

    final lens = tester.widget<DecoratedBox>(
      find.byKey(const Key('liquidGlassSelectedGradient')),
    );
    final decoration = lens.decoration as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;
    final position = tester.widget<AnimatedPositioned>(
      find.byKey(const Key('liquidGlassSelectionLens')),
    );

    expect(decoration.borderRadius, BorderRadius.circular(24));
    expect(gradient.colors, hasLength(3));
    expect(gradient.colors.every((color) => color.a < 1), isTrue);
    expect(
      gradient.colors.last,
      Color.lerp(
        AppAccentColor.teal.light,
        Colors.black,
        .08,
      )!.withValues(alpha: .38),
    );
    expect(position.top, 8);
    expect(position.height, 48);
  });

  testWidgets(
    'inactive destinations use black icons and labels in light mode',
    (tester) async {
      await _pumpTabBar(tester);

      for (final label in ['Calendar', 'Scan', 'Library', 'Settings']) {
        final icon = tester.widget<Icon>(
          find.descendant(
            of: find.byKey(Key('liquidGlassTabIcon-$label')),
            matching: find.byType(Icon),
          ),
        );
        final textStyle = tester.widget<AnimatedDefaultTextStyle>(
          find.byKey(Key('liquidGlassTabLabelStyle-$label')),
        );

        expect(icon.color, Colors.black);
        expect(textStyle.style.color, Colors.black);
      }

      expect(
        tester
            .widget<Icon>(
              find.descendant(
                of: find.byKey(const Key('liquidGlassTabIcon-Today')),
                matching: find.byType(Icon),
              ),
            )
            .color,
        AppAccentColor.teal.light,
      );
    },
  );

  testWidgets('final destination is announced as Settings', (tester) async {
    final semantics = tester.ensureSemantics();

    await _pumpTabBar(tester);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Profile'), findsNothing);
    expect(find.bySemanticsLabel('Settings'), findsOneWidget);
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(const Key('liquidGlassTabIcon-Settings')),
              matching: find.byType(Icon),
            ),
          )
          .icon,
      CupertinoIcons.gear,
    );
    semantics.dispose();
  });

  testWidgets('mobile tab selection provides one haptic and one callback', (
    tester,
  ) async {
    final haptics = <MethodCall>[];
    var selectedIndex = -1;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
        return null;
      },
    );
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await _pumpTabBar(tester, onTap: (index) => selectedIndex = index);
    haptics.clear();

    await tester.tap(find.text('Calendar'));
    await tester.pump();

    debugDefaultTargetPlatformOverride = null;

    expect(selectedIndex, 1);
    expect(haptics, hasLength(1));
    expect(haptics.single.arguments, 'HapticFeedbackType.selectionClick');
  });
}

Future<void> _pumpTabBar(
  WidgetTester tester, {
  ValueChanged<int>? onTap,
}) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightFor(AppAccentColor.teal),
      home: Scaffold(
        backgroundColor: const Color(0xFF6BA8C8),
        bottomNavigationBar: LiquidGlassTabBar(
          currentIndex: 0,
          onTap: onTap ?? (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
