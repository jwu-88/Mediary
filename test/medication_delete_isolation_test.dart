import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/dashboard_screen.dart';

const _selected = DashboardDoseData(
  id: 'delete-selected',
  medicationId: 'medication-1',
  name: 'Ibuprofen',
  details: '200 MG · 8:00 AM',
  status: 'due',
);
const _sameMedication = DashboardDoseData(
  id: 'keep-evening',
  medicationId: 'medication-1',
  name: 'Ibuprofen',
  details: '400 MG · 8:00 PM',
  status: 'taken',
);
const _neighbor = DashboardDoseData(
  id: 'keep-neighbor',
  medicationId: 'medication-2',
  name: 'Lisinopril',
  details: '10 MG · 9:00 AM',
  status: 'snoozed',
);
const _allDoses = [_selected, _sameMedication, _neighbor];

typedef _StatusCallback = Future<void> Function(
  String id,
  String status, {
  DateTime? snoozedUntil,
});

DashboardDoseData _withStatus(
  DashboardDoseData dose,
  String status, {
  DateTime? snoozedUntil,
}) => DashboardDoseData(
  id: dose.id,
  medicationId: dose.medicationId,
  name: dose.name,
  details: dose.details,
  status: status,
  snoozedUntil: snoozedUntil ?? dose.snoozedUntil,
);

Widget _dashboard({
  List<DashboardDoseData> doses = _allDoses,
  _StatusCallback? onStatusChanged,
  Future<void> Function(String)? onRemoveMedication,
  Key? dashboardKey,
}) => MaterialApp(
  home: Scaffold(
    body: DashboardScreen(
      key: dashboardKey,
      email: 'person@example.com',
      displayName: 'Taylor Morgan',
      now: DateTime(2026, 8, 23, 9),
      bottomPadding: 24,
      initialDoses: doses,
      onDoseStatusChanged: onStatusChanged,
      onRemoveMedication: onRemoveMedication,
    ),
  ),
);

Finder _deleteButton(String id) => find.byKey(Key('dashboardDeleteDose_$id'));

