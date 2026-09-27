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
  String? get userId => _user?.uid;
  var _receivedProfile = false;
  var _receivedMedications = false;
  var _receivedSchedules = false;
  var _receivedDoseLogs = false;
  var _receivedSavedMedications = false;
  var _receivedReports = false;
  var _receivedScans = false;
  bool _doseWindowSyncInFlight = false;
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
    await stop();
    _user = user;
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      _subscriptions.add(
        repository.watchProfile().listen((value) {
          profile = value;
          _receivedProfile = true;
          _finishInitialLoad();
        }, onError: _handleError),
      );
      _subscriptions.add(
        repository.watchMedications().listen((value) {
          medications = value;
          _receivedMedications = true;
          _finishInitialLoad();
        }, onError: _handleError),
      );
      _subscriptions.add(
        repository.watchSchedules().listen((value) {
          schedules = value;
          _receivedSchedules = true;
          _finishInitialLoad();
          _maybeEnsureDoseWindow();
        }, onError: _handleError),
      );
      _subscriptions.add(
        repository.watchDoseLogs().listen((value) {
          doseLogs = value;
          _receivedDoseLogs = true;
          _finishInitialLoad();
          _maybeEnsureDoseWindow();
        }, onError: _handleError),
      );
      _subscriptions.add(
        repository.watchSavedMedications().listen((value) {
          savedMedications = value;
          _receivedSavedMedications = true;
          _finishInitialLoad();
        }, onError: _handleError),
      );
      _subscriptions.add(
        repository.watchReports().listen((value) {
          reports = value;
          _receivedReports = true;
          _finishInitialLoad();
        }, onError: _handleError),
      );
      _subscriptions.add(
        repository.watchScans().listen((value) {
          scans = value;
          _receivedScans = true;
          _finishInitialLoad();
        }, onError: _handleError),
      );
      // Hydrate the user's medication data independently of profile setup.
      // Profile normalization is a write and can fail or be delayed on a
      // returning session; it must not prevent schedules and dose logs from
      // reaching the UI.
      await repository.ensureProfile(user);
    } catch (exception) {
      _handleError(exception);
    }
  }

  void _finishInitialLoad() {
    isLoading = !hasInitialData;
    notifyListeners();
  }

  void _handleError(Object exception, [StackTrace? stackTrace]) {
    error = exception;
    isLoading = false;
    notifyListeners();
  }

  Future<void> stop() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
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
    isLoading = true;
    error = null;
  }

  Future<void> saveProfile(ProfileWrite value) async {
    final user = _user;
    if (user == null) throw StateError('No signed-in user.');
    if (value.email != (user.email ?? '')) {
      await user.verifyBeforeUpdateEmail(value.email);
      throw StateError(
        'Email verification sent. Confirm the new address, then save again.',
      );
    }
    if (value.displayName != (user.displayName ?? '')) {
      await user.updateDisplayName(value.displayName);
    }
    await repository.updateProfile(value);
  }

  Future<void> updatePreference(String key, Object value) =>
      repository.updatePreference(key, value);

  Future<String> saveMedication(MedicationWrite value) =>
      repository.upsertMedication(value);

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

  Future<void> archiveMedication(String id) => repository.archiveMedication(id);

  Future<void> removeMedication(String id) => repository.removeMedication(id);

  Future<void> deactivateSchedule(String id) =>
      repository.deactivateSchedule(id);

  void _maybeEnsureDoseWindow() {
    if (_user == null || !_receivedSchedules || !_receivedDoseLogs) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day).toIso8601String();
    final signature = [
      today,
      for (final schedule in schedules)
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
    unawaited(() async {
      try {
        await repository.ensureUpcomingDoses(
          schedules: schedules,
          existing: doseLogs,
        );
      } catch (exception, stackTrace) {
        // Keep the active UI available when a background reconciliation is
        // temporarily offline. The next schedule/profile snapshot retries.
        _lastDoseWindowSignature = null;
        _handleError(exception, stackTrace);
      } finally {
        _doseWindowSyncInFlight = false;
      }
    }());
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
    unawaited(stop());
    super.dispose();
  }
}
