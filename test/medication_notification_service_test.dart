import 'package:flutter_test/flutter_test.dart';

import 'package:mediary/data/mediary_models.dart';
import 'package:mediary/notifications/medication_notification_service.dart';

void main() {
  DoseLogRecord dose({
    required String id,
    required DateTime scheduledFor,
    String status = 'due',
    DateTime? snoozedUntil,
  }) {
    return DoseLogRecord(
      id: id,
      medicationId: 'medication-1',
      scheduleId: 'schedule-$id',
      scheduledFor: scheduledFor,
      localDate: '2026-09-13',
      localTime: '09:00',
      status: status,
      snoozedUntil: snoozedUntil,
    );
  }

  test('uses stable positive notification ids for dose ids', () {
    final first = DefaultMedicationNotificationService.notificationIdForDose(
      'dose-1',
    );
    final second = DefaultMedicationNotificationService.notificationIdForDose(
      'dose-1',
    );

    expect(first, greaterThan(0));
    expect(first, second);
    expect(
      DefaultMedicationNotificationService.notificationIdForDose('dose-2'),
      isNot(first),
    );
  });

  test('returns a recent due dose once and ignores duplicates', () async {
    final service = DefaultMedicationNotificationService();
    final now = DateTime(2026, 9, 13, 9, 1);
    final due = dose(id: 'dose-1', scheduledFor: DateTime(2026, 9, 13, 9));

    final first = await service.syncDueDoses(
      doses: [due],
      medicationNames: const {'medication-1': 'Ibuprofen'},
      now: now,
    );
    final second = await service.syncDueDoses(
      doses: [due],
      medicationNames: const {'medication-1': 'Ibuprofen'},
      now: now.add(const Duration(seconds: 15)),
    );

    expect(first.single.body, 'Time to take Ibuprofen');
    expect(second, isEmpty);
    await service.dispose();
  });

  test(
    'does not notify stale initial doses, snoozed doses, or non-due doses',
    () async {
      final service = DefaultMedicationNotificationService();
      final now = DateTime(2026, 9, 13, 12);
      final stale = dose(
        id: 'stale',
        scheduledFor: now.subtract(const Duration(hours: 2)),
      );
      final snoozed = dose(
        id: 'snoozed',
        scheduledFor: now.subtract(const Duration(minutes: 1)),
        snoozedUntil: now.add(const Duration(minutes: 10)),
      );
      final taken = dose(
        id: 'taken',
        scheduledFor: now.subtract(const Duration(minutes: 1)),
        status: 'taken',
      );

      final result = await service.syncDueDoses(
        doses: [stale, snoozed, taken],
        medicationNames: const {'medication-1': 'Metformin'},
        now: now,
      );

      expect(result, isEmpty);
      await service.dispose();
    },
  );

  test('notifies a dose that becomes due after the initial sync', () async {
    final service = DefaultMedicationNotificationService();
    final now = DateTime(2026, 9, 13, 8);
    final future = dose(
      id: 'future',
      scheduledFor: now.add(const Duration(minutes: 5)),
    );

    expect(
      await service.syncDueDoses(
        doses: [future],
        medicationNames: const {'medication-1': 'Cetirizine'},
        now: now,
      ),
      isEmpty,
    );
    final due = await service.syncDueDoses(
      doses: [
        dose(id: 'future', scheduledFor: now.add(const Duration(minutes: 5))),
      ],
      medicationNames: const {'medication-1': 'Cetirizine'},
      now: now.add(const Duration(minutes: 6)),
    );

    expect(due.single.medicationName, 'Cetirizine');
    await service.dispose();
  });

  test(
    'uses the schedule timezone and local date/time when available',
    () async {
      final service = DefaultMedicationNotificationService();
      final now = DateTime.utc(2026, 9, 13, 9, 1);
      final scheduled = dose(
        id: 'utc-dose',
        // This value is deliberately different; the schedule metadata is the
        // source of truth for newly-created records.
        scheduledFor: DateTime.utc(2026, 9, 13, 9),
      );

      final result = await service.syncDueDoses(
        doses: [scheduled],
        medicationNames: const {'medication-1': 'Aspirin'},
        scheduleTimezones: const {'schedule-utc-dose': 'UTC'},
        now: now,
      );

      expect(result.single.scheduledFor.hour, 9);
      expect(result.single.scheduledFor.timeZoneOffset, Duration.zero);
      await service.dispose();
    },
  );
}
