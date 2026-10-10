import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sends edits through the existing keyboard connection. Unlike enterText,
/// this never focuses again between characters, exposing dropped input state.
Future<void> typeWithoutRefocusing(
  WidgetTester tester,
  Finder field,
  List<String> values,
) async {
  await tester.ensureVisible(field);
  await tester.showKeyboard(field);
  final editable = find.descendant(
    of: field,
    matching: find.byType(EditableText),
  );
  final original = tester.state<EditableTextState>(editable);
  for (final value in values) {
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      ),
    );
    await tester.pump();
    final current = tester.state<EditableTextState>(editable);
    expect(current, same(original), reason: 'field recreated for "$value"');
    expect(
      current.widget.focusNode.hasFocus,
      isTrue,
      reason: 'focus lost for "$value"',
    );
    expect(current.widget.controller.text, value);
    expect(tester.testTextInput.hasAnyClients, isTrue);
  }
}
