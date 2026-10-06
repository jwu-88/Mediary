import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/app_theme.dart';
import 'package:mediary/data/medication_catalog_client.dart';
import 'package:mediary/library_screens.dart';
import 'package:mediary/scanner_screens.dart';

const _medication = MedicationCatalogRecord(
  rxcui: '723',
  name: 'Amoxicillin',
  strength: '500 mg',
  form: 'capsule',
);

Widget _harness(Widget child, {double textScale = 1}) => MaterialApp(
  theme: AppTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: child,
);

void main() {
  testWidgets(
    'failed scan save retries the same record once and keeps review',
    (tester) async {
      var attempts = 0;
      final ids = <String?>[];
      final retry = Completer<String>();
      await tester.pumpWidget(
        _harness(
          ScanResultScreen(
            medication: _medication,
            scanRecordId: 'scan-existing',
            bottomNavigationInset: 0,
            onScanReady: (scan) {
              ids.add(scan.id);
              attempts++;
              if (attempts == 1) {
                return Future<String>.error(StateError('Offline'));
              }
              return retry.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('scanSaveError')), findsOneWidget);
      expect(find.text('Review Medication'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final action = find.byKey(const Key('retryScanSaveButton'));
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.tap(action);
      await tester.pump();
      expect(attempts, 2);
      expect(find.text('Saving Scan'), findsOneWidget);
      retry.complete('scan-existing');
      await tester.pumpAndSettle();
      expect(ids, ['scan-existing', 'scan-existing']);
      expect(find.byKey(const Key('scanSaveError')), findsNothing);
      expect(find.byKey(const Key('retryScanSaveButton')), findsNothing);
      expect(find.text('Review Medication'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late scan save failure after leaving review is handled', (
    tester,
  ) async {
    final saving = Completer<String>();
    await tester.pumpWidget(
      _harness(
        ScanResultScreen(
          medication: _medication,
          onScanReady: (_) => saving.future,
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    saving.completeError(StateError('Offline'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'calendar save failure offers retry without losing schedule fields',
    (tester) async {
      var attempts = 0;
      var additions = 0;
      final submitted = <ScanScheduleData>[];
      final retry = Completer<bool>();
      await tester.pumpWidget(
        _harness(
          ScanResultScreen(
            medication: _medication,
            bottomNavigationInset: 0,
            now: DateTime(2026, 8, 23, 7),
            onAdded: () => additions++,
            onScheduleConfirmed: (schedule) {
              submitted.add(schedule);
              attempts++;
              if (attempts == 1) {
                return Future<bool>.error(StateError('Offline'));
              }
              return retry.future;
            },
          ),
        ),
      );
      final action = find.byKey(const Key('addScanResultButton'));
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('scanScheduleError')), findsOneWidget);
      expect(
        find.text('Could not add to Calendar. Try again.'),
        findsOneWidget,
      );
      expect(additions, 0);
      await tester.tap(action);
      await tester.tap(action);
      await tester.pump();
      expect(attempts, 2);
      expect(find.text('Adding to Calendar'), findsOneWidget);
      retry.complete(true);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('scanScheduleError')), findsNothing);
      expect(find.text('Added to Calendar'), findsOneWidget);
      expect(additions, 1);
      expect(submitted[1].dose, submitted[0].dose);
      expect(submitted[1].frequency, submitted[0].frequency);
      expect(submitted[1].startDate, submitted[0].startDate);
      expect(submitted[1].time.localTime, submitted[0].time.localTime);
      expect(tester.takeException(), isNull);
    },
  );

  for (final initiallySaved in [false, true]) {
    testWidgets(
      'bookmark failure rolls back and retries saved=$initiallySaved',
      (tester) async {
        final writes = <bool>[];
        final retry = Completer<void>();
        await tester.pumpWidget(
          _harness(
            MedicationDetailScreen(
              medication: _medication,
              initialBookmarked: initiallySaved,
              onBookmarkChanged: (saved) {
                writes.add(saved);
                if (writes.length == 1) {
                  return Future<void>.error(StateError('Offline'));
                }
                return retry.future;
              },
            ),
          ),
        );
        final bookmark = find.byKey(
          const Key('medicationDetailBookmarkButton'),
        );
        await tester.tap(bookmark);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('medicationDetailBookmarkError')),
          findsOneWidget,
        );
        expect(
          find.byTooltip(
            initiallySaved ? 'Remove saved medication' : 'Save medication',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        final action = find.byKey(const Key('retryMedicationBookmarkButton'));
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.tap(bookmark);
        await tester.pump();
        expect(writes, [!initiallySaved, !initiallySaved]);
        expect(find.text('Saving'), findsOneWidget);
        retry.complete();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('medicationDetailBookmarkError')),
          findsNothing,
        );
        expect(
          find.byTooltip(
            initiallySaved ? 'Save medication' : 'Remove saved medication',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('calendar failure status fits a narrow screen at enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _harness(
        ScanResultScreen(
          medication: _medication,
          bottomNavigationInset: 0,
          now: DateTime(2026, 8, 23, 7),
          onScheduleConfirmed: (_) async => throw StateError('Offline'),
        ),
        textScale: 3,
      ),
    );
    await tester.tap(find.byKey(const Key('addScanResultButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scanScheduleError')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
