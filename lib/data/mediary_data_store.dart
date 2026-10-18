import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'mediary_models.dart';
import 'mediary_repository.dart';

class MediaryDataStore extends ChangeNotifier {
  MediaryDataStore({MediaryRepository? repository})
    : repository = repository ?? MediaryRepository();

  final MediaryRepository repository;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  UserProfileRecord? profile;
  List<MedicationRecord> medications = const [];
  List<ScheduleRecord> schedules = const [];
  List<DoseLogRecord> doseLogs = const [];
  List<SavedMedicationRecord> savedMedications = const [];
  List<ReportRecord> reports = const [];
  List<ScanRecord> scans = const [];
  bool isLoading = true;
  Object? error;
  User? _user;
  bool _disposed = false;
  int _generation = 0;
  bool _isCurrent(int generation) => !_disposed && generation == _generation;
  String? get userId => _user?.uid;
  var _receivedProfile = false;
  var _receivedMedications = false;
  var _receivedSchedules = false;
  var _receivedDoseLogs = false;
  var _receivedSavedMedications = false;
  var _receivedReports = false;
  var _receivedScans = false;
  bool _doseWindowSyncInFlight = false;
  Future<void>? _doseWindowSync;
  final Set<String> _removingMedicationIds = {};
  String? _lastDoseWindowSignature;

  bool get hasInitialData =>
      _receivedProfile &&
      _receivedMedications &&
      _receivedSchedules &&
      _receivedDoseLogs &&
      _receivedSavedMedications &&
      _receivedReports &&
      _receivedScans;

