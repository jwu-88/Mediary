import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/time_formatting.dart';

void main() {
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
