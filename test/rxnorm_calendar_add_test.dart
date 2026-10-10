import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/calendar_screen.dart';
import 'package:mediary/data/mediary_data_store.dart';
import 'package:mediary/data/mediary_models.dart';
import 'package:mediary/data/mediary_repository.dart';
import 'package:mediary/data/medication_catalog_client.dart';
import 'package:mediary/library_screens.dart';
import 'package:mediary/liquid_glass_back_button.dart';
import 'package:mediary/main.dart';
import 'package:mediary/medication_scan.dart';
import 'package:mediary/notifications/medication_notification_service.dart';

import 'support/medication_scan_fixture.dart';

class _Repository extends Fake implements MediaryRepository {}

class _Store extends MediaryDataStore {
  _Store() : super(repository: _Repository());

  @override
  bool get hasInitialData => true;
  Completer<void>? saving;
  bool fail = false;
  int attempts = 0;
  MedicationWrite? medication;
  ScheduleWrite? schedule;
  DoseWrite? dose;

  @override
  Future<String> saveScan(ScanWrite scan) async => 'scan-id';

  @override
  Future<void> commitScheduleAndDose({
    required MedicationWrite medication,
    required ScheduleWrite schedule,
    required DoseWrite? dose,
  }) async {
    attempts++;
    await saving?.future;
    if (fail) throw StateError('Offline');
    this.medication = medication;
    this.schedule = schedule;
    this.dose = dose;
  }

  void publishSavedRecords({
    bool medicationReady = true,
    bool scheduleReady = true,
    bool doseReady = true,
  }) {
    final med = medication!;
    final sched = schedule!;
    final occurrence = dose!;
    if (medicationReady) {
      medications = [
        MedicationRecord(
          id: med.id!,
          name: med.name,
          genericName: med.genericName,
          strength: med.strength,
          form: med.form,
          route: med.route,
          instructions: med.instructions,
          prescriber: med.prescriber,
          pharmacy: med.pharmacy,
          notes: med.notes,
          active: med.active,
          source: med.source,
          catalogId: med.catalogId,
        ),
      ];
    }
    if (scheduleReady) {
      schedules = [
        ScheduleRecord(
          id: sched.id!,
          medicationId: sched.medicationId,
          doseAmount: sched.doseAmount,
          doseUnit: sched.doseUnit,
          times: sched.times,
          frequency: sched.frequency,
          daysOfWeek: sched.daysOfWeek,
          startDate: sched.startDate,
          endDate: sched.endDate,
          timezone: sched.timezone,
          instructions: sched.instructions,
          active: sched.active,
        ),
      ];
    }
    if (doseReady) {
      doseLogs = [
        DoseLogRecord(
          id: occurrence.id!,
          medicationId: occurrence.medicationId,
          scheduleId: occurrence.scheduleId,
          scheduledFor: occurrence.scheduledFor,
          localDate: occurrence.localDate,
          localTime: occurrence.localTime,
          status: occurrence.status,
        ),
      ];
    }
    notifyListeners();
  }
}

class _Catalog implements MedicationCatalogClient {
  static const medication = MedicationCatalogRecord(
    rxcui: '123',
    name: 'Manual Medication',
    genericName: 'manual ingredient',
    strength: '10 MG',
    form: 'tablet',
  );

  @override
  Future<CatalogSearchPage> search(String query) async =>
      const CatalogSearchPage(items: [medication], sourceVersion: 'test');
  @override
  Future<MedicationCatalogRecord> getDetails(String rxcui) async => medication;
}

class _Detector implements MedicationScanDetector {
  _Detector({this.recognized = false});
  final bool recognized;
  @override
  Future<MedicationScanResult> detect(MedicationScanRequest request) async =>
      MedicationScanResult(
        imageUrl: '',
        extractedText: recognized ? _Catalog.medication.name : '',
        detectedMedicationName: recognized ? _Catalog.medication.name : '',
        confidence: recognized ? 1 : 0,
      );
}

class _Notifications extends Fake implements MedicationNotificationService {
  @override
  Future<void> initialize() async {}
  @override
  Future<void> clearDeliveredNotifications() async {}
  @override
  Future<void> requestPermission() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<List<MedicationDueNotification>> syncDueDoses({
    required List<DoseLogRecord> doses,
    required Map<String, String> medicationNames,
    Map<String, String> scheduleTimezones = const {},
    DateTime? now,
  }) async => [];
}

Future<void> _selectDestination(WidgetTester tester, int index) async {
  final sidebar = find.byKey(Key('webNavItem-$index'));
  if (sidebar.evaluate().isNotEmpty) {
    await tester.tapAt(Offset(38, tester.getCenter(sidebar).dy));
  } else {
    await tester.tap(find.text(['Dashboard', 'Calendar', 'Scan'][index]).last);
  }
  await tester.pumpAndSettle();
}