Finder _dashboardScrollable() => find
    .descendant(
      of: find.byKey(const Key('dashboardScrollView')),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _showDoseRows(WidgetTester tester) async {
  if (find.byKey(const Key('dashboardScrollView')).evaluate().isEmpty) return;
  await tester.scrollUntilVisible(
    _deleteButton(_neighbor.id),
    240,
    scrollable: _dashboardScrollable(),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapDelete(WidgetTester tester, String id) async {
  final button = _deleteButton(id);
  await tester.scrollUntilVisible(
    button,
    240,
    scrollable: _dashboardScrollable(),
  );
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await _showDoseRows(tester);
  await tester.tap(button);
  await tester.pumpAndSettle();
  await _showDoseRows(tester);
}

Future<void> _tapUndo(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Undo'),
    -240,
    scrollable: _dashboardScrollable(),
  );
  await tester.pumpAndSettle();
  await _showDoseRows(tester);
  await tester.tap(find.text('Undo'));
  await tester.pumpAndSettle();
  await _showDoseRows(tester);
}

void _expectOtherDosesUnchanged() {
  expect(_deleteButton(_sameMedication.id), findsOneWidget);
  expect(_deleteButton(_neighbor.id), findsOneWidget);
  expect(find.text('400 MG\n8:00 PM'), findsOneWidget);
  expect(find.text('10 MG\n9:00 AM'), findsOneWidget);
  expect(find.text('Taken'), findsOneWidget);
  expect(find.text('Later'), findsOneWidget);
}

void main() {
  void deletionTest(String description, WidgetTesterCallback body) {
    testWidgets(description, (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }

  deletionTest(
    'trash cancels only the selected dose and preserves the regimen',
    (tester) async {
      final changes = <(String, String)>[];
      final removedMedications = <String>[];
      await tester.pumpWidget(
        _dashboard(
          doses: const [_selected, _neighbor],
          onStatusChanged: (id, status, {snoozedUntil}) async {
            changes.add((id, status));
            expect(snoozedUntil, isNull);
          },
          onRemoveMedication: (id) async => removedMedications.add(id),
        ),
      );
      await _tapDelete(tester, _selected.id);

      expect(changes, [(_selected.id, 'cancelled')]);
      expect(removedMedications, isEmpty);
      expect(_deleteButton(_selected.id), findsNothing);
      expect(_deleteButton(_neighbor.id), findsOneWidget);
      expect(find.text('Remove From Today'), findsNothing);
    },
  );

  deletionTest(
    'trash preserves a different time and dose of the same medication',
    (tester) async {
      final changes = <(String, String)>[];
      final removedMedications = <String>[];
      await tester.pumpWidget(
        _dashboard(
          onStatusChanged: (id, status, {snoozedUntil}) async =>
              changes.add((id, status)),
          onRemoveMedication: (id) async => removedMedications.add(id),
        ),
      );
      await _tapDelete(tester, _selected.id);

      expect(changes, [(_selected.id, 'cancelled')]);
      expect(removedMedications, isEmpty);
      expect(_deleteButton(_selected.id), findsNothing);
      _expectOtherDosesUnchanged();
      expect(find.byTooltip('Remove Ibuprofen from today'), findsOneWidget);
    },
  );

  deletionTest('failed cancellation rolls back only the selected dose', (
    tester,
  ) async {
    final pending = Completer<void>();
    final changes = <(String, String)>[];
    await tester.pumpWidget(
      _dashboard(
        onStatusChanged: (id, status, {snoozedUntil}) {
          changes.add((id, status));
          return pending.future;
        },
        onRemoveMedication: (_) async => fail('Regimen deletion was called'),
      ),
    );
    await _tapDelete(tester, _selected.id);
    expect(_deleteButton(_selected.id), findsNothing);
    _expectOtherDosesUnchanged();
    pending.completeError(StateError('write failed'));
    await tester.pumpAndSettle();
    await _showDoseRows(tester);

    expect(changes, [(_selected.id, 'cancelled')]);
    expect(_deleteButton(_selected.id), findsOneWidget);
    expect(find.text('200 MG\n8:00 AM'), findsOneWidget);
    _expectOtherDosesUnchanged();
    expect(
      find.text('Could not remove this dose. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Undo'), findsNothing);
  });

  deletionTest(
    'late cancellation failure restores a dose after the undo window',
    (tester) async {
      final pending = Completer<void>();
      await tester.pumpWidget(
        _dashboard(
          onStatusChanged: (id, status, {snoozedUntil}) => pending.future,
        ),
      );
      await _tapDelete(tester, _selected.id);
      await tester.pump(const Duration(seconds: 7));
      pending.completeError(StateError('network unavailable'));
      await tester.pumpAndSettle();
      await _showDoseRows(tester);

      expect(_deleteButton(_selected.id), findsOneWidget);
      _expectOtherDosesUnchanged();
      expect(
        find.text('You appear to be offline. Reconnect and try again.'),
        findsOneWidget,
      );
    },
  );

  deletionTest(
    'one failed cancellation preserves another successful cancellation',
    (tester) async {
      final first = Completer<void>();
      final changes = <(String, String)>[];
      await tester.pumpWidget(
        _dashboard(
          onStatusChanged: (id, status, {snoozedUntil}) {
            changes.add((id, status));
            return id == _selected.id ? first.future : Future<void>.value();
          },
          onRemoveMedication: (_) async => fail('Regimen deletion was called'),
        ),
      );
      await _tapDelete(tester, _selected.id);
      await _tapDelete(tester, _sameMedication.id);
      first.completeError(StateError('write failed'));
      await tester.pumpAndSettle();
      await _showDoseRows(tester);

      expect(changes, [
        (_selected.id, 'cancelled'),
        (_sameMedication.id, 'cancelled'),
      ]);
      expect(_deleteButton(_selected.id), findsOneWidget);
      expect(_deleteButton(_sameMedication.id), findsNothing);
      expect(_deleteButton(_neighbor.id), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    },
  );

  deletionTest(
    'stale snapshot keeps cancellation isolated and failure restores it',
    (tester) async {
      final pending = Completer<void>();
      final key = GlobalKey();
      Future<void> callback(
        String id,
        String status, {
        DateTime? snoozedUntil,
      }) => pending.future;
      await tester.pumpWidget(
        _dashboard(dashboardKey: key, onStatusChanged: callback),
      );
      await _tapDelete(tester, _selected.id);
      await tester.pumpWidget(
        _dashboard(
          dashboardKey: key,
          doses: List<DashboardDoseData>.of(_allDoses),
          onStatusChanged: callback,
        ),
      );
      await tester.pumpAndSettle();
      await _showDoseRows(tester);
      expect(_deleteButton(_selected.id), findsNothing);
      _expectOtherDosesUnchanged();
      pending.completeError(StateError('write failed'));
      await tester.pumpAndSettle();
      await _showDoseRows(tester);
      expect(_deleteButton(_selected.id), findsOneWidget);
      _expectOtherDosesUnchanged();

      await tester.pumpWidget(
        _dashboard(
          dashboardKey: key,
          doses: List<DashboardDoseData>.of(_allDoses),
          onStatusChanged: callback,
        ),
      );
      await tester.pumpAndSettle();
      await _showDoseRows(tester);
      expect(_deleteButton(_selected.id), findsOneWidget);
      _expectOtherDosesUnchanged();
    },
  );

  deletionTest(
    'persisted cancellation survives snapshots and Dashboard recreation',
    (tester) async {
      var snapshot = List<DashboardDoseData>.of(_allDoses);
      final changes = <(String, String)>[];
      final removedMedications = <String>[];
      final key = GlobalKey();
      Future<void> persist(
        String id,
        String status, {
        DateTime? snoozedUntil,
      }) async {
        changes.add((id, status));
        snapshot = [
          for (final dose in snapshot)
            if (dose.id == id) _withStatus(dose, status) else dose,
        ];
      }

      await tester.pumpWidget(
        _dashboard(
          dashboardKey: key,
          doses: snapshot,
          onStatusChanged: persist,
          onRemoveMedication: (id) async => removedMedications.add(id),
        ),
      );
      await _tapDelete(tester, _selected.id);
      expect(snapshot.map((dose) => dose.status), [
        'cancelled',
        'taken',
        'snoozed',
      ]);
      expect(snapshot.map((dose) => dose.medicationId), [
        'medication-1',
        'medication-1',
        'medication-2',
      ]);
      await tester.pumpWidget(
        _dashboard(
          dashboardKey: key,
          doses: snapshot,
          onStatusChanged: persist,
        ),
      );
      await tester.pumpAndSettle();
      await _showDoseRows(tester);
      expect(_deleteButton(_selected.id), findsNothing);
      _expectOtherDosesUnchanged();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        _dashboard(doses: snapshot, onStatusChanged: persist),
      );
      await tester.pumpAndSettle();
      await _showDoseRows(tester);
      expect(_deleteButton(_selected.id), findsNothing);
      _expectOtherDosesUnchanged();
      expect(changes, [(_selected.id, 'cancelled')]);
      expect(removedMedications, isEmpty);
    },
  );

  deletionTest(
    'undo restores only the selected dose with its original status',
    (tester) async {
      var snapshot = List<DashboardDoseData>.of(_allDoses);
      final changes = <(String, String)>[];
      Future<void> persist(
        String id,
        String status, {
        DateTime? snoozedUntil,
      }) async {
        changes.add((id, status));
        snapshot = [
          for (final dose in snapshot)
            if (dose.id == id) _withStatus(dose, status) else dose,
        ];
      }

      await tester.pumpWidget(
        _dashboard(
          doses: snapshot,
          onStatusChanged: persist,
          onRemoveMedication: (_) async => fail('Regimen deletion was called'),
        ),
      );
      await _tapDelete(tester, _sameMedication.id);
      expect(_deleteButton(_selected.id), findsOneWidget);
      expect(_deleteButton(_sameMedication.id), findsNothing);
      await _tapUndo(tester);

      expect(changes, [
        (_sameMedication.id, 'cancelled'),
        (_sameMedication.id, 'taken'),
      ]);
      expect(_deleteButton(_selected.id), findsOneWidget);
      _expectOtherDosesUnchanged();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_dashboard(doses: snapshot));
      await tester.pumpAndSettle();
      await _showDoseRows(tester);
      expect(_deleteButton(_selected.id), findsOneWidget);
      _expectOtherDosesUnchanged();
    },
  );

  deletionTest(
    'undo preserves the snooze timestamp from a refreshed snapshot',
    (tester) async {
      final until = DateTime(2026, 8, 23, 9, 47, 12, 345);
      final changes = <(String, String, DateTime?)>[];
      final key = GlobalKey();
      Future<void> callback(
        String id,
        String status, {
        DateTime? snoozedUntil,
      }) async {
        changes.add((id, status, snoozedUntil));
      }

      await tester.pumpWidget(
        _dashboard(dashboardKey: key, onStatusChanged: callback),
      );
      await tester.pumpWidget(
        _dashboard(
          dashboardKey: key,
          doses: [
            _withStatus(_selected, 'snoozed', snoozedUntil: until),
            _sameMedication,
            _neighbor,
          ],
          onStatusChanged: callback,
          onRemoveMedication: (_) async => fail('Regimen deletion was called'),
        ),
      );
      await _tapDelete(tester, _selected.id);
      expect(_deleteButton(_selected.id), findsNothing);
      _expectOtherDosesUnchanged();
      await _tapUndo(tester);

      expect(changes, [
        (_selected.id, 'cancelled', null),
        (_selected.id, 'snoozed', until),
      ]);
      expect(_deleteButton(_selected.id), findsOneWidget);
      expect(_deleteButton(_sameMedication.id), findsOneWidget);
      expect(_deleteButton(_neighbor.id), findsOneWidget);
      expect(find.text('Later'), findsNWidgets(2));
      expect(find.text('Taken'), findsOneWidget);
    },
  );

  deletionTest(
    'undo reuses the exact timestamp captured by the snooze action',
    (tester) async {
      final pendingSnooze = Completer<void>();
      final changes = <(String, String, DateTime?)>[];
      await tester.pumpWidget(
        _dashboard(
          onStatusChanged: (id, status, {snoozedUntil}) {
            changes.add((id, status, snoozedUntil));
            return changes.length == 1
                ? pendingSnooze.future
                : Future<void>.value();
          },
          onRemoveMedication: (_) async => fail('Regimen deletion was called'),
        ),
      );
      await tester.scrollUntilVisible(
        _deleteButton(_selected.id),
        240,
        scrollable: _dashboardScrollable(),
      );
      await tester.ensureVisible(find.text('200 MG\n8:00 AM'));
      await tester.pumpAndSettle();
      await _showDoseRows(tester);
      await tester.tap(find.text('200 MG\n8:00 AM'));
      await tester.pumpAndSettle();
      await _showDoseRows(tester);
      await tester.tap(find.text('Remind Me Later'));
      // The row remains busy while the snooze write is deliberately pending.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(changes, hasLength(1));
      final until = changes.single.$3;
      expect(until, isNotNull);
      await tester.pump(const Duration(minutes: 2));
      pendingSnooze.complete();
      await tester.pumpAndSettle();
      await _showDoseRows(tester);
      await _tapDelete(tester, _selected.id);
      await _tapUndo(tester);

      expect(changes, [
        (_selected.id, 'snoozed', until),
        (_selected.id, 'cancelled', null),
        (_selected.id, 'snoozed', until),
      ]);
      expect(_deleteButton(_selected.id), findsOneWidget);
      expect(_deleteButton(_sameMedication.id), findsOneWidget);
      expect(_deleteButton(_neighbor.id), findsOneWidget);
      expect(find.text('Later'), findsNWidgets(2));
      expect(find.text('Taken'), findsOneWidget);
    },
  );

  deletionTest('failed undo keeps only the selected dose cancelled', (
    tester,
  ) async {
    final changes = <(String, String)>[];
    await tester.pumpWidget(
      _dashboard(
        onStatusChanged: (id, status, {snoozedUntil}) async {
          changes.add((id, status));
          if (status != 'cancelled') throw StateError('write failed');
        },
        onRemoveMedication: (_) async => fail('Regimen deletion was called'),
      ),
    );
    await _tapDelete(tester, _selected.id);
    await _tapUndo(tester);

    expect(changes, [(_selected.id, 'cancelled'), (_selected.id, 'due')]);
    expect(_deleteButton(_selected.id), findsNothing);
    _expectOtherDosesUnchanged();
    expect(
      find.text('Could not update this dose. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Undo'), findsNothing);
  });
}
