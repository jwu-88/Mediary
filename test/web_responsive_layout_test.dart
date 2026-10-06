import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/add_medication_screen.dart';
import 'package:mediary/app_theme.dart';
import 'package:mediary/calendar_screen.dart';
import 'package:mediary/dashboard_screen.dart';
import 'package:mediary/library_screens.dart';
import 'package:mediary/profile_screen.dart';
import 'package:mediary/scanner_screens.dart';
import 'package:mediary/settings_screen.dart';
import 'package:mediary/weekly_report_screen.dart';
import 'package:mediary/main.dart';
import 'package:mediary/app_legal.dart';

void main() {
  testWidgets(
    'web destinations stay usable across window sizes and enlarged text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final size in [
        const Size(360, 740),
        const Size(768, 600),
        const Size(900, 600),
        const Size(1024, 768),
        const Size(1440, 900),
        const Size(1920, 1080),
        const Size(2560, 1440),
      ]) {
        tester.view.physicalSize = size;
        final pages = <Widget>[
          AuthForm(
            onSubmit: ({
              required email,
              required password,
              required createAccount,
            }) async {},
          ),
          DashboardScreen(
            email: 'person@example.com',
            now: DateTime(2026, 10, 3),
          ),
          CalendarScreen(initialDate: DateTime(2026, 10, 3)),
          const MedicationLibraryScreen(),
          const ProfileScreen(
            email: 'person@example.com',
            displayName: 'Taylor Morgan',
          ),
          SettingsScreen(
            appearanceMode: ThemeMode.system,
            onAppearanceModeChanged: (_) {},
            accentColor: AppAccentColor.blue,
            onAccentColorChanged: (_) {},
          ),
          const AddMedicationScreen(),
          const ScanResultScreen(bottomNavigationInset: 0),
          WeeklyReportScreen(weekEnding: DateTime(2026, 10, 3)),
          const PrivacyPolicyPage(),
          const TermsPage(),
          const MedicationTimeSelectionPage(
            initialTime: TimeOfDay(hour: 9, minute: 30),
          ),
        ];
        for (final page in pages) {
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(
                    size == const Size(900, 600) ? 2 : 1.3,
                  ),
                ),
                child: child!,
              ),
              home: Scaffold(body: page),
            ),
          );
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: '${page.runtimeType} at $size',
          );
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    },
  );

  void useSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<double> renderWidth(
    WidgetTester tester, {
    required Widget screen,
    required Finder content,
  }) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: screen)));
    await tester.pump();
    expect(tester.takeException(), isNull);
    return tester.getSize(content).width;
  }

  testWidgets('primary screens use the desktop viewport without stretching', (
    tester,
  ) async {
    useSize(tester, const Size(1280, 720));

    expect(
      await renderWidth(
        tester,
        screen: DashboardScreen(
          email: 'person@example.com',
          now: DateTime(2026, 8, 30),
          bottomPadding: 24,
        ),
        content: find.byKey(const Key('dashboardScrollView')),
      ),
      1120,
    );
    expect(
      await renderWidth(
        tester,
        screen: CalendarScreen(
          initialDate: DateTime(2026, 8, 30),
          bottomPadding: 24,
        ),
        content: find.byKey(const Key('calendarScrollView')),
      ),
      1120,
    );
    expect(
      await renderWidth(
        tester,
        screen: const MedicationLibraryScreen(bottomPadding: 24),
        content: find.byKey(const Key('medicationLibraryScrollView')),
      ),
      1120,
    );
    expect(
      await renderWidth(
        tester,
        screen: const ProfileScreen(
          email: 'person@example.com',
          displayName: 'Taylor Morgan',
          bottomPadding: 24,
        ),
        content: find.byKey(const Key('profileScrollView')),
      ),
      1120,
    );
    expect(
      await renderWidth(
        tester,
        screen: SettingsScreen(
          embedded: true,
          appearanceMode: ThemeMode.system,
          onAppearanceModeChanged: (_) {},
          accentColor: AppAccentColor.blue,
          onAccentColorChanged: (_) {},
          bottomPadding: 24,
        ),
        content: find.byKey(
          const PageStorageKey<String>('settingsScrollPosition'),
        ),
      ),
      1120,
    );
  });

  testWidgets('detail and picker content remains viewport-safe', (
    tester,
  ) async {
    useSize(tester, const Size(1280, 720));

    expect(
      await renderWidth(
        tester,
        screen: WeeklyReportScreen(weekEnding: DateTime(2026, 8, 30)),
        content: find.byKey(const Key('weeklyReportScrollView')),
      ),
      1120,
    );
    expect(
      await renderWidth(
        tester,
        screen: const AddMedicationScreen(),
        content: find.byKey(const Key('medicationSearchField')),
      ),
      1070,
    );
    expect(
      await renderWidth(
        tester,
        screen: const ScanResultScreen(bottomNavigationInset: 0),
        content: find.byKey(const Key('scanResultScrollView')),
      ),
      1120,
    );
  });

  testWidgets('landscape destinations use horizontal desktop compositions', (
    tester,
  ) async {
    useSize(tester, const Size(1280, 720));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardScreen(
            email: 'person@example.com',
            now: DateTime(2026, 8, 30),
            bottomPadding: 24,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('dashboardLandscapeSummary')), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarScreen(
            initialDate: DateTime(2026, 8, 30),
            bottomPadding: 24,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('calendarLandscapeContent')), findsOneWidget);
  });

  testWidgets('content contracts to a narrow web window without overflow', (
    tester,
  ) async {
    useSize(tester, const Size(560, 640));

    final width = await renderWidth(
      tester,
      screen: CalendarScreen(
        initialDate: DateTime(2026, 8, 30),
        bottomPadding: 16,
      ),
      content: find.byKey(const Key('calendarScrollView')),
    );
    expect(width, lessThanOrEqualTo(560));
    expect(tester.takeException(), isNull);
  });
}
