import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/data/mediary_data_store.dart';
import 'package:mediary/data/mediary_models.dart';
import 'package:mediary/data/mediary_repository.dart';
import 'package:mediary/dashboard_screen.dart';
import 'package:mediary/main.dart';
import 'package:mediary/notifications/medication_notification_service.dart';

class _Repository extends Fake implements MediaryRepository {}

class _Notifications extends Fake implements MedicationNotificationService {
  @override
  Future<void> initialize() async {}
  @override
  Future<void> clearDeliveredNotifications() async {}
  @override
  Future<void> requestPermission() async {}
  @override
  Future<List<MedicationDueNotification>> syncDueDoses({
    required List<DoseLogRecord> doses,
    required Map<String, String> medicationNames,
    Map<String, String> scheduleTimezones = const {},
    DateTime? now,
  }) async => [];
}

class _Store extends MediaryDataStore {
  _Store() : super(repository: _Repository()) {
    isLoading = false;
    medications = List.generate(
      25,
      (i) => MedicationRecord(
        id: 'm$i',
        name: 'Synthetic Medication $i',
        genericName: '',
        strength: '10 mg',
        form: 'Tablet',
        route: '',
        instructions: '',
        prescriber: '',
        pharmacy: '',
        notes: '',
        active: true,
        source: 'manual',
      ),
    );
    schedules = List.generate(
      25,
      (i) => ScheduleRecord(
        id: 's$i',
        medicationId: 'm$i',
        doseAmount: 1,
        doseUnit: 'tablet',
        times: ['12:00:00'],
        frequency: 'daily',
        daysOfWeek: [],
        startDate: '2026-10-04',
        endDate: null,
        timezone: 'UTC',
        instructions: '',
        active: true,
      ),
    );
    doseLogs = List.generate(
      25,
      (i) => DoseLogRecord(
        id: 'd$i',
        medicationId: 'm$i',
        scheduleId: 's$i',
        scheduledFor: DateTime(2026, 10, 4, 12, i),
        localDate: '2026-10-04',
        localTime: '12:${i.toString().padLeft(2, '0')}:00',
        status: i > 11 ? 'taken' : 'due',
      ),
    );
  }
  @override
  bool get hasInitialData => true;
}

void main() {
  testWidgets('today statistics include doses beyond the twelfth occurrence', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = _Store();
    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticatedHome(
          email: 'qa@example.invalid',
          dataStore: store,
          now: DateTime(2026, 10, 4, 15),
          notificationService: _Notifications(),
          cameraPermissionRequester: () async => CameraAccessState.denied,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final dashboard = tester.widget<DashboardScreen>(
      find.byType(DashboardScreen),
    );
    expect(
      dashboard.initialDoses.length,
      25,
      reason: 'All 25 real doses must feed today counts; first 12 are due and the remaining 13 are taken.',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
}
