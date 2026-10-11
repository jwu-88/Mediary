import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/data/mediary_models.dart';
import 'package:mediary/notifications/medication_reminder_timing.dart';

DoseLogRecord _dose(
  DateTime time, {
  String id = 'dose',
  String status = 'due',
  DateTime? snoozedUntil,
  String? localDate,
  String? localTime,
}) => DoseLogRecord(
  id: id,
  medicationId: 'medication',
  scheduleId: 'schedule',
  scheduledFor: time,
  localDate: localDate ?? '2026-10-11',
  localTime: localTime ?? '09:00',
  status: status,
  snoozedUntil: snoozedUntil,
);

void main() {
  test('a partial minute never rounds down to an early timer callback', () {
    final now = DateTime.utc(2026, 10, 11, 8, 59, 47, 321, 456);
    expect(
      nextMedicationReminderDelay(
        now: now,
        doses: [_dose(DateTime.utc(2026, 10, 11, 9))],
      ),
      const Duration(seconds: 12, milliseconds: 679),
    );
  });

  test('an earlier second-level deadline wins over the minute heartbeat', () {
    final now = DateTime.utc(2026, 10, 11, 9, 0, 2);
    expect(
      nextMedicationReminderDelay(
        now: now,
        doses: [
          _dose(now.add(const Duration(minutes: 3)), id: 'later'),
          _dose(now.add(const Duration(seconds: 5)), id: 'first'),
        ],
      ),
      const Duration(seconds: 5),
    );
  });

  test('far-away reminders recheck on aligned minute boundaries', () {
    final now = DateTime.utc(2026, 10, 11, 9, 0, 20);
    expect(
      nextMedicationReminderDelay(
        now: now,
        doses: [_dose(now.add(const Duration(days: 1)))],
      ),
      const Duration(seconds: 40),
    );
  });

  test('minute alignment survives midnight and year rollover', () {
    final now = DateTime.utc(2026, 12, 31, 23, 59, 59, 999, 999);
    expect(
      nextMedicationReminderDelay(now: now, doses: [_dose(DateTime.utc(2027))]),
      const Duration(milliseconds: 1),
    );
  });

  test('snoozes keep their exact deadline instead of rounding to a minute', () {
    final now = DateTime.utc(2026, 10, 11, 9, 0, 2);
    final snooze = now.add(const Duration(seconds: 5, milliseconds: 500));
    final dose = _dose(
      now.subtract(const Duration(minutes: 15)),
      status: 'snoozed',
      snoozedUntil: snooze,
    );
    expect(medicationReminderTime(dose, scheduleTimezone: 'UTC'), snooze);
    expect(
      nextMedicationReminderDelay(now: now, doses: [dose]),
      const Duration(seconds: 5, milliseconds: 500),
    );
  });

  test(
    'foreground timing uses the same schedule timezone as native alarms',
    () {
      final now = DateTime.utc(2026, 10, 11, 12, 59, 50);
      final dose = _dose(DateTime.utc(2026, 10, 11, 9));
      expect(
        medicationReminderTime(
          dose,
          scheduleTimezone: 'America/New_York',
        ).toUtc(),
        DateTime.utc(2026, 10, 11, 13),
      );
      expect(
        nextMedicationReminderDelay(
          now: now,
          doses: [dose],
          scheduleTimezones: const {'schedule': 'America/New_York'},
        ),
        const Duration(seconds: 10),
      );
    },
  );

  test('no future reminders leave no repeating timer running', () {
    final now = DateTime.utc(2026, 10, 11, 9);
    expect(
      nextMedicationReminderDelay(
        now: now,
        doses: [_dose(now), _dose(now.subtract(const Duration(days: 1)))],
      ),
      isNull,
    );
    expect(nextMedicationReminderDelay(now: now, doses: []), isNull);
  });

  test('taken duplicates suppress a future legacy due record', () {
    final now = DateTime.utc(2026, 10, 11, 8);
    final due = DateTime.utc(2026, 10, 11, 9);
    expect(
      nextMedicationReminderDelay(
        now: now,
        doses: [
          _dose(due, id: 'legacy', localTime: '09:00'),
          _dose(due, id: 'canonical', status: 'taken', localTime: '09:00:00'),
        ],
      ),
      isNull,
    );
  });
}
