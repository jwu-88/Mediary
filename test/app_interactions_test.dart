import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/app_interactions.dart';
import 'package:mediary/app_theme.dart';

void main() {
  group('AppPressable', () {
    testWidgets('shows loading and blocks repeat activation for async work', (
      tester,
    ) async {
      final completion = Completer<void>();
      var activations = 0;

      await _pumpPressable(
        tester,
        AppPressable(
          semanticLabel: 'Save changes',
          loadingPresentation: AppPressableLoadingPresentation.replace,
          onPressed: () {
            activations += 1;
            return completion.future;
          },
          child: const SizedBox(
            width: 160,
            height: 48,
            child: Center(child: Text('Save')),
          ),
        ),
      );

      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(activations, 1);
      expect(
        find.byKey(const Key('appPressableLoadingIndicator')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Save changes'), findsOneWidget);

      await tester.tap(find.byType(AppPressable));
      await tester.pump();
      expect(activations, 1);

      completion.complete();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('appPressableLoadingIndicator')),
        findsNothing,
      );
    });

    testWidgets('disabled state dims content and cannot be activated', (
      tester,
    ) async {
      var activations = 0;
      await _pumpPressable(
        tester,
        AppPressable(
          enabled: false,
          onPressed: () => activations += 1,
          child: const SizedBox(
            width: 100,
            height: 44,
            child: Text('Disabled'),
          ),
        ),
      );

      await tester.tap(find.text('Disabled'), warnIfMissed: false);
      await tester.pump();

      final opacity = tester.widget<AnimatedOpacity>(
        find.byKey(const Key('appPressableOpacity')),
      );
      final detector = tester.widget<FocusableActionDetector>(
        find.byType(FocusableActionDetector),
      );
      expect(opacity.opacity, .46);
      expect(detector.mouseCursor, SystemMouseCursors.forbidden);
      expect(activations, 0);
    });

    testWidgets('pointer hover lifts and touch press compresses the surface', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      await _pumpPressable(
        tester,
        AppPressable(
          onPressed: () {},
          child: const SizedBox(width: 120, height: 48, child: Text('Open')),
        ),
      );

      final center = tester.getCenter(find.byType(AppPressable));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(center);
      await tester.pump();

      expect(
        tester
            .widget<AnimatedScale>(find.byKey(const Key('appPressableScale')))
            .scale,
        1.012,
      );

      await mouse.moveTo(const Offset(700, 500));
      await tester.pumpAndSettle();

      final touch = await tester.startGesture(center);
      await tester.pump();
      expect(
        tester
            .widget<AnimatedScale>(find.byKey(const Key('appPressableScale')))
            .scale,
        .985,
      );

      final overlay = tester.widget<AnimatedContainer>(
        find.byKey(const Key('appPressableFeedbackOverlay')),
      );
      final decoration = overlay.decoration! as BoxDecoration;
      expect(decoration.color, isNot(Colors.transparent));

      await touch.up();
      await mouse.removePointer();
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('reduced motion removes interaction animation duration', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(
                child: AppPressable(
                  onPressed: () {},
                  child: const SizedBox(width: 100, height: 44),
                ),
              ),
            ),
          ),
        ),
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byType(AppPressable)));
      await tester.pump();

      expect(
        tester
            .widget<AnimatedScale>(find.byKey(const Key('appPressableScale')))
            .duration,
        Duration.zero,
      );
      expect(
        tester
            .widget<AnimatedContainer>(
              find.byKey(const Key('appPressableFeedbackOverlay')),
            )
            .duration,
        Duration.zero,
      );

      await mouse.removePointer();
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('routes synchronous callback failures to onError', (
      tester,
    ) async {
      Object? reportedError;
      await _pumpPressable(
        tester,
        AppPressable(
          onPressed: () => throw StateError('sync failure'),
          onError: (error, _) => reportedError = error,
          child: const SizedBox(width: 120, height: 48, child: Text('Fail')),
        ),
      );

      await tester.tap(find.text('Fail'));
      await tester.pump();

      expect(reportedError, isA<StateError>());
      expect(tester.takeException(), isNull);
    });

    testWidgets('routes unmanaged asynchronous failures to onError', (
      tester,
    ) async {
      Object? reportedError;
      await _pumpPressable(
        tester,
        AppPressable(
          autoManageBusy: false,
          onPressed: () => Future<void>.error(StateError('async failure')),
          onError: (error, _) => reportedError = error,
          child: const SizedBox(width: 120, height: 48, child: Text('Fail')),
        ),
      );

      await tester.tap(find.text('Fail'));
      await tester.pump();

      expect(reportedError, isA<StateError>());
      expect(tester.takeException(), isNull);
    });
  });

  group('AppHaptics', () {
    testWidgets('uses native feedback only on supported mobile platforms', (
      tester,
    ) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') calls.add(call);
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

      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      await AppHaptics.selection();
      expect(calls, isEmpty);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await AppHaptics.selection();
      await AppHaptics.primaryAction();

      expect(calls, hasLength(2));
      expect(calls.first.arguments, 'HapticFeedbackType.selectionClick');
      expect(calls.last.arguments, 'HapticFeedbackType.mediumImpact');
      debugDefaultTargetPlatformOverride = null;
    });
  });

  testWidgets('responsive Cupertino buttons hover and show async progress', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final completion = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: ResponsiveCupertinoButton(
              buttonKey: const Key('responsiveCupertinoButton'),
              semanticLabel: 'Open details',
              onPressed: () => completion.future,
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    final button = find.byKey(const Key('responsiveCupertinoButton'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(button));
    await tester.pump();
    expect(
      tester
          .widget<AnimatedScale>(find.byKey(const Key('appPressableScale')))
          .scale,
      1.018,
    );

    await tester.tap(button);
    await tester.pump();
    expect(
      find.byKey(const Key('responsiveCupertinoLoadingIndicator')),
      findsOneWidget,
    );

    completion.complete();
    await tester.pumpAndSettle();
    await mouse.removePointer();
    debugDefaultTargetPlatformOverride = null;
  });

  test('button themes expose hover, press, disabled, and cursor feedback', () {
    final theme = AppTheme.lightFor(AppAccentColor.blue);
    final style = theme.filledButtonTheme.style!;
    final iconStyle = theme.iconButtonTheme.style!;

    expect(
      style.overlayColor!.resolve({WidgetState.hovered}),
      AppAccentColor.blue.light.withValues(alpha: .09),
    );
    expect(
      style.overlayColor!.resolve({WidgetState.pressed}),
      AppAccentColor.blue.light.withValues(alpha: .16),
    );
    expect(
      style.mouseCursor!.resolve({WidgetState.disabled}),
      SystemMouseCursors.forbidden,
    );
    expect(style.elevation!.resolve({WidgetState.hovered}), 2);
    expect(iconStyle.shape!.resolve({}), isA<CircleBorder>());
  });
}

Future<void> _pumpPressable(WidgetTester tester, Widget pressable) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Center(child: pressable)),
    ),
  );
}
