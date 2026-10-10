import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/data/mediary_data_store.dart';
import 'package:mediary/data/mediary_models.dart';
import 'package:mediary/data/mediary_repository.dart';
import 'package:mediary/data/medication_catalog_client.dart';
import 'package:mediary/dashboard_screen.dart';
import 'package:mediary/main.dart';
import 'package:mediary/notifications/medication_notification_service.dart';

import 'support/continuous_text_entry.dart';

class _EmptyCatalog implements MedicationCatalogClient {
  @override
  Future<CatalogSearchPage> search(String query) async =>
      const CatalogSearchPage(items: [], sourceVersion: 'test');
  @override
  Future<MedicationCatalogRecord> getDetails(String rxcui) async =>
      throw StateError('No selection');
}

class _UnusedRepository extends Fake implements MediaryRepository {}

class _SnapshotStore extends MediaryDataStore {
  _SnapshotStore() : super(repository: _UnusedRepository());
  @override
  bool get hasInitialData => true;

  void refresh() => notifyListeners();

  @override
  Future<void> updateDoseStatus(
    String id,
    String status, {
    DateTime? takenAt,
    DateTime? snoozedUntil,
  }) async {
    doseLogs = [
      for (final dose in doseLogs)
        if (dose.id == id)
          DoseLogRecord(
            id: dose.id,
            medicationId: dose.medicationId,
            scheduleId: dose.scheduleId,
            scheduledFor: dose.scheduledFor,
            localDate: dose.localDate,
            localTime: dose.localTime,
            status: status,
            takenAt: takenAt,
            snoozedUntil: snoozedUntil,
          )
        else
          dose,
    ];
    refresh();
  }
}

class _NotificationSpy implements MedicationNotificationService {
  int cleared = 0;
  final snapshots = <List<DoseLogRecord>>[];
  Completer<void>? hold;
  List<MedicationDueNotification> nextDue = [];
  @override
  Future<void> initialize() async {}
  @override
  Future<void> requestPermission() async {}
  @override
  Future<String> permissionState() async => 'granted';
  @override
  Future<void> cancelDose(String doseId) async {}
  @override
  Future<void> clearDeliveredNotifications() async => cleared++;
  @override
  Future<void> dispose() async {}
  @override
  Future<List<MedicationDueNotification>> syncDueDoses({
    required List<DoseLogRecord> doses,
    required Map<String, String> medicationNames,
    Map<String, String> scheduleTimezones = const {},
    DateTime? now,
  }) async {
    snapshots.add(doses);
    await hold?.future;
    final result = nextDue;
    nextDue = [];
    return result;
  }
}

