import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/app_legal.dart';
import 'package:mediary/app_theme.dart';
import 'package:mediary/data/medication_catalog_client.dart';
import 'package:mediary/library_screens.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _TestLauncher extends UrlLauncherPlatform {
  var fail = true;
  var calls = 0;
  @override
  get linkDelegate => null;
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    calls++;
    return !fail;
  }
}

void main() {
  for (final throws in [false, true]) {
    testWidgets(
      'support launch failure keeps address visible and permits retry (throws=$throws)',
      (tester) async {
        var fail = true;
        var calls = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: ContactSupportPage(
              supportEmail: 'support@example.com',
              onOpenEmail: (_) async {
                calls++;
                if (fail && throws) throw StateError('unavailable');
                return !fail;
              },
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('openSupportEmailButton')));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Unable to open your email app'),
          findsOneWidget,
        );
        expect(find.text('support@example.com'), findsOneWidget);
        expect(find.byKey(const Key('copySupportEmailButton')), findsOneWidget);
        fail = false;
        await tester.tap(find.byKey(const Key('openSupportEmailButton')));
        await tester.pumpAndSettle();
        expect(calls, 2);
        expect(find.byKey(const Key('supportActionStatus')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('current label launch failure gives a visible retry state', (
    tester,
  ) async {
    final previous = UrlLauncherPlatform.instance;
    final launcher = _TestLauncher();
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = previous);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const MedicationDetailScreen(
          medication: MedicationCatalogRecord(
            rxcui: 'test',
            name: 'Ibuprofen',
            strength: '200 mg',
            form: 'Tablet',
            labelUrl: 'https://dailymed.nlm.nih.gov/test',
          ),
        ),
      ),
    );
    final scrollable = find
        .descendant(
          of: find.byKey(const Key('medicationDetailScrollView')),
          matching: find.byType(Scrollable),
        )
        .first;
    final action = find.byKey(const Key('openMedicationLabelButton'));
    await tester.scrollUntilVisible(action, 150, scrollable: scrollable);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('medicationLabelError')), findsOneWidget);
    launcher.fail = false;
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(launcher.calls, 2);
    expect(find.byKey(const Key('medicationLabelError')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'welcome completion remains reachable in a short large-text window',
    (tester) async {
      tester.view.physicalSize = const Size(568, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(3)),
            child: child!,
          ),
          home: ThankYouPage(onDone: () => calls++),
        ),
      );
      await tester.ensureVisible(find.byKey(const Key('thankYouDoneButton')));
      await tester.tap(find.byKey(const Key('thankYouDoneButton')));
      await tester.pump();
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
