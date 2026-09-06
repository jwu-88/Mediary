import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/liquid_glass_back_button.dart';

void main() {
  testWidgets('liquid glass back button is accessible and invokes callback', (
    tester,
  ) async {
    var presses = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LiquidGlassBackButton(
              semanticLabel: 'Back to Library',
              onPressed: () => presses++,
            ),
          ),
        ),
      ),
    );

    final button = find.byType(LiquidGlassBackButton);
    expect(tester.getSize(button), const Size.square(44));
    expect(
      tester.getSemantics(button),
      matchesSemantics(
        label: 'Back to Library',
        isButton: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(button);
    expect(presses, 1);
  });

  testWidgets('mobile back action provides one primary haptic', (tester) async {
    final haptics = <MethodCall>[];
    var presses = 0;
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LiquidGlassBackButton(onPressed: () => presses += 1),
          ),
        ),
      ),
    );
    haptics.clear();

    await tester.tap(find.byType(LiquidGlassBackButton));
    await tester.pump();

    debugDefaultTargetPlatformOverride = null;

    expect(presses, 1);
    expect(haptics, hasLength(1));
    expect(haptics.single.arguments, 'HapticFeedbackType.mediumImpact');
  });
}
