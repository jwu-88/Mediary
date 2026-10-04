import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../time_formatting.dart';
import 'mediary_models.dart';

/// A single, deterministic occurrence of a medication schedule.
class ScheduleOccurrence {
  const ScheduleOccurrence({
    required this.id,
    required this.scheduleId,
    required this.medicationId,
    required this.scheduledFor,
    required this.localDate,
    required this.localTime,
  });

  final String id;
  final String scheduleId;
  final String medicationId;
  final DateTime scheduledFor;
  final String localDate;
  final String localTime;
}

/// Pure recurrence calculation for medication schedules.
///
/// The generator never reads or writes Firestore. It uses the schedule's
/// local date/time as the source of truth and converts each occurrence through
/// the configured IANA timezone, which keeps DST transitions predictable.
class ScheduleOccurrenceGenerator {
  const ScheduleOccurrenceGenerator();

  static const defaultLookahead = Duration(days: 30);

  List<ScheduleOccurrence> generate(
    ScheduleRecord schedule, {
    DateTime? from,
    DateTime? through,
  }) {
    if (!schedule.active || schedule.frequency == 'asNeeded') {
      return const <ScheduleOccurrence>[];
    }

    final startDate = parseLocalDate(schedule.startDate);
    if (startDate == null || schedule.times.isEmpty) {
      return const <ScheduleOccurrence>[];
    }
    final current = from ?? DateTime.now();
    final horizon = through ?? current.add(defaultLookahead);
    if (!horizon.isAfter(current)) return const <ScheduleOccurrence>[];

    final location = _locationFor(schedule.timezone);
    if (location == null) return const <ScheduleOccurrence>[];
    final localStart = tz.TZDateTime(
      location,
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final endDate = parseLocalDate(schedule.endDate ?? '');
    if (schedule.endDate != null && endDate == null) return const [];
    final endInstant = endDate == null
        ? horizon
        : tz.TZDateTime(
            location,
            endDate.year,
            endDate.month,
            endDate.day,
            23,
            59,
            59,
          );
    final upperBound = endInstant.isBefore(horizon) ? endInstant : horizon;
    if (!upperBound.isAfter(current)) return const <ScheduleOccurrence>[];

    final frequency = schedule.frequency;
    if (frequency == 'every8Hours' || frequency == 'every12Hours') {
      return _intervalOccurrences(
        schedule: schedule,
        localStart: localStart,
        current: current,
        upperBound: upperBound,
        location: location,
        interval: Duration(hours: frequency == 'every8Hours' ? 8 : 12),
      );
    }

    final matchingDays = frequency == 'weekly'
        ? _weeklyDays(schedule, localStart)
        : const <int>[];
    final firstDate = DateTime.utc(
      localStart.year,
      localStart.month,
      localStart.day,
    );
    final lastLocalDate = tz.TZDateTime.from(upperBound, location);
    final lastDate = DateTime.utc(
      lastLocalDate.year,
      lastLocalDate.month,
      lastLocalDate.day,
    );
    final occurrences = <ScheduleOccurrence>[];
    final seenIds = <String>{};
    for (
      var date = firstDate;
      !date.isAfter(lastDate);
      date = date.add(const Duration(days: 1))
    ) {
      if (frequency == 'once' && date != firstDate) break;
      if (frequency == 'weekly' && !matchingDays.contains(date.weekday)) {
        continue;
      }
      if (frequency != 'daily' &&
          frequency != 'weekly' &&
          frequency != 'once') {
        continue;
      }
      for (final rawTime in schedule.times) {
        final time = MedicationTime.tryFromLocalTime(rawTime);
        if (time == null) continue;
        final scheduledFor = tz.TZDateTime(
          location,
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
          time.second,
        );
        if (scheduledFor.isBefore(current) ||
            scheduledFor.isAfter(upperBound)) {
          continue;
        }
        final actualTime = MedicationTime(
          hour: scheduledFor.hour,
          minute: scheduledFor.minute,
          second: scheduledFor.second,
        );
        final occurrence = _occurrence(schedule, scheduledFor, actualTime);
        if (seenIds.add(occurrence.id)) occurrences.add(occurrence);
      }
    }
    occurrences.sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
    return occurrences;
  }

  List<ScheduleOccurrence> _intervalOccurrences({
    required ScheduleRecord schedule,
    required tz.TZDateTime localStart,
    required DateTime current,
    required DateTime upperBound,
    required tz.Location location,
    required Duration interval,
  }) {
    final anchorTime = MedicationTime.tryFromLocalTime(schedule.times.first);
    if (anchorTime == null) return const [];
    var candidate = tz.TZDateTime(
      location,
      localStart.year,
      localStart.month,
      localStart.day,
      anchorTime.hour,
      anchorTime.minute,
      anchorTime.second,
    );
    if (candidate.isBefore(current)) {
      final elapsed = current.difference(candidate).inSeconds;
      final steps = elapsed ~/ interval.inSeconds;
      candidate = candidate.add(interval * steps);
      while (candidate.isBefore(current)) {
        candidate = candidate.add(interval);
      }
    }
    final occurrences = <ScheduleOccurrence>[];
    while (!candidate.isAfter(upperBound)) {
      final local = tz.TZDateTime.from(candidate, location);
      final time = MedicationTime(
        hour: local.hour,
        minute: local.minute,
        second: local.second,
      );
      occurrences.add(_occurrence(schedule, candidate, time));
      candidate = candidate.add(interval);
    }
    return occurrences;
  }

  List<int> _weeklyDays(ScheduleRecord schedule, tz.TZDateTime localStart) {
    final days =
        schedule.daysOfWeek
            .where((day) => day >= DateTime.monday && day <= DateTime.sunday)
            .toSet()
            .toList()
          ..sort();
    return days.isEmpty ? <int>[localStart.weekday] : days;
  }

  ScheduleOccurrence _occurrence(
    ScheduleRecord schedule,
    DateTime scheduledFor,
    MedicationTime time,
  ) {
    final localDate =
        '${scheduledFor.year.toString().padLeft(4, '0')}-'
        '${scheduledFor.month.toString().padLeft(2, '0')}-'
        '${scheduledFor.day.toString().padLeft(2, '0')}';
    final localTime = time.localTime;
    return ScheduleOccurrence(
      id: deterministicOccurrenceId(
        schedule.id,
        localDate: localDate,
        localTime: localTime,
      ),
      scheduleId: schedule.id,
      medicationId: schedule.medicationId,
      scheduledFor: scheduledFor,
      localDate: localDate,
      localTime: localTime,
    );
  }

  static String deterministicOccurrenceId(
    String scheduleId, {
    required String localDate,
    required String localTime,
  }) {
    final safeScheduleId = Uri.encodeComponent(scheduleId);
    return '${safeScheduleId}_${localDate}_'
        '${MedicationTime.fromLocalTime(localTime).localTime.replaceAll(':', '')}';
  }

  static DateTime? parseLocalDate(String value) {
    if (!RegExp(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}$').hasMatch(value)) return null;
    final parts = value.split('-').map(int.parse).toList();
    final date = DateTime.utc(parts[0], parts[1], parts[2]);
    return date.year == parts[0] &&
            date.month == parts[1] &&
            date.day == parts[2]
        ? date
        : null;
  }

  static tz.Location? _locationFor(String timezone) {
    tz_data.initializeTimeZones();
    final normalized = timezone.trim();
    if (normalized.isEmpty) return null;
    try {
      return tz.getLocation(normalized);
    } catch (_) {
      return null;
    }
  }
}
