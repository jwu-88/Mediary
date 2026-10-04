import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:permission_handler/permission_handler.dart';

import 'add_medication_screen.dart';
import 'app_legal.dart';
import 'app_interactions.dart';
import 'app_layout.dart';
import 'app_theme.dart';
import 'calendar_screen.dart';
import 'dashboard_screen.dart';
import 'data/mediary_data_store.dart';
import 'data/mediary_models.dart';
import 'data/dose_occurrence_identity.dart';
import 'data/mediary_repository.dart';
import 'data/medication_catalog_client.dart';
import 'data/schedule_occurrence_generator.dart';
import 'firebase_options.dart';
import 'in_app_page.dart';
import 'library_screens.dart';
import 'liquid_glass_tab_bar.dart';
import 'medication_time_picker.dart';
import 'medication_scan.dart';
import 'notifications/medication_notification_service.dart';
import 'profile_screen.dart';
import 'scanner_screens.dart';
import 'settings_screen.dart';
import 'web_camera.dart';
import 'web_page_metadata.dart';
import 'web_floating_notice_card.dart';
import 'web_navigation_sidebar.dart';
import 'weekly_report_screen.dart';
import 'text_formatting.dart';
import 'time_formatting.dart';

export 'medication_time_picker.dart';

final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
Future<void>? _googleSignInInitialization;

Future<void> signInWithGoogle(FirebaseAuth auth) async {
  if (kIsWeb) {
    final provider = GoogleAuthProvider();
    try {
      await auth.signInWithPopup(provider);
    } on FirebaseAuthException catch (error) {
      if (_normalizedAuthCode(error.code) != 'popup-blocked') rethrow;
      await auth.signInWithRedirect(provider);
    }
    return;
  }

  final initialization = _googleSignInInitialization ??= _googleSignIn
      .initialize();
  try {
    await initialization;
  } catch (_) {
    if (identical(_googleSignInInitialization, initialization)) {
      _googleSignInInitialization = null;
    }
    rethrow;
  }
  final googleUser = await _googleSignIn.authenticate();
  final googleAuth = googleUser.authentication;
  final credential = GoogleAuthProvider.credential(idToken: googleAuth.idToken);
  await auth.signInWithCredential(credential);
}

Future<void> signOut(FirebaseAuth auth) async {
  await auth.signOut();
  if (_googleSignInInitialization != null) {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      if (kDebugMode) {
        debugPrint('Google provider cleanup failed after Firebase sign-out.');
      }
    }
  }
}

enum FirebaseAuthAction {
  signIn,
  createAccount,
  googleSignIn,
  emailVerification,
}

String _normalizedAuthCode(String code) =>
    code.toLowerCase().replaceFirst('auth/', '').replaceAll('_', '-');

bool _isCanceledGoogleAuth(FirebaseAuthException error) {
  return const {
    'popup-closed-by-user',
    'cancelled-popup-request',
    'web-context-cancelled',
  }.contains(_normalizedAuthCode(error.code));
}

/// Converts Firebase's platform-specific codes into safe, actionable copy.
String firebaseAuthErrorMessage(
  FirebaseAuthException error, {
  required FirebaseAuthAction action,
}) {
  final code = _normalizedAuthCode(error.code);
  switch (code) {
    case 'invalid-email':
      return 'Enter a valid email address.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
    case 'invalid-login-credentials':
      return 'Incorrect email or password.';
    case 'email-already-in-use':
      return 'An account already exists for this email address.';
    case 'weak-password':
      return 'Use a stronger password with at least 8 characters.';
    case 'user-disabled':
      return 'This account has been disabled. Contact support for help.';
    case 'network-request-failed':
      return 'Unable to connect. Check your internet connection and try again.';
    case 'too-many-requests':
      return 'Too many attempts. Wait a moment before trying again.';
    case 'operation-not-allowed':
      return action == FirebaseAuthAction.googleSignIn
          ? 'Google sign-in is not enabled for Mediary.'
          : 'Email and password authentication is not enabled for Mediary.';
    case 'account-exists-with-different-credential':
      return 'An account already exists with a different sign-in method.';
    case 'credential-already-in-use':
      return 'This sign-in credential is already linked to another account.';
    case 'unauthorized-domain':
      return 'This web address is not authorized for Google sign-in.';
    case 'popup-blocked':
      return 'Your browser blocked Google sign-in. Allow pop-ups and try again.';
    case 'app-not-authorized':
    case 'invalid-api-key':
      return 'Mediary is not authorized to use its Firebase configuration.';
    case 'internal-error':
      return 'Authentication is temporarily unavailable. Please try again.';
    default:
      return switch (action) {
        FirebaseAuthAction.createAccount =>
          'Unable to create your account. Please try again.',
        FirebaseAuthAction.googleSignIn =>
          'Unable to sign in with Google. Please try again.',
        FirebaseAuthAction.emailVerification =>
          'Unable to verify your email right now. Please try again.',
        FirebaseAuthAction.signIn => 'Unable to sign in. Please try again.',
      };
  }
}

enum CameraAccessState {
  notRequested,
  requesting,
  granted,
  denied,
  permanentlyDenied,
  error,
}

typedef CameraPermissionRequester = Future<CameraAccessState> Function();

Future<CameraAccessState> requestCameraAccess() async {
  if (kIsWeb) {
    final granted = await requestWebCameraAccess();
    return granted ? CameraAccessState.granted : CameraAccessState.denied;
  }
  final status = await Permission.camera.request();
  if (status.isGranted) {
    return CameraAccessState.granted;
  }
  if (status.isPermanentlyDenied || status.isRestricted) {
    return CameraAccessState.permanentlyDenied;
  }
  return CameraAccessState.denied;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final FirebaseAuth _auth = FirebaseAuth.instance;
  ThemeMode _appearanceMode = ThemeMode.system;
  AppAccentColor _accentColor = AppAccentColor.blue;
  TimeDisplayFormat _timeDisplayFormat = TimeDisplayFormat.twelveHour;

  // Themes are expensive to build (ColorScheme.fromSeed + ~40 sub-themes).
  // Cache them so a setState for appearance/accent does not rebuild both
  // ThemeData trees on every frame of the theme transition.
  late ThemeData _lightTheme = AppTheme.lightFor(_accentColor);
  late ThemeData _darkTheme = AppTheme.darkFor(_accentColor);

  void _setAccentColor(AppAccentColor accent) {
    if (accent == _accentColor) return;
    setState(() {
      _accentColor = accent;
      _lightTheme = AppTheme.lightFor(accent);
      _darkTheme = AppTheme.darkFor(accent);
    });
  }

  bool get _reduceMotion => WidgetsBinding
      .instance
      .platformDispatcher
      .accessibilityFeatures
      .disableAnimations;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAccessibilityFeatures() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mediary',
      debugShowCheckedModeBanner: false,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: _appearanceMode,
      themeAnimationDuration: _reduceMotion
          ? Duration.zero
          : AppTheme.transitionDuration,
      themeAnimationCurve: AppTheme.transitionCurve,
      builder: (context, child) {
        return AppThemeTransitionSurface(
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: AuthGate(
        auth: _auth,
        appearanceMode: _appearanceMode,
        onAppearanceModeChanged: (mode) {
          setState(() => _appearanceMode = mode);
        },
        accentColor: _accentColor,
        onAccentColorChanged: _setAccentColor,
        timeDisplayFormat: _timeDisplayFormat,
        onTimeDisplayFormatChanged: (format) {
          setState(() => _timeDisplayFormat = format);
        },
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.auth,
    required this.appearanceMode,
    required this.onAppearanceModeChanged,
    required this.accentColor,
    required this.onAccentColorChanged,
    this.timeDisplayFormat = TimeDisplayFormat.twelveHour,
    this.onTimeDisplayFormatChanged,
  });

  final FirebaseAuth auth;
  final ThemeMode appearanceMode;
  final ValueChanged<ThemeMode> onAppearanceModeChanged;
  final AppAccentColor accentColor;
  final ValueChanged<AppAccentColor> onAccentColorChanged;
  final TimeDisplayFormat timeDisplayFormat;
  final ValueChanged<TimeDisplayFormat>? onTimeDisplayFormatChanged;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Stream<User?> _authStateChanges;
  User? _initialUser;
  bool _returningUser = false;
  String? _dataStoreStartingUid;
  String? _confirmedVerifiedUid;
  MediaryDataStore? _dataStore;

  @override
  void initState() {
    super.initState();
    _subscribeToAuth(widget.auth);
  }

  @override
  void didUpdateWidget(covariant AuthGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.auth, widget.auth)) {
      _subscribeToAuth(widget.auth);
    }
  }

  void _subscribeToAuth(FirebaseAuth auth) {
    _initialUser = auth.currentUser;
    _returningUser = _returningUser || _initialUser != null;
    _confirmedVerifiedUid = null;
    _authStateChanges = auth.userChanges();
  }

  void _syncDataStore(User? user) {
    if (user == null) {
      _dataStore?.dispose();
      _dataStore = null;
      _dataStoreStartingUid = null;
      return;
    }
    if (_dataStore?.userId == user.uid) return;
    if (_dataStoreStartingUid == user.uid) return;
    _dataStore?.dispose();
    final store = MediaryDataStore(
      repository: MediaryRepository(auth: widget.auth),
    );
    _dataStore = store;
    _dataStoreStartingUid = user.uid;
    unawaited(
      store.start(user).whenComplete(() {
        if (identical(_dataStore, store)) _dataStoreStartingUid = null;
      }),
    );
  }

  @override
  void dispose() {
    _dataStore?.dispose();
    super.dispose();
  }

  bool _requiresEmailVerification(User user) {
    if (user.emailVerified || _confirmedVerifiedUid == user.uid) return false;
    return user.providerData.any(
      (provider) => provider.providerId == EmailAuthProvider.PROVIDER_ID,
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsScreen(
          appearanceMode: widget.appearanceMode,
          onAppearanceModeChanged: widget.onAppearanceModeChanged,
          accentColor: widget.accentColor,
          onAccentColorChanged: widget.onAccentColorChanged,
          timeDisplayFormat: widget.timeDisplayFormat,
          onTimeDisplayFormatChanged: widget.onTimeDisplayFormatChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStateChanges,
      initialData: _initialUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const WebPageMetadata(
            title: 'Mediary',
            description:
                'Identify, organize, and track medications with Mediary.',
            child: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }

        final user = snapshot.data;
        if (user != null) {
          _returningUser = true;
          _syncDataStore(user);
          if (_requiresEmailVerification(user)) {
            return WebPageMetadata(
              title: 'Verify Your Email — Mediary',
              description: 'Verify your email to continue using Mediary.',
              child: EmailVerificationScreen(
                email: user.email ?? 'your email address',
                onResend: user.sendEmailVerification,
                onRefresh: () async {
                  await user.reload();
                  final refreshed = widget.auth.currentUser;
                  final verified = refreshed?.emailVerified ?? false;
                  if (verified && mounted) {
                    setState(() => _confirmedVerifiedUid = refreshed!.uid);
                  }
                  return verified;
                },
                onSignOut: () => signOut(widget.auth),
              ),
            );
          }
          return AuthenticatedHome(
            email: user.email ?? 'Signed-in user',
            displayName: user.displayName,
            photoUrl: user.photoURL,
            appearanceMode: widget.appearanceMode,
            onAppearanceModeChanged: widget.onAppearanceModeChanged,
            accentColor: widget.accentColor,
            onAccentColorChanged: widget.onAccentColorChanged,
            timeDisplayFormat: widget.timeDisplayFormat,
            onTimeDisplayFormatChanged: widget.onTimeDisplayFormatChanged,
            onSignOut: () => signOut(widget.auth),
            dataStore: _dataStore,
            cameraPermissionRequester: requestCameraAccess,
            onOpenCameraSettings: openAppSettings,
          );
        }

        _confirmedVerifiedUid = null;

        return WebPageMetadata(
          title: _returningUser
              ? 'Sign in — Mediary'
              : 'Create an Account — Mediary',
          description: _returningUser
              ? 'Sign in to manage your Mediary medication schedule.'
              : 'Create a Mediary account to organize and track medications.',
          child: AuthForm(
            initialCreateAccount: !_returningUser,
            onOpenSettings: () => _openSettings(context),
            onGoogleSignIn: () => signInWithGoogle(widget.auth),
            onSubmit:
                ({
                  required email,
                  required password,
                  required createAccount,
                }) async {
                  if (createAccount) {
                    final credential = await widget.auth
                        .createUserWithEmailAndPassword(
                          email: email,
                          password: password,
                        );
                    final newUser = credential.user;
                    if (newUser != null && !newUser.emailVerified) {
                      try {
                        await newUser.sendEmailVerification();
                      } on FirebaseAuthException {
                        // Account creation succeeded. The verification page lets
                        // the user safely retry delivery without creating a
                        // duplicate account.
                      }
                    }
                    return;
                  }

                  await widget.auth.signInWithEmailAndPassword(
                    email: email,
                    password: password,
                  );
                },
          ),
        );
      },
    );
  }
}

