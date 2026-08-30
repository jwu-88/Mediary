import 'package:flutter/material.dart';
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
}
