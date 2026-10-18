import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/data/mediary_data_store.dart';
import 'package:mediary/data/mediary_models.dart';
import 'package:mediary/data/mediary_repository.dart';

class _User extends Fake implements User {
  _User(this.uid);
  @override
  final String uid;
}

class _Repository extends Fake implements MediaryRepository {
  final pending = <String, Completer<void>>{};
  final removing = Completer<List<String>>();
  @override
  Future<List<String>> removeMedication(String id) => removing.future;
  @override
  Stream<UserProfileRecord?> watchProfile() => Stream.value(null);
  @override
  Stream<List<MedicationRecord>> watchMedications() => Stream.value([]);
  @override
  Stream<List<ScheduleRecord>> watchSchedules() => Stream.value([]);
  @override
  Stream<List<DoseLogRecord>> watchDoseLogs() => Stream.value([]);
  @override
  Stream<List<SavedMedicationRecord>> watchSavedMedications() =>
      Stream.value([]);
  @override
  Stream<List<ReportRecord>> watchReports() => Stream.value([]);
  @override
  Stream<List<ScanRecord>> watchScans() => Stream.value([]);
  @override
  Future<void> ensureProfile(User user) =>
      (pending[user.uid] = Completer<void>()).future;
  @override
  Future<int> ensureUpcomingDoses({
    required List<ScheduleRecord> schedules,
    required List<DoseLogRecord> existing,
    DateTime? now,
    Duration lookahead = const Duration(days: 30),
  }) async => 0;
}

class _DelayedRepository extends _Repository {
  final profileStream = StreamController<UserProfileRecord?>();
  final medicationStream = StreamController<List<MedicationRecord>>();
  final scheduleStream = StreamController<List<ScheduleRecord>>();
  final doseStream = StreamController<List<DoseLogRecord>>();
  final savedMedicationStream = StreamController<List<SavedMedicationRecord>>();
  final reportStream = StreamController<List<ReportRecord>>();
  final scanStream = StreamController<List<ScanRecord>>();

  @override
  Stream<UserProfileRecord?> watchProfile() => profileStream.stream;
  @override
  Stream<List<MedicationRecord>> watchMedications() => medicationStream.stream;
  @override
  Stream<List<ScheduleRecord>> watchSchedules() => scheduleStream.stream;
  @override
  Stream<List<DoseLogRecord>> watchDoseLogs() => doseStream.stream;
  @override
  Stream<List<SavedMedicationRecord>> watchSavedMedications() =>
      savedMedicationStream.stream;
  @override
  Stream<List<ReportRecord>> watchReports() => reportStream.stream;
  @override
  Stream<List<ScanRecord>> watchScans() => scanStream.stream;
  @override
  Future<void> ensureProfile(User user) async {}

  Future<void> close() async {
    await Future.wait([
      profileStream.close(),
      medicationStream.close(),
      scheduleStream.close(),
      doseStream.close(),
      savedMedicationStream.close(),
      reportStream.close(),
      scanStream.close(),
    ]);
  }

  void emitInitialData() {
    profileStream.add(null);
    medicationStream.add([]);
    scheduleStream.add([]);
    doseStream.add([]);
    savedMedicationStream.add([]);
    reportStream.add([]);
    scanStream.add([]);
  }
}

void main() {
  test('waits for initial data before a medication write', () async {
    final repository = _DelayedRepository();
    final store = MediaryDataStore(repository: repository);
    await store.start(_User('hydration-user'));
    var completed = false;
    final waiting = store.waitForInitialData().then((_) => completed = true);
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);

    repository.emitInitialData();
    await waiting;
    expect(completed, isTrue);
    expect(store.hasInitialData, isTrue);

    await store.stop();
    await repository.close();
    store.dispose();
  });

  test(
    'profile failure after disposal cannot notify a disposed store',
    () async {
      final repository = _Repository();
      final store = MediaryDataStore(repository: repository);
      final starting = store.start(_User('first'));
      await Future<void>.delayed(Duration.zero);
      store.dispose();
      repository.pending['first']!.completeError(StateError('offline'));
      await expectLater(starting, completes);
    },
  );

  test(
    'late profile failure from a previous account cannot affect a new session',
    () async {
      final repository = _Repository();
      final store = MediaryDataStore(repository: repository);
      final first = store.start(_User('first'));
      await Future<void>.delayed(Duration.zero);
      final second = store.start(_User('second'));
      await Future<void>.delayed(Duration.zero);
      repository.pending['first']!.completeError(StateError('old session'));
      repository.pending['second']!.complete();
      await Future.wait([first, second]);
      expect(store.userId, 'second');
      expect(store.error, isNull);
      store.dispose();
    },
  );
  test('medication removal completed after disposal does not notify', () async {
    final repository = _Repository();
    final store = MediaryDataStore(repository: repository);
    final removal = store.removeMedicationAndGetRelatedIds('medication');
    await Future<void>.delayed(Duration.zero);
    store.dispose();
    repository.removing.complete(['dose']);
    await expectLater(removal, throwsStateError);
  });
}