typedef AuthSubmitter = Future<void> Function({
  required String email,
  required String password,
  required bool createAccount,
});

typedef GoogleAuthSubmitter = Future<void> Function();

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.onResend,
    required this.onRefresh,
    required this.onSignOut,
  });

  final String email;
  final Future<void> Function() onResend;
  final Future<bool> Function() onRefresh;
  final Future<void> Function() onSignOut;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

enum _VerificationAction { resend, refresh, signOut }

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  _VerificationAction? _busyAction;
  String? _statusMessage;
  bool _statusIsError = false;

  bool get _isBusy => _busyAction != null;

  void _setStatus(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _statusIsError = isError;
    });
  }

  Future<void> _resend() async {
    if (_isBusy) return;
    unawaited(AppHaptics.primaryAction());
    setState(() {
      _busyAction = _VerificationAction.resend;
      _statusMessage = null;
    });
    try {
      await widget.onResend();
      _setStatus('Verification email sent. Check your inbox.');
    } on FirebaseAuthException catch (error) {
      _setStatus(
        firebaseAuthErrorMessage(
          error,
          action: FirebaseAuthAction.emailVerification,
        ),
        isError: true,
      );
    } catch (_) {
      _setStatus(
        'Unable to send a verification email. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  Future<void> _refresh() async {
    if (_isBusy) return;
    unawaited(AppHaptics.selection());
    setState(() {
      _busyAction = _VerificationAction.refresh;
      _statusMessage = null;
    });
    try {
      final verified = await widget.onRefresh();
      if (verified) {
        _setStatus('Email verified. Loading Mediary.');
      } else {
        _setStatus(
          'Your email is not verified yet. Open the link, then try again.',
        );
      }
    } on FirebaseAuthException catch (error) {
      _setStatus(
        firebaseAuthErrorMessage(
          error,
          action: FirebaseAuthAction.emailVerification,
        ),
        isError: true,
      );
    } catch (_) {
      _setStatus(
        'Unable to check verification status. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  Future<void> _signOut() async {
    if (_isBusy) return;
    unawaited(AppHaptics.selection());
    setState(() {
      _busyAction = _VerificationAction.signOut;
      _statusMessage = null;
    });
    try {
      await widget.onSignOut();
    } on FirebaseAuthException catch (error) {
      _setStatus(
        firebaseAuthErrorMessage(error, action: FirebaseAuthAction.signIn),
        isError: true,
      );
    } catch (_) {
      _setStatus('Unable to sign out. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      key: const Key('emailVerificationScreen'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.mark_email_unread_outlined,
                    color: colors.primary,
                    size: 52,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Verify Your Email',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Thank you for creating your Mediary account.',
                    key: Key('thankYouMessage'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Verify ${widget.email} before continuing to Mediary. '
                    'Use the link in your inbox, then return here.',
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(height: 1.45),
                  ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 20),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _statusMessage!,
                        key: const Key('emailVerificationStatus'),
                        style: TextStyle(
                          color: _statusIsError ? colors.error : colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  FilledButton(
                    key: const Key('refreshEmailVerificationButton'),
                    onPressed: _isBusy ? null : _refresh,
                    child: _busyAction == _VerificationAction.refresh
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('I Have Verified My Email'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: const Key('resendVerificationButton'),
                    onPressed: _isBusy ? null : _resend,
                    child: _busyAction == _VerificationAction.resend
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send a New Verification Email'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    key: const Key('verificationSignOutButton'),
                    onPressed: _isBusy ? null : _signOut,
                    child: _busyAction == _VerificationAction.signOut
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Use a Different Account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthForm extends StatefulWidget {
  const AuthForm({
    super.key,
    required this.onSubmit,
    this.onOpenSettings,
    this.onGoogleSignIn,
    this.initialCreateAccount = true,
  });

  final AuthSubmitter onSubmit;
  final VoidCallback? onOpenSettings;
  final GoogleAuthSubmitter? onGoogleSignIn;
  final bool initialCreateAccount;

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _confirmPasswordFocus = FocusNode();
  late bool _createAccount;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _isGoogleSubmitting = false;
  String? _errorMessage;

  bool get _isBusy => _isSubmitting || _isGoogleSubmitting;

  @override
  void initState() {
    super.initState();
    _createAccount = widget.initialCreateAccount;
  }

  @override
  void didUpdateWidget(covariant AuthForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCreateAccount != widget.initialCreateAccount &&
        !_isBusy) {
      _createAccount = widget.initialCreateAccount;
      _confirmPasswordController.clear();
      _errorMessage = null;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  void _clearStaleError(String _) {
    if (_errorMessage != null) setState(() => _errorMessage = null);
  }

  Future<void> _submit() async {
    if (_isBusy || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    unawaited(AppHaptics.primaryAction());
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.onSubmit(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        createAccount: _createAccount,
      );
      TextInput.finishAutofillContext();
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage = firebaseAuthErrorMessage(
            error,
            action: _createAccount
                ? FirebaseAuthAction.createAccount
                : FirebaseAuthAction.signIn,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'Something went wrong. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isBusy || widget.onGoogleSignIn == null) {
      return;
    }

    unawaited(AppHaptics.primaryAction());
    setState(() {
      _isGoogleSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.onGoogleSignIn!();
    } on GoogleSignInException catch (error) {
      if (mounted && error.code != GoogleSignInExceptionCode.canceled) {
        setState(() {
          _errorMessage = switch (error.code) {
            GoogleSignInExceptionCode.clientConfigurationError ||
            GoogleSignInExceptionCode.providerConfigurationError =>
              'Google sign-in is not configured correctly.',
            GoogleSignInExceptionCode.uiUnavailable =>
              'Google sign-in could not open. Please try again.',
            GoogleSignInExceptionCode.interrupted =>
              'Google sign-in was interrupted. Please try again.',
            _ => 'Unable to sign in with Google. Please try again.',
          };
        });
      }
    } on FirebaseAuthException catch (error) {
      if (mounted && !_isCanceledGoogleAuth(error)) {
        setState(
          () => _errorMessage = firebaseAuthErrorMessage(
            error,
            action: FirebaseAuthAction.googleSignIn,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage = 'Unable to sign in with Google. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleSubmitting = false);
      }
    }
  }

  void _changeMode() {
    unawaited(AppHaptics.selection());
    FocusScope.of(context).unfocus();
    setState(() {
      _createAccount = !_createAccount;
      _confirmPasswordController.clear();
      _errorMessage = null;
    });
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Email is required.';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Password is required.';
    }
    if (_createAccount && password.length < 8) {
      return 'Use at least 8 characters for a new password.';
    }
    if (!_createAccount && password.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    return null;
  }

  String? _validatePasswordConfirmation(String? value) {
    if (!_createAccount) return null;
    if ((value ?? '').isEmpty) return 'Confirm your password.';
    if (value != _passwordController.text) return 'Passwords do not match.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final title = _createAccount ? 'Create an Account' : 'Welcome Back';
    final action = _createAccount ? 'Create Account' : 'Sign In';
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final viewport = MediaQuery.sizeOf(context);
    final compactWeb = kIsWeb && viewport.width >= 900 && viewport.height < 800;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            key: const Key('settingsButton'),
            // Web tooltips render in an OverlayPortal. Removing this
            // transient overlay before pushing Settings avoids a Flutter
            // web overlay-size assertion while keeping the icon semantic
            // label below available to assistive technology.
            tooltip: kIsWeb ? null : 'Settings',
            onPressed: widget.onOpenSettings == null
                ? null
                : () {
                    unawaited(AppHaptics.selection());
                    widget.onOpenSettings!();
                  },
            icon: const Icon(
              Icons.settings_outlined,
              semanticLabel: 'Settings',
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/medication_auth_background.jpg',
            key: const Key('authMedicationBackground'),
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF07111D)
                  .withValues(alpha: isDark ? .80 : .66),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DecoratedBox(
                        key: const Key('authCredentialsCard'),
                        decoration: authPanelDecoration(theme),
                        child: Padding(
                          padding: EdgeInsets.all(compactWeb ? 20 : 24),
                          child: Theme(
                            data: theme.copyWith(
                              inputDecorationTheme: theme.inputDecorationTheme
                                  .copyWith(
                                    filled: true,
                                    fillColor: colors.surface.withValues(
                                      alpha: isDark ? .48 : .82,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: colors.outline,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: colors.outline,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: colors.primary,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                            ),
                            child: Form(
                              key: _formKey,
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                    size: compactWeb ? 32 : 48,
                                  ),
                                  SizedBox(height: compactWeb ? 12 : 24),
                                  Text(
                                    title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _createAccount
                                        ? 'Create your Mediary account.'
                                        : 'Sign in to Mediary.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge,
                                  ),
                                  SizedBox(height: compactWeb ? 16 : 32),
                                  TextFormField(
                                    key: const Key('emailField'),
                                    controller: _emailController,
                                    enabled: !_isBusy,
                                    autofillHints: const [AutofillHints.email],
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    onChanged: _clearStaleError,
                                    validator: _validateEmail,
                                    decoration: const InputDecoration(
                                      labelText: 'Email',
                                      prefixIcon: Icon(Icons.email_outlined),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    key: const Key('passwordField'),
                                    controller: _passwordController,
                                    enabled: !_isBusy,
                                    autofillHints: _createAccount
                                        ? const [AutofillHints.newPassword]
                                        : const [AutofillHints.password],
                                    obscureText: _obscurePassword,
                                    textInputAction: _createAccount
                                        ? TextInputAction.next
                                        : TextInputAction.done,
                                    onChanged: _clearStaleError,
                                    onFieldSubmitted: (_) => _createAccount
                                        ? _confirmPasswordFocus.requestFocus()
                                        : _submit(),
                                    validator: _validatePassword,
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      prefixIcon: const Icon(
                                        Icons.lock_outline,
                                      ),
                                      suffixIcon: IconButton(
                                        tooltip: _obscurePassword
                                            ? 'Show password'
                                            : 'Hide password',
                                        onPressed: _isBusy
                                            ? null
                                            : () {
                                                unawaited(
                                                  AppHaptics.selection(),
                                                );
                                                setState(
                                                  () => _obscurePassword =
                                                      !_obscurePassword,
                                                );
                                              },
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_createAccount) ...[
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      key: const Key('confirmPasswordField'),
                                      controller: _confirmPasswordController,
                                      focusNode: _confirmPasswordFocus,
                                      enabled: !_isBusy,
                                      autofillHints: const [
                                        AutofillHints.newPassword,
                                      ],
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.done,
                                      onChanged: _clearStaleError,
                                      onFieldSubmitted: (_) => _submit(),
                                      validator: _validatePasswordConfirmation,
                                      decoration: const InputDecoration(
                                        labelText: 'Confirm Password',
                                        prefixIcon: Icon(Icons.lock_outline),
                                      ),
                                    ),
                                  ],
                                  if (_errorMessage != null) ...[
                                    const SizedBox(height: 16),
                                    Semantics(
                                      liveRegion: true,
                                      child: Text(
                                        _errorMessage!,
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error,
                                        ),
                                      ),
                                    ),
                                  ],
                                  SizedBox(height: compactWeb ? 16 : 24),
                                  FilledButton(
                                    key: const Key('submitButton'),
                                    onPressed: _isBusy ? null : _submit,
                                    child: _isSubmitting
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(action),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    key: const Key('googleSignInButton'),
                                    onPressed:
                                        _isBusy || widget.onGoogleSignIn == null
                                        ? null
                                        : _signInWithGoogle,
                                    icon: _isGoogleSubmitting
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            'G',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                    label: const Text('Sign In with Google'),
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton(
                                    onPressed: _isBusy ? null : _changeMode,
                                    child: Text(
                                      _createAccount
                                          ? 'Already have an account? Sign In'
                                          : 'Need an account? Create One',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: compactWeb ? 12 : 20),
                      const LegalLinksFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthenticatedHome extends StatefulWidget {
  const AuthenticatedHome({
    super.key,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.onOpenSettings,
    this.appearanceMode = ThemeMode.system,
    this.onAppearanceModeChanged,
    this.accentColor = AppAccentColor.blue,
    this.onAccentColorChanged,
    this.timeDisplayFormat = TimeDisplayFormat.twelveHour,
    this.onTimeDisplayFormatChanged,
    this.onSignOut,
    this.dataStore,
    this.catalogClient,
    this.scanDetector,
    this.notificationService,
    this.now,
    this.cameraPermissionRequester,
    this.onOpenCameraSettings,
    this.useSidebarNavigation,
  });

  final String email;
  final String? displayName;
  final String? photoUrl;
  @Deprecated('Use the embedded Settings hub and Account route.')
  final VoidCallback? onOpenSettings;
  final ThemeMode appearanceMode;
  final ValueChanged<ThemeMode>? onAppearanceModeChanged;
  final AppAccentColor accentColor;
  final ValueChanged<AppAccentColor>? onAccentColorChanged;
  final TimeDisplayFormat timeDisplayFormat;
  final ValueChanged<TimeDisplayFormat>? onTimeDisplayFormatChanged;
  final Future<void> Function()? onSignOut;
  final MediaryDataStore? dataStore;
  final MedicationCatalogClient? catalogClient;
  final MedicationScanDetector? scanDetector;
  final MedicationNotificationService? notificationService;
  final DateTime? now;
  final CameraPermissionRequester? cameraPermissionRequester;
  final Future<bool> Function()? onOpenCameraSettings;

  /// Overrides adaptive navigation selection for previews and tests.
  /// Web uses the sidebar by default; native platforms use the bottom bar.
  final bool? useSidebarNavigation;

  @override
  State<AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

enum _ScanAlternative { choosePhoto, pasteImage }

class _AuthenticatedHomeState extends State<AuthenticatedHome>
    with WidgetsBindingObserver {
  late final MedicationCatalogClient _catalogClient =
      widget.catalogClient ?? RxNormMedicationCatalogClient();
  late final MedicationScanDetector _scanDetector =
      widget.scanDetector ?? const MedicationOcrDetector();
  late final MedicationNotificationService _notificationService =
      widget.notificationService ?? DefaultMedicationNotificationService();
  int _selectedIndex = 0;
  final Set<int> _visitedDestinations = {0};
  bool _showScanResult = false;
  MedicationScanResult? _scanResult;
  MedicationCatalogRecord? _scanMedication;
  String? _scanRecordId;
  DateTime? _calendarFocusDate;
  final List<CalendarDoseData> _pendingCalendarDoses = [];
  final Map<String, String> _pendingCalendarDoseMedicationIds = {};
  final Set<String> _cancelledDoseIds = <String>{};
  final Map<String, String> _pendingScheduleKeys = <String, String>{};
  CameraAccessState _cameraAccess = CameraAccessState.notRequested;
  String? _appliedPreferenceSignature;
  Timer? _notificationTimer;
  bool _notificationSyncInFlight = false;
  bool _notificationSyncRequested = false;
  final List<_MedicationToast> _webMedicationToasts = <_MedicationToast>[];
  final Map<String, Timer> _webMedicationToastTimers = <String, Timer>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.dataStore?.addListener(_onStoreChanged);
    if (widget.dataStore != null) {
      _startNotificationMonitoring();
    }
  }

  @override
  void didUpdateWidget(covariant AuthenticatedHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataStore != widget.dataStore) {
      oldWidget.dataStore?.removeListener(_onStoreChanged);
      widget.dataStore?.addListener(_onStoreChanged);
      _appliedPreferenceSignature = null;
      _cancelledDoseIds.clear();
      if (oldWidget.dataStore == null && widget.dataStore != null) {
        _startNotificationMonitoring();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.dataStore?.removeListener(_onStoreChanged);
    _notificationTimer?.cancel();
    for (final timer in _webMedicationToastTimers.values) {
      timer.cancel();
    }
    _webMedicationToastTimers.clear();
    if (widget.notificationService == null) {
      unawaited(_notificationService.dispose());
    }
    if (widget.catalogClient == null &&
        _catalogClient is RxNormMedicationCatalogClient) {
      _catalogClient.dispose();
    }
    super.dispose();
  }

  void _startNotificationMonitoring() {
    _notificationTimer ??= Timer.periodic(
      const Duration(seconds: 15),
      (_) => _syncMedicationNotifications(),
    );
    unawaited(() async {
      try {
        await _notificationService.initialize();
        await _notificationService.clearDeliveredNotifications();
        if (!kIsWeb) await _notificationService.requestPermission();
        await _syncMedicationNotifications();
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Medication notification setup failed: $error');
        }
      }
    }());
  }

  Future<void> _syncMedicationNotifications() async {
    final store = widget.dataStore;
    if (_notificationSyncInFlight) {
      _notificationSyncRequested = true;
      return;
    }
    // Wait for the complete authenticated snapshot before deciding which
    // native reminders should remain. The store starts empty while Firestore
    // listeners hydrate; syncing that transient state can consume the
    // notification service's initial-sync protection.
    if (store == null || !store.hasInitialData || !mounted) {
      return;
    }
    _notificationSyncInFlight = true;
    try {
      if (store.profile?.preferences.doseNotifications != true) {
        await _notificationService.syncDueDoses(
          doses: const <DoseLogRecord>[],
          medicationNames: const <String, String>{},
        );
        return;
      }
      final names = <String, String>{
        for (final medication in store.medications)
          medication.id: medication.name,
      };
      final activeMedicationIds = {
        for (final medication in store.medications)
          if (medication.active) medication.id,
      };
      final scheduleTimezones = <String, String>{
        for (final schedule in store.schedules) schedule.id: schedule.timezone,
      };
      final automaticScheduleOwners = {
        for (final schedule in store.schedules)
          if (schedule.active &&
              activeMedicationIds.contains(schedule.medicationId) &&
              schedule.frequency != 'asNeeded')
            schedule.id: schedule.medicationId,
      };
      final due = await _notificationService.syncDueDoses(
        doses: [
          for (final dose in uniqueDoseOccurrences(store.doseLogs))
            if (activeMedicationIds.contains(dose.medicationId) &&
                automaticScheduleOwners[dose.scheduleId] == dose.medicationId &&
                !_cancelledDoseIds.contains(dose.id))
              dose,
        ],
        medicationNames: names,
        scheduleTimezones: scheduleTimezones,
        now: DateTime.now(),
      );
      if (kIsWeb && mounted) {
        for (final notification in due) {
          _showWebMedicationToast(notification);
        }
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Medication notification sync failed: $error');
      }
    } finally {
      _notificationSyncInFlight = false;
      if (_notificationSyncRequested && mounted) {
        _notificationSyncRequested = false;
        unawaited(_syncMedicationNotifications());
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    for (final timer in _webMedicationToastTimers.values) {
      timer.cancel();
    }
    _webMedicationToastTimers.clear();
    if (mounted) setState(_webMedicationToasts.clear);
    unawaited(() async {
      try {
        await _notificationService.clearDeliveredNotifications();
        await _syncMedicationNotifications();
      } catch (error) {
        if (kDebugMode) debugPrint('Reminder cleanup failed: $error');
      }
    }());
  }

  Future<void> _sendTestMedicationNotification() async {
    await _notificationService.sendTestNotification();
  }

  void _requestMedicationNotificationPermission() {
    if (!kIsWeb) return;
    unawaited(
      _notificationService.requestPermission().catchError((_) {
        // The in-app reminder remains available if the browser blocks the
        // permission request outside a user gesture.
      }),
    );
  }

  void _showWebMedicationToast(MedicationDueNotification notification) {
    final toastKey = _webMedicationToastKey(notification);
    if (!mounted || _webMedicationToasts.isNotEmpty) {
      return;
    }
    final toast = _MedicationToast(notification, toastKey);
    setState(() {
      _webMedicationToasts.add(toast);
    });
    _webMedicationToastTimers[toastKey] = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() {
        _webMedicationToasts.removeWhere((item) => item.key == toastKey);
      });
      _webMedicationToastTimers.remove(toastKey);
    });
  }

  String _webMedicationToastKey(MedicationDueNotification notification) {
    final scheduled = notification.scheduledFor;
    final medication = notification.medicationName.trim().toLowerCase();
    return '$medication|${scheduled.year}-${scheduled.month}-'
        '${scheduled.day}-${scheduled.hour}-${scheduled.minute}';
  }

  void _onStoreChanged() {
    final store = widget.dataStore;
    if (store != null) {
      final activeMedicationIds = {
        for (final medication in store.medications)
          if (medication.active) medication.id,
      };
      _pendingScheduleKeys.removeWhere(
        (_, medicationId) => !activeMedicationIds.contains(medicationId),
      );
      final persistedOccurrenceIds = {
        for (final dose in store.doseLogs)
          ScheduleOccurrenceGenerator.deterministicOccurrenceId(
            dose.scheduleId,
            localDate: dose.localDate,
            localTime: dose.localTime,
          ),
      };
      final stalePendingDoseIds = _pendingCalendarDoseMedicationIds.entries
          .where(
            (entry) =>
                !activeMedicationIds.contains(entry.value) ||
                persistedOccurrenceIds.contains(entry.key),
          )
          .map((entry) => entry.key)
          .toSet();
      if (stalePendingDoseIds.isNotEmpty) {
        _pendingCalendarDoses.removeWhere(
          (dose) => stalePendingDoseIds.contains(dose.id),
        );
        _pendingCalendarDoseMedicationIds.removeWhere(
          (doseId, _) => stalePendingDoseIds.contains(doseId),
        );
      }
      if (_webMedicationToasts.isNotEmpty) {
        final activeScheduleIds = {
          for (final schedule in store.schedules)
            if (schedule.active &&
                schedule.frequency != 'asNeeded' &&
                activeMedicationIds.contains(schedule.medicationId))
              schedule.id,
        };
        final activeDoseIds = {
          for (final dose in store.doseLogs)
            if (activeMedicationIds.contains(dose.medicationId) &&
                activeScheduleIds.contains(dose.scheduleId) &&
                dose.status == 'due')
              dose.id,
        };
        final staleToastKeys = _webMedicationToasts
            .where(
              (toast) => !activeDoseIds.contains(toast.notification.doseId),
            )
            .map((toast) => toast.key)
            .toSet();
        if (staleToastKeys.isNotEmpty) {
          _webMedicationToasts.removeWhere(
            (toast) => staleToastKeys.contains(toast.key),
          );
          for (final key in staleToastKeys) {
            _webMedicationToastTimers.remove(key)?.cancel();
          }
        }
      }
    }
    unawaited(_syncMedicationNotifications());
    final preferences = widget.dataStore?.profile?.preferences;
    if (preferences == null) {
      if (mounted) setState(() {});
      return;
    }
    final signature = [
      preferences.theme,
      preferences.accentColor,
      preferences.timeFormat,
    ].join('|');
    if (signature != _appliedPreferenceSignature) {
      _appliedPreferenceSignature = signature;
      final mode = switch (preferences.theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      final accent = AppAccentColor.values.firstWhere(
        (value) => value.name == preferences.accentColor,
        orElse: () => AppAccentColor.blue,
      );
      final timeFormat = TimeDisplayFormat.fromPreference(
        preferences.timeFormat,
      );
      widget.onAppearanceModeChanged?.call(mode);
      widget.onAccentColorChanged?.call(accent);
      widget.onTimeDisplayFormatChanged?.call(timeFormat);
    }
    if (mounted) setState(() {});
  }

  Future<void> _updateDoseStatus(
    String doseId,
    String status, {
    DateTime? snoozedUntil,
  }) async {
    final store = widget.dataStore;
    if (store == null) return;

    final cancelling = status == 'cancelled';
    final wasCancelled = _cancelledDoseIds.contains(doseId);
    if (mounted) {
      setState(() {
        if (cancelling) {
          _cancelledDoseIds.add(doseId);
        } else {
          _cancelledDoseIds.remove(doseId);
        }
      });
    }
    try {
      await store.updateDoseStatus(
        doseId,
        status,
        takenAt: status == 'taken' ? DateTime.now() : null,
        snoozedUntil: snoozedUntil,
      );
      if (status != 'due') {
        try {
          await _notificationService.cancelDose(doseId);
        } catch (notificationError) {
          if (kDebugMode) {
            debugPrint('Dose reminder cancellation failed: $notificationError');
          }
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          if (wasCancelled) {
            _cancelledDoseIds.add(doseId);
          } else {
            _cancelledDoseIds.remove(doseId);
          }
        });
      }
      rethrow;
    }
  }

  Future<void> _removeMedicationAndClearReminders(String medicationId) async {
    final store = widget.dataStore;
    if (store == null) return;
    final relatedIds = await store.removeMedicationAndGetRelatedIds(
      medicationId,
    );
    _pendingCalendarDoses.removeWhere((dose) => relatedIds.contains(dose.id));
    _pendingCalendarDoseMedicationIds.removeWhere(
      (doseId, _) => relatedIds.contains(doseId),
    );
    _pendingScheduleKeys.removeWhere((_, id) => id == medicationId);
    for (final id in relatedIds) {
      try {
        await _notificationService.cancelDose(id);
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Deleted medication reminder cancellation failed: $error');
        }
      }
    }
    if (mounted) setState(() {});
  }

  bool get _usesSidebarNavigation => widget.useSidebarNavigation ?? kIsWeb;

  void _selectDestination(int index) {
    setState(() {
      _selectedIndex = index;
      _visitedDestinations.add(index);
      if (index == 2) _showScanResult = false;
    });
    if (index == 2 && _cameraAccess == CameraAccessState.notRequested) {
      _requestCameraAccess();
    }
  }

  Future<void> _requestCameraAccess() async {
    if (_cameraAccess == CameraAccessState.requesting) {
      return;
    }

    setState(() => _cameraAccess = CameraAccessState.requesting);
    CameraAccessState result;
    try {
      final requester = widget.cameraPermissionRequester ?? requestCameraAccess;
      result = await requester();
    } catch (_) {
      result = CameraAccessState.error;
    }
    if (!mounted) return;
    setState(() => _cameraAccess = result);
    if (result != CameraAccessState.granted) {
      await _showCameraAlternatives();
    }
  }

  Future<void> _showCameraAlternatives() async {
    if (!mounted) return;
    final choice = await showDialog<_ScanAlternative>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Camera access unavailable'),
        content: const Text(
          'You can still identify a medication by choosing a photo or pasting '
          'an image from your clipboard.',
        ),
        actions: [
          TextButton(
            key: const Key('cameraAlternativeCancelButton'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('cameraAlternativeChoosePhotoButton'),
            onPressed: () =>
                Navigator.of(dialogContext).pop(_ScanAlternative.choosePhoto),
            child: const Text('Choose photo'),
          ),
          TextButton(
            key: const Key('cameraAlternativePasteButton'),
            onPressed: () =>
                Navigator.of(dialogContext).pop(_ScanAlternative.pasteImage),
            child: const Text('Paste image'),
          ),
          FilledButton(
            key: const Key('cameraAlternativeOkButton'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case _ScanAlternative.choosePhoto:
        await _chooseMedicationPhoto();
      case _ScanAlternative.pasteImage:
        await _pasteMedicationPhoto();
      case null:
        break;
    }
  }

  Future<void> _showScanAccessDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            key: const Key('scanAccessCancelButton'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('scanAccessOkButton'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    final store = widget.dataStore;
    final profilePhotoUrl = store?.profile?.photoUrl ?? widget.photoUrl;
    final series = _reportSeries(store);
    return DashboardScreen(
      email: store?.profile?.email ?? widget.email,
      displayName: store?.profile?.displayName ?? widget.displayName,
      photoUrl: profilePhotoUrl,
      now: widget.now,
      bottomPadding: _usesSidebarNavigation ? 32 : 120,
      initialDoses: _dashboardDoses(store),
      weeklyTaken: series.taken.reduce((a, b) => a + b),
      weeklyScheduled: series.scheduled.reduce((a, b) => a + b),
      onOpenCalendar: () => _selectDestination(1),
      onDoseStatusChanged: store == null ? null : _updateDoseStatus,
      onRemoveMedication: store == null
          ? null
          : _removeMedicationAndClearReminders,
      onViewReport: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => WeeklyReportScreen(
              weekEnding: widget.now,
              dailyTaken: _reportSeries(store).taken,
              dailyScheduled: _reportSeries(store).scheduled,
              timingOffsetsMinutes: _reportSeries(store).offsets,
              dailySkipped: _reportSeries(store).skipped,
              onSaveReport: store == null
                  ? null
                  : (report) => store.saveReport(report),
            ),
          ),
        );
      },
      onOpenAccount: () => _openAccount(context),
    );
  }

  Future<MedicationCatalogRecord> _catalogDetailsFor(
    MedicationOption medication,
  ) async {
    try {
      return await _catalogClient.getDetails(medication.id);
    } catch (_) {
      return medication.toCatalogRecord();
    }
  }

  ({List<int> taken, List<int> scheduled, List<int> offsets, List<int> skipped})
  _reportSeries(MediaryDataStore? store) {
    final ending = DateUtils.dateOnly(widget.now ?? DateTime.now());
    final start = ending.subtract(const Duration(days: 6));
    final taken = List<int>.filled(7, 0);
    final scheduled = List<int>.filled(7, 0);
    final offsets = List<int>.filled(7, 0);
    final skipped = List<int>.filled(7, 0);
    for (final dose in _visibleDoseLogs(store)) {
      final date = DateUtils.dateOnly(dose.scheduledFor);
      final index = date.difference(start).inDays;
      if (index < 0 || index > 6 || dose.status == 'cancelled') continue;
      scheduled[index]++;
      if (dose.status == 'skipped') skipped[index]++;
      if (dose.status == 'taken') {
        taken[index]++;
        if (dose.takenAt != null) {
          offsets[index] += dose.takenAt!
              .difference(dose.scheduledFor)
              .inMinutes;
        }
      }
    }
    return (
      taken: taken,
      scheduled: scheduled,
      offsets: offsets,
      skipped: skipped,
    );
  }

  List<DashboardDoseData> _dashboardDoses(MediaryDataStore? store) {
    if (store == null) return const [];
    final todayKey = _dateKey(DateUtils.dateOnly(widget.now ?? DateTime.now()));
    final medications = {
      for (final medication in store.medications) medication.id: medication,
    };
    final doses =
        _visibleDoseLogs(store)
            .where(
              (dose) =>
                  dose.status != 'cancelled' && dose.localDate == todayKey,
            )
            .toList()
          ..sort(
            (first, second) =>
                first.scheduledFor.compareTo(second.scheduledFor),
          );
    return [
      for (final dose in doses.take(12))
        DashboardDoseData(
          id: dose.id,
          medicationId: dose.medicationId,
          name: medications[dose.medicationId]?.name ?? 'Medication',
          details: [
            if (medications[dose.medicationId]?.strength.isNotEmpty ?? false)
              medications[dose.medicationId]!.strength,
            if (dose.localDate.isNotEmpty || dose.localTime.isNotEmpty)
              [
                if (dose.localDate.isNotEmpty) formatLocalDate(dose.localDate),
                if (dose.localTime.isNotEmpty)
                  formatLocalTime(dose.localTime, widget.timeDisplayFormat),
              ].join(' · '),
          ].join(' · '),
          status: dose.status,
          snoozedUntil: dose.snoozedUntil,
        ),
    ];
  }

  Widget _buildLibrary(BuildContext context) {
    final store = widget.dataStore;
    return MedicationLibraryScreen(
      catalogClient: _catalogClient,
      bottomPadding: _usesSidebarNavigation ? 32 : 128,
      initialSavedMedicationIds: {
        if (store != null) ...store.savedMedications.map((item) => item.id),
      },
      onSavedChanged: store == null
          ? null
          : (medicationId, saved, {catalogVersion}) async {
              if (saved) {
                await store.saveLibraryMedication(
                  id: medicationId,
                  catalogId: medicationId,
                  catalogSource: 'rxnorm',
                  catalogVersion: catalogVersion,
                );
              } else {
                await store.unsaveLibraryMedication(medicationId);
              }
            },
    );
  }

  void _openAccount(BuildContext context) {
    final legacyAccountAction = widget.onOpenSettings;
    if (legacyAccountAction != null) {
      legacyAccountAction();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (accountContext) => ListenableBuilder(
          listenable: widget.dataStore ?? const AlwaysStoppedAnimation(0),
          builder: (context, child) => ProfileScreen(
            email: widget.dataStore?.profile?.email ?? widget.email,
            displayName:
                widget.dataStore?.profile?.displayName ?? widget.displayName,
            photoUrl: widget.dataStore?.profile?.photoUrl ?? widget.photoUrl,
            initialBloodType: widget.dataStore?.profile?.bloodType,
            initialAllergies: widget.dataStore?.profile?.allergies,
            initialCareTeam: widget.dataStore?.profile?.careTeam,
            activeMedicationCount:
                widget.dataStore?.medications
                    .where((medication) => medication.active)
                    .length ??
                0,
            activeMedicationNames:
                widget.dataStore?.medications
                    .where((medication) => medication.active)
                    .map((medication) => medication.name)
                    .toList(growable: false) ??
                const [],
            activeMedications:
                widget.dataStore?.medications
                    .where((medication) => medication.active)
                    .toList(growable: false) ??
                const [],
            onRemoveMedication: widget.dataStore == null
                ? null
                : _removeMedicationAndClearReminders,
            pageTitle: 'Account',
            onBack: () => Navigator.of(accountContext).maybePop(),
            onOpenLibrary: () {
              Navigator.of(accountContext).pop();
              if (mounted) setState(() => _selectedIndex = 3);
            },
            onSignOut: widget.onSignOut,
            onSave: widget.dataStore == null
                ? null
                : (draft) => widget.dataStore!.saveProfile(
                    ProfileWrite(
                      displayName: draft.name,
                      email: draft.email,
                      bloodType: draft.bloodType,
                      allergies: draft.allergies,
                      careTeam: draft.careTeam,
                      photoUrl: draft.photoUrl,
                    ),
                  ),
            bottomPadding: 32,
          ),
        ),
      ),
    );
  }

  Widget _buildSettings(BuildContext context) {
    final profilePhotoUrl =
        widget.dataStore?.profile?.photoUrl ?? widget.photoUrl;
    return SettingsScreen(
      embedded: true,
      appearanceMode: widget.appearanceMode,
      onAppearanceModeChanged: widget.onAppearanceModeChanged ?? (_) {},
      accentColor: widget.accentColor,
      onAccentColorChanged: widget.onAccentColorChanged ?? (_) {},
      timeDisplayFormat: widget.timeDisplayFormat,
      onTimeDisplayFormatChanged: widget.onTimeDisplayFormatChanged,
      onSendTestNotification: widget.dataStore == null
          ? null
          : _sendTestMedicationNotification,
      onReadNotificationPermission: widget.dataStore == null
          ? null
          : _notificationService.permissionState,
      accountEmail: widget.dataStore?.profile?.email ?? widget.email,
      accountDisplayName:
          widget.dataStore?.profile?.displayName ?? widget.displayName,
      accountPhotoUrl: profilePhotoUrl,
      onPreferenceChanged: (key, value) async {
        if (key == 'doseNotifications' && value == true) {
          await _notificationService.requestPermission();
        }
        await widget.dataStore?.updatePreference(key, value);
      },
      initialPreferences: widget.dataStore?.profile?.preferences,
      onOpenAccount: () => _openAccount(context),
      bottomPadding: _usesSidebarNavigation ? 32 : 120,
    );
  }

  Widget _buildScanner(BuildContext context) {
    final store = widget.dataStore;
    if (_showScanResult) {
      return ScanResultScreen(
        onBack: () => setState(() => _showScanResult = false),
        onScanAgain: _resetScan,
        onScanReady: store?.saveScan,
        scanRecordId: _scanRecordId,
        scanResult: _scanResult,
        medication: _scanMedication,
        onScheduleConfirmed: store == null ? null : _commitScanSchedule,
        onSearchMedication: () => _openMedicationSearchFromScan(context),
        timeDisplayFormat: widget.timeDisplayFormat,
        scheduledTimezone: preferredScheduleTimezone(store?.profile?.timezone),
        bottomNavigationInset: _usesSidebarNavigation ? 16 : 106,
      );
    }

    return MedicationScannerScreen(
      accessState: switch (_cameraAccess) {
        CameraAccessState.notRequested => ScannerAccessState.notRequested,
        CameraAccessState.requesting => ScannerAccessState.requesting,
        CameraAccessState.granted => ScannerAccessState.granted,
        CameraAccessState.denied => ScannerAccessState.denied,
        CameraAccessState.permanentlyDenied =>
          ScannerAccessState.permanentlyDenied,
        CameraAccessState.error => ScannerAccessState.error,
      },
      onRequestAccess: _requestCameraAccess,
      onUseOtherScanOptions: _showCameraAlternatives,
      onCapture: _runMedicationScan,
      onChoosePhoto: _chooseMedicationPhoto,
      onOpenSettings: widget.onOpenCameraSettings ?? openAppSettings,
      isActive: _selectedIndex == 2,
      bottomNavigationInset: _usesSidebarNavigation ? 16 : 112,
    );
  }

  void _resetScan() {
    setState(() {
      _showScanResult = false;
      _scanResult = null;
      _scanMedication = null;
      _scanRecordId = null;
    });
  }

  Future<void> _runMedicationScan() async {
    await _runMedicationScanRequest(const MedicationScanRequest.sample());
  }

  Future<void> _chooseMedicationPhoto() async {
    try {
      final picked = await pickMedicationPhoto();
      if (picked == null) return;
      await _runMedicationScanRequest(
        MedicationScanRequest.fromImage(
          imageBytes: picked.bytes,
          fileName: picked.fileName,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _scanRecordId = null;
        _scanResult = const MedicationScanResult(
          imageUrl: '',
          extractedText: '',
          detectedMedicationName: '',
          confidence: 0,
          errorMessage:
              'Unable to open that image. Please choose another photo.',
        );
        _scanMedication = null;
        _showScanResult = true;
      });
    }
  }

  Future<void> _pasteMedicationPhoto() async {
    try {
      final pasted = await pasteMedicationPhoto();
      if (pasted == null) {
        if (!mounted) return;
        await _showScanAccessDialog(
          title: 'Clipboard image unavailable',
          message:
              'No image was found in the clipboard. Copy a medication photo '
              'and try again.',
        );
        return;
      }
      await _runMedicationScanRequest(
        MedicationScanRequest.fromImage(
          imageBytes: pasted.bytes,
          fileName: pasted.fileName,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      await _showScanAccessDialog(
        title: 'Clipboard access unavailable',
        message:
            'Mediary could not read the clipboard. Allow clipboard access '
            'and try again, or choose a photo instead.',
      );
    }
  }

  Future<void> _runMedicationScanRequest(MedicationScanRequest request) async {
    final store = widget.dataStore;
    String? scanRecordId;
    if (store != null) {
      try {
        scanRecordId = await store.saveScan(
          const ScanWrite(
            status: 'processing',
            detectedMedicationName: '',
            extractedText: '',
            confidence: 0,
          ),
        );
      } catch (_) {
        // The review flow remains useful when the scan metadata write fails.
      }
    }

    MedicationScanResult result;
    try {
      result = await _scanDetector.detect(request);
    } catch (error) {
      result = MedicationScanResult(
        imageUrl: request.imageUrl,
        imageBytes: request.imageBytes,
        extractedText: '',
        detectedMedicationName: '',
        confidence: 0,
        errorMessage:
            'Unable to analyze this medication image. Please try again.',
      );
    }

    MedicationCatalogRecord? medication;
    if (!result.hasError) {
      medication = await _resolveScanMedication(result.detectedMedicationName);
    }

    if (!mounted) return;
    setState(() {
      _scanRecordId = scanRecordId;
      _scanResult = result;
      _scanMedication = medication;
      _showScanResult = true;
    });
  }

  Future<MedicationCatalogRecord?> _resolveScanMedication(String name) async {
    final query = name.trim();
    if (query.isEmpty) return null;
    try {
      final page = await _catalogClient.search(query);
      if (page.items.isEmpty) return null;
      MedicationCatalogRecord? candidate = matchMedicationCatalogRecord(
        query,
        page.items,
      );
      // RxNorm often returns a list of strength/form variants. Any result
      // returned for the scan's generic name is a better review target than
      // incorrectly reporting that the medication was not found.
      candidate ??= page.items.length == 1 ? page.items.first : null;
      if (candidate == null) return null;
      try {
        return await _catalogClient.getDetails(candidate.rxcui);
      } catch (_) {
        return candidate;
      }
    } catch (_) {
      return null;
    }
  }

  void _openMedicationSearchFromScan(BuildContext context) {
    final initialQuery = _scanResult?.detectedMedicationName.trim() ?? '';
    unawaited(
      pushInAppPage<void>(
        context,
        builder: (_) => MedicationLibraryScreen(
          catalogClient: _catalogClient,
          initialQuery: initialQuery,
          onBack: () => Navigator.of(context).maybePop(),
          bottomPadding: 32,
        ),
      ),
    );
  }

  Future<bool> _commitScanSchedule(ScanScheduleData schedule) async {
    final store = widget.dataStore;
    final catalog = _scanMedication;
    if (store == null || catalog == null) {
      throw StateError('A confirmed medication is required before scheduling.');
    }

    final existingMedication = _existingMedicationFor(store, catalog.rxcui);
    final medicationId =
        existingMedication?.id ?? _catalogMedicationId(catalog.rxcui);
    final doseAmount = _scanDoseAmount(schedule.dose);
    final doseUnit = _scanDoseUnit(schedule.dose, catalog);
    final frequency = _scanFrequency(schedule.frequency);
    final localDate = _dateKey(schedule.startDate);
    final localTime = schedule.time.localTime;
    final scheduleTimezone = preferredScheduleTimezone(store.profile?.timezone);
    final scheduleId = _scheduleId(
      catalog.rxcui,
      localDate: localDate,
      localTime: localTime,
      frequency: frequency,
      doseAmount: doseAmount,
    );
    final endDate = _scanEndDate(schedule.startDate, schedule.duration);
    final doseId = ScheduleOccurrenceGenerator.deterministicOccurrenceId(
      scheduleId,
      localDate: localDate,
      localTime: localTime,
    );
    final scheduledFor = medicationScheduledDate(
      schedule.startDate,
      schedule.time,
      scheduleTimezone,
    );

    if (_isDuplicateSchedule(
      store,
      catalogId: catalog.rxcui,
      medicationId: medicationId,
      doseAmount: doseAmount,
      doseUnit: doseUnit,
      localTime: localTime,
    )) {
      await _showDuplicateScheduleDialog();
      return false;
    }

    await store.commitScheduleAndDose(
      medication: MedicationWrite(
        id: medicationId,
        name: existingMedication?.name ?? catalog.name,
        genericName: existingMedication?.genericName ?? catalog.genericName,
        strength: existingMedication?.strength ?? catalog.strength,
        form: existingMedication?.form ?? catalog.form,
        route: existingMedication?.route ?? catalog.route,
        instructions: existingMedication?.instructions ?? '',
        prescriber: existingMedication?.prescriber ?? '',
        pharmacy: existingMedication?.pharmacy ?? '',
        notes: existingMedication?.notes ?? '',
        active: existingMedication?.active ?? true,
        catalogId: catalog.rxcui,
        catalogSource: 'rxnorm',
        catalogVersion: catalog.sourceVersion,
        source: 'scanner',
      ),
      schedule: ScheduleWrite(
        id: scheduleId,
        medicationId: medicationId,
        doseAmount: doseAmount,
        doseUnit: doseUnit,
        times: [localTime],
        frequency: frequency,
        daysOfWeek: frequency == 'weekly'
            ? [schedule.startDate.weekday]
            : const <int>[],
        startDate: localDate,
        endDate: endDate,
        timezone: scheduleTimezone,
        instructions: 'Confirmed from scanned medication label.',
      ),
      dose: frequency == 'asNeeded'
          ? null
          : DoseWrite(
              id: doseId,
              medicationId: medicationId,
              scheduleId: scheduleId,
              scheduledFor: scheduledFor,
              localDate: localDate,
              localTime: localTime,
            ),
    );

    if (frequency != 'asNeeded') {
      _requestMedicationNotificationPermission();
    }

    final calendarDose = CalendarDoseData(
      id: doseId,
      localDate: localDate,
      name: existingMedication?.name ?? catalog.name,
      details: [
        if ((existingMedication?.strength ?? catalog.strength).isNotEmpty)
          existingMedication?.strength ?? catalog.strength,
        formatLocalTime(localTime, widget.timeDisplayFormat),
      ].join(' · '),
      status: 'due',
    );
    if (mounted && frequency != 'asNeeded') {
      setState(() {
        _cancelledDoseIds.remove(doseId);
        _calendarFocusDate = schedule.startDate;
        _pendingCalendarDoses.removeWhere((dose) => dose.id == doseId);
        _pendingCalendarDoses.add(calendarDose);
        _pendingCalendarDoseMedicationIds[doseId] = medicationId;
        _pendingScheduleKeys[_scanScheduleKey(
              catalogId: catalog.rxcui,
              doseAmount: doseAmount,
              doseUnit: doseUnit,
              localTime: localTime,
            )] =
            medicationId;
      });
    }
    return true;
  }

  Future<void> _showDuplicateScheduleDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Duplicate medication'),
        content: const Text(
          'This medication already has the same dose and time on your '
          'calendar. Duplicate medications are not allowed.',
        ),
        actions: [
          TextButton(
            key: const Key('duplicateMedicationCancelButton'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('duplicateMedicationOkButton'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  bool _isDuplicateSchedule(
    MediaryDataStore store, {
    required String catalogId,
    required String medicationId,
    required double doseAmount,
    required String doseUnit,
    required String localTime,
  }) {
    final key = _scanScheduleKey(
      catalogId: catalogId,
      doseAmount: doseAmount,
      doseUnit: doseUnit,
      localTime: localTime,
    );
    if (_pendingScheduleKeys.containsKey(key)) return true;

    final medicationIds = <String>{
      medicationId,
      _catalogMedicationId(catalogId),
    };
    medicationIds.addAll(
      store.medications
          .where((medication) => medication.catalogId == catalogId)
          .map((medication) => medication.id),
    );
    final normalizedUnit = _normalizeDoseUnit(doseUnit);
    return store.schedules.any(
      (schedule) =>
          schedule.active &&
          medicationIds.contains(schedule.medicationId) &&
          (schedule.doseAmount - doseAmount).abs() < 0.0001 &&
          _normalizeDoseUnit(schedule.doseUnit) == normalizedUnit &&
          schedule.times.any(
            (time) =>
                MedicationTime.fromLocalTime(time).localTime ==
                MedicationTime.fromLocalTime(localTime).localTime,
          ),
    );
  }

  String _scanScheduleKey({
    required String catalogId,
    required double doseAmount,
    required String doseUnit,
    required String localTime,
  }) =>
      '$catalogId|${doseAmount.toStringAsFixed(4)}|${_normalizeDoseUnit(doseUnit)}|${MedicationTime.fromLocalTime(localTime).localTime}';

  String _normalizeDoseUnit(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.endsWith('s') && normalized.length > 1) {
      return normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  double _scanDoseAmount(String dose) {
    final normalized = dose.replaceAll('½', '0.5');
    final match = RegExp(r'\d+(?:\.\d+)?').firstMatch(normalized);
    return double.tryParse(match?.group(0) ?? '') ?? 1;
  }

  String _scanDoseUnit(String dose, MedicationCatalogRecord catalog) {
    final normalized = dose
        .replaceAll('½', '')
        .replaceAll(RegExp(r'\d+(?:\.\d+)?'), '')
        .trim()
        .toLowerCase();
    if (normalized.isNotEmpty) {
      final firstWord = normalized.split(RegExp(r'\s+')).first;
      return firstWord.endsWith('s') && firstWord.length > 1
          ? firstWord.substring(0, firstWord.length - 1)
          : firstWord;
    }
    return catalog.form.trim().toLowerCase().isEmpty
        ? 'dose'
        : catalog.form.trim().toLowerCase();
  }

  String _scanFrequency(String label) => switch (label) {
    'No Repeat' => 'once',
    'Once daily' => 'daily',
    'Every 8 hours' => 'every8Hours',
    'Every 12 hours' => 'every12Hours',
    'As needed' => 'asNeeded',
    _ => 'once',
  };

  String? _scanEndDate(DateTime startDate, String duration) {
    final match = RegExp(r'\d+').firstMatch(duration);
    final days = int.tryParse(match?.group(0) ?? '');
    if (days == null || days < 1) return null;
    return _dateKey(startDate.add(Duration(days: days - 1)));
  }

  Widget _buildCalendar(BuildContext context) {
    final store = widget.dataStore;
    return CalendarScreen(
      initialDate: _calendarFocusDate ?? widget.now,
      bottomPadding: _usesSidebarNavigation ? 32 : 120,
      initialDoses: _calendarDoses(store),
      onDoseStatusChanged: store == null ? null : _updateDoseStatus,
      onAddDose: store == null
          ? null
          : (date) async {
              final selections = await showAddMedicationScreen(
                context,
                catalogClient: _catalogClient,
              );
              if (selections == null || selections.isEmpty || !mounted) {
                return const <CalendarDoseData>[];
              }
              if (!context.mounted) return const <CalendarDoseData>[];
              final scheduleDraft = await _showScheduleDetails(
                context,
                initialTimezone: preferredScheduleTimezone(
                  store.profile?.timezone,
                ),
                scheduleDate: date,
              );
              if (scheduleDraft == null || !mounted) {
                return const <CalendarDoseData>[];
              }
              final time = scheduleDraft.time;
              final selectedDate = scheduleDraft.date;
              final scheduledFor = medicationScheduledDate(
                selectedDate,
                time,
                scheduleDraft.timezone,
              );
              final localDate = _dateKey(selectedDate);
              final localTime = time.localTime;
              final addedDoses = <CalendarDoseData>[];
              for (final medication in selections) {
                final catalog = await _catalogDetailsFor(medication);
                final existingMedication = _existingMedicationFor(
                  store,
                  catalog.rxcui,
                );
                final medicationId =
                    existingMedication?.id ??
                    _catalogMedicationId(catalog.rxcui);
                final doseUnit = catalog.form.isNotEmpty
                    ? catalog.form.toLowerCase()
                    : medication.form.toLowerCase();
                if (_isDuplicateSchedule(
                  store,
                  catalogId: catalog.rxcui,
                  medicationId: medicationId,
                  doseAmount: scheduleDraft.doseAmount,
                  doseUnit: doseUnit,
                  localTime: localTime,
                )) {
                  await _showDuplicateScheduleDialog();
                  continue;
                }
                final scheduleId = _scheduleId(
                  catalog.rxcui,
                  localDate: localDate,
                  localTime: localTime,
                  frequency: scheduleDraft.frequency,
                  doseAmount: scheduleDraft.doseAmount,
                );
                final doseId =
                    ScheduleOccurrenceGenerator.deterministicOccurrenceId(
                      scheduleId,
                      localDate: localDate,
                      localTime: localTime,
                    );
                await store.commitScheduleAndDose(
                  medication: MedicationWrite(
                    id: medicationId,
                    name: existingMedication?.name ?? catalog.name,
                    genericName:
                        existingMedication?.genericName ?? catalog.genericName,
                    strength: existingMedication?.strength ?? catalog.strength,
                    form: existingMedication?.form ?? catalog.form,
                    route: existingMedication?.route ?? catalog.route,
                    instructions: existingMedication?.instructions ?? '',
                    prescriber: existingMedication?.prescriber ?? '',
                    pharmacy: existingMedication?.pharmacy ?? '',
                    notes: existingMedication?.notes ?? '',
                    active: existingMedication?.active ?? true,
                    catalogId: catalog.rxcui,
                    catalogSource: 'rxnorm',
                    catalogVersion: catalog.sourceVersion,
                    source: existingMedication?.source ?? 'library',
                  ),
                  schedule: ScheduleWrite(
                    id: scheduleId,
                    medicationId: medicationId,
                    doseAmount: scheduleDraft.doseAmount,
                    doseUnit: doseUnit,
                    times: [localTime],
                    frequency: scheduleDraft.frequency,
                    daysOfWeek: scheduleDraft.daysOfWeek,
                    startDate: localDate,
                    endDate: scheduleDraft.frequency == 'once'
                        ? localDate
                        : null,
                    timezone: scheduleDraft.timezone,
                  ),
                  dose: scheduleDraft.frequency == 'asNeeded'
                      ? null
                      : DoseWrite(
                          id: doseId,
                          medicationId: medicationId,
                          scheduleId: scheduleId,
                          scheduledFor: scheduledFor,
                          localDate: localDate,
                          localTime: localTime,
                        ),
                );
                _cancelledDoseIds.remove(doseId);
                _pendingScheduleKeys[_scanScheduleKey(
                      catalogId: catalog.rxcui,
                      doseAmount: scheduleDraft.doseAmount,
                      doseUnit: doseUnit,
                      localTime: localTime,
                    )] =
                    medicationId;
                if (scheduleDraft.frequency != 'asNeeded') {
                  addedDoses.add(
                    CalendarDoseData(
                      id: doseId,
                      localDate: localDate,
                      name: catalog.name,
                      details: [
                        '${_formatDoseAmount(scheduleDraft.doseAmount)} $doseUnit',
                        formatLocalTime(localTime, widget.timeDisplayFormat),
                      ].join(' · '),
                      status: 'due',
                    ),
                  );
                }
              }
              if (addedDoses.isNotEmpty) {
                _requestMedicationNotificationPermission();
              }
              return addedDoses;
            },
    );
  }

  Future<_ScheduleDraft?> _showScheduleDetails(
    BuildContext context, {
    required String initialTimezone,
    required DateTime scheduleDate,
  }) {
    final current = widget.now ?? DateTime.now();
    final target = nextMedicationScheduleTime(now: current);
    final selectedDate = DateUtils.isSameDay(scheduleDate, current)
        ? DateUtils.dateOnly(target)
        : scheduleDate;
    return pushInAppPage<_ScheduleDraft>(
      context,
      builder: (context) => _ScheduleDetailsPage(
        initialTimezone: initialTimezone,
        scheduleDate: selectedDate,
        initialTime: defaultMedicationTime(now: current),
        timeDisplayFormat: widget.timeDisplayFormat,
      ),
    );
  }

  MedicationRecord? _existingMedicationFor(
    MediaryDataStore store,
    String catalogId,
  ) {
    for (final medication in store.medications) {
      if (medication.catalogId == catalogId) return medication;
    }
    return null;
  }

  String _catalogMedicationId(String catalogId) => 'rxnorm_$catalogId';

  String _scheduleId(
    String catalogId, {
    required String localDate,
    required String localTime,
    required String frequency,
    required double doseAmount,
  }) {
    final amount = doseAmount.toString().replaceAll('.', '_');
    return '${frequency}_${catalogId}_${localDate}_${localTime}_$amount';
  }

  String _formatDoseAmount(double amount) => amount == amount.roundToDouble()
      ? amount.toInt().toString()
      : amount.toString();

  List<CalendarDoseData> _calendarDoses(MediaryDataStore? store) {
    final medications = {
      for (final medication in store?.medications ?? const <MedicationRecord>[])
        if (medication.active) medication.id: medication,
    };
    final persisted = [
      for (final dose in _visibleDoseLogs(store))
        CalendarDoseData(
          id: dose.id,
          localDate: dose.localDate,
          name: medications[dose.medicationId]?.name ?? 'Medication',
          details: [
            if (medications[dose.medicationId]?.strength.isNotEmpty ?? false)
              medications[dose.medicationId]!.strength,
            if (dose.localTime.isNotEmpty)
              formatLocalTime(dose.localTime, widget.timeDisplayFormat),
          ].join(' · '),
          status: dose.status,
        ),
    ];
    final persistedIds = {for (final dose in persisted) dose.id};
    final persistedOccurrenceIds = {
      for (final dose in store?.doseLogs ?? const <DoseLogRecord>[])
        ScheduleOccurrenceGenerator.deterministicOccurrenceId(
          dose.scheduleId,
          localDate: dose.localDate,
          localTime: dose.localTime,
        ),
    };
    return [
      ...persisted,
      for (final dose in _pendingCalendarDoses)
        if (!persistedIds.contains(dose.id) &&
            !persistedOccurrenceIds.contains(dose.id) &&
            !_cancelledDoseIds.contains(dose.id))
          dose,
    ];
  }

  List<DoseLogRecord> _visibleDoseLogs(MediaryDataStore? store) {
    if (store == null) return const [];
    final medications = {
      for (final medication in store.medications)
        if (medication.active) medication.id,
    };
    final scheduleOwners = {
      for (final schedule in store.schedules)
        if (schedule.active) schedule.id: schedule.medicationId,
    };
    return [
      for (final dose in uniqueDoseOccurrences(store.doseLogs))
        if (dose.status != 'cancelled' &&
            !_cancelledDoseIds.contains(dose.id) &&
            medications.contains(dose.medicationId) &&
            ((dose.status != 'due' && dose.status != 'snoozed') ||
                scheduleOwners[dose.scheduleId] == dose.medicationId))
          dose,
    ];
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  ({String title, String description}) get _webPageMetadata {
    if (_showScanResult) {
      return (
        title: 'Review Medication — Mediary',
        description: 'Review and schedule a medication scan in Mediary.',
      );
    }
    return switch (_selectedIndex) {
      1 => (
        title: 'Calendar — Mediary',
        description: 'Plan medication doses and keep your schedule organized.',
      ),
      2 => (
        title: 'Scan Medication — Mediary',
        description: 'Scan or choose a medication image for review in Mediary.',
      ),
      3 => (
        title: 'Medication Library — Mediary',
        description: 'Explore medication reference information in Mediary.',
      ),
      4 => (
        title: 'Settings — Mediary',
        description:
            'Manage Mediary preferences, privacy, and account settings.',
      ),
      _ => (
        title: 'Dashboard — Mediary',
        description:
            'Track today’s medications and weekly progress with Mediary.',
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    // Only build a destination once it has been visited. IndexedStack keeps
    // every child mounted and rebuilds all of them on each frame (e.g. during
    // the theme transition), so deferring unseen screens cuts that cost.
    Widget lazy(int index, Widget Function(BuildContext) build) =>
        _visitedDestinations.contains(index)
        ? build(context)
        : const SizedBox.shrink();

    Widget activePage(int index, Widget page) {
      return RepaintBoundary(
        child: TickerMode(enabled: _selectedIndex == index, child: page),
      );
    }

    final pages = IndexedStack(
      index: _selectedIndex,
      children: [
        activePage(0, lazy(0, _buildDashboard)),
        activePage(1, lazy(1, _buildCalendar)),
        activePage(2, lazy(2, _buildScanner)),
        activePage(3, lazy(3, _buildLibrary)),
        activePage(4, lazy(4, _buildSettings)),
      ],
    );

    late Widget appShell;
    if (_usesSidebarNavigation) {
      final desktopWeb = kIsWeb && AppBreakpoints.isDesktop(context);
      final shell = Scaffold(
        body: desktopWeb
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: WebNavigationSidebar.collapsedWidth,
                      ),
                      child: pages,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: WebNavigationSidebar(
                      currentIndex: _selectedIndex,
                      onTap: _selectDestination,
                      overlayHoverArea: false,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  WebNavigationSidebar(
                    currentIndex: _selectedIndex,
                    onTap: _selectDestination,
                  ),
                  Expanded(child: pages),
                ],
              ),
      );
      appShell = shell;
    } else {
      appShell = Scaffold(
        extendBody: true,
        body: pages,
        bottomNavigationBar: LiquidGlassTabBar(
          currentIndex: _selectedIndex,
          onTap: _selectDestination,
        ),
      );
    }

    final metadata = _webPageMetadata;
    return WebPageMetadata(
      title: metadata.title,
      description: metadata.description,
      child: _withWebMedicationNotifications(appShell),
    );
  }

  Widget _withWebMedicationNotifications(Widget child) {
    if (!kIsWeb || _webMedicationToasts.isEmpty) return child;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          key: const Key('webMedicationNotificationToast'),
          bottom: MediaQuery.paddingOf(context).bottom + webFloatingNoticeInset,
          right: webFloatingNoticeInset,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth:
                  MediaQuery.sizeOf(context).width <
                      webFloatingNoticeMaxWidth + (webFloatingNoticeInset * 2)
                  ? MediaQuery.sizeOf(context).width -
                        (webFloatingNoticeInset * 2)
                  : webFloatingNoticeMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final toast in _webMedicationToasts)
                  _MedicationToastCard(
                    key: ValueKey(toast.key),
                    notification: toast.notification,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MedicationToast {
  const _MedicationToast(this.notification, this.key);

  final MedicationDueNotification notification;
  final String key;
}

class _MedicationToastCard extends StatefulWidget {
  const _MedicationToastCard({super.key, required this.notification});

  final MedicationDueNotification notification;

  @override
  State<_MedicationToastCard> createState() => _MedicationToastCardState();
}

class _MedicationToastCardState extends State<_MedicationToastCard> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(1.2, 0),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        child: WebFloatingNoticeCard(
          key: const Key('medicationNotificationCard'),
          icon: Icons.notifications_active_outlined,
          title: widget.notification.title,
          body: widget.notification.body,
        ),
      ),
    );
  }
}

class _ScheduleDraft {
  const _ScheduleDraft({
    required this.doseAmount,
    required this.frequency,
    required this.daysOfWeek,
    required this.timezone,
    required this.time,
    required this.date,
  });

  final double doseAmount;
  final String frequency;
  final List<int> daysOfWeek;
  final String timezone;
  final MedicationTime time;
  final DateTime date;
}

class _ScheduleDetailsPage extends StatefulWidget {
  const _ScheduleDetailsPage({
    required this.initialTimezone,
    required this.scheduleDate,
    required this.initialTime,
    required this.timeDisplayFormat,
  });

  final String initialTimezone;
  final DateTime scheduleDate;
  final MedicationTime initialTime;
  final TimeDisplayFormat timeDisplayFormat;

  @override
  State<_ScheduleDetailsPage> createState() => _ScheduleDetailsPageState();
}

class _ScheduleDetailsPageState extends State<_ScheduleDetailsPage> {
  static const _frequencyOptions = [
    ('once', 'No Repeat', 'Only on the selected calendar day'),
    ('daily', 'Every Day', 'Repeat daily at this time'),
    ('weekly', 'Every Week', 'Repeat weekly at this time'),
    ('every8Hours', 'Every 8 Hours', 'Repeat every 8 hours'),
    ('every12Hours', 'Every 12 Hours', 'Repeat every 12 hours'),
    ('asNeeded', 'As Needed', 'Use when needed; keep the schedule active'),
  ];

  late final TextEditingController _doseController;
  late String _frequency;
  late Set<int> _daysOfWeek;
  late String _timezone;
  late MedicationTime _time;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _doseController = TextEditingController(text: '1');
    _frequency = 'once';
    _daysOfWeek = {widget.scheduleDate.weekday};
    _timezone = widget.initialTimezone.trim().isEmpty
        ? deviceScheduleTimezone()
        : widget.initialTimezone.trim();
    _time = widget.initialTime;
  }

  @override
  void dispose() {
    _doseController.dispose();
    super.dispose();
  }

  String get _frequencyLabel =>
      _frequencyOptions.firstWhere((option) => option.$1 == _frequency).$2;

  String get _scheduleDateLabel {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${weekdays[widget.scheduleDate.weekday - 1]}, '
        '${months[widget.scheduleDate.month - 1]} '
        '${widget.scheduleDate.day}, ${widget.scheduleDate.year}';
  }

  Future<void> _chooseFrequency() async {
    final selected = await pushInAppPage<String>(
      context,
      builder: (context) => InAppOptionPage<String>(
        title: 'Repeat',
        subtitle: 'Choose how often this medication repeats.',
        options: [
          for (final option in _frequencyOptions)
            InAppPageOption<String>(
              label: option.$2,
              detail: option.$3,
              value: option.$1,
              selected: option.$1 == _frequency,
            ),
        ],
      ),
    );
    if (selected != null && mounted) {
      setState(() => _frequency = selected);
    }
  }

  Future<void> _chooseTimezone() async {
    final zones = <String>{
      _timezone,
      'UTC',
      'America/New_York',
      'America/Chicago',
      'America/Denver',
      'America/Los_Angeles',
    }.toList();
    final selected = await pushInAppPage<String>(
      context,
      builder: (context) => InAppOptionPage<String>(
        title: 'Time Zone',
        subtitle: 'Schedules are stored using this IANA time zone.',
        options: [
          for (final zone in zones)
            InAppPageOption<String>(
              label: zone,
              value: zone,
              selected: zone == _timezone,
            ),
        ],
      ),
    );
    if (selected != null && mounted) {
      setState(() => _timezone = selected);
    }
  }

  Future<void> _chooseTime() async {
    final selected = await pushInAppPage<MedicationTime>(
      context,
      builder: (context) => MedicationTimeSelectionPage(
        initialTime: _time.timeOfDay,
        scheduledDate: widget.scheduleDate,
        minimumDateTime: DateTime.now(),
        scheduledTimezone: _timezone,
        use24HourFormat:
            widget.timeDisplayFormat == TimeDisplayFormat.twentyFourHour,
      ),
    );
    if (selected != null && mounted) setState(() => _time = selected);
  }

  void _save() {
    final amount = double.tryParse(_doseController.text.trim());
    if (amount == null || !amount.isFinite || amount <= 0) {
      setState(() => _errorMessage = 'Enter a dose amount greater than zero.');
      return;
    }
    if (isMedicationTimeInPast(
      widget.scheduleDate,
      _time,
      timezone: _timezone,
    )) {
      setState(
        () => _errorMessage =
            'Choose a future date and time for this medication.',
      );
      return;
    }
    if (_frequency == 'weekly' && _daysOfWeek.isEmpty) {
      setState(() => _errorMessage = 'Choose at least one day of the week.');
      return;
    }
    Navigator.of(context).pop(
      _ScheduleDraft(
        doseAmount: amount,
        frequency: _frequency,
        daysOfWeek: _daysOfWeek.toList()..sort(),
        timezone: _timezone,
        time: _time,
        date: widget.scheduleDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final timeLabel = _time.format(widget.timeDisplayFormat);
    return InAppPageScaffold(
      title: 'Schedule Medication',
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Text(
            'Set the dose, date, time, and repeat behavior for this medication.',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const Key('scheduleDoseAmountField'),
            controller: _doseController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Dose Amount',
              hintText: '1',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_errorMessage != null) setState(() => _errorMessage = null);
            },
          ),
          const SizedBox(height: 14),
          _ScheduleChoiceTile(
            key: const Key('scheduleDateChoice'),
            label: 'Date',
            value: _scheduleDateLabel,
            leadingIcon: Icons.calendar_today_outlined,
            showChevron: false,
          ),
          const SizedBox(height: 10),
          _TimeSelectionCard(
            key: const Key('scheduleTimeChoice'),
            time: timeLabel,
            onTap: _chooseTime,
          ),
          const SizedBox(height: 10),
          _ScheduleChoiceTile(
            key: const Key('scheduleFrequencyChoice'),
            label: 'Repeat',
            value: _frequencyLabel,
            leadingIcon: Icons.repeat,
            onTap: _chooseFrequency,
          ),
          if (_frequency == 'weekly') ...[
            const SizedBox(height: 10),
            _WeekdaySelector(
              selectedDays: _daysOfWeek,
              onChanged: (day, selected) {
                setState(() {
                  if (selected) {
                    _daysOfWeek.add(day);
                  } else {
                    _daysOfWeek.remove(day);
                  }
                  _errorMessage = null;
                });
              },
            ),
          ],
          const SizedBox(height: 10),
          _ScheduleChoiceTile(
            key: const Key('scheduleTimezoneChoice'),
            label: 'Time Zone',
            value: _timezone,
            onTap: _chooseTimezone,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              key: const Key('scheduleDetailsError'),
              style: TextStyle(color: colors.error, fontSize: 13),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('saveScheduleDetailsButton'),
              onPressed: _save,
              child: const Text('Create Schedule'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegacyMedicationTimeSelectionPage extends StatefulWidget {
  const _LegacyMedicationTimeSelectionPage({required this.initialTime});

  final TimeOfDay initialTime;

  @override
  State<_LegacyMedicationTimeSelectionPage> createState() =>
      _LegacyMedicationTimeSelectionPageState();
}

class _LegacyMedicationTimeSelectionPageState
    extends State<_LegacyMedicationTimeSelectionPage> {
  static const _presets = [
    ('Morning', TimeOfDay(hour: 8, minute: 0)),
    ('Noon', TimeOfDay(hour: 12, minute: 0)),
    ('Evening', TimeOfDay(hour: 18, minute: 0)),
    ('Bedtime', TimeOfDay(hour: 21, minute: 0)),
  ];

  late TimeOfDay _time = widget.initialTime;

  bool _isSelected(TimeOfDay time) =>
      time.hour == _time.hour && time.minute == _time.minute;

  Future<void> _chooseCustomTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'Choose Medication Time',
      cancelText: 'Cancel',
      confirmText: 'Use Time',
    );
    if (selected != null && mounted) setState(() => _time = selected);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InAppPageScaffold(
      title: 'Choose Time',
      actions: [
        TextButton(
          key: const Key('confirmScheduleTimeButton'),
          onPressed: () => Navigator.of(context).pop(_time),
          child: const Text('Done'),
        ),
      ],
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Text(
            'Choose when you want a reminder. Pick a common time or set an exact time.',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: .42),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.primary.withValues(alpha: .22)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  color: colors.primary,
                  size: 26,
                ),
                const SizedBox(height: 8),
                Text(
                  _time.format(context),
                  key: const Key('selectedScheduleTime'),
                  style: TextStyle(
                    color: colors.onPrimaryContainer,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Medication Reminder Time',
                  style: TextStyle(
                    color: colors.onPrimaryContainer.withValues(alpha: .78),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Quick Choices',
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in _presets)
                ChoiceChip(
                  key: Key('scheduleTimePreset_${preset.$1}'),
                  label: Text('${preset.$1} · ${preset.$2.format(context)}'),
                  selected: _isSelected(preset.$2),
                  onSelected: (_) => setState(() => _time = preset.$2),
                ),
            ],
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            key: const Key('customScheduleTimeButton'),
            onPressed: _chooseCustomTime,
            icon: const Icon(Icons.access_time),
            label: const Text('Choose Custom Time'),
          ),
          const SizedBox(height: 12),
          Text(
            'You can change this reminder later from the Calendar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _WeekdaySelector extends StatelessWidget {
  const _WeekdaySelector({required this.selectedDays, required this.onChanged});

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _fullNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final Set<int> selectedDays;
  final void Function(int day, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Days of the Week',
          style: TextStyle(
            color: colors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var index = 0; index < _labels.length; index++) ...[
              Expanded(
                child: Semantics(
                  label: _fullNames[index],
                  selected: selectedDays.contains(index + 1),
                  child: FilterChip(
                    key: Key('scheduleWeekdayChip_${index + 1}'),
                    label: Text(_labels[index]),
                    selected: selectedDays.contains(index + 1),
                    onSelected: (selected) => onChanged(index + 1, selected),
                    showCheckmark: false,
                    padding: EdgeInsets.zero,
                    labelPadding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                  ),
                ),
              ),
              if (index < _labels.length - 1) const SizedBox(width: 4),
            ],
          ],
        ),
      ],
    );
  }
}

class _TimeSelectionCard extends StatelessWidget {
  const _TimeSelectionCard({
    super.key,
    required this.time,
    required this.onTap,
  });

  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          leading: Icon(Icons.access_time, color: colors.primary),
          title: const Text('Time'),
          subtitle: Text(time, key: const Key('scheduleTimeValue')),
          trailing: Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _ScheduleChoiceTile extends StatelessWidget {
  const _ScheduleChoiceTile({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
    this.leadingIcon,
    this.showChevron = true,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final IconData? leadingIcon;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: ListTile(
        onTap: onTap,
        leading: leadingIcon == null
            ? null
            : Icon(leadingIcon, color: colors.primary),
        title: Text(titleCaseDisplay(label)),
        subtitle: Text(value),
        trailing: showChevron
            ? Icon(Icons.chevron_right, color: colors.onSurfaceVariant)
            : null,
      ),
    );
  }
}
