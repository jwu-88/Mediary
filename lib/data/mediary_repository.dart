import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'mediary_models.dart';

class ProfileWrite {
  const ProfileWrite({
    required this.displayName,
    required this.email,
    required this.bloodType,
    required this.allergies,
    required this.careTeam,
    this.photoUrl,
  });

  final String displayName;
  final String email;
  final String bloodType;
  final List<String> allergies;
  final String careTeam;
  final String? photoUrl;
}

class MedicationWrite {
  const MedicationWrite({
    required this.name,
    required this.genericName,
    required this.strength,
    required this.form,
    required this.source,
    this.id,
    this.catalogId,
    this.catalogSource,
    this.catalogVersion,
    this.route = '',
    this.instructions = '',
    this.prescriber = '',
    this.pharmacy = '',
    this.notes = '',
    this.active = true,
  });

  final String? id;
  final String? catalogId;
  final String? catalogSource;
  final String? catalogVersion;
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
}

class ScheduleWrite {
  const ScheduleWrite({
    required this.medicationId,
    required this.doseAmount,
    required this.doseUnit,
    required this.times,
    required this.frequency,
    required this.startDate,
    required this.timezone,
    this.id,
    this.daysOfWeek = const [],
    this.endDate,
    this.instructions = '',
    this.active = true,
  });

  final String? id;
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
}

class DoseWrite {
  const DoseWrite({
    required this.medicationId,
    required this.scheduleId,
    required this.scheduledFor,
    required this.localDate,
    required this.localTime,
    this.id,
    this.status = 'due',
    this.takenAt,
    this.snoozedUntil,
    this.notes = '',
  });

  final String? id;
  final String medicationId;
  final String scheduleId;
  final DateTime scheduledFor;
  final String localDate;
  final String localTime;
  final String status;
  final DateTime? takenAt;
  final DateTime? snoozedUntil;
  final String notes;
}

class ScanWrite {
  const ScanWrite({
    required this.status,
    required this.detectedMedicationName,
    required this.extractedText,
    required this.confidence,
    this.errorMessage = '',
    this.id,
  });

  final String? id;
  final String status;
  final String detectedMedicationName;
  final String extractedText;
  final double confidence;
  final String errorMessage;
}

class ReportWrite {
  const ReportWrite({
    required this.periodStart,
    required this.periodEnd,
    required this.doseCount,
    required this.takenCount,
    required this.missedCount,
    required this.skippedCount,
    required this.adherencePercent,
    required this.sourceVersion,
    this.id,
  });

  final String? id;
  final String periodStart;
  final String periodEnd;
  final int doseCount;
  final int takenCount;
  final int missedCount;
  final int skippedCount;
  final double adherencePercent;
  final String sourceVersion;
}

class MediaryRepository {
  MediaryRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : firestore = firestore ?? FirebaseFirestore.instance,
      auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  String get uid {
    final currentUid = auth.currentUser?.uid;
    if (currentUid == null || currentUid.isEmpty) {
      throw StateError('A signed-in user is required for Firestore access.');
    }
    return currentUid;
  }

  DocumentReference<Map<String, dynamic>> get _userRef =>
      firestore.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> get _medications =>
      _userRef.collection('medications');

  CollectionReference<Map<String, dynamic>> get _schedules =>
      _userRef.collection('schedules');

  CollectionReference<Map<String, dynamic>> get _doseLogs =>
      _userRef.collection('doseLogs');

  CollectionReference<Map<String, dynamic>> get _savedMedications =>
      _userRef.collection('savedMedications');

  CollectionReference<Map<String, dynamic>> get _reports =>
      _userRef.collection('reports');

  CollectionReference<Map<String, dynamic>> get _scans =>
      _userRef.collection('scans');

