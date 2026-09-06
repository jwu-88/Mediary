import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:permission_handler/permission_handler.dart';

import 'add_medication_screen.dart';
import 'app_interactions.dart';
import 'app_theme.dart';
import 'calendar_screen.dart';
import 'dashboard_screen.dart';
import 'data/mediary_data_store.dart';
import 'data/mediary_models.dart';
import 'data/mediary_repository.dart';
import 'firebase_options.dart';
import 'library_screens.dart';
import 'liquid_glass_tab_bar.dart';
import 'profile_screen.dart';
import 'scanner_screens.dart';
import 'settings_screen.dart';
import 'web_camera.dart';
import 'web_navigation_sidebar.dart';
import 'weekly_report_screen.dart';

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
      builder: (context, child) =>
          AppThemeTransitionSurface(child: child ?? const SizedBox.shrink()),
      home: AuthGate(
        auth: _auth,
        appearanceMode: _appearanceMode,
        onAppearanceModeChanged: (mode) {
          setState(() => _appearanceMode = mode);
        },
        accentColor: _accentColor,
        onAccentColorChanged: _setAccentColor,
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
  });

  final FirebaseAuth auth;
  final ThemeMode appearanceMode;
  final ValueChanged<ThemeMode> onAppearanceModeChanged;
  final AppAccentColor accentColor;
  final ValueChanged<AppAccentColor> onAccentColorChanged;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Stream<User?> _authStateChanges;
  User? _initialUser;
  bool _returningUser = false;
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
      return;
    }
    if (_dataStore?.userId == user.uid) return;
    _dataStore?.dispose();
    final store = MediaryDataStore(
      repository: MediaryRepository(auth: widget.auth),
    );
    _dataStore = store;
    unawaited(store.start(user));
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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user != null) {
          _returningUser = true;
          _syncDataStore(user);
          if (_requiresEmailVerification(user)) {
            return EmailVerificationScreen(
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
            onSignOut: () => signOut(widget.auth),
            dataStore: _dataStore,
            cameraPermissionRequester: requestCameraAccess,
            onOpenCameraSettings: openAppSettings,
          );
        }

        _confirmedVerifiedUid = null;

        return AuthForm(
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
    final action = _createAccount ? 'Create account' : 'Sign in';
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

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
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: isDark ? .62 : .48),
                  Colors.black.withValues(alpha: isDark ? .76 : .58),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor.withValues(
                        alpha: isDark ? .93 : .95,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: colors.outlineVariant.withValues(alpha: .55),
                        width: .7,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x38000000),
                          blurRadius: 28,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: 48,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              title,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _createAccount
                                  ? 'Create your Mediary account.'
                                  : 'Sign in to Mediary.',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 32),
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
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  tooltip: _obscurePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: _isBusy
                                      ? null
                                      : () {
                                          unawaited(AppHaptics.selection());
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
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
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
                              label: const Text('Sign in with Google'),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _isBusy ? null : _changeMode,
                              child: Text(
                                _createAccount
                                    ? 'Already have an account? Sign in'
                                    : 'Need an account? Create one',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
    this.onSignOut,
    this.dataStore,
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
  final Future<void> Function()? onSignOut;
  final MediaryDataStore? dataStore;
  final DateTime? now;
  final CameraPermissionRequester? cameraPermissionRequester;
  final Future<bool> Function()? onOpenCameraSettings;

  /// Overrides adaptive navigation selection for previews and tests.
  /// Web uses the sidebar by default; native platforms use the bottom bar.
  final bool? useSidebarNavigation;

  @override
  State<AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends State<AuthenticatedHome> {
  int _selectedIndex = 0;
  final Set<int> _visitedDestinations = {0};
  bool _showScanResult = false;
  CameraAccessState _cameraAccess = CameraAccessState.notRequested;
  String? _appliedPreferenceSignature;

  @override
  void initState() {
    super.initState();
    widget.dataStore?.addListener(_onStoreChanged);
  }

  @override
  void didUpdateWidget(covariant AuthenticatedHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataStore != widget.dataStore) {
      oldWidget.dataStore?.removeListener(_onStoreChanged);
      widget.dataStore?.addListener(_onStoreChanged);
      _appliedPreferenceSignature = null;
    }
  }

  @override
  void dispose() {
    widget.dataStore?.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    final preferences = widget.dataStore?.profile?.preferences;
    if (preferences == null) return;
    final signature = [preferences.theme, preferences.accentColor].join('|');
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
      widget.onAppearanceModeChanged?.call(mode);
      widget.onAccentColorChanged?.call(accent);
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
    try {
      final requester = widget.cameraPermissionRequester ?? requestCameraAccess;
      final result = await requester();
      if (mounted) {
        setState(() => _cameraAccess = result);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _cameraAccess = CameraAccessState.error);
      }
    }
  }

  Widget _buildDashboard(BuildContext context) {
    final store = widget.dataStore;
    final profilePhotoUrl = store?.profile?.photoUrl ?? widget.photoUrl;
    return DashboardScreen(
      email: store?.profile?.email ?? widget.email,
      displayName: store?.profile?.displayName ?? widget.displayName,
      photoUrl: profilePhotoUrl,
      now: widget.now,
      bottomPadding: _usesSidebarNavigation ? 32 : 120,
      initialDoses: _dashboardDoses(store),
      onDoseStatusChanged: store == null
          ? null
          : (doseId, status, {snoozedUntil}) => store.updateDoseStatus(
              doseId,
              status,
              takenAt: status == 'taken' ? DateTime.now() : null,
              snoozedUntil: snoozedUntil,
            ),
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
      onAddMedication: () async {
        final selections = await showAddMedicationScreen(context);
        if (selections != null && store != null) {
          for (final medication in selections) {
            await store.saveMedication(
              MedicationWrite(
                id: medication.id,
                name: medication.name,
                genericName: medication.genericName,
                strength: medication.strength,
                form: medication.form,
                source: 'library',
              ),
            );
          }
        }
        return selections?.map((medication) => medication.name).toList();
      },
      onOpenAccount: () => _openAccount(context),
    );
  }

  ({List<int> taken, List<int> scheduled, List<int> offsets, List<int> skipped})
  _reportSeries(MediaryDataStore? store) {
    final ending = DateUtils.dateOnly(widget.now ?? DateTime.now());
    final start = ending.subtract(const Duration(days: 6));
    final taken = List<int>.filled(7, 0);
    final scheduled = List<int>.filled(7, 0);
    final offsets = List<int>.filled(7, 0);
    final skipped = List<int>.filled(7, 0);
    for (final dose in store?.doseLogs ?? const <DoseLogRecord>[]) {
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
    final medications = {
      for (final medication in store.medications) medication.id: medication,
    };
    final doses =
        store.doseLogs.where((dose) => dose.status != 'cancelled').toList()
          ..sort(
            (first, second) =>
                first.scheduledFor.compareTo(second.scheduledFor),
          );
    return [
      for (final dose in doses.take(12))
        DashboardDoseData(
          id: dose.id,
          name: medications[dose.medicationId]?.name ?? 'Medication',
          details: [
            if (medications[dose.medicationId]?.strength.isNotEmpty ?? false)
              medications[dose.medicationId]!.strength,
            if (dose.localTime.isNotEmpty) dose.localTime,
          ].join(' · '),
          status: dose.status,
        ),
    ];
  }

  Widget _buildLibrary(BuildContext context) {
    final store = widget.dataStore;
    return MedicationLibraryScreen(
      bottomPadding: _usesSidebarNavigation ? 32 : 128,
      initialSavedMedicationIds: {
        if (store != null) ...store.savedMedications.map((item) => item.id),
      },
      onSavedChanged: store == null
          ? null
          : (medicationId, saved) async {
              if (saved) {
                await store.saveLibraryMedication(id: medicationId);
              } else {
                await store.unsaveLibraryMedication(medicationId);
              }
            },
      onOpenMedication: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => MedicationDetailScreen(
              initialBookmarked:
                  store?.savedMedications.any(
                    (item) => item.id == 'amoxicillin-500-capsule',
                  ) ??
                  false,
              onBookmarkChanged: store == null
                  ? null
                  : (saved) async {
                      if (saved) {
                        await store.saveLibraryMedication(
                          id: 'amoxicillin-500-capsule',
                        );
                      } else {
                        await store.unsaveLibraryMedication(
                          'amoxicillin-500-capsule',
                        );
                      }
                    },
            ),
          ),
        );
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
        builder: (accountContext) => ProfileScreen(
          email: widget.dataStore?.profile?.email ?? widget.email,
          displayName:
              widget.dataStore?.profile?.displayName ?? widget.displayName,
          photoUrl: widget.dataStore?.profile?.photoUrl ?? widget.photoUrl,
          initialBloodType: widget.dataStore?.profile?.bloodType,
          initialAllergies: widget.dataStore?.profile?.allergies,
          initialCareTeam: widget.dataStore?.profile?.careTeam,
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
      accountEmail: widget.dataStore?.profile?.email ?? widget.email,
      accountDisplayName:
          widget.dataStore?.profile?.displayName ?? widget.displayName,
      accountPhotoUrl: profilePhotoUrl,
      onPreferenceChanged: widget.dataStore?.updatePreference,
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
        onScanAgain: () => setState(() => _showScanResult = false),
        onScanReady: store?.saveScan,
        onScheduleConfirmed: store == null
            ? null
            : (schedule) async {
                final doseParts = schedule.dose.split(' ');
                final doseAmount = schedule.dose.startsWith('½')
                    ? .5
                    : double.tryParse(doseParts.first) ?? 1;
                final doseUnit = doseParts.length > 1
                    ? doseParts.last
                    : 'capsule';
                final frequency = switch (schedule.frequency) {
                  'Every 8 hours' => 'every8Hours',
                  'Every 12 hours' => 'every12Hours',
                  'As needed' => 'asNeeded',
                  _ => 'daily',
                };
                final durationDays =
                    int.tryParse(schedule.duration.split(' ').first) ?? 7;
                final endDate = schedule.startDate.add(
                  Duration(days: durationDays - 1),
                );
                final localDate = _dateKey(schedule.startDate);
                final localTime =
                    '${schedule.time.hour.toString().padLeft(2, '0')}:${schedule.time.minute.toString().padLeft(2, '0')}';
                final scheduleId = 'scan_amoxicillin_${localDate}_$localTime';
                await store.commitScheduleAndDose(
                  medication: const MedicationWrite(
                    id: 'amoxicillin-500-capsule',
                    name: 'Amoxicillin',
                    genericName: 'Amoxicillin',
                    strength: '500 mg',
                    form: 'Capsule',
                    source: 'scanner',
                  ),
                  schedule: ScheduleWrite(
                    id: scheduleId,
                    medicationId: 'amoxicillin-500-capsule',
                    doseAmount: doseAmount,
                    doseUnit: doseUnit,
                    times: [localTime],
                    frequency: frequency,
                    startDate: localDate,
                    endDate: _dateKey(endDate),
                    timezone: 'UTC',
                  ),
                  dose: DoseWrite(
                    id: '${scheduleId}_$localDate',
                    medicationId: 'amoxicillin-500-capsule',
                    scheduleId: scheduleId,
                    scheduledFor: DateTime(
                      schedule.startDate.year,
                      schedule.startDate.month,
                      schedule.startDate.day,
                      schedule.time.hour,
                      schedule.time.minute,
                    ),
                    localDate: localDate,
                    localTime: localTime,
                  ),
                );
              },
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
      onClose: () => setState(() {
        stopWebCamera();
        _selectedIndex = 0;
        _showScanResult = false;
      }),
      onCapture: () => setState(() => _showScanResult = true),
      onOpenSettings: widget.onOpenCameraSettings ?? openAppSettings,
      isActive: _selectedIndex == 2,
      bottomNavigationInset: _usesSidebarNavigation ? 16 : 112,
    );
  }

  Widget _buildCalendar(BuildContext context) {
    final store = widget.dataStore;
    return CalendarScreen(
      initialDate: widget.now,
      bottomPadding: _usesSidebarNavigation ? 32 : 120,
      initialDoses: _calendarDoses(store),
      onDoseStatusChanged: store == null
          ? null
          : (doseId, status) => store.updateDoseStatus(
              doseId,
              status,
              takenAt: status == 'taken' ? DateTime.now() : null,
            ),
      onAddDose: store == null
          ? null
          : (date) async {
              final selections = await showAddMedicationScreen(context);
              if (selections == null || selections.isEmpty || !mounted) {
                return;
              }
              if (!context.mounted) return;
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(DateTime.now()),
              );
              if (time == null || !mounted) return;
              final scheduledFor = DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              );
              final localDate = _dateKey(date);
              final localTime =
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
              for (final medication in selections) {
                final scheduleId =
                    'once_${medication.id}_${localDate}_$localTime';
                await store.commitScheduleAndDose(
                  medication: MedicationWrite(
                    id: medication.id,
                    name: medication.name,
                    genericName: medication.genericName,
                    strength: medication.strength,
                    form: medication.form,
                    source: 'library',
                  ),
                  schedule: ScheduleWrite(
                    id: scheduleId,
                    medicationId: medication.id,
                    doseAmount: 1,
                    doseUnit: medication.form.toLowerCase(),
                    times: [localTime],
                    frequency: 'once',
                    startDate: localDate,
                    endDate: localDate,
                    timezone: 'UTC',
                  ),
                  dose: DoseWrite(
                    id: scheduleId,
                    medicationId: medication.id,
                    scheduleId: scheduleId,
                    scheduledFor: scheduledFor,
                    localDate: localDate,
                    localTime: localTime,
                  ),
                );
              }
            },
    );
  }

  List<CalendarDoseData> _calendarDoses(MediaryDataStore? store) {
    if (store == null) return const [];
    final medications = {
      for (final medication in store.medications) medication.id: medication,
    };
    return [
      for (final dose in store.doseLogs.where(
        (dose) => dose.status != 'cancelled',
      ))
        CalendarDoseData(
          id: dose.id,
          localDate: dose.localDate,
          name: medications[dose.medicationId]?.name ?? 'Medication',
          details: [
            if (medications[dose.medicationId]?.strength.isNotEmpty ?? false)
              medications[dose.medicationId]!.strength,
            if (dose.localTime.isNotEmpty) dose.localTime,
          ].join(' · '),
          status: dose.status,
        ),
    ];
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
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

    final pages = IndexedStack(
      index: _selectedIndex,
      children: [
        lazy(0, _buildDashboard),
        lazy(1, _buildCalendar),
        TickerMode(
          enabled: _selectedIndex == 2,
          child: lazy(2, _buildScanner),
        ),
        lazy(3, _buildLibrary),
        lazy(4, _buildSettings),
      ],
    );

    if (_usesSidebarNavigation) {
      final shell = Scaffold(
        body: Row(
          children: [
            WebNavigationSidebar(
              currentIndex: _selectedIndex,
              onTap: _selectDestination,
            ),
            Expanded(child: pages),
          ],
        ),
      );
      if (!kIsWeb || MediaQuery.sizeOf(context).width < 900) return shell;
      final mediaQuery = MediaQuery.of(context);
      final baseTextSize = mediaQuery.textScaler.scale(1);
      return MediaQuery(
        data: mediaQuery.copyWith(
          textScaler: TextScaler.linear(baseTextSize * 1.22),
        ),
        child: shell,
      );
    }

    return Scaffold(
      extendBody: true,
      body: pages,
      bottomNavigationBar: LiquidGlassTabBar(
        currentIndex: _selectedIndex,
        onTap: _selectDestination,
      ),
    );
  }
}
