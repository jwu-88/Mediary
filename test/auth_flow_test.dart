import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mediary/main.dart';

void main() {
  Widget buildForm({
    required AuthSubmitter onSubmit,
    GoogleAuthSubmitter? onGoogleSignIn,
    bool initialCreateAccount = true,
  }) {
    return MaterialApp(
      home: AuthForm(
        onSubmit: onSubmit,
        onGoogleSignIn: onGoogleSignIn,
        initialCreateAccount: initialCreateAccount,
      ),
    );
  }

  Future<void> enterCredentials(
    WidgetTester tester, {
    bool includeConfirmation = false,
  }) async {
    await tester.enterText(
      find.byKey(const Key('emailField')),
      'person@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('passwordField')),
      'secure-password',
    );
    if (includeConfirmation) {
      await tester.enterText(
        find.byKey(const Key('confirmPasswordField')),
        'secure-password',
      );
    }
  }

  test('maps platform-specific Firebase failures to actionable messages', () {
    const expectations = {
      'INVALID_LOGIN_CREDENTIALS': 'Incorrect email or password.',
      'auth/user-disabled':
          'This account has been disabled. Contact support for help.',
      'unauthorized-domain':
          'This web address is not authorized for Google sign-in.',
      'app-not-authorized':
          'Mediary is not authorized to use its Firebase configuration.',
    };

    for (final entry in expectations.entries) {
      expect(
        firebaseAuthErrorMessage(
          FirebaseAuthException(code: entry.key),
          action: entry.key == 'unauthorized-domain'
              ? FirebaseAuthAction.googleSignIn
              : FirebaseAuthAction.signIn,
        ),
        entry.value,
      );
    }
  });

  testWidgets(
    'first visit starts with create account and returning-user toggle',
    (tester) async {
      await tester.pumpWidget(
        buildForm(
          onSubmit: ({
            required email,
            required password,
            required createAccount,
          }) async {},
        ),
      );

      expect(find.text('Create an Account'), findsOneWidget);
      expect(find.byKey(const Key('confirmPasswordField')), findsOneWidget);
      expect(find.byKey(const Key('authMedicationBackground')), findsOneWidget);

      await tester.ensureVisible(find.text('Already have an account? Sign in'));
      await tester.tap(find.text('Already have an account? Sign in'));
      await tester.pump();

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Need an account? Create one'), findsOneWidget);
      expect(find.byKey(const Key('confirmPasswordField')), findsNothing);
    },
  );

  testWidgets('account creation requires matching password confirmation', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      buildForm(
        onSubmit:
            ({
              required email,
              required password,
              required createAccount,
            }) async {
              calls++;
            },
      ),
    );
    await enterCredentials(tester);
    await tester.enterText(
      find.byKey(const Key('confirmPasswordField')),
      'different-password',
    );

    await tester.ensureVisible(find.byKey(const Key('submitButton')));
    await tester.tap(find.byKey(const Key('submitButton')));
    await tester.pump();

    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('editing credentials clears a stale Firebase error', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildForm(
        initialCreateAccount: false,
        onSubmit:
            ({
              required email,
              required password,
              required createAccount,
            }) async {
              throw FirebaseAuthException(code: 'INVALID_LOGIN_CREDENTIALS');
            },
      ),
    );
    await enterCredentials(tester);
    await tester.tap(find.byKey(const Key('submitButton')));
    await tester.pump();
    expect(find.text('Incorrect email or password.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('emailField')),
      'updated@example.com',
    );
    await tester.pump();
    expect(find.text('Incorrect email or password.'), findsNothing);
  });

  testWidgets('Google failures are contextual and cancellation stays silent', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildForm(
        onSubmit: ({
          required email,
          required password,
          required createAccount,
        }) async {},
        onGoogleSignIn: () async {
          throw FirebaseAuthException(code: 'unauthorized-domain');
        },
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('googleSignInButton')));
    await tester.tap(find.byKey(const Key('googleSignInButton')));
    await tester.pump();
    expect(
      find.text('This web address is not authorized for Google sign-in.'),
      findsOneWidget,
    );

    await tester.pumpWidget(
      buildForm(
        onSubmit: ({
          required email,
          required password,
          required createAccount,
        }) async {},
        onGoogleSignIn: () async {
          throw const GoogleSignInException(
            code: GoogleSignInExceptionCode.canceled,
          );
        },
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('googleSignInButton')));
    await tester.tap(find.byKey(const Key('googleSignInButton')));
    await tester.pump();
    expect(find.textContaining('Unable to sign in'), findsNothing);
  });

  testWidgets('email verification supports refresh, resend, and sign out', (
    tester,
  ) async {
    var refreshCalls = 0;
    var resendCalls = 0;
    var signOutCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: EmailVerificationScreen(
          email: 'person@example.com',
          onRefresh: () async {
            refreshCalls++;
            return false;
          },
          onResend: () async => resendCalls++,
          onSignOut: () async => signOutCalls++,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('refreshEmailVerificationButton')));
    await tester.pump();
    expect(refreshCalls, 1);
    expect(find.textContaining('not verified yet'), findsOneWidget);

    await tester.tap(find.byKey(const Key('resendVerificationButton')));
    await tester.pump();
    expect(resendCalls, 1);
    expect(find.textContaining('Verification email sent'), findsOneWidget);

    await tester.tap(find.byKey(const Key('verificationSignOutButton')));
    await tester.pump();
    expect(signOutCalls, 1);
  });
}
