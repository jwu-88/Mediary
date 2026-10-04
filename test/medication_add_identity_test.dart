import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/data/dose_occurrence_identity.dart';
import 'package:mediary/data/mediary_models.dart';
import 'package:mediary/data/mediary_repository.dart';
import 'package:mediary/data/schedule_occurrence_generator.dart';

class _User extends Fake implements User {
  @override
  String get uid => 'test-user';
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User get currentUser => _User();
}

class _Firestore extends Fake implements FirebaseFirestore {
  final documents = <String, Map<String, dynamic>>{};
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);
  @override
  WriteBatch batch() => _Batch(this);
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final transaction = _Transaction(this);
    final result = await handler(transaction);
    for (final operation in transaction.operations) {
      operation();
    }
    return result;
  }
}

// Firestore seals interfaces for production; these test-only fakes exercise
// repository writes without accessing an account.
// ignore: subtype_of_sealed_class
class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.store, this.path);
  final _Firestore store;
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Document(store, '${this.path}/${path ?? 'generated-id'}');
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #where) {
      return _Query(
        store,
        path,
        invocation.positionalArguments.first as String,
        invocation.namedArguments[#isEqualTo],
      );
    }
    return super.noSuchMethod(invocation);
  }
}

// ignore: subtype_of_sealed_class
class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Document(this.store, this.path);
  final _Firestore store;
  @override
  final String path;
  @override
  String get id => path.split('/').last;
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _Collection(store, '$path/$collectionPath');
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _Snapshot(this, store.documents[path]);
}

// ignore: subtype_of_sealed_class
class _Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.reference, this.values);
  @override
  final _Document reference;
  final Map<String, dynamic>? values;
  @override
  bool get exists => values != null;
  @override
  String get id => reference.id;
  @override
  Map<String, dynamic>? data() => values;
}

// ignore: subtype_of_sealed_class
class _QueryDocument extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _QueryDocument(this.reference, this.values);
  @override
  final _Document reference;
  final Map<String, dynamic> values;
  @override
  String get id => reference.id;
  @override
  Map<String, dynamic> data() => values;
}

class _QueryResult extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _QueryResult(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

// ignore: subtype_of_sealed_class
class _Query extends Fake implements Query<Map<String, dynamic>> {
  _Query(this.store, this.path, this.field, this.equals);
  final _Firestore store;
  final String path;
  final String field;
  final Object? equals;
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _QueryResult([
    for (final entry in store.documents.entries)
      if (entry.key.startsWith('$path/') && entry.value[field] == equals)
        _QueryDocument(_Document(store, entry.key), entry.value),
  ]);
}

class _Batch extends Fake implements WriteBatch {
  _Batch(this.store);
  final _Firestore store;
  final operations = <void Function()>[];
  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    operations.add(
      () => store.documents[document.path] = {
        ...?store.documents[document.path],
        ...(data as Map<String, dynamic>),
      },
    );
  }

  @override
  void update<T>(DocumentReference<T> document, T data) => set(document, data);
  @override
  Future<void> commit() async {
    for (final operation in operations) {
      operation();
    }
  }
}

class _Transaction extends Fake implements Transaction {
  _Transaction(this.store);
  final _Firestore store;
  final operations = <void Function()>[];
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> ref,
  ) async =>
      _Snapshot(_Document(store, ref.path), store.documents[ref.path])
          as DocumentSnapshot<T>;
  @override
  Transaction set<T>(DocumentReference<T> ref, T data, [SetOptions? options]) {
    operations.add(
      () => store.documents[ref.path] = {
        ...?store.documents[ref.path],
        ...(data as Map<String, dynamic>),
      },
    );
    return this;
  }

  @override
  Transaction update(
    DocumentReference<Object?> ref,
    Map<Object, Object?> data,
  ) => set(ref, Map<String, dynamic>.from(data));
}

DoseLogRecord _dose(
  String id, {
  String status = 'due',
  String time = '09:00:00',
  String scheduleId = 'schedule',
  String date = '2026-10-05',
}) => DoseLogRecord(
  id: id,
  medicationId: 'medication',
  scheduleId: scheduleId,
  scheduledFor: DateTime.utc(2026, 10, 5, 9),
  localDate: date,
  localTime: time,
  status: status,
);

