import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/time_formatting.dart';

void main() {
  test(
    'default medication time rounds strictly forward to ten-minute boundaries',
    () {
      for (final entry in [
        (DateTime(2026, 10, 4, 10, 19), '10:20:00'),
        (DateTime(2026, 10, 4, 1, 21), '01:30:00'),
        (DateTime(2026, 10, 4, 10, 21), '10:30:00'),
        (DateTime(2026, 10, 4, 10, 20), '10:30:00'),
        (DateTime(2026, 10, 4, 10, 29, 59, 999), '10:30:00'),
        (DateTime(2026, 10, 4, 10, 59), '11:00:00'),
        (DateTime(2026, 10, 4, 23, 59), '00:00:00'),
      ]) {
        expect(defaultMedicationTime(now: entry.$1).localTime, entry.$2);
      }
      expect(
        nextMedicationScheduleTime(now: DateTime(2026, 10, 4, 23, 59)),
        DateTime(2026, 10, 5),
      );
      expect(
        nextMedicationScheduleTime(now: DateTime.utc(2026, 12, 31, 23, 59)),
        DateTime.utc(2027, 1, 1),
      );
    },
  );
  test('formats medication times without seconds', () {
    const time = MedicationTime(hour: 20, minute: 8, second: 42);

    expect(time.format(TimeDisplayFormat.twelveHour), '8:08 PM');
    expect(time.format(TimeDisplayFormat.twentyFourHour), '20:08');
    expect(
      formatLocalTime('20:08:42', TimeDisplayFormat.twelveHour),
      '8:08 PM',
    );
  });

  test('formats schedule dates exactly for table display', () {
    expect(formatLocalDate('2026-09-27'), '09/27/2026');
    expect(formatLocalDate('not-a-date'), 'not-a-date');
  });
}
