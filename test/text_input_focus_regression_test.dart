import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/liquid_glass_search_field.dart';
import 'package:mediary/main.dart';
import 'package:mediary/profile_screen.dart';

import 'support/continuous_text_entry.dart';

void main() {
  for (final platform in [TargetPlatform.iOS]) {
    for (final size in const [Size(390, 844), Size(1280, 800)]) {
      void configure(WidgetTester tester) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
      }

      testWidgets(
        'auth fields retain focus across validation on $platform at $size',
        (tester) async {
          configure(tester);
          await tester.pumpWidget(
            MaterialApp(
              home: AuthForm(
                onSubmit: ({
                  required email,
                  required password,
                  required createAccount,
                }) async {},
              ),
            ),
          );
          for (final entry in [
            ('emailField', ['', 'p', 'pe', 'person@example.com']),
            ('passwordField', ['', 's', 'se', 'secure-password']),
            ('confirmPasswordField', ['', 's', 'se', 'secure-password']),
          ]) {
            await typeWithoutRefocusing(
              tester,
              find.byKey(Key(entry.$1)),
              entry.$2,
            );
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(platform),
      );

      testWidgets(
        'profile fields retain focus with keyboard insets on $platform at $size',
        (tester) async {
          configure(tester);
          await tester.pumpWidget(
            const MaterialApp(
              home: ProfileScreen(
                email: 'person@example.com',
                displayName: 'Person',
                bottomPadding: 0,
              ),
            ),
          );
          await tester.tap(find.byKey(const Key('editProfileButton')));
          await tester.pumpAndSettle();
          tester.view.viewInsets = const FakeViewPadding(bottom: 280);
          addTearDown(tester.view.resetViewInsets);
          await tester.pump();
          for (final entry in [
            ('profileNameField', ['', 'P', 'Pe', 'Person Name']),
            ('profileEmailField', ['', 'p', 'pe', 'person@example.com']),
            ('careTeamField', ['', 'D', 'Dr', 'Dr Smith']),
          ]) {
            await typeWithoutRefocusing(
              tester,
              find.byKey(Key(entry.$1)),
              entry.$2,
            );
          }
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(platform),
      );

      testWidgets(
        'search retains focus through clear-button and parent rebuilds on $platform at $size',
        (tester) async {
          configure(tester);
          final controller = TextEditingController();
          addTearDown(controller.dispose);
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, refresh) => LiquidGlassSearchField(
                    controller: controller,
                    hintText: 'Search',
                    textFieldKey: const Key('searchInput'),
                    onChanged: (_) => refresh(() {}),
                  ),
                ),
              ),
            ),
          );
          await typeWithoutRefocusing(
            tester,
            find.byKey(const Key('searchInput')),
            ['', 'b', 'be', 'ben', 'benadryl'],
          );
          await tester.tap(
            find.byKey(const Key('liquidGlassSearchClearButton')),
          );
          await tester.pump();
          final editable = tester.widget<EditableText>(
            find.byType(EditableText),
          );
          expect(editable.focusNode.hasFocus, isTrue);
          expect(controller.text, isEmpty);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(platform),
      );
    }
  }
}
