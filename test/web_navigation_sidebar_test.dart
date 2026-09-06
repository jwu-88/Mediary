import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/app_interactions.dart';
import 'package:mediary/web_navigation_sidebar.dart';

void main() {
  testWidgets('final web destination is Settings', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WebNavigationSidebar(currentIndex: 4, onTap: (_) {}),
        ),
      ),
    );

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Profile'), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp(r'\bSettings\b')),
      findsAtLeastNWidgets(1),
    );
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(const Key('webNavItem-4')),
              matching: find.byType(Icon),
            ),
          )
          .icon,
      CupertinoIcons.gear_solid,
    );
    semantics.dispose();
  });

  testWidgets('destination has hover, press, and callback feedback', (
    tester,
  ) async {
    var taps = 0;
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WebNavigationSidebar(currentIndex: 0, onTap: (_) => taps += 1),
        ),
      ),
    );

    final item = find.byKey(const Key('webNavItem-1'));
    final pressable = find.descendant(
      of: item,
      matching: find.byType(AppPressable),
    );
    final feedbackScale = find.descendant(
      of: pressable,
      matching: find.byKey(const Key('appPressableScale')),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getTopLeft(find.byKey(const Key('webNavigationSidebar'))) +
          const Offset(30, 30),
    );
    await tester.pumpAndSettle();
    await mouse.moveTo(tester.getCenter(item));
    await tester.pump();

    expect(tester.widget<AnimatedScale>(feedbackScale).scale, 1.012);

    await mouse.down(tester.getCenter(item));
    await tester.pump();
    expect(tester.widget<AnimatedScale>(feedbackScale).scale, .975);

    await mouse.up();
    await tester.pump();
    expect(taps, 1);

    await mouse.removePointer();
    debugDefaultTargetPlatformOverride = null;
  });
}
