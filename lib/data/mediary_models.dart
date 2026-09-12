import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? firestoreDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

String _string(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;

bool _bool(Object? value, [bool fallback = false]) =>
    value is bool ? value : fallback;

double _double(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return fallback;
}

int _int(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  return fallback;
}

List<String> _strings(Object? value) => value is Iterable
    ? value.whereType<String>().toList(growable: false)
    : const [];

List<int> _ints(Object? value) => value is Iterable
    ? value.whereType<num>().map((item) => item.toInt()).toList(growable: false)
    : const [];

class MediaryPreferences {
  const MediaryPreferences({
    this.theme = 'system',
    this.accentColor = 'blue',
    this.doseNotifications = true,
    this.followUpAlerts = true,
    this.reminderSound = 'Gentle Chime',
    this.language = 'English',
    this.units = 'Metric',
  });

  final String theme;
  final String accentColor;
  final bool doseNotifications;
  final bool followUpAlerts;
  final String reminderSound;
  final String language;
  final String units;

  factory MediaryPreferences.fromMap(Map<String, dynamic>? data) {
    return MediaryPreferences(
      theme: _string(data?['theme'], 'system'),
      accentColor: _string(data?['accentColor'], 'blue'),
      doseNotifications: _bool(data?['doseNotifications'], true),
      followUpAlerts: _bool(data?['followUpAlerts'], true),
      reminderSound: _string(data?['reminderSound'], 'Gentle Chime'),
      language: _string(data?['language'], 'English'),
      units: _string(data?['units'], 'Metric'),
    );
  }
}

class UserProfileRecord {
  const UserProfileRecord({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.bloodType,
    required this.allergies,
    required this.careTeam,
    required this.timezone,
    required this.preferences,
    this.photoUrl,
  });

  final String uid;
  final String email;
  final String displayName;
  final String bloodType;
  final List<String> allergies;
  final String careTeam;
  final String timezone;
  final MediaryPreferences preferences;
  final String? photoUrl;

  factory UserProfileRecord.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return UserProfileRecord(
      uid: snapshot.id,
      email: _string(data['email']),
      displayName: _string(data['displayName']),
      bloodType: _string(data['bloodType'], 'O+'),
      allergies: _strings(data['allergies']),
      careTeam: _string(data['careTeam']),
      timezone: _string(data['timezone'], 'UTC'),
      preferences: MediaryPreferences.fromMap(
        data['preferences'] as Map<String, dynamic>?,
      ),
      photoUrl: _string(data['photoUrl']).trim().isEmpty
          ? null
          : _string(data['photoUrl']).trim(),
    );
  }
}

class MedicationRecord {
  const MedicationRecord({
    required this.id,
    required this.name,
    required this.genericName,
    required this.strength,
    required this.form,
    required this.route,
    required this.instructions,
    required this.prescriber,
    required this.pharmacy,
    required this.notes,
    required this.active,
    required this.source,
    this.catalogId,
    this.catalogSource,
    this.catalogVersion,
    this.createdAt,
    this.updatedAt,
    this.archivedAt,
  });

  final String id;
  final String name;
  final String genericName;
  final String strength;
  final String form;
  final String route;
  final String instructions;
  final String prescriber;
  final String pharmacy;
  final String notes;
  final bool active;
  final String source;
  final String? catalogId;
  final String? catalogSource;
  final String? catalogVersion;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? archivedAt;

  factory MedicationRecord.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return MedicationRecord(
      id: snapshot.id,
      name: _string(data['name']),
      genericName: _string(data['genericName']),
      strength: _string(data['strength']),
      form: _string(data['form']),
      route: _string(data['route']),
      instructions: _string(data['instructions']),
      prescriber: _string(data['prescriber']),
      pharmacy: _string(data['pharmacy']),
      notes: _string(data['notes']),
      active: _bool(data['active'], true),
      source: _string(data['source'], 'manual'),
      catalogId: _nullableString(data['catalogId']),
      catalogSource: _nullableString(data['catalogSource']),
      catalogVersion: _nullableString(data['catalogVersion']),
      createdAt: firestoreDate(data['createdAt']),
      updatedAt: firestoreDate(data['updatedAt']),
      archivedAt: firestoreDate(data['archivedAt']),
    );
  }
}