  Future<void> start(User user) async {
    if (_user?.uid == user.uid && _subscriptions.isNotEmpty) return;
    if (_disposed) return;
    final stopping = stop();
    final generation = _generation;
    await stopping;
    if (!_isCurrent(generation)) return;
    _user = user;
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      _subscriptions.add(
        repository.watchProfile().listen(
          (value) {
            if (!_isCurrent(generation)) return;
            profile = value;
            _receivedProfile = true;
            _finishInitialLoad();
          },
          onError: (Object exception, StackTrace stackTrace) {
            if (_isCurrent(generation)) _handleError(exception, stackTrace);
          },
        ),
      );
      _subscriptions.add(
        repository.watchMedications().listen(
          (value) {
            if (!_isCurrent(generation)) return;
            medications = value;
            _receivedMedications = true;
            _finishInitialLoad();
            _maybeEnsureDoseWindow();
          },
          onError: (Object exception, StackTrace stackTrace) {
            if (_isCurrent(generation)) _handleError(exception, stackTrace);
          },
        ),
      );
      _subscriptions.add(
        repository.watchSchedules().listen(
          (value) {
            if (!_isCurrent(generation)) return;
            schedules = value;
            _receivedSchedules = true;
            _finishInitialLoad();
            _maybeEnsureDoseWindow();
          },
          onError: (Object exception, StackTrace stackTrace) {
            if (_isCurrent(generation)) _handleError(exception, stackTrace);
          },
        ),
      );
      _subscriptions.add(
        repository.watchDoseLogs().listen(
          (value) {
            if (!_isCurrent(generation)) return;
            doseLogs = value;
            _receivedDoseLogs = true;
            _finishInitialLoad();
            _maybeEnsureDoseWindow();
          },
          onError: (Object exception, StackTrace stackTrace) {
            if (_isCurrent(generation)) _handleError(exception, stackTrace);
          },
        ),
      );
      _subscriptions.add(
        repository.watchSavedMedications().listen(
          (value) {
            if (!_isCurrent(generation)) return;
            savedMedications = value;
            _receivedSavedMedications = true;
            _finishInitialLoad();
          },
          onError: (Object exception, StackTrace stackTrace) {
            if (_isCurrent(generation)) _handleError(exception, stackTrace);
          },
        ),
      );
      _subscriptions.add(
        repository.watchReports().listen(
          (value) {
            if (!_isCurrent(generation)) return;
            reports = value;
            _receivedReports = true;
            _finishInitialLoad();
          },
          onError: (Object exception, StackTrace stackTrace) {
            if (_isCurrent(generation)) _handleError(exception, stackTrace);
          },
        ),
      );
      _subscriptions.add(
        repository.watchScans().listen(
          (value) {
            if (!_isCurrent(generation)) return;
            scans = value;
            _receivedScans = true;
            _finishInitialLoad();
          },
          onError: (Object exception, StackTrace stackTrace) {
            if (_isCurrent(generation)) _handleError(exception, stackTrace);
          },
        ),
      );
      // hydrate the user's medication data independently of profile setup.
      // profile normalization is a write and can fail or be delayed on a
      // returning session; it must not prevent schedules and dose logs from
      // reaching the ui.
      await repository.ensureProfile(user);
    } catch (exception) {
      if (_isCurrent(generation)) _handleError(exception);
    }
  }

  void _finishInitialLoad() {
    if (_disposed) return;
    isLoading = !hasInitialData;
    notifyListeners();
  }

  void _handleError(Object exception, [StackTrace? stackTrace]) {
    if (_disposed) return;
    error = exception;
    isLoading = false;
    notifyListeners();
  }

  Future<void> stop() async {
    _generation++;
    final subscriptions = List.of(_subscriptions);
    _subscriptions.clear();
    _user = null;
    profile = null;
    medications = const [];
    schedules = const [];
    doseLogs = const [];
    savedMedications = const [];
    reports = const [];
    scans = const [];
    _receivedProfile = false;
    _receivedMedications = false;
    _receivedSchedules = false;
    _receivedDoseLogs = false;
    _receivedSavedMedications = false;
    _receivedReports = false;
    _receivedScans = false;
    _doseWindowSyncInFlight = false;
    _lastDoseWindowSignature = null;
    _doseWindowSync = null;
    _removingMedicationIds.clear();
    isLoading = true;
    error = null;
    await Future.wait(
      subscriptions.map((subscription) => subscription.cancel()),
    );
  }

  Future<void> saveProfile(ProfileWrite value) async {
    final user = _user;
    final generation = _generation;
    if (user == null || _disposed) throw StateError('No signed-in user.');
    if (value.email != (user.email ?? '')) {
      await user.verifyBeforeUpdateEmail(value.email);
      throw StateError(
        'Email verification sent. Confirm the new address, then save again.',
      );
    }
    if (value.displayName != (user.displayName ?? '')) {
      await user.updateDisplayName(value.displayName);
    }
    if (!_isCurrent(generation)) {
      throw StateError('Account changed while saving.');
    }
    await repository.updateProfile(value);
  }

  Future<void> waitForInitialData({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (hasInitialData) return;
    if (_disposed || _user == null) {
      throw StateError('Medication data is unavailable.');
    }

    final ready = Completer<void>();
    void checkReadiness() {
      if (ready.isCompleted) return;
      if (hasInitialData) {
        ready.complete();
      } else if (error != null) {
        ready.completeError(error!);
      }
    }

    addListener(checkReadiness);
    checkReadiness();
    try {
      await ready.future.timeout(
        timeout,
        onTimeout: () => throw TimeoutException(
          'Timed out waiting for medication data.',
          timeout,
        ),
      );
    } finally {
      removeListener(checkReadiness);
    }
  }

  Future<void> updatePreference(String key, Object value) =>
      repository.updatePreference(key, value);

  Future<String> saveMedication(MedicationWrite value) =>
      repository.upsertMedication(value);

  Future<int> migrateLegacyMedicationAliases({
    required Map<String, String> catalogIdsByLegacyId,
    required String catalogVersion,
  }) async {
    if (catalogIdsByLegacyId.isEmpty) return 0;
    final generation = _generation;
    final migrated = await repository.migrateLegacyMedicationAliases(
      catalogIdsByLegacyId: catalogIdsByLegacyId,
      catalogVersion: catalogVersion,
    );
    if (!_isCurrent(generation) || migrated == 0) return migrated;

    medications = [
      for (final medication in medications)
        if (catalogIdsByLegacyId[medication.id] case final catalogId?)
          medication.copyWithCatalogAlias(
            catalogId: catalogId,
            catalogVersion: catalogVersion,
          )
        else
          medication,
    ];
    notifyListeners();
    return migrated;
  }

  Future<String> saveSchedule(ScheduleWrite value) =>
      repository.upsertSchedule(value);

  Future<String> saveDose(DoseWrite value) => repository.upsertDose(value);

  Future<int> ensureUpcomingDoses({DateTime? now}) async {
    if (_user == null) throw StateError('No signed-in user.');
    return repository.ensureUpcomingDoses(
      schedules: schedules,
      existing: doseLogs,
      now: now,
    );
  }

  Future<void> updateDoseStatus(
    String id,
    String status, {
    DateTime? takenAt,
    DateTime? snoozedUntil,
  }) => repository.updateDoseStatus(
    id,
    status,
    takenAt: takenAt,
    snoozedUntil: snoozedUntil,
  );

  Future<void> archiveMedication(String id) async {
    await removeMedication(id);
  }

  Future<void> removeMedication(String id) async {
    await removeMedicationAndGetRelatedIds(id);
  }

  Future<Set<String>> removeMedicationAndGetRelatedIds(String id) async {
    final generation = _generation;
    if (_disposed) throw StateError('Account is closed.');
    final selected = medications.where((medication) => medication.id == id);
    final catalogId = selected.isEmpty ? null : selected.first.catalogId;
    final medicationIds = <String>{
      id,
      if (catalogId != null)
        for (final medication in medications)
          if (medication.catalogId == catalogId) medication.id,
    };
    _removingMedicationIds.addAll(medicationIds);
    try {
      // let an already-running generator finish before querying deletions so
      // it cannot recreate occurrences after their medication was removed.
      await _doseWindowSync;
      if (!_isCurrent(generation)) {
        throw StateError('Account changed while removing.');
      }
      return await _removeMedicationAndGetRelatedIds(medicationIds, generation);
    } finally {
      if (_isCurrent(generation)) {
        _removingMedicationIds.removeAll(medicationIds);
      }
    }
  }

  Future<Set<String>> _removeMedicationAndGetRelatedIds(
    Set<String> medicationIds,
    int generation,
  ) async {
    final scheduleIds = schedules
        .where((schedule) => medicationIds.contains(schedule.medicationId))
        .map((schedule) => schedule.id)
        .toSet();
    final deletedDoseIds = <String>{};
    for (final medicationId in medicationIds) {
      deletedDoseIds.addAll(await repository.removeMedication(medicationId));
      if (!_isCurrent(generation)) {
        throw StateError('Account changed while removing.');
      }
    }
    final relatedIds = {...scheduleIds, ...deletedDoseIds};
    medications = medications
        .where((medication) => !medicationIds.contains(medication.id))
        .toList(growable: false);
    schedules = schedules
        .where((schedule) => !scheduleIds.contains(schedule.id))
        .toList(growable: false);
    doseLogs = doseLogs
        .where(
          (dose) =>
              !medicationIds.contains(dose.medicationId) &&
              !relatedIds.contains(dose.id),
        )
        .toList(growable: false);
    notifyListeners();
    return relatedIds;
  }

  Future<void> deactivateSchedule(String id) =>
      repository.deactivateSchedule(id);

  void _maybeEnsureDoseWindow() {
    if (_user == null ||
        !_receivedMedications ||
        !_receivedSchedules ||
        !_receivedDoseLogs) {
      return;
    }
    final activeMedicationIds = {
      for (final medication in medications)
        if (medication.active &&
            !_removingMedicationIds.contains(medication.id))
          medication.id,
    };
    final validSchedules = schedules
        .where(
          (schedule) => activeMedicationIds.contains(schedule.medicationId),
        )
        .toList(growable: false);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day).toIso8601String();
    final signature = [
      today,
      for (final schedule in validSchedules)
        '${schedule.id}:${schedule.frequency}:${schedule.startDate}:'
            '${schedule.endDate}:${schedule.timezone}:${schedule.times.join(',')}:'
            '${schedule.daysOfWeek.join(',')}:${schedule.active}:'
            '${schedule.updatedAt?.millisecondsSinceEpoch}',
    ].join('|');
    if (_doseWindowSyncInFlight || signature == _lastDoseWindowSignature) {
      return;
    }
    _lastDoseWindowSignature = signature;
    _doseWindowSyncInFlight = true;
    final generation = _generation;
    _doseWindowSync = () async {
      var completed = false;
      try {
        await repository.ensureUpcomingDoses(
          schedules: validSchedules,
          existing: doseLogs,
        );
        completed = true;
      } catch (exception, stackTrace) {
        // keep the active ui available when a background reconciliation is
        // temporarily offline. the next schedule/profile snapshot retries.
        if (_isCurrent(generation)) {
          _lastDoseWindowSignature = null;
          _handleError(exception, stackTrace);
        }
      } finally {
        if (_isCurrent(generation)) {
          _doseWindowSyncInFlight = false;
          if (completed) _maybeEnsureDoseWindow();
        }
      }
    }();
    unawaited(_doseWindowSync);
  }

  Future<void> saveLibraryMedication({
    required String id,
    String libraryVersion = 'current',
    String? catalogId,
    String? catalogSource,
    String? catalogVersion,
  }) => repository.saveLibraryMedication(
    medicationId: id,
    libraryVersion: libraryVersion,
    catalogId: catalogId,
    catalogSource: catalogSource,
    catalogVersion: catalogVersion,
  );

  Future<void> unsaveLibraryMedication(String id) =>
      repository.unsaveLibraryMedication(id);

  Future<String> saveReport(ReportWrite value) =>
      repository.upsertReport(value);

  Future<String> saveScan(ScanWrite value) => repository.createScan(value);

  Future<void> commitScheduleAndDose({
    required MedicationWrite medication,
    required ScheduleWrite schedule,
    required DoseWrite? dose,
  }) => repository.commitScheduleAndDose(
    medication: medication,
    schedule: schedule,
    dose: dose,
  );

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    super.dispose();
  }
}
