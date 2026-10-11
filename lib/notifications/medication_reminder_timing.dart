import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/dose_occurrence_identity.dart';
import '../data/mediary_models.dart';
import '../time_formatting.dart';

bool _timeZonesInitialized = false;

void initializeMedicationReminderTimeZones() {
  if (_timeZonesInitialized) return;
  tz_data.initializeTimeZones();
  try {
    tz.setLocalLocation(tz.getLocation(deviceScheduleTimezone()));
  } catch (_) {
    // retain the package's default location if the device zone is unknown.
  }
  _timeZonesInitialized = true;
}

/// shares one reminder instant between foreground timers and native alarms.
DateTime medicationReminderTime(
  DoseLogRecord dose, {
  String? scheduleTimezone,
}) {
  if (dose.snoozedUntil != null) return dose.snoozedUntil!;
  final normalizedTimezone = scheduleTimezone?.trim();
  if (normalizedTimezone == null || normalizedTimezone.isEmpty) {
    // legacy timestamps already represent an absolute reminder instant.
    return dose.scheduledFor;
  }
  initializeMedicationReminderTimeZones();
  final location = _locationFor(normalizedTimezone);
  final dateParts = dose.localDate.split('-').map(int.tryParse).toList();
  final timeParts = dose.localTime.split(':').map(int.tryParse).toList();
  if (dateParts.length == 3 &&
      dateParts.every((part) => part != null) &&
      timeParts.length >= 2 &&
      timeParts.take(2).every((part) => part != null)) {
    final second = timeParts.length > 2 && timeParts[2] != null
        ? timeParts[2]!
        : 0;
    final metadataDate = tz.TZDateTime(
      location,
      dateParts[0]!,
      dateParts[1]!,
      dateParts[2]!,
      timeParts[0]!,
      timeParts[1]!,
      second,
    );
    if (normalizedTimezone == 'UTC') {
      // earlier schedules used utc even when their timestamp used device time.
      final deviceTime = tz.TZDateTime.from(
        dose.scheduledFor,
        _locationFor(deviceScheduleTimezone()),
      );
      if (deviceTime.year == dateParts[0] &&
          deviceTime.month == dateParts[1] &&
          deviceTime.day == dateParts[2] &&
          deviceTime.hour == timeParts[0] &&
          deviceTime.minute == timeParts[1] &&
          deviceTime.second == second) {
        return dose.scheduledFor;
      }
    }
    return metadataDate;
  }
  return tz.TZDateTime.from(dose.scheduledFor, location);
}

/// wakes at the next dose or minute boundary, whichever comes first.
/// recomputing from the wall clock avoids drifting with app startup or delays.
Duration? nextMedicationReminderDelay({
  required DateTime now,
  required Iterable<DoseLogRecord> doses,
  Map<String, String> scheduleTimezones = const {},
}) {
  DateTime? nextDue;
  for (final dose in uniqueDoseOccurrences(doses.toList())) {
    if (dose.status != 'due' && dose.status != 'snoozed') continue;
    final due = medicationReminderTime(
      dose,
      scheduleTimezone: scheduleTimezones[dose.scheduleId],
    );
    if (due.isAfter(now) && (nextDue == null || due.isBefore(nextDue))) {
      nextDue = due;
    }
  }
  if (nextDue == null) return null;

  final untilMinute = Duration(
    microseconds:
        Duration.microsecondsPerMinute -
        now.second * Duration.microsecondsPerSecond -
        now.millisecond * Duration.microsecondsPerMillisecond -
        now.microsecond,
  );
  final untilDue = nextDue.difference(now);
  final delay = untilDue < untilMinute ? untilDue : untilMinute;
  // timers have millisecond resolution. round up to avoid early callbacks or
  // spinning on a positive sub-millisecond remainder.
  return Duration(
    milliseconds:
        (delay.inMicroseconds + Duration.microsecondsPerMillisecond - 1) ~/
        Duration.microsecondsPerMillisecond,
  );
}

tz.Location _locationFor(String timezone) {
  try {
    return tz.getLocation(timezone);
  } catch (_) {
    return tz.local;
  }
}