String? _nullableString(Object? value) {
  if (value is! String) return null;
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

class ScheduleRecord {
  const ScheduleRecord({
    required this.id,
    required this.medicationId,
    required this.doseAmount,
    required this.doseUnit,
    required this.times,
    required this.frequency,
    required this.daysOfWeek,
    required this.startDate,
    required this.endDate,
    required this.timezone,
    required this.instructions,
    required this.active,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String medicationId;
  final double doseAmount;
  final String doseUnit;
  final List<String> times;
  final String frequency;
  final List<int> daysOfWeek;
  final String startDate;
  final String? endDate;
  final String timezone;
  final String instructions;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ScheduleRecord.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return ScheduleRecord(
      id: snapshot.id,
      medicationId: _string(data['medicationId']),
      doseAmount: _double(data['doseAmount']),
      doseUnit: _string(data['doseUnit']),
      times: _strings(data['times']),
      frequency: _string(data['frequency'], 'once'),
      daysOfWeek: _ints(data['daysOfWeek']),
      startDate: _string(data['startDate']),
      endDate: data['endDate'] as String?,
      timezone: _string(data['timezone'], 'UTC'),
      instructions: _string(data['instructions']),
      active: _bool(data['active'], true),
      createdAt: firestoreDate(data['createdAt']),
      updatedAt: firestoreDate(data['updatedAt']),
    );
  }
}

class DoseLogRecord {
  const DoseLogRecord({
    required this.id,
    required this.medicationId,
    required this.scheduleId,
    required this.scheduledFor,
    required this.localDate,
    required this.localTime,
    required this.status,
    this.takenAt,
    this.snoozedUntil,
    this.notes = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String medicationId;
  final String scheduleId;
  final DateTime scheduledFor;
  final String localDate;
  final String localTime;
  final String status;
  final DateTime? takenAt;
  final DateTime? snoozedUntil;
  final String notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DoseLogRecord.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return DoseLogRecord(
      id: snapshot.id,
      medicationId: _string(data['medicationId']),
      scheduleId: _string(data['scheduleId']),
      scheduledFor: firestoreDate(data['scheduledFor']) ?? DateTime.now(),
      localDate: _string(data['localDate']),
      localTime: _string(data['localTime']),
      status: _string(data['status'], 'due'),
      takenAt: firestoreDate(data['takenAt']),
      snoozedUntil: firestoreDate(data['snoozedUntil']),
      notes: _string(data['notes']),
      createdAt: firestoreDate(data['createdAt']),
      updatedAt: firestoreDate(data['updatedAt']),
    );
  }
}

class SavedMedicationRecord {
  const SavedMedicationRecord({
    required this.id,
    this.catalogId,
    this.catalogSource,
    this.catalogVersion,
    this.libraryVersion = '',
  });

  final String id;
  final String? catalogId;
  final String? catalogSource;
  final String? catalogVersion;
  final String libraryVersion;

  factory SavedMedicationRecord.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return SavedMedicationRecord(
      id: snapshot.id,
      catalogId: _nullableString(data['catalogId']),
      catalogSource: _nullableString(data['catalogSource']),
      catalogVersion: _nullableString(data['catalogVersion']),
      libraryVersion: _string(data['libraryVersion']),
    );
  }
}

class ReportRecord {
  const ReportRecord({
    required this.id,
    required this.periodStart,
    required this.periodEnd,
    required this.doseCount,
    required this.takenCount,
    required this.missedCount,
    required this.skippedCount,
    required this.adherencePercent,
    required this.sourceVersion,
    this.generatedAt,
  });

  final String id;
  final String periodStart;
  final String periodEnd;
  final int doseCount;
  final int takenCount;
  final int missedCount;
  final int skippedCount;
  final double adherencePercent;
  final String sourceVersion;
  final DateTime? generatedAt;

  factory ReportRecord.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return ReportRecord(
      id: snapshot.id,
      periodStart: _string(data['periodStart']),
      periodEnd: _string(data['periodEnd']),
      doseCount: _int(data['doseCount']),
      takenCount: _int(data['takenCount']),
      missedCount: _int(data['missedCount']),
      skippedCount: _int(data['skippedCount']),
      adherencePercent: _double(data['adherencePercent']),
      sourceVersion: _string(data['sourceVersion'], 'v1'),
      generatedAt: firestoreDate(data['generatedAt']),
    );
  }
}

class ScanRecord {
  const ScanRecord({
    required this.id,
    required this.status,
    required this.detectedMedicationName,
    required this.extractedText,
    required this.confidence,
    required this.errorMessage,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String status;
  final String detectedMedicationName;
  final String extractedText;
  final double confidence;
  final String errorMessage;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ScanRecord.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return ScanRecord(
      id: snapshot.id,
      status: _string(data['status'], 'complete'),
      detectedMedicationName: _string(data['detectedMedicationName']),
      extractedText: _string(data['extractedText']),
      confidence: _double(data['confidence']),
      errorMessage: _string(data['errorMessage']),
      createdAt: firestoreDate(data['createdAt']),
      updatedAt: firestoreDate(data['updatedAt']),
    );
  }
}
