import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/data/mediary_data_store.dart';
import 'package:mediary/data/mediary_models.dart';
import 'package:mediary/data/mediary_repository.dart';
import 'package:mediary/data/medication_catalog_client.dart';
import 'package:mediary/main.dart';
import 'package:mediary/calendar_screen.dart';
import 'package:mediary/notifications/medication_notification_service.dart';
import 'package:mediary/time_formatting.dart';

import 'support/continuous_text_entry.dart';

class _Repository extends Fake implements MediaryRepository {}

class _Store extends MediaryDataStore {
  _Store() : super(repository: _Repository());
  final savedAmounts = <double>[];
  final savedSchedules = <ScheduleWrite>[];
  final savedDoses = <DoseWrite>[];
  final writtenMedications = <MedicationWrite>[];
  @override
  bool get hasInitialData => true;
  @override
  Future<void> commitScheduleAndDose({
    required MedicationWrite medication,
    required ScheduleWrite schedule,
    required DoseWrite? dose,
  }) async {
    savedAmounts.add(schedule.doseAmount);
    savedSchedules.add(schedule);
    writtenMedications.add(medication);
    if (dose != null) savedDoses.add(dose);
  }

  void hydrateSavedRecords() {
    final medication = writtenMedications.single;
    final schedule = savedSchedules.single;
    final dose = savedDoses.single;
    medications = [
      MedicationRecord(
        id: medication.id!,
        name: medication.name,
        genericName: medication.genericName,
        strength: medication.strength,
        form: medication.form,
        route: medication.route,
        instructions: medication.instructions,
        prescriber: medication.prescriber,
        pharmacy: medication.pharmacy,
        notes: medication.notes,
        active: medication.active,
        source: medication.source,
      ),
    ];
    schedules = [
      ScheduleRecord(
        id: schedule.id!,
        medicationId: schedule.medicationId,
        doseAmount: schedule.doseAmount,
        doseUnit: schedule.doseUnit,
        times: schedule.times,
        frequency: schedule.frequency,
        daysOfWeek: schedule.daysOfWeek,
        startDate: schedule.startDate,
        endDate: schedule.endDate,
        timezone: schedule.timezone,
        instructions: schedule.instructions,
        active: schedule.active,
      ),
    ];
    doseLogs = [
      DoseLogRecord(
        id: dose.id!,
        medicationId: dose.medicationId,
        scheduleId: dose.scheduleId,
        scheduledFor: dose.scheduledFor,
        localDate: dose.localDate,
        localTime: dose.localTime,
        status: dose.status,
      ),
    ];
    notifyListeners();
  }
}

class _Catalog implements MedicationCatalogClient {
  static const medication = MedicationCatalogRecord(
    rxcui: '123',
    name: 'Audit Medication',
    strength: '1 MG',
    form: 'tablet',
  );
  @override
  Future<CatalogSearchPage> search(String query) async =>
      const CatalogSearchPage(items: [medication], sourceVersion: 'test');
  @override
  Future<MedicationCatalogRecord> getDetails(String rxcui) async => medication;
}

class _Notifications extends Fake implements MedicationNotificationService {
  @override
  Future<void> initialize() async {}
  @override
  Future<void> clearDeliveredNotifications() async {}
  @override
  Future<void> requestPermission() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<List<MedicationDueNotification>> syncDueDoses({
    required List<DoseLogRecord> doses,
    required Map<String, String> medicationNames,
    Map<String, String> scheduleTimezones = const {},
    DateTime? now,
  }) async => [];
}

Future<_Store> _openSchedule(
  WidgetTester tester, {
  Size size = const Size(1440, 900),
  TimeDisplayFormat timeDisplayFormat = TimeDisplayFormat.twelveHour,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final store = _Store();
  final sidebar = kIsWeb || size.width >= 900;
  addTearDown(store.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: AuthenticatedHome(
        email: 'audit@example.com',
        now: DateTime.now().add(const Duration(days: 2)),
        dataStore: store,
        catalogClient: _Catalog(),
        notificationService: _Notifications(),
        useSidebarNavigation: sidebar,
        timeDisplayFormat: timeDisplayFormat,
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (sidebar) {
    await tester.tapAt(const Offset(38, 168));
  } else {
    await tester.tap(find.text('Calendar'));
  }
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('calendarAddButton')));
  await tester.tap(find.byKey(const Key('calendarAddButton')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('medicationSearchField')),
    'audit',
  );
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('medicationOption_123')));
  await tester.pumpAndSettle();
  await tester.ensureVisible(
    find.byKey(const Key('addSelectedMedicationsButton')),
  );
  await tester.tap(find.byKey(const Key('addSelectedMedicationsButton')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('scheduleDoseAmountField')), findsOneWidget);
  return store;
}

