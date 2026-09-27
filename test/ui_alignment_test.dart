import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/app_theme.dart';
import 'package:mediary/calendar_screen.dart';
import 'package:mediary/dashboard_screen.dart';
import 'package:mediary/weekly_report_screen.dart';

void main() {
  Widget shell(Widget screen) {
    if (screen is WeeklyReportScreen) return screen;
    return Scaffold(body: screen);
  }

  void useSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: shell(screen)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  DashboardScreen dashboard() => DashboardScreen(
    email: 'person@example.com',
    displayName: 'Taylor Morgan',
    now: DateTime(2026, 8, 30, 9),
    bottomPadding: 24,
  );

  CalendarScreen calendar() =>
      CalendarScreen(initialDate: DateTime(2026, 8, 30), bottomPadding: 24);

  WeeklyReportScreen report() => WeeklyReportScreen(
    weekEnding: DateTime(2026, 8, 30),
    dailyTaken: const [2, 2, 2, 1, 2, 1, 1],
    dailyScheduled: const [2, 2, 2, 2, 2, 1, 1],
    timingOffsetsMinutes: const [2, -1, 5, 12, 4, 8, 9],
  );

  testWidgets('primary screen gutters and section headings share an inset', (
    tester,
  ) async {
    useSize(tester, const Size(430, 932));

    await pumpScreen(tester, dashboard());
    final dashboardDate = tester.getTopLeft(
      find.byKey(const Key('dashboardDate')),
    );
    final dashboardSection = tester.getTopLeft(
      find.byKey(const Key('dashboardWeeklyProgressHeader')),
    );

    await pumpScreen(tester, calendar());
    final calendarTitle = tester.getTopLeft(
      find.byKey(const Key('calendarTitle')),
    );
    final calendarSection = tester.getTopLeft(
      find.byKey(const Key('calendarSelectedDateHeader')),
    );

    await pumpScreen(tester, report());
    final reportDate = tester.getTopLeft(
      find.byKey(const Key('weeklyReportWeekEnding')),
    );
    final reportSection = tester.getTopLeft(
      find.byKey(const Key('weeklyReportDailyDosesHeading')),
    );

    for (final point in [
      dashboardDate,
      dashboardSection,
      calendarTitle,
      calendarSection,
      reportDate,
      reportSection,
    ]) {
      expect(point.dx, closeTo(16, .01));
    }
  });

  testWidgets('desktop screens share the same centered content width', (
    tester,
  ) async {
    useSize(tester, const Size(1280, 720));
    const expectedLeft = 276.0; // (1280 - 760) / 2 + 16 inset.

    await pumpScreen(tester, dashboard());
    expect(
      tester.getTopLeft(find.byKey(const Key('dashboardDate'))).dx,
      closeTo(expectedLeft, .01),
    );

    await pumpScreen(tester, calendar());
    expect(
      tester.getTopLeft(find.byKey(const Key('calendarTitle'))).dx,
      closeTo(expectedLeft, .01),
    );

    await pumpScreen(tester, report());
    expect(
      tester.getTopLeft(find.byKey(const Key('weeklyReportWeekEnding'))).dx,
      closeTo(expectedLeft, .01),
    );
  });

  testWidgets('primary screens remain usable at a narrow width', (
    tester,
  ) async {
    useSize(tester, const Size(320, 800));

    await pumpScreen(tester, dashboard());
    await pumpScreen(tester, calendar());
    await pumpScreen(tester, report());

    expect(tester.takeException(), isNull);
  });
}
