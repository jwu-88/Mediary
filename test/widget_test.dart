import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application/app_theme.dart';
import 'package:flutter_application/liquid_glass_tab_bar.dart';
import 'package:flutter_application/main.dart';
import 'package:flutter_application/profile_screen.dart';
import 'package:flutter_application/settings_screen.dart';

void main() {
  Widget buildForm(AuthSubmitter onSubmit) {
    return MaterialApp(home: AuthForm(onSubmit: onSubmit));
  }

  testWidgets('validates email and password before submitting', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      buildForm(({
        required email,
        required password,
        required createAccount,
      }) async {
        calls++;
      }),
    );

    await tester.tap(find.byKey(const Key('submitButton')));
    await tester.pump();
    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('emailField')), 'not-an-email');
    await tester.enterText(find.byKey(const Key('passwordField')), '123');
    await tester.tap(find.byKey(const Key('submitButton')));
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(
      find.text('Password must be at least 6 characters.'),
      findsOneWidget,
    );
    expect(calls, 0);
  });

  testWidgets('switches to account creation and submits its mode', (
    tester,
  ) async {
    String? submittedEmail;
    var createdAccount = false;
    await tester.pumpWidget(
      buildForm(({
        required email,
        required password,
        required createAccount,
      }) async {
        submittedEmail = email;
        createdAccount = createAccount;
      }),
    );

    await tester.tap(find.text('Need an account? Create one'));
    await tester.pump();
    expect(find.text('Create an account'), findsOneWidget);
    expect(find.text('Already have an account? Sign in'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('emailField')),
      'person@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('passwordField')),
      'secure-password',
    );
    await tester.tap(find.byKey(const Key('submitButton')));
    await tester.pump();

    expect(submittedEmail, 'person@example.com');
    expect(createdAccount, isTrue);
  });

  testWidgets(
    'toggles password visibility and shows mapped authentication errors',
    (tester) async {
      await tester.pumpWidget(
        buildForm(({
          required email,
          required password,
          required createAccount,
        }) async {
          throw FirebaseAuthException(code: 'email-already-in-use');
        }),
      );

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      await tester.tap(find.text('Need an account? Create one'));
      await tester.enterText(
        find.byKey(const Key('emailField')),
        'person@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('passwordField')),
        'secure-password',
      );
      await tester.tap(find.byKey(const Key('submitButton')));
      await tester.pump();
      expect(
        find.text('An account already exists for this email address.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('shows progress and prevents a duplicate submission', (
    tester,
  ) async {
    final completer = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      buildForm(({required email, required password, required createAccount}) {
        calls++;
        return completer.future;
      }),
    );

    await tester.enterText(
      find.byKey(const Key('emailField')),
      'person@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('passwordField')),
      'secure-password',
    );
    await tester.tap(find.byKey(const Key('submitButton')));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.byKey(const Key('submitButton')));
    await tester.pump();
    expect(calls, 1);

    completer.complete();
    await tester.pump();
  });

  testWidgets('starts Google sign-in and prevents duplicate submissions', (
    tester,
  ) async {
    final completer = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthForm(
          onSubmit: ({
            required email,
            required password,
            required createAccount,
          }) async {},
          onGoogleSignIn: () {
            calls++;
            return completer.future;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('googleSignInButton')));
    await tester.pump();
    expect(calls, 1);
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.byKey(const Key('googleSignInButton')));
    await tester.pump();
    expect(calls, 1);

    completer.complete();
    await tester.pump();
  });

  testWidgets('renders the dashboard greeting, date, and bottom toolbar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticatedHome(
          email: 'person@example.com',
          displayName: 'Taylor Morgan',
          now: DateTime(2026, 8, 23),
        ),
      ),
    );

    expect(find.text('Good morning, Taylor'), findsOneWidget);
    expect(find.text('SUNDAY, AUGUST 23'), findsOneWidget);
    expect(find.byKey(const Key('liquidGlassTabBar')), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Weekly progress'), findsOneWidget);
    expect(find.text('Today’s schedule'), findsOneWidget);
    expect(find.text('Amoxicillin'), findsOneWidget);
  });

  testWidgets('dashboard falls back to the email username', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticatedHome(
          email: 'person@example.com',
          now: DateTime(2026, 8, 23),
        ),
      ),
    );

    expect(find.text('Good morning, person'), findsOneWidget);
  });

  testWidgets('profile matches the reference and supports editing safely', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticatedHome(
          email: 'taylor@example.com',
          displayName: 'Taylor Morgan',
        ),
      ),
    );

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<LiquidGlassTabBar>(find.byType(LiquidGlassTabBar))
          .currentIndex,
      4,
    );
    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.text('Your profile'), findsOneWidget);
    expect(find.text('Taylor Morgan'), findsOneWidget);
    expect(find.text('Health details'), findsOneWidget);
    expect(find.text('Penicillin'), findsOneWidget);
    expect(find.text('3 active'), findsOneWidget);
    expect(find.text('Emergency profile'), findsOneWidget);

    await tester.tap(find.byKey(const Key('editProfileButton')));
    await tester.pumpAndSettle();

    expect(find.text('EDITING'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('profileNameField')))
          .focusNode!
          .hasFocus,
      isTrue,
    );

    await tester.enterText(
      find.byKey(const Key('profileNameField')),
      'Taylor Reed',
    );
    final reminderSwitch = tester.widget<CupertinoSwitch>(
      find.byKey(const Key('doseReminderSwitch')),
    );
    expect(reminderSwitch.onChanged, isNotNull);
    reminderSwitch.onChanged!(false);
    await tester.pump();
    expect(find.text('Off'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cancelProfileEditButton')));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Discard Changes'));
    await tester.pumpAndSettle();
    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.text('Taylor Morgan'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);
  });

  testWidgets('failed profile save preserves the draft in edit mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          email: 'taylor@example.com',
          displayName: 'Taylor Morgan',
          onSave: (_) async => throw Exception('Save failed'),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('editProfileButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('profileNameField')),
      'Taylor Reed',
    );
    await tester.tap(find.byKey(const Key('doneProfileEditButton')));
    await tester.pumpAndSettle();

    expect(find.text('EDITING'), findsOneWidget);
    expect(find.byKey(const Key('profileSaveError')), findsOneWidget);
    expect(find.text('Taylor Reed'), findsOneWidget);
  });

  testWidgets(
    'requests camera access, keeps the toolbar, and shows a date-correct calendar',
    (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var cameraRequests = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AuthenticatedHome(
            email: 'person@example.com',
            now: DateTime(2024, 2, 29),
            cameraPermissionRequester: () async {
              cameraRequests++;
              return CameraAccessState.granted;
            },
          ),
        ),
      );

      LiquidGlassTabBar toolbar() =>
          tester.widget<LiquidGlassTabBar>(find.byType(LiquidGlassTabBar));

      expect(find.byKey(const Key('liquidGlassTabBar')), findsOneWidget);
      expect(toolbar().currentIndex, 0);

      await tester.tap(find.text('Scan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(cameraRequests, 1);
      expect(find.byKey(const Key('liquidGlassTabBar')), findsOneWidget);
      expect(toolbar().currentIndex, 2);
      expect(find.text('Scan medication'), findsOneWidget);
      expect(find.byKey(const Key('scannerCameraPanel')), findsOneWidget);
      expect(find.byKey(const Key('captureMedicationButton')), findsOneWidget);

      await tester.tap(find.byKey(const Key('captureMedicationButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.byKey(const Key('liquidGlassTabBar')), findsOneWidget);
      expect(toolbar().currentIndex, 2);
      expect(find.text('Review medication'), findsOneWidget);
      expect(find.text('98% match'), findsOneWidget);

      await tester.tap(find.byKey(const Key('scanResultBackButton')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('closeScannerButton')));
      await tester.pump();
      expect(find.byKey(const Key('liquidGlassTabBar')), findsOneWidget);
      expect(toolbar().currentIndex, 0);

      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('liquidGlassTabBar')), findsOneWidget);
      expect(toolbar().currentIndex, 1);
      expect(find.byKey(const Key('calendarGrid')), findsOneWidget);
      expect(find.text('February 2024'), findsOneWidget);
      expect(find.text('Thursday, February 29'), findsOneWidget);
    },
  );

  testWidgets('library opens the reference medication detail screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: AuthenticatedHome(email: 'person@example.com')),
    );

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<LiquidGlassTabBar>(find.byType(LiquidGlassTabBar))
          .currentIndex,
      3,
    );
    expect(find.text('Medication library'), findsOneWidget);
    expect(find.text('Antibiotics 101'), findsOneWidget);

    await tester.tap(find.byKey(const Key('medicationAmoxicillin')));
    await tester.pumpAndSettle();
    expect(find.text('What it treats'), findsOneWidget);
    expect(find.text('Important safety'), findsOneWidget);
    expect(find.text('Add to my schedule'), findsOneWidget);
  });

  testWidgets('opens settings and enables dark mode', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final darkMode = ValueNotifier(false);
    addTearDown(darkMode.dispose);

    await tester.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: darkMode,
        builder: (context, enabled, child) {
          return MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: enabled ? ThemeMode.dark : ThemeMode.light,
            home: Builder(
              builder: (context) => AuthForm(
                onSubmit: ({
                  required email,
                  required password,
                  required createAccount,
                }) async {},
                onOpenSettings: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => SettingsScreen(
                        darkModeEnabled: darkMode.value,
                        onDarkModeChanged: (value) => darkMode.value = value,
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Dark appearance'), findsOneWidget);
    expect(find.text('App preferences'), findsOneWidget);
    expect(find.text('Account'), findsNothing);

    await tester.tap(find.byKey(const Key('darkModeSwitch')));
    await tester.pumpAndSettle();
    expect(darkMode.value, isTrue);
    expect(
      tester
          .widget<CupertinoSwitch>(find.byKey(const Key('darkModeSwitch')))
          .value,
      isTrue,
    );
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
  });

  testWidgets('settings shows the signed-in footer and signs out', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var signOutCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          darkModeEnabled: false,
          onDarkModeChanged: (_) {},
          accountEmail: 'person@example.com',
          onSignOut: () async {
            signOutCalls++;
          },
        ),
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.textContaining('person@example.com'), findsOneWidget);
    await tester.tap(find.byKey(const Key('settingsSignOutButton')));
    await tester.pumpAndSettle();
    expect(signOutCalls, 1);
  });
}
