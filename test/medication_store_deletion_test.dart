import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/data/mediary_data_store.dart';
import 'package:mediary/data/mediary_models.dart';
import 'package:mediary/data/mediary_repository.dart';

class _DeletionRepository extends Fake implements MediaryRepository {
  String? removedId;
  Object? failure;
  Completer<void>? generating;
  final generatedSchedules = <List<String>>[];

  @override
  Stream<UserProfileRecord?> watchProfile() => Stream.value(null);
  @override
  Stream<List<MedicationRecord>> watchMedications() =>
      Stream.value([_medication('removed'), _medication('neighbor')]);
  @override
  Stream<List<ScheduleRecord>> watchSchedules() => Stream.value([
    _schedule('schedule-removed', 'removed'),
    _schedule('schedule-neighbor', 'neighbor'),
    _schedule('orphan-schedule', 'deleted-medication'),
  ]);
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
  Future<void> ensureProfile(User user) async {}
  @override
  Future<int> ensureUpcomingDoses({
    required List<ScheduleRecord> schedules,
    required List<DoseLogRecord> existing,
    DateTime? now,
    Duration lookahead = const Duration(days: 14),
  }) async {
    generatedSchedules.add(schedules.map((schedule) => schedule.id).toList());
    await generating?.future;
    return 0;
  }

  @override
  Future<List<String>> removeMedication(String medicationId) async {
    if (failure != null) throw failure!;
    removedId = medicationId;
    return ['dose-removed', 'legacy-dose'];
  }
}

class _TestUser extends Fake implements User {
  @override
  String get uid => 'deletion-test-user';
}

MedicationRecord _medication(String id) => MedicationRecord(
  id: id,
  name: 'Same Medication Name',
  genericName: '',
  strength: '200 MG',
  form: 'Tablet',
  route: '',
  instructions: '',
  prescriber: '',
  pharmacy: '',
  notes: '',
  active: true,
  source: 'manual',
);

ScheduleRecord _schedule(String id, String medicationId) => ScheduleRecord(
  id: id,
  medicationId: medicationId,
  doseAmount: 1,
  doseUnit: 'tablet',
  times: const ['09:00'],
  frequency: 'daily',
  daysOfWeek: const [],
  startDate: '2026-10-04',
  endDate: null,
  timezone: 'UTC',
  instructions: '',
  active: true,
);

DoseLogRecord _dose(String id, String medicationId, String scheduleId) =>
    DoseLogRecord(
      id: id,
      medicationId: medicationId,
      scheduleId: scheduleId,
      scheduledFor: DateTime(2026, 10, 4, 9),
      localDate: '2026-10-04',
      localTime: '09:00',
      status: 'due',
    );

void main() {
  late _DeletionRepository repository;
  late MediaryDataStore store;

  setUp(() {
    repository = _DeletionRepository();
    store = MediaryDataStore(repository: repository)
      ..medications = [_medication('removed'), _medication('neighbor')]
      ..schedules = [
        _schedule('schedule-removed', 'removed'),
        _schedule('schedule-neighbor', 'neighbor'),
      ]
      ..doseLogs = [
        _dose('dose-removed', 'removed', 'schedule-removed'),
        _dose('legacy-dose', '', 'schedule-removed'),
        _dose('dose-neighbor', 'neighbor', 'schedule-neighbor'),
      ];
  });
  tearDown(() => store.dispose());

  test('full medication deletion updates listeners and preserves a same-name neighbor', () async {
    var changes = 0;
    store.addListener(() => changes++);
    final related = await store.removeMedicationAndGetRelatedIds('removed');
    expect(repository.removedId, 'removed');
    expect(store.medications.single.id, 'neighbor');
    expect(store.schedules.single.id, 'schedule-neighbor');
    expect(store.doseLogs.single.id, 'dose-neighbor');
    expect(
      related,
      containsAll(['schedule-removed', 'dose-removed', 'legacy-dose']),
    );
    expect(changes, 1);
  });

  test('failed medication deletion leaves all data intact', () async {
    repository.failure = StateError('Offline');
    await expectLater(store.removeMedication('removed'), throwsStateError);
    expect(store.medications, hasLength(2));
    expect(store.schedules, hasLength(2));
    expect(store.doseLogs, hasLength(3));
  });

  test(
    'deletion waits for dose generation and never regenerates orphan schedules',
    () async {
      repository.generating = Completer<void>();
      await store.start(_TestUser());
      await Future<void>.delayed(Duration.zero);
      expect(repository.generatedSchedules.single, [
        'schedule-removed',
        'schedule-neighbor',
      ]);
      final deleting = store.removeMedication('removed');
      await Future<void>.delayed(Duration.zero);
      expect(repository.removedId, isNull);
      repository.generating!.complete();
      await deleting;
      expect(repository.removedId, 'removed');
      expect(store.medications.single.id, 'neighbor');
      expect(repository.generatedSchedules.last, ['schedule-neighbor']);
      await store.stop();
    },
  );
}