Future<void> _openScan(
  WidgetTester tester,
  _Store store, {
  Size size = const Size(402, 874),
  bool recognized = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(store.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: AuthenticatedHome(
        email: 'test@example.com',
        now: DateTime.now().add(const Duration(days: 2)),
        dataStore: store,
        catalogClient: _Catalog(),
        scanDetector: _Detector(recognized: recognized),
        cameraCapture: () async => medicationScanFixture,
        cameraPermissionRequester: () async => CameraAccessState.granted,
        notificationService: _Notifications(),
        useSidebarNavigation: size.width > 800,
      ),
    ),
  );
  await tester.pumpAndSettle();
  // Visit Calendar first to also exercise refreshing an existing destination.
  await _selectDestination(tester, 1);
  await _selectDestination(tester, 2);
  await tester.tap(find.byKey(const Key('captureMedicationButton')));
  await tester.pumpAndSettle();
}

Future<void> _openManualDetails(
  WidgetTester tester,
  _Store store,
  Size size,
) async {
  await _openScan(tester, store, size: size);
  await tester.tap(find.byKey(const Key('addScanResultButton')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('medicationSearchField')),
    'manual',
  );
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
  await tester.tap(find.text(_Catalog.medication.name));
  await tester.pumpAndSettle();
  expect(find.byType(MedicationDetailScreen), findsOneWidget);
}

Future<void> _confirmSchedule(WidgetTester tester, {bool settle = true}) async {
  await tester.tap(find.byKey(const Key('addMedicationButton')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('scheduleDoseAmountField')), '2');
  final save = find.byKey(const Key('saveScheduleDetailsButton'));
  await tester.ensureVisible(save);
  await tester.tap(save);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _expectCalendarMedication(WidgetTester tester) async {
  expect(find.byType(MedicationDetailScreen), findsNothing);
  expect(find.byType(MedicationLibraryScreen), findsNothing);
  expect(find.text('Review Medication'), findsNothing);
  expect(find.byType(CalendarScreen), findsOneWidget);
  await tester.scrollUntilVisible(
    find.text(_Catalog.medication.name),
    200,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('calendarScrollView')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
  expect(find.text(_Catalog.medication.name), findsOneWidget);
  expect(tester.takeException(), isNull);
}

void main() {
  for (final size in [const Size(402, 874), const Size(1440, 900)]) {
    testWidgets('RxNorm addition saves and returns to Calendar at $size', (
      tester,
    ) async {
      final store = _Store()..saving = Completer<void>();
      await _openManualDetails(tester, store, size);
      await _confirmSchedule(tester, settle: false);
      expect(store.attempts, 1);
      expect(store.medication, isNull);
      expect(find.byType(MedicationDetailScreen), findsOneWidget);
      expect(find.text('Adding to Calendar'), findsOneWidget);
      await tester.tap(find.byKey(const Key('addMedicationButton')));
      await tester.pump();
      expect(store.attempts, 1);
      store.saving!.complete();
      await tester.pumpAndSettle();
      expect(store.medication!.catalogId, '123');
      expect(store.schedule!.medicationId, store.medication!.id);
      expect(store.schedule!.doseAmount, 2);
      expect(store.dose!.scheduleId, store.schedule!.id);
      await _expectCalendarMedication(tester);
      expect(
        tester.widget<CalendarScreen>(find.byType(CalendarScreen)).initialDate,
        DateTime.parse(store.dose!.localDate),
      );
      // An unrelated update and out-of-order streams must not hide the row.
      store.publishSavedRecords(
        medicationReady: false,
        scheduleReady: false,
        doseReady: false,
      );
      await tester.pumpAndSettle();
      await _expectCalendarMedication(tester);
      store.publishSavedRecords(medicationReady: false, scheduleReady: false);
      await tester.pumpAndSettle();
      await _expectCalendarMedication(tester);
      store.publishSavedRecords(scheduleReady: false);
      await tester.pumpAndSettle();
      await _expectCalendarMedication(tester);
      store.publishSavedRecords();
      await tester.pumpAndSettle();
      await _expectCalendarMedication(tester);
      await _selectDestination(tester, 0);
      await _selectDestination(tester, 1);
      await _expectCalendarMedication(tester);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('failed RxNorm save stays on details and can retry', (
    tester,
  ) async {
    final store = _Store()..fail = true;
    await _openManualDetails(tester, store, const Size(402, 874));
    await _confirmSchedule(tester);
    expect(store.medication, isNull);
    expect(find.byType(MedicationDetailScreen), findsOneWidget);
    expect(find.text('Could not add to Calendar. Try again.'), findsOneWidget);
    expect(find.text('Added to My Schedule'), findsNothing);
    store.fail = false;
    await _confirmSchedule(tester);
    expect(store.attempts, 2);
    await _expectCalendarMedication(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('cancelled RxNorm schedule does not add or navigate', (
    tester,
  ) async {
    final store = _Store();
    await _openManualDetails(tester, store, const Size(402, 874));
    await tester.tap(find.byKey(const Key('addMedicationButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(LiquidGlassBackButton).last);
    await tester.pumpAndSettle();
    expect(store.attempts, 0);
    expect(find.byType(MedicationDetailScreen), findsOneWidget);
    expect(find.text('Added to My Schedule'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('recognized scan saves and returns to Calendar', (tester) async {
    final store = _Store();
    await _openScan(tester, store, recognized: true);
    await tester.tap(find.byKey(const Key('addScanResultButton')));
    await tester.pumpAndSettle();
    expect(store.attempts, 1);
    await _expectCalendarMedication(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
