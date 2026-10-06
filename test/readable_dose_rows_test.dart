import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/app_theme.dart';
import 'package:mediary/calendar_screen.dart';
import 'package:mediary/dashboard_screen.dart';

void main() {
  for (final page in ['dashboard', 'calendar']) {
    for (final width in [320.0, 430.0]) {
      for (final scale in [2.0, 3.0]) {
        testWidgets(
          '$page shows full dose information at $width with ${scale}x text',
          (tester) async {
            tester.view.physicalSize = Size(width, 800);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            const name = 'Amoxicillin Clavulanate Extended Release Tablet';
            const details = '875 MG / 125 MG · 10:36 AM';
            final changes = <(String, String)>[];
            Future<void> changed(
              String id,
              String status, {
              DateTime? snoozedUntil,
            }) async {
              changes.add((id, status));
            }

            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.light,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: page == 'dashboard'
                      ? DashboardScreen(
                          email: 'qa@example.invalid',
                          now: DateTime(2026, 8, 23, 14),
                          initialDoses: const [
                            DashboardDoseData(
                              id: 'large',
                              name: name,
                              details: details,
                              status: 'due',
                            ),
                          ],
                          onDoseStatusChanged: changed,
                        )
                      : CalendarScreen(
                          initialDate: DateTime(2026, 8, 23),
                          initialDoses: const [
                            CalendarDoseData(
                              id: 'large',
                              localDate: '2026-08-23',
                              name: name,
                              details: details,
                              status: 'due',
                            ),
                          ],
                          onDoseStatusChanged: changed,
                        ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final scrollable = find
                .descendant(
                  of: find.byKey(Key('${page}ScrollView')),
                  matching: find.byType(Scrollable),
                )
                .first;
            final nameFinder = find.byKey(Key('${page}ReadableDoseName_large'));
            await tester.scrollUntilVisible(
              nameFinder,
              240,
              scrollable: scrollable,
            );
            await tester.pumpAndSettle();
            for (final part in ['Name', 'Details', 'Status']) {
              final finder = find.byKey(
                Key('${page}ReadableDose${part}_large'),
              );
              expect(finder, findsOneWidget);
              final text = tester.widget<Text>(finder);
              expect(text.maxLines, isNull);
              final paragraph = tester.renderObject<RenderParagraph>(finder);
              expect(paragraph.didExceedMaxLines, isFalse);
            }
            expect(tester.widget<Text>(nameFinder).data, name);
            expect(
              tester
                  .widget<Text>(
                    find.byKey(Key('${page}ReadableDoseDetails_large')),
                  )
                  .data,
              details,
            );
            expect(tester.takeException(), isNull);
            final delete = find.byKey(Key('${page}DeleteDose_large'));
            await tester.ensureVisible(delete);
            await tester.pumpAndSettle();
            expect(tester.getSize(delete), const Size(44, 44));
            await tester.tap(delete);
            await tester.pumpAndSettle();
            expect(changes, [('large', 'cancelled')]);
            expect(find.text('Remove From Day'), findsNothing);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }
}
