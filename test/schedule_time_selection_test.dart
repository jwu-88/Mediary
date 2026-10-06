import 'package:mediary/app_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/medication_time_picker.dart';
import 'package:mediary/time_formatting.dart';

void main() {
  for (final size in const [
    Size(1024, 768),
    Size(1440, 900),
    Size(1920, 1080),
    Size(900, 600),
  ]) {
    for (final use24HourFormat in [false, true]) {
      testWidgets(
        'desktop time entry returns an exact ${use24HourFormat ? 24 : 12}-hour time at $size with large text',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          MedicationTime? result;
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      result = await Navigator.of(context).push<MedicationTime>(
                        MaterialPageRoute(
                          builder: (_) => MedicationTimeSelectionPage(
                            initialTime: const TimeOfDay(hour: 11, minute: 38),
                            use24HourFormat: use24HourFormat,
                          ),
                        ),
                      );
                    },
                    child: const Text('Open Desktop Time Picker'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open Desktop Time Picker'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byKey(const Key('timeWheel_Hours')), findsNothing);
          final hour = find.byKey(const Key('scheduleHourInput'));
          final minute = find.byKey(const Key('scheduleMinuteInput'));
          final done = find.byKey(const Key('confirmScheduleTimeButton'));
          await tester.enterText(hour, use24HourFormat ? '24' : '13');
          await tester.pump();
          expect(tester.widget<AppButton>(done).onPressed, isNull);
          await tester.enterText(hour, use24HourFormat ? '23' : '11');
          await tester.pump();
          await tester.enterText(minute, '60');
          await tester.pump();
          expect(tester.widget<AppButton>(done).onPressed, isNull);
          await tester.enterText(minute, '');
          await tester.pump();
          expect(tester.widget<AppButton>(done).onPressed, isNull);

          final bedtime = find.byKey(const Key('scheduleTimePreset_Bedtime'));
          final scrollable = find
              .descendant(
                of: find.byType(MedicationTimeSelectionPage),
                matching: find.byType(Scrollable),
              )
              .first;
          await tester.scrollUntilVisible(bedtime, 200, scrollable: scrollable);
          await tester.pumpAndSettle();
          await tester.tap(bedtime);
          await tester.pumpAndSettle();
          expect(tester.widget<AppButton>(done).onPressed, isNotNull);
          await tester.scrollUntilVisible(hour, -200, scrollable: scrollable);
          await tester.pumpAndSettle();
          expect(
            tester.widget<TextFormField>(hour).controller!.text,
            use24HourFormat ? '21' : '9',
          );
          await tester.enterText(hour, use24HourFormat ? '23' : '11');
          await tester.pump();
          await tester.enterText(minute, '45');
          await tester.pump();
          expect(
            find.text(use24HourFormat ? '23:45' : '11:45 PM'),
            findsOneWidget,
          );
          expect(done.hitTestable(), findsOneWidget);
          await tester.tap(done);
          await tester.pumpAndSettle();
          expect(result?.hour, 23);
          expect(result?.minute, 45);
          expect(find.text('Open Desktop Time Picker'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

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
    final done = tester.widget<AppButton>(
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
            .widget<AppButton>(
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
            .widget<AppButton>(
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
