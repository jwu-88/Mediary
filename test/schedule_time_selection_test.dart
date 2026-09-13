import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/main.dart';

void main() {
  testWidgets('time selection offers quick choices and a clear confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MedicationTimeSelectionPage(
                    initialTime: TimeOfDay(hour: 11, minute: 38),
                  ),
                ),
              ),
              child: const Text('Open Time Picker'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Time Picker'));
    await tester.pumpAndSettle();
    expect(find.text('Choose Time'), findsOneWidget);
    expect(find.text('Quick Choices'), findsOneWidget);
    expect(find.text('11:38 AM'), findsOneWidget);

    await tester.tap(find.byKey(const Key('scheduleTimePreset_Morning')));
    await tester.pump();
    expect(find.byKey(const Key('selectedScheduleTime')), findsOneWidget);
    expect(find.text('8:00 AM'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirmScheduleTimeButton')));
    await tester.pumpAndSettle();
    expect(find.text('Open Time Picker'), findsOneWidget);
  });
}
