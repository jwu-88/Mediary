import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets('renders the authenticated home screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticatedHome(
          email: 'person@example.com',
          onSignOut: () async {},
        ),
      ),
    );

    expect(find.text('You are signed in'), findsOneWidget);
    expect(find.text('person@example.com'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });
}
