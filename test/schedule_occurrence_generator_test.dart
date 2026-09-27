import 'package:flutter_test/flutter_test.dart';

import 'package:mediary/data/mediary_models.dart';
import 'package:mediary/data/schedule_occurrence_generator.dart';

void main() {
  ScheduleRecord schedule({
    String frequency = 'daily',
    List<String> times = const ['08:00:00'],
    List<int> daysOfWeek = const [],
    String startDate = '2026-09-01',
    String? endDate,
    String timezone = 'America/New_York',
  }) {
    return ScheduleRecord(
      id: 'schedule-1',
      medicationId: 'medication-1',
      doseAmount: 1,
      doseUnit: 'tablet',
      times: times,
      frequency: frequency,
      daysOfWeek: daysOfWeek,
      startDate: startDate,
      endDate: endDate,
      timezone: timezone,
      instructions: '',
      active: true,
    );
  }

  final generator = const ScheduleOccurrenceGenerator();

  test('generates daily occurrences and caps the end date', () {
    final result = generator.generate(
      schedule(endDate: '2026-09-03'),
      from: DateTime.utc(2026, 9, 1),
      through: DateTime.utc(2026, 9, 10),
    );

    expect(result, hasLength(3));
    expect(result.map((item) => item.localDate), [
      '2026-09-01',
      '2026-09-02',
      '2026-09-03',
    ]);
  });

  test('uses selected weekly days and defaults to the start weekday', () {
    final selectedDays = generator.generate(
      schedule(
        frequency: 'weekly',
        daysOfWeek: [DateTime.monday, DateTime.wednesday],
      ),
      from: DateTime.utc(2026, 9, 1),
      through: DateTime.utc(2026, 9, 8, 23),
    );
    expect(selectedDays.map((item) => item.localDate), [
      '2026-09-02',
      '2026-09-07',
    ]);

    final defaultDay = generator.generate(
      schedule(frequency: 'weekly'),
      from: DateTime.utc(2026, 9, 1),
      through: DateTime.utc(2026, 9, 15, 23),
    );
    expect(defaultDay.map((item) => item.localDate), [
      '2026-09-01',
      '2026-09-08',
      '2026-09-15',
    ]);
  });

  test('does not generate automatic occurrences for as-needed schedules', () {
    expect(
      generator.generate(
        schedule(frequency: 'asNeeded'),
        from: DateTime.utc(2026, 9, 1),
        through: DateTime.utc(2026, 10),
      ),
      isEmpty,
    );
  });

  test('uses deterministic IDs and preserves local time across DST', () {
    final first = generator.generate(
      schedule(
        frequency: 'every8Hours',
        times: const ['01:30:00'],
        startDate: '2026-11-01',
      ),
      from: DateTime.utc(2026, 11, 1),
      through: DateTime.utc(2026, 11, 2, 23),
    );
    final second = generator.generate(
      schedule(
        frequency: 'every8Hours',
        times: const ['01:30:00'],
        startDate: '2026-11-01',
      ),
      from: DateTime.utc(2026, 11, 1),
      through: DateTime.utc(2026, 11, 2, 23),
    );

    expect(first, isNotEmpty);
    expect(first.map((item) => item.id), second.map((item) => item.id));
    expect(first.first.localTime, '01:30:00');
  });
}
