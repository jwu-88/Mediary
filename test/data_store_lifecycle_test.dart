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

void main() {
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
}
