import 'package:flutter/material.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

enum TimeDisplayFormat {
  twelveHour,
  twentyFourHour;

  String get preferenceValue => this == twelveHour ? '12-hour' : '24-hour';

  String get label => this == twelveHour ? '12-hour' : '24-hour';

  static TimeDisplayFormat fromPreference(String value) =>
      value == '24-hour' ? twentyFourHour : twelveHour;
}

class MedicationTime {
  const MedicationTime({
    required this.hour,
    required this.minute,
    this.second = 0,
  });

  final int hour;
  final int minute;
  final int second;

  factory MedicationTime.fromTimeOfDay(TimeOfDay time, {int second = 0}) {
    return MedicationTime(hour: time.hour, minute: time.minute, second: second);
  }

  factory MedicationTime.fromLocalTime(String value) {
    final parts = value.split(':').map(int.tryParse).toList();
    return MedicationTime(
      hour: parts.isNotEmpty && parts[0] != null ? parts[0]! : 0,
      minute: parts.length > 1 && parts[1] != null ? parts[1]! : 0,
      second: parts.length > 2 && parts[2] != null ? parts[2]! : 0,
    ).normalized;
  }

  MedicationTime get normalized => MedicationTime(
    hour: hour.clamp(0, 23),
    minute: minute.clamp(0, 59),
    second: second.clamp(0, 59),
  );

  TimeOfDay get timeOfDay => TimeOfDay(hour: hour, minute: minute);

  String get localTime =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}';

  DateTime onDate(DateTime date) =>
      DateTime(date.year, date.month, date.day, hour, minute, second);

  String format(TimeDisplayFormat displayFormat) {
    if (displayFormat == TimeDisplayFormat.twentyFourHour) {
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    }
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final period = hour < 12 ? 'AM' : 'PM';
    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }
}

String formatLocalTime(String value, TimeDisplayFormat displayFormat) =>
    MedicationTime.fromLocalTime(value).format(displayFormat);

String formatLocalDate(String value) {
  final parts = value.split('-').map(int.tryParse).toList();
  if (parts.length != 3 || parts.any((part) => part == null)) return value;
  final year = parts[0]!;
  final month = parts[1]!;
  final day = parts[2]!;
  if (year < 1 || month < 1 || month > 12 || day < 1 || day > 31) {
    return value;
  }
  return '${month.toString().padLeft(2, '0')}/'
      '${day.toString().padLeft(2, '0')}/$year';
}

/// Returns a best-effort IANA timezone for the device's current timezone.
///
/// The schedule editor stores IANA names, while Dart exposes a short timezone
/// abbreviation on most platforms. These are the common user-facing zones;
/// unknown zones fall back to UTC and can still be selected explicitly.
String deviceScheduleTimezone() {
  switch (DateTime.now().timeZoneName.toUpperCase()) {
    case 'EST':
    case 'EDT':
      return 'America/New_York';
    case 'CST':
    case 'CDT':
      return 'America/Chicago';
    case 'MST':
    case 'MDT':
      return 'America/Denver';
    case 'PST':
    case 'PDT':
      return 'America/Los_Angeles';
    case 'AKST':
    case 'AKDT':
      return 'America/Anchorage';
    case 'HST':
      return 'Pacific/Honolulu';
    case 'GMT':
    case 'UTC':
      return 'UTC';
    case 'BST':
      return 'Europe/London';
    case 'CET':
    case 'CEST':
      return 'Europe/Paris';
    case 'JST':
      return 'Asia/Tokyo';
    case 'IST':
      return 'Asia/Kolkata';
    case 'AEST':
    case 'AEDT':
      return 'Australia/Sydney';
    case 'NZST':
    case 'NZDT':
      return 'Pacific/Auckland';
  }

  final offset = DateTime.now().timeZoneOffset;
  if (offset.inMinutes == 0) return 'UTC';
  final hours = offset.inHours;
  if (offset.inMinutes == hours * 60 && hours >= -12 && hours <= 14) {
    // Etc/GMT uses the opposite sign convention.
    return 'Etc/GMT${hours > 0 ? '-' : '+'}${hours.abs()}';
  }
  return 'UTC';
}

String preferredScheduleTimezone(String? configuredTimezone) {
  final normalized = configuredTimezone?.trim();
  if (normalized == null || normalized.isEmpty || normalized == 'UTC') {
    return deviceScheduleTimezone();
  }
  return normalized;
}

bool isMedicationTimeInPast(
  DateTime date,
  MedicationTime time, {
  DateTime? now,
  String? timezone,
}) {
  final current = now ?? DateTime.now();
  final scheduled = timezone == null
      ? time.onDate(date)
      : medicationScheduledDate(date, time, timezone);
  return !scheduled.isAfter(current);
}

MedicationTime defaultMedicationTime() {
  final target = DateTime.now().add(const Duration(minutes: 2));
  return MedicationTime(hour: target.hour, minute: target.minute);
}

DateTime medicationScheduledDate(
  DateTime date,
  MedicationTime time,
  String timezone,
) {
  tz_data.initializeTimeZones();
  final location = switch (timezone.trim()) {
    '' => tz.local,
    final value => _timeZoneLocation(value),
  };
  return tz.TZDateTime(
    location,
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
    time.second,
  );
}

tz.Location _timeZoneLocation(String timezone) {
  try {
    return tz.getLocation(timezone);
  } catch (_) {
    return tz.local;
  }
}
