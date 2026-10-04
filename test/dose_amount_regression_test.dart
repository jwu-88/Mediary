import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/data/mediary_data_store.dart';
import 'package:mediary/data/mediary_models.dart';
import 'package:mediary/data/mediary_repository.dart';
import 'package:mediary/data/medication_catalog_client.dart';
import 'package:mediary/main.dart';
import 'package:mediary/notifications/medication_notification_service.dart';

class _Repository extends Fake implements MediaryRepository {}

class _Store extends MediaryDataStore {
  _Store() : super(repository: _Repository());
  final savedAmounts = <double>[];
  @override
  bool get hasInitialData => true;
  @override
  Future<void> commitScheduleAndDose({
    required MedicationWrite medication,
    required ScheduleWrite schedule,
    required DoseWrite? dose,
  }) async {
    savedAmounts.add(schedule.doseAmount);
  }
}

class _Catalog implements MedicationCatalogClient {
  static const medication = MedicationCatalogRecord(
    rxcui: '123',
    name: 'Audit Medication',
    strength: '1 MG',
    form: 'tablet',
  );
  @override
  Future<CatalogSearchPage> search(String query) async =>
      const CatalogSearchPage(items: [medication], sourceVersion: 'test');
  @override
  Future<MedicationCatalogRecord> getDetails(String rxcui) async => medication;
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

Future<_Store> _openSchedule(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final store = _Store();
  addTearDown(store.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: AuthenticatedHome(
        email: 'audit@example.com',
        now: DateTime.now().add(const Duration(days: 2)),
        dataStore: store,
        catalogClient: _Catalog(),
        notificationService: _Notifications(),
        useSidebarNavigation: true,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tapAt(const Offset(38, 168));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('calendarAddButton')));
  await tester.tap(find.byKey(const Key('calendarAddButton')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('medicationSearchField')),
    'audit',
  );
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('medicationOption_123')));
  await tester.pumpAndSettle();
  await tester.ensureVisible(
    find.byKey(const Key('addSelectedMedicationsButton')),
  );
  await tester.tap(find.byKey(const Key('addSelectedMedicationsButton')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('scheduleDoseAmountField')), findsOneWidget);
  return store;
}

void main() {
  testWidgets(
    'empty, zero, negative, non-finite and Unicode numeric input never writes a schedule',
    (tester) async {
      final store = await _openSchedule(tester);
      for (final input in [
        '',
        ' ',
        '0',
        '-0',
        '-1',
        'NaN',
        'Infinity',
        '-Infinity',
        '1e309',
        '１',
        '١',
        '1,5',
        '½',
        '1/2',
      ]) {
        await tester.enterText(
          find.byKey(const Key('scheduleDoseAmountField')),
          input,
        );
        await tester.ensureVisible(
          find.byKey(const Key('saveScheduleDetailsButton')),
        );
        await tester.tap(find.byKey(const Key('saveScheduleDetailsButton')));
        await tester.pumpAndSettle();
        expect(store.savedAmounts, isEmpty, reason: 'input=$input');
        expect(
          find.text('Enter a dose amount greater than zero.'),
          findsOneWidget,
          reason: 'input=$input',
        );
        expect(tester.takeException(), isNull, reason: 'input=$input');
      }
      await tester.enterText(
        find.byKey(const Key('scheduleDoseAmountField')),
        '0.5',
      );
      await tester.ensureVisible(
        find.byKey(const Key('saveScheduleDetailsButton')),
      );
      await tester.tap(find.byKey(const Key('saveScheduleDetailsButton')));
      await tester.pumpAndSettle();
      expect(store.savedAmounts, [.5]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'large finite dose amount displays the same numeric value that was saved',
    (tester) async {
      final store = await _openSchedule(tester);
      await tester.enterText(
        find.byKey(const Key('scheduleDoseAmountField')),
        '1e100',
      );
      await tester.ensureVisible(
        find.byKey(const Key('saveScheduleDetailsButton')),
      );
      await tester.tap(find.byKey(const Key('saveScheduleDetailsButton')));
      await tester.pumpAndSettle();
      expect(store.savedAmounts, [1e100]);
      await tester.scrollUntilVisible(
        find.text('Audit Medication'),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('calendarScrollView')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      final doseLabels = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data ?? '')
          .where((text) => text.toLowerCase().contains('tablet'))
          .toList();
      expect(
        doseLabels.any((text) => text.toLowerCase().contains('1e+100')),
        isTrue,
        reason: 'stored=1e100; displayed=$doseLabels',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
