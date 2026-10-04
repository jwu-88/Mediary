import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/calendar_screen.dart';
import 'package:mediary/data/medication_catalog_client.dart';
import 'package:mediary/data/schedule_occurrence_generator.dart';
import 'package:mediary/scanner_screens.dart';

void main() {
  testWidgets('calendar shows the actual date after a midnight rollover', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: CalendarScreen(
          initialDate: DateTime(2026, 10, 4),
          onAddDose: (_) async => const [
            CalendarDoseData(
              id: 'midnight-dose',
              localDate: '2026-10-05',
              name: 'Midnight Medication',
              details: '1 MG · 12:00 AM',
              status: 'due',
            ),
          ],
        ),
      ),
    );
    final add = find.byKey(const Key('calendarAddButton'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.text('Monday, October 5'), findsOneWidget);
    expect(find.text('Midnight Medication'), findsOneWidget);
  });

  for (final snapshotFirst in [false, true]) {
    testWidgets(
      'calendar add remains one row when snapshotFirst=$snapshotFirst',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final date = DateTime(2026, 10, 5);
        final dose = CalendarDoseData(
          id: ScheduleOccurrenceGenerator.deterministicOccurrenceId(
            'schedule',
            localDate: '2026-10-05',
            localTime: '09:00:00',
          ),
          localDate: '2026-10-05',
          name: 'Test Medication',
          details: '1 MG · 9:00 AM',
          status: 'due',
        );
        var saved = const <CalendarDoseData>[];
        late StateSetter update;
        final saving = Completer<List<CalendarDoseData>>();
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return CalendarScreen(
                  initialDate: date,
                  initialDoses: saved,
                  bottomPadding: 24,
                  onAddDose: (_) => saving.future,
                );
              },
            ),
          ),
        );
        final add = find.byKey(const Key('calendarAddButton'));
        await tester.ensureVisible(add);
        await tester.tap(add);
        await tester.pump();
        if (snapshotFirst) {
          update(() => saved = [dose]);
          await tester.pump();
        }
        saving.complete([dose]);
        await tester.pumpAndSettle();
        if (!snapshotFirst) {
          update(() => saved = [dose]);
          await tester.pumpAndSettle();
        }
        expect(find.text('Test Medication'), findsOneWidget);
        expect(
          find.byKey(Key('calendarDeleteDose_${dose.id}')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final example in [
    (DateTime(2026, 10, 4, 10, 19), '10:20 AM'),
    (DateTime(2026, 10, 4, 1, 21), '1:30 AM'),
    (DateTime(2026, 10, 4, 23, 59), '12:00 AM'),
  ]) {
    testWidgets('scan scheduling defaults to ${example.$2}', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: ScanResultScreen(
            medication: const MedicationCatalogRecord(
              rxcui: 'test-med',
              name: 'Test Medication',
              strength: '1 MG',
              form: 'tablet',
            ),
            now: example.$1,
            bottomNavigationInset: 0,
          ),
        ),
      );
      final field = find.byKey(const Key('scanScheduleTimeField'));
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: field, matching: find.text(example.$2)),
        findsOneWidget,
      );
      if (example.$1.hour == 23) {
        expect(find.text('Oct 5, 2026'), findsOneWidget);
      }
      expect(find.text('No Repeat'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
