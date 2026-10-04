import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'mediary_models.dart';
import 'dose_occurrence_identity.dart';
import 'schedule_occurrence_generator.dart';
import '../time_formatting.dart';

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
  static const _validFrequencies = {
    'once',
    'daily',
    'weekly',
    'every8Hours',
    'every12Hours',
    'asNeeded',
  };

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
      'timeFormat': ['12-hour', '24-hour'].contains(preferences['timeFormat'])
          ? preferences['timeFormat']
          : '12-hour',
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
      'timezone':
          data['timezone'] is String &&
              (data['timezone'] as String).trim().isNotEmpty
          ? data['timezone']
          : deviceScheduleTimezone(),
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
        uniqueDoseOccurrences(snapshot.docs.map(DoseLogRecord.fromSnapshot)),
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
      'timeFormat',
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
    final snapshot = await ref.get();
    final exists = snapshot.exists;
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
    if (!exists || snapshot.data()?['createdAt'] is! Timestamp) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    await ref.set(data, SetOptions(merge: true));
    return ref.id;
  }

  Future<void> archiveMedication(String medicationId) async {
    await removeMedication(medicationId);
  }

  /// Permanently removes one medication and all of its regimen records.
  ///
  /// Every query is constrained to this exact medication ID, so deleting one
  /// medication cannot affect another medication in the same account. The
  /// operation is committed in bounded batches so users with many schedules or
  /// dose logs are handled without exceeding Firestore's batch limit.
  Future<List<String>> removeMedication(String medicationId) async {
    if (medicationId.trim().isEmpty) {
      throw ArgumentError.value(
        medicationId,
        'medicationId',
        'A non-empty medication ID is required.',
      );
    }

    final medicationRef = _medications.doc(medicationId);
    final medicationSnapshot = await medicationRef.get();
    final schedules = await _schedules
        .where('medicationId', isEqualTo: medicationId)
        .get();
    final scheduleIds = schedules.docs.map((schedule) => schedule.id).toSet();
    final doseReferences = <String, DocumentReference<Map<String, dynamic>>>{};
    final doses = await _doseLogs
        .where('medicationId', isEqualTo: medicationId)
        .get();
    for (final dose in doses.docs) {
      doseReferences[dose.id] = dose.reference;
    }
    // Older dose records may only point to their schedule. Include them so
    // removing a medication cannot leave a reminder orphaned by legacy data.
    final allScheduleIds = scheduleIds.toList(growable: false);
    for (var offset = 0; offset < allScheduleIds.length; offset += 30) {
      final scheduleIdBatch = allScheduleIds.skip(offset).take(30).toList();
      final scheduleDoses = await _doseLogs
          .where('scheduleId', whereIn: scheduleIdBatch)
          .get();
      for (final dose in scheduleDoses.docs) {
        doseReferences[dose.id] = dose.reference;
      }
    }

    final operations = <void Function(WriteBatch)>[];
    if (medicationSnapshot.exists) {
      operations.add((batch) => batch.delete(medicationRef));
    }
    for (final schedule in schedules.docs) {
      operations.add((batch) => batch.delete(schedule.reference));
    }
    for (final doseReference in doseReferences.values) {
      operations.add((batch) => batch.delete(doseReference));
    }

    await _commitOperations(operations);
    return doseReferences.keys.toList(growable: false);
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
    _validateSchedule(schedule);
    final ref = schedule.id == null
        ? _schedules.doc()
        : _schedules.doc(schedule.id);
    final snapshot = await ref.get();
    final exists = snapshot.exists;
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
    if (!exists || snapshot.data()?['createdAt'] is! Timestamp) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    await ref.set(data, SetOptions(merge: true));
    return ref.id;
  }

  Future<void> deactivateSchedule(String scheduleId) async {
    await _schedules.doc(scheduleId).update({
      'active': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await cancelScheduleDoses(scheduleId);
  }

  Future<String> upsertDose(DoseWrite dose) async {
    _validateDose(dose);
    final ref = dose.id == null ? _doseLogs.doc() : _doseLogs.doc(dose.id);
    final snapshot = await ref.get();
    final exists = snapshot.exists;
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
    if (!exists || snapshot.data()?['createdAt'] is! Timestamp) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
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
    try {
      final reference = _doseLogs.doc(doseId);
      final snapshot = await reference.get();
      if (!snapshot.exists) return;
      final dose = snapshot.data()!;
      final references = <String, DocumentReference<Map<String, dynamic>>>{
        doseId: reference,
      };
      final scheduleId = dose['scheduleId'];
      if (scheduleId is String && scheduleId.isNotEmpty) {
        final candidates = await _doseLogs
            .where('scheduleId', isEqualTo: scheduleId)
            .get();
        final localTime = MedicationTime.fromLocalTime(
          dose['localTime'] as String? ?? '',
        ).localTime;
        for (final candidate in candidates.docs) {
          final other = candidate.data();
          if (other['medicationId'] == dose['medicationId'] &&
              other['localDate'] == dose['localDate'] &&
              MedicationTime.fromLocalTime(other['localTime'] as String? ?? '')
                      .localTime ==
                  localTime) {
            references[candidate.id] = candidate.reference;
          }
        }
      }
      // Update every legacy copy of this exact occurrence, not other times or
      // dates. A stale duplicate must not undo Taken, Snooze, Delete, or Undo.
      await _commitOperations([
        for (final reference in references.values)
          (batch) => batch.update(reference, data),
      ]);
    } on FirebaseException catch (error) {
      // A stale dashboard can outlive a dose that was removed on another
      // device. Treat that idempotent case as success so the UI can reconcile
      // on the next Firestore snapshot; surface permission/network failures.
      if (error.code != 'not-found') rethrow;
    }
  }

  /// Creates missing future occurrences and cancels obsolete future ones.
  ///
  /// Existing records are matched by schedule, local date, and local time so
  /// older random document IDs remain compatible. New records always use the
  /// generator's deterministic ID, making retries and app restarts idempotent.
  Future<int> ensureUpcomingDoses({
    required List<ScheduleRecord> schedules,
    required List<DoseLogRecord> existing,
    DateTime? now,
    Duration lookahead = ScheduleOccurrenceGenerator.defaultLookahead,
  }) async {
    final current = now ?? DateTime.now();
    final through = current.add(lookahead);
    final generator = const ScheduleOccurrenceGenerator();
    final occurrencesBySchedule = <String, List<ScheduleOccurrence>>{};
    final operations = <void Function(WriteBatch)>[];
    final existingByKey = <String, DoseLogRecord>{};

    String key(String scheduleId, String localDate, String localTime) =>
        '$scheduleId|$localDate|${MedicationTime.fromLocalTime(localTime).localTime}';

    for (final dose in existing) {
      existingByKey[key(dose.scheduleId, dose.localDate, dose.localTime)] =
          dose;
    }

    for (final schedule in schedules.where((item) => item.active)) {
      final occurrences = generator.generate(
        schedule,
        from: current,
        through: through,
      );
      occurrencesBySchedule[schedule.id] = occurrences;
      for (final occurrence in occurrences) {
        final existingDose =
            existingByKey[key(
              schedule.id,
              occurrence.localDate,
              occurrence.localTime,
            )];
        if (existingDose == null) {
          final ref = _doseLogs.doc(occurrence.id);
          operations.add(
            (batch) => batch.set(ref, {
              'medicationId': occurrence.medicationId,
              'scheduleId': occurrence.scheduleId,
              'scheduledFor': Timestamp.fromDate(occurrence.scheduledFor),
              'localDate': occurrence.localDate,
              'localTime': occurrence.localTime,
              'status': 'due',
              'notes': '',
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true)),
          );
        } else if (_canReconcile(existingDose) &&
            existingDose.scheduledFor.millisecondsSinceEpoch !=
                occurrence.scheduledFor.millisecondsSinceEpoch) {
          // A timezone or DST interpretation changed while the local slot
          // stayed the same. Keep the user's dose record but repair its
          // instant so notification scheduling follows the updated schedule.
          final ref = _doseLogs.doc(existingDose.id);
          operations.add(
            (batch) => batch.update(ref, {
              'scheduledFor': Timestamp.fromDate(occurrence.scheduledFor),
              'updatedAt': FieldValue.serverTimestamp(),
            }),
          );
        }
      }
    }

    // A schedule edit can make an already-generated future dose obsolete.
    // Preserve taken/missed history, but cancel anything still actionable.
    final generatedKeys = <String>{
      for (final entry in occurrencesBySchedule.entries)
        for (final occurrence in entry.value)
          key(entry.key, occurrence.localDate, occurrence.localTime),
    };
    final activeScheduleIds = occurrencesBySchedule.keys.toSet();
    for (final dose in existing) {
      if (!activeScheduleIds.contains(dose.scheduleId) ||
          !_canReconcile(dose) ||
          !dose.scheduledFor.isAfter(
            current.subtract(const Duration(minutes: 2)),
          )) {
        continue;
      }
      final doseKey = key(dose.scheduleId, dose.localDate, dose.localTime);
      if (!generatedKeys.contains(doseKey)) {
        final ref = _doseLogs.doc(dose.id);
        operations.add(
          (batch) => batch.update(ref, {
            'status': 'cancelled',
            'snoozedUntil': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          }),
        );
      }
    }

    await _commitOperations(operations);
    return occurrencesBySchedule.values.fold<int>(
      0,
      (total, items) => total + items.length,
    );
  }

  /// Cancels actionable doses for an inactive schedule while preserving logs.
  Future<void> cancelScheduleDoses(String scheduleId) async {
    final snapshot = await _doseLogs
        .where('scheduleId', isEqualTo: scheduleId)
        .get();
    final operations = <void Function(WriteBatch)>[];
    for (final dose in snapshot.docs) {
      final status = dose.data()['status'];
      if (status != 'due' && status != 'snoozed') continue;
      operations.add(
        (batch) => batch.update(dose.reference, {
          'status': 'cancelled',
          'snoozedUntil': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      );
    }
    await _commitOperations(operations);
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
    required DoseWrite? dose,
  }) async {
    _validateSchedule(schedule);
    if (dose != null) _validateDose(dose);
    final medicationRef = medication.id == null
        ? _medications.doc()
        : _medications.doc(medication.id);
    final scheduleRef = schedule.id == null
        ? _schedules.doc()
        : _schedules.doc(schedule.id);
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
    if (dose != null) {
      // The initial add and background generator must target the same record,
      // even if independent Firestore listeners arrive out of order.
      final doseRef = _doseLogs.doc(
        ScheduleOccurrenceGenerator.deterministicOccurrenceId(
          scheduleRef.id,
          localDate: dose.localDate,
          localTime: dose.localTime,
        ),
      );
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
    }
    await batch.commit();
  }

  bool _canReconcile(DoseLogRecord dose) =>
      dose.status == 'due' || dose.status == 'snoozed';

  Future<void> _commitOperations(
    List<void Function(WriteBatch)> operations,
  ) async {
    const maxOperationsPerBatch = 450;
    for (
      var start = 0;
      start < operations.length;
      start += maxOperationsPerBatch
    ) {
      final end = (start + maxOperationsPerBatch).clamp(0, operations.length);
      final batch = firestore.batch();
      for (final operation in operations.sublist(start, end)) {
        operation(batch);
      }
      await batch.commit();
    }
  }

  void _validateSchedule(ScheduleWrite schedule) {
    if (schedule.medicationId.trim().isEmpty) {
      throw ArgumentError.value(schedule.medicationId, 'medicationId');
    }
    if (!schedule.doseAmount.isFinite || schedule.doseAmount <= 0) {
      throw ArgumentError.value(schedule.doseAmount, 'doseAmount');
    }
    if (schedule.doseUnit.trim().isEmpty) {
      throw ArgumentError.value(schedule.doseUnit, 'doseUnit');
    }
    if (!_validFrequencies.contains(schedule.frequency)) {
      throw ArgumentError.value(schedule.frequency, 'frequency');
    }
    if (schedule.times.isEmpty ||
        schedule.times.any((time) => !_isValidLocalTime(time))) {
      throw ArgumentError.value(schedule.times, 'times');
    }
    if (DateTime.tryParse(schedule.startDate) == null) {
      throw ArgumentError.value(schedule.startDate, 'startDate');
    }
    if (schedule.endDate != null &&
        (DateTime.tryParse(schedule.endDate!) == null ||
            DateTime.parse(schedule.endDate!)
                .isBefore(DateTime.parse(schedule.startDate)))) {
      throw ArgumentError.value(schedule.endDate, 'endDate');
    }
    if (schedule.daysOfWeek.any((day) => day < 1 || day > 7)) {
      throw ArgumentError.value(schedule.daysOfWeek, 'daysOfWeek');
    }
    _validateTimezone(schedule.timezone);
  }

  void _validateDose(DoseWrite dose) {
    if (dose.medicationId.trim().isEmpty || dose.scheduleId.trim().isEmpty) {
      throw ArgumentError('Dose references must not be empty.');
    }
    if (dose.localDate.trim().isEmpty || !_isValidLocalTime(dose.localTime)) {
      throw ArgumentError('Dose local date/time is invalid.');
    }
    const statuses = {
      'due',
      'taken',
      'missed',
      'skipped',
      'cancelled',
      'snoozed',
    };
    if (!statuses.contains(dose.status)) {
      throw ArgumentError.value(dose.status, 'status');
    }
    if (dose.status == 'snoozed' && dose.snoozedUntil == null) {
      throw ArgumentError('Snoozed doses require snoozedUntil.');
    }
  }

  bool _isValidLocalTime(String value) {
    final parts = value.split(':').map(int.tryParse).toList();
    return (parts.length == 2 || parts.length == 3) &&
        parts.every((part) => part != null) &&
        parts[0]! >= 0 &&
        parts[0]! <= 23 &&
        parts[1]! >= 0 &&
        parts[1]! <= 59 &&
        (parts.length == 2 || (parts[2]! >= 0 && parts[2]! <= 59));
  }

  void _validateTimezone(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) throw ArgumentError.value(value, 'timezone');
    tz_data.initializeTimeZones();
    try {
      tz.getLocation(normalized);
    } catch (_) {
      throw ArgumentError.value(value, 'timezone', 'Unknown IANA timezone.');
    }
  }
}
