import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/app_theme.dart';
import 'package:mediary/library_screens.dart';
import 'package:mediary/profile_screen.dart';
import 'package:mediary/settings_screen.dart';

void main() {
  testWidgets('library search filters medications and uses glass styling', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MedicationLibraryScreen(bottomPadding: 0)),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('liquidGlassSearchSurface')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('medicationSearchField')),
      'ibuprofen',
    );
    await tester.pump();

    expect(find.text('Ibuprofen'), findsOneWidget);
    expect(find.text('Amoxicillin'), findsNothing);

    await tester.tap(find.byKey(const Key('liquidGlassSearchClearButton')));
    await tester.pump();
    expect(find.text('Amoxicillin'), findsOneWidget);
  });

  testWidgets('library previews, saves, and filters medications', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MedicationLibraryScreen(bottomPadding: 0)),
      ),
    );
    await tester.pump();

    await tester.drag(
      find.byKey(const Key('medicationLibraryScrollView')),
      const Offset(0, -360),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('medicationIbuprofen')));
    await tester.pumpAndSettle();
    expect(find.text('Save Medication'), findsOneWidget);

    await tester.tap(find.text('Save Medication'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('medicationLibraryScrollView')),
      const Offset(0, 500),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('savedMedicationsButton')));
    await tester.pumpAndSettle();

    expect(find.text('Ibuprofen'), findsOneWidget);
    expect(find.text('Amoxicillin'), findsNothing);
  });

  testWidgets('medication details show the complete side-effect list', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MedicationDetailScreen())),
    );
    await tester.pump();

    await tester.drag(
      find.byKey(const Key('medicationDetailScrollView')),
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('View All'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Headache'), findsOneWidget);
    expect(find.textContaining('Seek urgent care'), findsOneWidget);
  });

  testWidgets('profile rows open useful summaries', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileScreen(
          email: 'jayden@example.com',
          displayName: 'Jayden Wu',
          bottomPadding: 0,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Health Report'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Mediary Health Report'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets('settings choices and export update immediately', (tester) async {
    String? copiedData;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedData =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          appearanceMode: ThemeMode.system,
          onAppearanceModeChanged: (_) {},
          accentColor: AppAccentColor.blue,
          onAccentColorChanged: (_) {},
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Reminder Sound'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bell'));
    await tester.pumpAndSettle();
    expect(find.text('Bell'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Privacy Controls'),
      240,
      scrollable: find.descendant(
        of: find.byKey(const Key('settingsScrollView')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('Privacy Controls'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('privacyControlDivider0')), findsOneWidget);
    expect(find.byKey(const Key('privacyControlDivider1')), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('exportDataButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('exportDataButton')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Data copied securely'), findsOneWidget);
    expect(copiedData, contains('Mediary Data Export'));
  });
}
