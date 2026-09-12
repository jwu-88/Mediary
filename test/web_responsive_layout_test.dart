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

void main() {
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
      760,
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
      760,
    );
    expect(
      await renderWidth(
        tester,
        screen: const MedicationLibraryScreen(bottomPadding: 24),
        content: find.byKey(const Key('medicationLibraryScrollView')),
      ),
      760,
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
      760,
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
      760,
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
      760,
    );
    expect(
      await renderWidth(
        tester,
        screen: const AddMedicationScreen(),
        content: find.byKey(const Key('medicationSearchField')),
      ),
      726,
    );
    expect(
      await renderWidth(
        tester,
        screen: const ScanResultScreen(bottomNavigationInset: 0),
        content: find.byKey(const Key('scanResultScrollView')),
      ),
      720,
    );
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
