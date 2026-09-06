import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/add_medication_screen.dart';
import 'package:mediary/app_interactions.dart';
import 'package:mediary/calendar_screen.dart';
import 'package:mediary/library_screens.dart';
import 'package:mediary/profile_screen.dart';

void main() {
  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('medication selection rows and CTA use native feedback', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(const MaterialApp(home: AddMedicationScreen()));

    final row = find.byKey(
      const Key('medicationOption_amoxicillin-500-capsule'),
    );
    expect(tester.widget<AppPressable>(row).haptic, AppHapticKind.selection);

    await tester.tap(row);
    await tester.pump();
    expect(find.text('1 Selected'), findsOneWidget);

    final cta = find.descendant(
      of: find.byKey(const Key('addSelectedMedicationsButton')),
      matching: find.byType(AppPressable),
    );
    expect(cta, findsOneWidget);
    expect(
      tester.widget<AppPressable>(cta).haptic,
      AppHapticKind.primaryAction,
    );
  });

  testWidgets('library categories and medication rows use native feedback', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MedicationLibraryScreen(bottomPadding: 0)),
      ),
    );

    expect(
      tester
          .widget<AppPressable>(
            find.byKey(const Key('medicationCategoryPopular')),
          )
          .haptic,
      AppHapticKind.selection,
    );
    expect(
      tester
          .widget<AppPressable>(find.byKey(const Key('medicationAmoxicillin')))
          .haptic,
      AppHapticKind.selection,
    );
  });

  testWidgets('calendar dates and dose rows use native feedback', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: CalendarScreen(
          initialDate: DateTime(2026, 8, 23),
          bottomPadding: 0,
        ),
      ),
    );

    expect(
      tester
          .widget<AppPressable>(find.byKey(const Key('calendarDay-2026-08-23')))
          .haptic,
      AppHapticKind.selection,
    );
    final doseRow = find.ancestor(
      of: find.text('Amoxicillin'),
      matching: find.byType(AppPressable),
    );
    expect(doseRow, findsOneWidget);
  });

  testWidgets('editable profile avatar and rows use native feedback', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileScreen(
          email: 'jayden@example.com',
          displayName: 'Jayden Wu',
          bottomPadding: 0,
        ),
      ),
    );

    expect(
      find.ancestor(
        of: find.text('Health Report'),
        matching: find.byType(AppPressable),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('editProfileButton')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AppPressable>(
            find.byKey(const Key('changeProfilePhotoButton')),
          )
          .haptic,
      AppHapticKind.selection,
    );
  });
}
