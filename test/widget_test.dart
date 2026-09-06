import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mediary/app_theme.dart';
import 'package:mediary/firebase_options.dart';
import 'package:mediary/liquid_glass_appearance_selector.dart';
import 'package:mediary/liquid_glass_tab_bar.dart';
import 'package:mediary/main.dart';
import 'package:mediary/profile_screen.dart';
import 'package:mediary/settings_screen.dart';
import 'package:mediary/web_navigation_sidebar.dart';

void main() {
  test('web Firebase options target the Mediary project', () {
    expect(DefaultFirebaseOptions.web.projectId, 'cacapp-3a771');
    expect(
      DefaultFirebaseOptions.web.appId,
      '1:958809412045:web:226158a702998a63c57484',
    );
  });

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
    await tester.ensureVisible(find.byKey(const Key('submitButton')));
    await tester.tap(find.byKey(const Key('submitButton')));
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(
      find.text('Use at least 8 characters for a new password.'),
      findsOneWidget,
    );
    expect(calls, 0);
  });

  testWidgets('defaults to account creation and submits its mode', (
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

    expect(find.text('Create an Account'), findsOneWidget);
    expect(find.text('Already have an account? Sign in'), findsOneWidget);
    expect(find.byKey(const Key('confirmPasswordField')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('emailField')),
      'person@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('passwordField')),
      'secure-password',
    );
    await tester.enterText(
      find.byKey(const Key('confirmPasswordField')),
      'secure-password',
    );
    await tester.ensureVisible(find.byKey(const Key('submitButton')));
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

      await tester.enterText(
        find.byKey(const Key('emailField')),
        'person@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('passwordField')),
        'secure-password',
      );
      await tester.enterText(
        find.byKey(const Key('confirmPasswordField')),
        'secure-password',
      );
      await tester.ensureVisible(find.byKey(const Key('submitButton')));
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
    await tester.enterText(
      find.byKey(const Key('confirmPasswordField')),
      'secure-password',
    );
    await tester.ensureVisible(find.byKey(const Key('submitButton')));
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

    await tester.ensureVisible(find.byKey(const Key('googleSignInButton')));
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

    expect(find.text('Good Morning, Taylor'), findsOneWidget);
    expect(find.text('SUNDAY, AUGUST 23'), findsOneWidget);
    expect(find.byKey(const Key('liquidGlassTabBar')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('liquidGlassTabBar'))).height,
      64,
    );
    final selectionLensSize = tester.getSize(
      find.byKey(const Key('liquidGlassSelectionLens')),
    );
    expect(selectionLensSize.width, greaterThan(selectionLensSize.height + 8));
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Weekly Progress'), findsOneWidget);
    expect(find.text('Today’s Schedule'), findsOneWidget);
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

    expect(find.text('Good Morning, person'), findsOneWidget);
  });

  testWidgets('dashboard opens dedicated report and medication pages', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticatedHome(
          email: 'person@example.com',
          displayName: 'Taylor Morgan',
          now: DateTime(2026, 8, 30),
        ),
      ),
    );

    expect(find.text('You’re right on track!'), findsOneWidget);
    expect(find.byKey(const Key('dashboardScheduleTable')), findsOneWidget);
    expect(find.text('Dose & Time'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('dashboardScheduleTable')),
        matching: find.byType(Divider),
      ),
      findsNWidgets(3),
    );

    await tester.tap(find.byKey(const Key('dashboardViewReportButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('weeklyReportScrollView')), findsOneWidget);
    expect(find.byKey(const Key('dailyDoseChart')), findsOneWidget);
    expect(find.byKey(const Key('liquidGlassTabBar')), findsNothing);

    await tester.tap(find.byKey(const Key('weeklyReportBackButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dashboardAddButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('addMedicationScreen')), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('medicationOption_ibuprofen-200-tablet')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('addSelectedMedicationsButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboardScheduleTable')), findsOneWidget);
    expect(find.text('Ibuprofen'), findsOneWidget);
  });

  testWidgets('web shell uses an opaque hover sidebar instead of glass', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: AuthenticatedHome(
          email: 'person@example.com',
          useSidebarNavigation: true,
        ),
      ),
    );

    expect(find.byType(WebNavigationSidebar), findsOneWidget);
    expect(find.byKey(const Key('liquidGlassTabBar')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('webNavigationSidebar')),
        matching: find.byType(BackdropFilter),
      ),
      findsNothing,
    );
    expect(
      tester.getSize(find.byKey(const Key('webNavigationSidebar'))).width,
      76,
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(900, 100));
    await mouse.moveTo(
      tester.getCenter(
        find.byKey(const Key('webNavigationSidebarHoverRegion')),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('webNavigationSidebar'))).width,
      224,
    );
    expect(find.text('Mediary'), findsOneWidget);

    await mouse.moveTo(const Offset(180, 100));
    await tester.pump();
    expect(
      tester.getSize(find.byKey(const Key('webNavigationSidebar'))).width,
      224,
    );

    await mouse.moveTo(const Offset(280, 100));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('webNavigationSidebar'))).width,
      76,
    );

    await mouse.moveTo(const Offset(40, 100));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('webNavigationSidebar'))).width,
      224,
    );

    await tester.tap(find.byKey(const Key('webNavItem-3')));
    await tester.pumpAndSettle();
    expect(find.text('Medication Library'), findsOneWidget);
    expect(
      tester
          .widget<WebNavigationSidebar>(find.byType(WebNavigationSidebar))
          .currentIndex,
      3,
    );
  });

  testWidgets('settings account supports editing safely', (tester) async {
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

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<LiquidGlassTabBar>(find.byType(LiquidGlassTabBar))
          .currentIndex,
      4,
    );
    expect(find.byKey(const Key('settingsPageTitle')), findsOneWidget);
    expect(find.text('App Preferences'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Connected Apps'), findsOneWidget);

    final settingsScrollable = find.descendant(
      of: find.byKey(const Key('settingsScrollView')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('settingsPrivacySectionTitle')),
      300,
      scrollable: settingsScrollable,
    );
    expect(find.text('Privacy'), findsOneWidget);
    expect(find.text('Health Details'), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const Key('settingsAccountRow')),
      -300,
      scrollable: settingsScrollable,
    );

    await tester.tap(find.byKey(const Key('settingsAccountRow')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profilePageTitle')), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Taylor Morgan'), findsOneWidget);
    expect(find.text('Health Details'), findsOneWidget);
    expect(find.text('Penicillin'), findsOneWidget);
    expect(find.text('3 active'), findsOneWidget);
    expect(find.text('Emergency Profile'), findsOneWidget);

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

    await tester.tap(find.byKey(const Key('cancelProfileEditButton')));
    await tester.pumpAndSettle();
    expect(find.text('Discard Changes?'), findsOneWidget);
    await tester.tap(find.text('Discard Changes'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profilePageTitle')), findsOneWidget);
    expect(find.text('Taylor Morgan'), findsOneWidget);

    await tester.tap(find.byKey(const Key('accountBackButton')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('settingsPageTitle')),
      -300,
      scrollable: settingsScrollable,
    );
    expect(find.byKey(const Key('settingsPageTitle')), findsOneWidget);
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
      expect(find.text('Scan Medication'), findsOneWidget);
      expect(find.byKey(const Key('scannerCameraPanel')), findsOneWidget);
      expect(find.byKey(const Key('captureMedicationButton')), findsOneWidget);

      await tester.tap(find.byKey(const Key('captureMedicationButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.byKey(const Key('liquidGlassTabBar')), findsOneWidget);
      expect(toolbar().currentIndex, 2);
      expect(find.text('Review Medication'), findsOneWidget);
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
    expect(find.text('Medication Library'), findsOneWidget);
    expect(find.text('Antibiotics 101'), findsOneWidget);

    await tester.tap(find.byKey(const Key('medicationAmoxicillin')));
    await tester.pumpAndSettle();
    expect(find.text('What It Treats'), findsOneWidget);
    expect(find.text('Important Safety'), findsOneWidget);
    expect(find.text('Add to My Schedule'), findsOneWidget);
  });

  testWidgets('opens settings and selects dark appearance', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final appearanceMode = ValueNotifier(ThemeMode.system);
    addTearDown(appearanceMode.dispose);

    await tester.pumpWidget(
      ValueListenableBuilder<ThemeMode>(
        valueListenable: appearanceMode,
        builder: (context, mode, child) {
          return MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: mode,
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
                        appearanceMode: appearanceMode.value,
                        onAppearanceModeChanged: (value) =>
                            appearanceMode.value = value,
                        accentColor: AppAccentColor.blue,
                        onAccentColorChanged: (_) {},
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
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Dark Appearance'), findsNothing);
    expect(find.text('App Preferences'), findsOneWidget);
    expect(find.text('Account'), findsNothing);
    expect(
      tester
          .widget<LiquidGlassAppearanceSelector>(
            find.byType(LiquidGlassAppearanceSelector),
          )
          .value,
      ThemeMode.system,
    );

    await tester.ensureVisible(find.byKey(const Key('appearanceOptionDark')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('appearanceOptionDark')));
    await tester.pumpAndSettle();
    expect(appearanceMode.value, ThemeMode.dark);
    expect(
      tester
          .widget<LiquidGlassAppearanceSelector>(
            find.byType(LiquidGlassAppearanceSelector),
          )
          .value,
      ThemeMode.dark,
    );
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(
      tester
          .widget<Scaffold>(find.byKey(const Key('settingsScreen')))
          .backgroundColor,
      AppColors.darkBackground,
    );
  });

  testWidgets('account shows the signed-in identity and signs out', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var signOutCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          email: 'person@example.com',
          displayName: 'Person Example',
          bottomPadding: 0,
          onSignOut: () async {
            signOutCalls++;
          },
        ),
      ),
    );

    await tester.ensureVisible(find.byKey(const Key('accountSignOutButton')));
    await tester.pumpAndSettle();
    expect(find.textContaining('person@example.com'), findsOneWidget);
    await tester.tap(find.byKey(const Key('accountSignOutButton')));
    await tester.pumpAndSettle();
    expect(signOutCalls, 1);
  });
}
