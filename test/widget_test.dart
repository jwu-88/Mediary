import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application/app_theme.dart';
import 'package:flutter_application/main.dart';

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
    expect(find.byType(CupertinoTabBar), findsOneWidget);
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

  testWidgets('requests camera access and shows a date-correct calendar', (
    tester,
  ) async {
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

    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();
    expect(cameraRequests, 1);
    expect(find.text('Scanner ready'), findsOneWidget);
    expect(find.text('Camera access is enabled.'), findsOneWidget);

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendarDatePicker')), findsOneWidget);
    expect(find.text('February 29, 2024'), findsOneWidget);
    final calendar = tester.widget<CalendarDatePicker>(
      find.byKey(const Key('calendarDatePicker')),
    );
    expect(calendar.currentDate, DateTime(2024, 2, 29));
  });

  testWidgets('opens settings and enables dark mode', (tester) async {
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
    expect(find.text('Dark mode'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Account'), findsNothing);

    await tester.tap(find.byKey(const Key('darkModeSwitch')));
    await tester.pumpAndSettle();
    expect(darkMode.value, isTrue);
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const Key('darkModeSwitch')))
          .value,
      isTrue,
    );
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
  });

  testWidgets('settings shows the account section and signs out', (
    tester,
  ) async {
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

    expect(find.text('Account'), findsOneWidget);
    expect(find.text('person@example.com'), findsOneWidget);
    await tester.tap(find.byKey(const Key('settingsSignOutButton')));
    await tester.pumpAndSettle();
    expect(signOutCalls, 1);
  });
}
