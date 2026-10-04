import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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

    expect(
      find.byKey(const Key('timeWheel_Hours')),
      kIsWeb ? findsNothing : findsOneWidget,
    );
    expect(
      find.byKey(const Key('timeWheel_Minutes')),
      kIsWeb ? findsNothing : findsOneWidget,
    );
    expect(
      find.byKey(const Key('medicationTimeKeyboardInput')),
      kIsWeb ? findsOneWidget : findsNothing,
    );
    expect(find.byKey(const Key('timeWheel_Seconds')), findsNothing);

    await tester.tap(find.byKey(const Key('confirmScheduleTimeButton')));
    await tester.pumpAndSettle();
    expect(find.text('Open Time Picker'), findsOneWidget);
  });

  testWidgets('past schedule times cannot be confirmed', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MedicationTimeSelectionPage(
          initialTime: TimeOfDay(hour: 8, minute: 0),
          scheduledDate: DateTime(2026, 9, 27),
          minimumDateTime: DateTime(2026, 9, 27, 9),
        ),
      ),
    );

    expect(find.byKey(const Key('pastScheduleTimeError')), findsOneWidget);
    final done = tester.widget<TextButton>(
      find.byKey(const Key('confirmScheduleTimeButton')),
    );
    expect(done.onPressed, isNull);
  });

  testWidgets(
    'desktop time entry validates hours and minutes and accepts presets',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: MedicationTimeSelectionPage(
            initialTime: TimeOfDay(hour: 11, minute: 38),
          ),
        ),
      );

      expect(
        find.byKey(const Key('medicationTimeKeyboardInput')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('timeWheel_Hours')), findsNothing);
      await tester.enterText(find.byKey(const Key('scheduleHourInput')), '9');
      await tester.enterText(
        find.byKey(const Key('scheduleMinuteInput')),
        '75',
      );
      await tester.pump();
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const Key('confirmScheduleTimeButton')),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const Key('scheduleMinuteInput')),
        '45',
      );
      await tester.pump();
      expect(find.text('9:45 AM'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const Key('confirmScheduleTimeButton')),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(const Key('scheduleTimePreset_Bedtime')));
      await tester.pump();
      expect(find.text('9:00 PM'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
