import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/data/mediary_models.dart';
import 'package:mediary/data/schedule_occurrence_generator.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

ScheduleRecord _schedule({
  String id = 'schedule',
  String startDate = '2026-01-01',
  String? endDate,
  List<String> times = const ['08:00:00'],
  String timezone = 'UTC',
  String frequency = 'daily',
  List<int> daysOfWeek = const [],
  bool active = true,
}) => ScheduleRecord(
  id: id,
  medicationId: 'medication',
  doseAmount: 1,
  doseUnit: 'tablet',
  times: times,
  frequency: frequency,
  daysOfWeek: daysOfWeek,
  startDate: startDate,
  endDate: endDate,
  timezone: timezone,
  instructions: '',
  active: active,
);

void main() {
  const generator = ScheduleOccurrenceGenerator();

  test(
    'leap day and year rollover generate exactly one occurrence per day',
    () {
      for (final bounds in [
        (DateTime.utc(2028, 2, 28), DateTime.utc(2028, 3, 1, 23), '2028-02-28'),
        (
          DateTime.utc(2026, 12, 31),
          DateTime.utc(2027, 1, 2, 23),
          '2026-12-31',
        ),
      ]) {
        final occurrences = generator.generate(
          _schedule(startDate: bounds.$3),
          from: bounds.$1,
          through: bounds.$2,
        );
        expect(occurrences, hasLength(3));
        expect(occurrences.map((dose) => dose.id).toSet(), hasLength(3));
      }
    },
  );

  test(
    'inactive, empty-time and reversed range schedules generate no doses',
    () {
      for (final schedule in [
        _schedule(active: false),
        _schedule(times: []),
        _schedule(startDate: '2026-01-10', endDate: '2026-01-01'),
      ]) {
        expect(
          generator.generate(
            schedule,
            from: DateTime.utc(2026),
            through: DateTime.utc(2026, 1, 2),
          ),
          isEmpty,
        );
      }
    },
  );

  test(
    'every eight hours retains exact elapsed interval across spring DST',
    () {
      final doses = generator.generate(
        _schedule(
          startDate: '2026-03-07',
          times: ['23:30'],
          timezone: 'America/New_York',
          frequency: 'every8Hours',
        ),
        from: DateTime.utc(2026, 3, 8),
        through: DateTime.utc(2026, 3, 10),
      );
      expect(doses, isNotEmpty);
      for (var index = 1; index < doses.length; index++) {
        expect(
          doses[index].scheduledFor.difference(doses[index - 1].scheduledFor),
          const Duration(hours: 8),
        );
      }
    },
  );

  test('duplicate local times produce a single deterministic occurrence', () {
    final doses = generator.generate(
      _schedule(times: ['08:00', '08:00:00', '08:00:00']),
      from: DateTime.utc(2026),
      through: DateTime.utc(2026, 1, 1, 23),
    );
    expect(doses, hasLength(1));
  });

  for (final time in ['-1:00', '24:00', '08:99', 'not-a-time', '']) {
    test(
      'invalid local time "$time" never creates a silently changed dose',
      () {
        final doses = generator.generate(
          _schedule(times: [time]),
          from: DateTime.utc(2026),
          through: DateTime.utc(2026, 1, 1, 23),
        );
        expect(doses, isEmpty);
      },
    );
  }

  test('invalid calendar date is rejected rather than rolled into March', () {
    expect(
      generator.generate(
        _schedule(startDate: '2026-02-30'),
        from: DateTime.utc(2026, 2, 28),
        through: DateTime.utc(2026, 3, 3, 23),
      ),
      isEmpty,
    );
  });

  test(
    'unknown IANA timezone never silently schedules in an unrelated zone',
    () {
      expect(
        generator.generate(
          _schedule(timezone: 'America/Imaginary_City'),
          from: DateTime.utc(2026),
          through: DateTime.utc(2026, 1, 1, 23),
        ),
        isEmpty,
      );
    },
  );

  test('spring DST occurrence metadata matches the actual local reminder time', () {
    tz_data.initializeTimeZones();
    final location = tz.getLocation('America/New_York');
    final doses = generator.generate(
      _schedule(
        startDate: '2026-03-08',
        times: ['02:30:00'],
        timezone: location.name,
      ),
      from: DateTime.utc(2026, 3, 8),
      through: DateTime.utc(2026, 3, 9),
    );
    expect(doses, hasLength(1));
    final actual = tz.TZDateTime.from(doses.single.scheduledFor, location);
    final actualTime =
        '${actual.hour.toString().padLeft(2, '0')}:${actual.minute.toString().padLeft(2, '0')}:00';
    expect(doses.single.localTime, actualTime);
  });

  test(
    'fall DST produces one occurrence per calendar day on the host timezone',
    () {
      final doses = generator.generate(
        _schedule(startDate: '2026-10-31', timezone: 'America/New_York'),
        from: DateTime.utc(2026, 10, 31),
        through: DateTime.utc(2026, 11, 3, 23),
      );
      expect(doses.map((dose) => dose.localDate).toList(), [
        '2026-10-31',
        '2026-11-01',
        '2026-11-02',
        '2026-11-03',
      ]);
      expect(doses.map((dose) => dose.id).toSet().length, doses.length);
    },
  );

  test(
    'different legal schedule IDs never collide after occurrence generation',
    () {
      final first = generator.generate(
        _schedule(id: 'a+b'),
        from: DateTime.utc(2026),
        through: DateTime.utc(2026, 1, 1, 23),
      );
      final second = generator.generate(
        _schedule(id: 'a_b'),
        from: DateTime.utc(2026),
        through: DateTime.utc(2026, 1, 1, 23),
      );
      expect(first.single.id, isNot(second.single.id));
    },
  );
}