void main() {
  for (final size in const [Size(1280, 800), Size(390, 844)]) {
    for (final format in TimeDisplayFormat.values) {
      testWidgets(
        'scheduler saves the displayed draft and keeps it after hydration at $size in $format',
        (tester) async {
          final store = await _openSchedule(
            tester,
            size: size,
            timeDisplayFormat: format,
          );
          final amountField = find.byKey(const Key('scheduleDoseAmountField'));
          // clear a validation error, then continue through a decimal value
          // using the same keyboard client.
          await tester.enterText(amountField, '0');
          await tester.ensureVisible(
            find.byKey(const Key('saveScheduleDetailsButton')),
          );
          await tester.tap(find.byKey(const Key('saveScheduleDetailsButton')));
          await tester.pump();
          await typeWithoutRefocusing(tester, amountField, [
            '',
            '0',
            '0.',
            '0.5',
          ]);
          await tester.ensureVisible(
            find.byKey(const Key('scheduleTimeChoice')),
          );
          await tester.tap(find.byKey(const Key('scheduleTimeChoice')));
          await tester.pumpAndSettle();
          final keyboard = kIsWeb || size.width >= 900;
          final expected = keyboard
              ? const MedicationTime(hour: 23, minute: 45)
              : const MedicationTime(hour: 21, minute: 0);
          if (keyboard) {
            await tester.ensureVisible(
              find.byKey(const Key('scheduleTimePreset_Bedtime')),
            );
            await tester.tap(
              find.byKey(const Key('scheduleTimePreset_Bedtime')),
            );
            await tester.pump();
            await typeWithoutRefocusing(
              tester,
              find.byKey(const Key('scheduleHourInput')),
              [
                '',
                format == TimeDisplayFormat.twentyFourHour ? '2' : '1',
                format == TimeDisplayFormat.twentyFourHour ? '23' : '11',
              ],
            );
            await typeWithoutRefocusing(
              tester,
              find.byKey(const Key('scheduleMinuteInput')),
              ['', '4', '45'],
            );
          } else {
            await tester.ensureVisible(
              find.byKey(const Key('scheduleTimePreset_Bedtime')),
            );
            await tester.tap(
              find.byKey(const Key('scheduleTimePreset_Bedtime')),
            );
            await tester.pump();
          }
          expect(find.text(expected.format(format)), findsOneWidget);
          await tester.tap(find.byKey(const Key('confirmScheduleTimeButton')));
          await tester.pumpAndSettle();
          expect(find.text(expected.format(format)), findsOneWidget);
          await tester.ensureVisible(
            find.byKey(const Key('scheduleTimezoneChoice')),
          );
          await tester.tap(find.byKey(const Key('scheduleTimezoneChoice')));
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const Key('inAppOption-America/Los_Angeles')),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.byKey(const Key('saveScheduleDetailsButton')),
          );
          await tester.tap(find.byKey(const Key('saveScheduleDetailsButton')));
          await tester.pumpAndSettle();
          final schedule = store.savedSchedules.single;
          final dose = store.savedDoses.single;
          expect(schedule.doseAmount, .5);
          expect(schedule.doseUnit, 'tablet');
          expect(schedule.frequency, 'once');
          expect(schedule.timezone, 'America/Los_Angeles');
          expect(schedule.startDate, dose.localDate);
          expect(schedule.endDate, dose.localDate);
          expect(schedule.times, [expected.localTime]);
          expect(dose.localTime, expected.localTime);
          expect(
            dose.scheduledFor,
            medicationScheduledDate(
              DateTime.parse(dose.localDate),
              expected,
              schedule.timezone,
            ),
          );
          final before = tester
              .widget<CalendarScreen>(find.byType(CalendarScreen))
              .initialDoses
              .single;
          expect(
            before.details,
            '1 MG · 0.5 tablet · ${expected.format(format)}',
          );
          store.hydrateSavedRecords();
          await tester.pump();
          final after = tester
              .widget<CalendarScreen>(find.byType(CalendarScreen))
              .initialDoses
              .single;
          expect(after.id, before.id);
          expect(after.details, before.details);
          expect(after.localDate, before.localDate);
          expect(after.status, before.status);
          expect(
            find.text('1 MG\n0.5 Tablet\n${expected.format(format)}'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  testWidgets(
    'empty, zero, negative, non-finite and Unicode numeric input never writes a schedule',
    (tester) async {
      final store = await _openSchedule(tester);
      for (final input in [
        '',
        ' ',
        '0',
        '-0',
        '-1',
        'NaN',
        'Infinity',
        '-Infinity',
        '1e309',
        '１',
        '١',
        '1,5',
        '½',
        '1/2',
      ]) {
        await tester.enterText(
          find.byKey(const Key('scheduleDoseAmountField')),
          input,
        );
        await tester.ensureVisible(
          find.byKey(const Key('saveScheduleDetailsButton')),
        );
        await tester.tap(find.byKey(const Key('saveScheduleDetailsButton')));
        await tester.pumpAndSettle();
        expect(store.savedAmounts, isEmpty, reason: 'input=$input');
        expect(
          find.text('Enter a dose amount greater than zero.'),
          findsOneWidget,
          reason: 'input=$input',
        );
        expect(tester.takeException(), isNull, reason: 'input=$input');
      }
      await tester.enterText(
        find.byKey(const Key('scheduleDoseAmountField')),
        '0.5',
      );
      await tester.ensureVisible(
        find.byKey(const Key('saveScheduleDetailsButton')),
      );
      await tester.tap(find.byKey(const Key('saveScheduleDetailsButton')));
      await tester.pumpAndSettle();
      expect(store.savedAmounts, [.5]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'large finite dose amount displays the same numeric value that was saved',
    (tester) async {
      final store = await _openSchedule(tester);
      await tester.enterText(
        find.byKey(const Key('scheduleDoseAmountField')),
        '1e100',
      );
      await tester.ensureVisible(
        find.byKey(const Key('saveScheduleDetailsButton')),
      );
      await tester.tap(find.byKey(const Key('saveScheduleDetailsButton')));
      await tester.pumpAndSettle();
      expect(store.savedAmounts, [1e100]);
      await tester.scrollUntilVisible(
        find.text('Audit Medication'),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('calendarScrollView')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      final doseLabels = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data ?? '')
          .where((text) => text.toLowerCase().contains('tablet'))
          .toList();
      expect(
        doseLabels.any((text) => text.toLowerCase().contains('1e+100')),
        isTrue,
        reason: 'stored=1e100; displayed=$doseLabels',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