void main() {
  const date = '2026-10-05';
  const localTime = '09:00:00';
  final id = ScheduleOccurrenceGenerator.deterministicOccurrenceId(
    'schedule',
    localDate: date,
    localTime: localTime,
  );
  final schedule = ScheduleRecord(
    id: 'schedule',
    medicationId: 'medication',
    doseAmount: 1,
    doseUnit: 'tablet',
    times: const [localTime],
    frequency: 'once',
    daysOfWeek: const [],
    startDate: date,
    endDate: date,
    timezone: 'UTC',
    instructions: '',
    active: true,
  );

  for (final generatorFirst in [false, true]) {
    test('stale generation preserves a dose taken on another device', () async {
      final database = _Firestore();
      database.documents['users/test-user/doseLogs/$id'] = {
        'status': 'taken',
        'takenAt': DateTime.utc(2026, 10, 5, 9),
      };
      await MediaryRepository(
        firestore: database,
        auth: _Auth(),
      ).ensureUpcomingDoses(
        schedules: [schedule],
        existing: [],
        now: DateTime.utc(2026, 10, 5, 8),
        lookahead: const Duration(days: 1),
      );
      expect(
        database.documents['users/test-user/doseLogs/$id']!['status'],
        'taken',
      );
    });

    test(
      'add and stale generator write one dose when generatorFirst=$generatorFirst',
      () async {
        final database = _Firestore();
        final repository = MediaryRepository(
          firestore: database,
          auth: _Auth(),
        );
        Future<void> add() => repository.commitScheduleAndDose(
          medication: const MedicationWrite(
            id: 'medication',
            name: 'Test Medication',
            genericName: '',
            strength: '1 MG',
            form: 'Tablet',
            source: 'manual',
          ),
          schedule: const ScheduleWrite(
            id: 'schedule',
            medicationId: 'medication',
            doseAmount: 1,
            doseUnit: 'tablet',
            times: [localTime],
            frequency: 'once',
            startDate: date,
            endDate: date,
            timezone: 'UTC',
          ),
          // Reproduce the old caller's schedule-ID-shaped initial dose.
          dose: DoseWrite(
            id: 'schedule',
            medicationId: 'medication',
            scheduleId: 'schedule',
            scheduledFor: DateTime.utc(2026, 10, 5, 9),
            localDate: date,
            localTime: localTime,
          ),
        );
        Future<void> generate() async {
          await repository.ensureUpcomingDoses(
            schedules: [schedule],
            existing: [],
            now: DateTime.utc(2026, 10, 5, 8),
          );
        }

        if (generatorFirst) {
          await generate();
          await add();
        } else {
          await add();
          await generate();
        }
        final paths = database.documents.keys
            .where((path) => path.contains('/doseLogs/'))
            .toList();
        expect(paths, ['users/test-user/doseLogs/$id']);
      },
    );
  }

  test(
    'hour-minute legacy time matches the generated slot without a second dose',
    () async {
      final database = _Firestore();
      final repository = MediaryRepository(firestore: database, auth: _Auth());
      await repository.ensureUpcomingDoses(
        schedules: [schedule],
        existing: [_dose('legacy', time: '09:00')],
        now: DateTime.utc(2026, 10, 5, 8),
      );
      expect(database.documents, isEmpty);
    },
  );

  test(
    'legacy copies are updated together without changing other entries',
    () async {
      final database = _Firestore();
      final repository = MediaryRepository(firestore: database, auth: _Auth());
      final records = [
        _dose(id),
        _dose('legacy', time: '09:00'),
        _dose('later', time: '10:00'),
        _dose('tomorrow', date: '2026-10-06'),
        _dose('other-regimen', scheduleId: 'other'),
      ];
      for (final dose in records) {
        database.documents['users/test-user/doseLogs/${dose.id}'] = {
          'medicationId': dose.medicationId,
          'scheduleId': dose.scheduleId,
          'localDate': dose.localDate,
          'localTime': dose.localTime,
          'status': dose.status,
        };
      }
      for (final status in ['cancelled', 'due', 'taken', 'snoozed']) {
        await repository.updateDoseStatus(
          id,
          status,
          snoozedUntil: status == 'snoozed'
              ? DateTime.utc(2026, 10, 5, 9, 15)
              : null,
        );
        expect(
          database.documents['users/test-user/doseLogs/$id']!['status'],
          status,
        );
        expect(
          database.documents['users/test-user/doseLogs/legacy']!['status'],
          status,
        );
        for (final neighbor in ['later', 'tomorrow', 'other-regimen']) {
          expect(
            database.documents['users/test-user/doseLogs/$neighbor']!['status'],
            'due',
          );
        }
      }
    },
  );

  test('existing duplicate copies display one slot, preferring recorded user actions', () {
    for (final status in ['cancelled', 'taken', 'snoozed']) {
      final result = uniqueDoseOccurrences([
        _dose(id),
        _dose('legacy', status: status, time: '09:00'),
      ]);
      expect(result, hasLength(1));
      expect(result.single.status, status);
    }
    expect(uniqueDoseOccurrences([_dose('legacy'), _dose(id)]).single.id, id);
  });

  test('different schedule entries remain separate', () {
    expect(
      uniqueDoseOccurrences([
        _dose(id),
        _dose('different-time', time: '10:00'),
        _dose('different-day', date: '2026-10-06'),
        _dose('different-schedule', scheduleId: 'other'),
      ]),
      hasLength(4),
    );
  });
}