  Future<void> ensureProfile(User user) async {
    final ref = firestore.collection('users').doc(user.uid);
    final snapshot = await ref.get();
    final data = snapshot.data() ?? const <String, dynamic>{};
    final existingPhotoUrl = data['photoUrl'] is String
        ? (data['photoUrl'] as String).trim()
        : '';
    final existingPreferences = data['preferences'];
    final preferences = existingPreferences is Map
        ? Map<String, dynamic>.from(existingPreferences)
        : const <String, dynamic>{};
    final theme = ['system', 'light', 'dark'].contains(preferences['theme'])
        ? preferences['theme']
        : 'system';
    final accentColor =
        [
          'blue',
          'indigo',
          'purple',
          'teal',
          'orange',
        ].contains(preferences['accentColor'])
        ? preferences['accentColor']
        : 'blue';
    final normalizedPreferences = <String, dynamic>{
      'theme': theme,
      'accentColor': accentColor,
      'doseNotifications': preferences['doseNotifications'] is bool
          ? preferences['doseNotifications']
          : true,
      'followUpAlerts': preferences['followUpAlerts'] is bool
          ? preferences['followUpAlerts']
          : true,
      'reminderSound': preferences['reminderSound'] is String
          ? preferences['reminderSound']
          : 'Gentle Chime',
      'language': preferences['language'] is String
          ? preferences['language']
          : 'English',
      'units': preferences['units'] is String ? preferences['units'] : 'Metric',
    };
    await ref.set({
      'email': user.email ?? (data['email'] is String ? data['email'] : ''),
      'displayName':
          user.displayName ??
          (data['displayName'] is String ? data['displayName'] : ''),
      'bloodType': data['bloodType'] is String ? data['bloodType'] : 'O+',
      'allergies': data['allergies'] is Iterable
          ? (data['allergies'] as Iterable).whereType<String>().toList()
          : const <String>[],
      'careTeam': data['careTeam'] is String ? data['careTeam'] : '',
      'photoUrl': existingPhotoUrl.isNotEmpty
          ? existingPhotoUrl
          : (user.photoURL ?? ''),
      'timezone': data['timezone'] is String ? data['timezone'] : 'UTC',
      'preferences': normalizedPreferences,
      'createdAt': data['createdAt'] is Timestamp
          ? data['createdAt']
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<UserProfileRecord?> watchProfile() {
    return _userRef.snapshots().map(
      (snapshot) =>
          snapshot.exists ? UserProfileRecord.fromSnapshot(snapshot) : null,
    );
  }

  Stream<List<MedicationRecord>> watchMedications() =>
      _medications.snapshots().map(
        (snapshot) => snapshot.docs
            .map(MedicationRecord.fromSnapshot)
            .where((medication) => medication.active)
            .toList(growable: false),
      );

  Stream<List<ScheduleRecord>> watchSchedules() => _schedules.snapshots().map(
    (snapshot) => snapshot.docs
        .map(ScheduleRecord.fromSnapshot)
        .where((schedule) => schedule.active)
        .toList(growable: false),
  );

  Stream<List<DoseLogRecord>> watchDoseLogs() => _doseLogs.snapshots().map(
    (snapshot) =>
        snapshot.docs.map(DoseLogRecord.fromSnapshot).toList(growable: false),
  );

  Stream<List<SavedMedicationRecord>> watchSavedMedications() =>
      _savedMedications.snapshots().map(
        (snapshot) => snapshot.docs
            .map(SavedMedicationRecord.fromSnapshot)
            .toList(growable: false),
      );

  Stream<List<ReportRecord>> watchReports() => _reports.snapshots().map(
    (snapshot) =>
        snapshot.docs.map(ReportRecord.fromSnapshot).toList(growable: false),
  );

  Stream<List<ScanRecord>> watchScans() => _scans.snapshots().map(
    (snapshot) =>
        snapshot.docs.map(ScanRecord.fromSnapshot).toList(growable: false),
  );

  Future<void> updateProfile(ProfileWrite profile) async {
    await _userRef.update({
      'displayName': profile.displayName,
      'email': profile.email,
      'bloodType': profile.bloodType,
      'allergies': profile.allergies,
      'careTeam': profile.careTeam,
      'photoUrl': profile.photoUrl ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updatePreference(String key, Object value) async {
    const allowedKeys = {
      'theme',
      'accentColor',
      'doseNotifications',
      'followUpAlerts',
      'reminderSound',
      'language',
      'units',
    };
    if (!allowedKeys.contains(key)) {
      throw ArgumentError.value(key, 'key', 'Unsupported preference.');
    }
    await _userRef.update({
      'preferences.$key': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> upsertMedication(MedicationWrite medication) async {
    final ref = medication.id == null
        ? _medications.doc()
        : _medications.doc(medication.id);
    final exists = (await ref.get()).exists;
    final data = <String, dynamic>{
      'name': medication.name,
      'genericName': medication.genericName,
      'strength': medication.strength,
      'form': medication.form,
      'route': medication.route,
      'instructions': medication.instructions,
      'prescriber': medication.prescriber,
      'pharmacy': medication.pharmacy,
      'notes': medication.notes,
      'active': medication.active,
      'source': medication.source,
      'catalogId': ?medication.catalogId,
      'catalogSource': ?medication.catalogSource,
      'catalogVersion': ?medication.catalogVersion,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!exists) data['createdAt'] = FieldValue.serverTimestamp();
    await ref.set(data, SetOptions(merge: true));
    return ref.id;
  }

  Future<void> archiveMedication(String medicationId) async {
    await _medications.doc(medicationId).update({
      'active': false,
      'archivedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Annotates legacy private medication documents with live catalog aliases.
  ///
  /// The document IDs are intentionally preserved so schedules and dose logs
  /// keep their existing references. Callers should build [catalogIdsByLegacyId]
  /// by resolving legacy names through [MedicationCatalogClient], and omit any
  /// unresolved IDs so those records remain valid manual medications.
  Future<int> migrateLegacyMedicationAliases({
    required Map<String, String> catalogIdsByLegacyId,
    required String catalogVersion,
  }) async {
    if (catalogIdsByLegacyId.isEmpty) return 0;
    final snapshot = await _medications.get();
    final batch = firestore.batch();
    var migrated = 0;
    for (final document in snapshot.docs) {
      final catalogId = catalogIdsByLegacyId[document.id];
      if (catalogId == null || catalogId.trim().isEmpty) continue;
      batch.update(document.reference, {
        'catalogId': catalogId.trim(),
        'catalogSource': 'rxnorm',
        'catalogVersion': catalogVersion,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      migrated++;
    }
    if (migrated > 0) await batch.commit();
    return migrated;
  }

  Future<String> upsertSchedule(ScheduleWrite schedule) async {
    final ref = schedule.id == null
        ? _schedules.doc()
        : _schedules.doc(schedule.id);
    final exists = (await ref.get()).exists;
    final data = <String, dynamic>{
      'medicationId': schedule.medicationId,
      'doseAmount': schedule.doseAmount,
      'doseUnit': schedule.doseUnit,
      'times': schedule.times,
      'frequency': schedule.frequency,
      'daysOfWeek': schedule.daysOfWeek,
      'startDate': schedule.startDate,
      'timezone': schedule.timezone,
      'instructions': schedule.instructions,
      'active': schedule.active,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (schedule.endDate != null) {
      data['endDate'] = schedule.endDate;
    } else if (exists) {
      data['endDate'] = FieldValue.delete();
    }
    if (!exists) data['createdAt'] = FieldValue.serverTimestamp();
    await ref.set(data, SetOptions(merge: true));
    return ref.id;
  }

  Future<void> deactivateSchedule(String scheduleId) async {
    await _schedules.doc(scheduleId).update({
      'active': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> upsertDose(DoseWrite dose) async {
    final ref = dose.id == null ? _doseLogs.doc() : _doseLogs.doc(dose.id);
    final exists = (await ref.get()).exists;
    final data = <String, dynamic>{
      'medicationId': dose.medicationId,
      'scheduleId': dose.scheduleId,
      'scheduledFor': Timestamp.fromDate(dose.scheduledFor),
      'localDate': dose.localDate,
      'localTime': dose.localTime,
      'status': dose.status,
      'notes': dose.notes,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (dose.takenAt != null) {
      data['takenAt'] = Timestamp.fromDate(dose.takenAt!);
    }
    if (dose.snoozedUntil != null) {
      data['snoozedUntil'] = Timestamp.fromDate(dose.snoozedUntil!);
    }
    if (!exists) data['createdAt'] = FieldValue.serverTimestamp();
    await ref.set(data, SetOptions(merge: true));
    return ref.id;
  }

  Future<void> updateDoseStatus(
    String doseId,
    String status, {
    DateTime? takenAt,
    DateTime? snoozedUntil,
  }) async {
    final data = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      'takenAt': takenAt == null
          ? FieldValue.delete()
          : Timestamp.fromDate(takenAt),
      'snoozedUntil': snoozedUntil == null
          ? FieldValue.delete()
          : Timestamp.fromDate(snoozedUntil),
    };
    await _doseLogs.doc(doseId).update(data);
  }

  Future<void> saveLibraryMedication({
    required String medicationId,
    String libraryVersion = 'current',
    String? catalogId,
    String? catalogSource,
    String? catalogVersion,
  }) async {
    await _savedMedications.doc(medicationId).set({
      'savedAt': FieldValue.serverTimestamp(),
      'libraryVersion': libraryVersion,
      'catalogId': ?catalogId,
      'catalogSource': ?catalogSource,
      'catalogVersion': ?catalogVersion,
    });
  }

  Future<void> unsaveLibraryMedication(String medicationId) async {
    await _savedMedications.doc(medicationId).delete();
  }

  Future<String> upsertReport(ReportWrite report) async {
    final id = report.id ?? '${report.periodStart}_${report.periodEnd}';
    await _reports.doc(id).set({
      'periodStart': report.periodStart,
      'periodEnd': report.periodEnd,
      'doseCount': report.doseCount,
      'takenCount': report.takenCount,
      'missedCount': report.missedCount,
      'skippedCount': report.skippedCount,
      'adherencePercent': report.adherencePercent,
      'generatedAt': FieldValue.serverTimestamp(),
      'sourceVersion': report.sourceVersion,
    }, SetOptions(merge: true));
    return id;
  }

  Future<String> createScan(ScanWrite scan) async {
    final ref = scan.id == null ? _scans.doc() : _scans.doc(scan.id);
    final exists = (await ref.get()).exists;
    final data = <String, dynamic>{
      'status': scan.status,
      'detectedMedicationName': scan.detectedMedicationName,
      'extractedText': scan.extractedText,
      'confidence': scan.confidence,
      'errorMessage': scan.errorMessage,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!exists) data['createdAt'] = FieldValue.serverTimestamp();
    await ref.set(data, SetOptions(merge: true));
    return ref.id;
  }

  Future<void> commitScheduleAndDose({
    required MedicationWrite medication,
    required ScheduleWrite schedule,
    required DoseWrite dose,
  }) async {
    final medicationRef = medication.id == null
        ? _medications.doc()
        : _medications.doc(medication.id);
    final scheduleRef = schedule.id == null
        ? _schedules.doc()
        : _schedules.doc(schedule.id);
    final doseRef = dose.id == null ? _doseLogs.doc() : _doseLogs.doc(dose.id);
    final batch = firestore.batch();

    batch.set(medicationRef, {
      'name': medication.name,
      'genericName': medication.genericName,
      'strength': medication.strength,
      'form': medication.form,
      'route': medication.route,
      'instructions': medication.instructions,
      'prescriber': medication.prescriber,
      'pharmacy': medication.pharmacy,
      'notes': medication.notes,
      'active': medication.active,
      'source': medication.source,
      'catalogId': ?medication.catalogId,
      'catalogSource': ?medication.catalogSource,
      'catalogVersion': ?medication.catalogVersion,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(scheduleRef, {
      'medicationId': medicationRef.id,
      'doseAmount': schedule.doseAmount,
      'doseUnit': schedule.doseUnit,
      'times': schedule.times,
      'frequency': schedule.frequency,
      'daysOfWeek': schedule.daysOfWeek,
      'startDate': schedule.startDate,
      if (schedule.endDate != null) 'endDate': schedule.endDate,
      'timezone': schedule.timezone,
      'instructions': schedule.instructions,
      'active': schedule.active,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(doseRef, {
      'medicationId': medicationRef.id,
      'scheduleId': scheduleRef.id,
      'scheduledFor': Timestamp.fromDate(dose.scheduledFor),
      'localDate': dose.localDate,
      'localTime': dose.localTime,
      'status': dose.status,
      'notes': dose.notes,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (dose.takenAt != null) 'takenAt': Timestamp.fromDate(dose.takenAt!),
      if (dose.snoozedUntil != null)
        'snoozedUntil': Timestamp.fromDate(dose.snoozedUntil!),
    }, SetOptions(merge: true));
    await batch.commit();
  }
}