void main() {
  late _SnapshotStore store;
  late _NotificationSpy notifications;
  setUp(() {
    notifications = _NotificationSpy();
    store = _SnapshotStore()
      ..profile = const UserProfileRecord(
        uid: 'test-user',
        email: 'test@example.com',
        displayName: 'Test User',
        bloodType: '',
        allergies: [],
        careTeam: '',
        timezone: 'UTC',
        preferences: MediaryPreferences(),
      )
      ..medications = const [
        MedicationRecord(
          id: 'active-med',
          name: 'Medication',
          genericName: '',
          strength: '1 MG',
          form: 'Tablet',
          route: '',
          instructions: '',
          prescriber: '',
          pharmacy: '',
          notes: '',
          active: true,
          source: 'manual',
        ),
      ]
      ..schedules = const [
        ScheduleRecord(
          id: 'active-schedule',
          medicationId: 'active-med',
          doseAmount: 1,
          doseUnit: 'tablet',
          times: ['09:00'],
          frequency: 'daily',
          daysOfWeek: [],
          startDate: '2026-10-04',
          endDate: null,
          timezone: 'UTC',
          instructions: '',
          active: true,
        ),
        ScheduleRecord(
          id: 'orphan-schedule',
          medicationId: 'deleted-med',
          doseAmount: 1,
          doseUnit: 'tablet',
          times: ['09:00'],
          frequency: 'daily',
          daysOfWeek: [],
          startDate: '2026-10-04',
          endDate: null,
          timezone: 'UTC',
          instructions: '',
          active: true,
        ),
      ]
      ..doseLogs = [
        for (final entry in [
          ('active-dose', 'active-med', 'active-schedule'),
          ('deleted-dose', 'deleted-med', 'orphan-schedule'),
          ('missing-schedule-dose', 'active-med', 'missing-schedule'),
        ])
          DoseLogRecord(
            id: entry.$1,
            medicationId: entry.$2,
            scheduleId: entry.$3,
            scheduledFor: DateTime(2026, 10, 4, 9),
            localDate: '2026-10-04',
            localTime: '09:00',
            status: 'due',
          ),
      ];
  });
  tearDown(() => store.dispose());

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticatedHome(
          email: 'test@example.com',
          now: DateTime(2026, 10, 4, 9),
          dataStore: store,
          notificationService: notifications,
          catalogClient: _EmptyCatalog(),
          useSidebarNavigation: true,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'web reminders appear and expire without interrupting text input',
    (tester) async {
      if (!kIsWeb) return;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester);
      await tester.tapAt(const Offset(38, 280));
      await tester.pumpAndSettle();
      final field = find.byKey(const Key('medicationSearchField'));
      await typeWithoutRefocusing(tester, field, ['b', 'be']);
      final editable = find.descendant(
        of: field,
        matching: find.byType(EditableText),
      );
      final original = tester.state<EditableTextState>(editable);
      notifications.nextDue = [
        MedicationDueNotification(
          doseId: 'active-dose',
          medicationName: 'Medication',
          scheduledFor: DateTime.now(),
        ),
      ];
      store.refresh();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.byKey(const Key('webMedicationNotificationToast')),
        findsOneWidget,
      );
      expect(tester.state<EditableTextState>(editable), same(original));
      expect(original.widget.focusNode.hasFocus, isTrue);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'ben',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      expect(
        find.byKey(const Key('webMedicationNotificationToast')),
        findsNothing,
      );
      expect(tester.state<EditableTextState>(editable), same(original));
      expect(original.widget.focusNode.hasFocus, isTrue);
      expect(original.widget.controller.text, 'ben');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'opening and resuming clear delivered alerts and reject orphan reminders',
    (tester) async {
      await open(tester);
      expect(notifications.cleared, 1);
      expect(
        tester
            .widget<DashboardScreen>(find.byType(DashboardScreen))
            .initialDoses
            .map((dose) => dose.id),
        ['active-dose'],
      );
      expect(notifications.snapshots.last.map((dose) => dose.id), [
        'active-dose',
      ]);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(notifications.cleared, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'undoing a removed snoozed entry restores its reminder eligibility',
    (tester) async {
      final original = store.doseLogs.first;
      final until = DateTime.now().add(const Duration(minutes: 15));
      store.doseLogs = [
        DoseLogRecord(
          id: original.id,
          medicationId: original.medicationId,
          scheduleId: original.scheduleId,
          scheduledFor: original.scheduledFor,
          localDate: original.localDate,
          localTime: original.localTime,
          status: 'snoozed',
          snoozedUntil: until,
        ),
      ];
      await open(tester);
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(
            of: find.byKey(const Key('dashboardScrollView')),
            matching: find.byType(Scrollable),
          )
          .first;
      final remove = find.byKey(const Key('dashboardDeleteDose_active-dose'));
      await tester.scrollUntilVisible(remove, 240, scrollable: scrollable);
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Undo'),
        -240,
        scrollable: scrollable,
      );
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(store.doseLogs.single.status, 'snoozed');
      expect(store.doseLogs.single.snoozedUntil, until);
      expect(notifications.snapshots.last.single.id, 'active-dose');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'deletion arriving during notification sync is reconciled immediately',
    (tester) async {
      notifications.hold = Completer<void>();
      await open(tester);
      expect(notifications.snapshots, hasLength(1));
      store.medications = [];
      store.schedules = [];
      store.doseLogs = [];
      store.refresh();
      notifications.hold!.complete();
      await tester.pump();
      await tester.pump();
      expect(notifications.snapshots, hasLength(2));
      expect(notifications.snapshots.last, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
