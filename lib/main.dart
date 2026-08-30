import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:permission_handler/permission_handler.dart';

import 'add_medication_screen.dart';
import 'app_theme.dart';
import 'calendar_screen.dart';
import 'dashboard_screen.dart';
import 'firebase_options.dart';
import 'library_screens.dart';
import 'liquid_glass_tab_bar.dart';
import 'profile_screen.dart';
import 'scanner_screens.dart';
import 'settings_screen.dart';
import 'web_navigation_sidebar.dart';
import 'weekly_report_screen.dart';

final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
Future<void>? _googleSignInInitialization;

Future<void> signInWithGoogle(FirebaseAuth auth) async {
  if (kIsWeb) {
    await auth.signInWithPopup(GoogleAuthProvider());
    return;
  }

  await (_googleSignInInitialization ??= _googleSignIn.initialize());
  final googleUser = await _googleSignIn.authenticate();
  final googleAuth = googleUser.authentication;
  final credential = GoogleAuthProvider.credential(idToken: googleAuth.idToken);
  await auth.signInWithCredential(credential);
}

Future<void> signOut(FirebaseAuth auth) async {
  await auth.signOut();
  if (_googleSignInInitialization != null) {
    await _googleSignIn.signOut();
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
  await Firebase.initializeApp(
    options: kIsWeb ? DefaultFirebaseOptions.web : null,
  );
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
      theme: AppTheme.lightFor(_accentColor),
      darkTheme: AppTheme.darkFor(_accentColor),
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
        onAccentColorChanged: (accent) {
          setState(() => _accentColor = accent);
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
    _authStateChanges = auth.authStateChanges();
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
          return AuthenticatedHome(
            email: user.email ?? 'Signed-in user',
            displayName: user.displayName,
            photoUrl: user.photoURL,
            appearanceMode: widget.appearanceMode,
            onAppearanceModeChanged: widget.onAppearanceModeChanged,
            accentColor: widget.accentColor,
            onAccentColorChanged: widget.onAccentColorChanged,
            onSignOut: () => signOut(widget.auth),
            cameraPermissionRequester: requestCameraAccess,
            onOpenCameraSettings: openAppSettings,
          );
        }

        return AuthForm(
          onOpenSettings: () => _openSettings(context),
          onGoogleSignIn: () => signInWithGoogle(widget.auth),
          onSubmit:
              ({required email, required password, required createAccount}) {
                if (createAccount) {
                  return widget.auth.createUserWithEmailAndPassword(
                    email: email,
                    password: password,
                  );
                }

                return widget.auth.signInWithEmailAndPassword(
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

class AuthForm extends StatefulWidget {
  const AuthForm({
    super.key,
    required this.onSubmit,
    this.onOpenSettings,
    this.onGoogleSignIn,
  });

  final AuthSubmitter onSubmit;
  final VoidCallback? onOpenSettings;
  final GoogleAuthSubmitter? onGoogleSignIn;

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _createAccount = false;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _isGoogleSubmitting = false;
  String? _errorMessage;

  bool get _isBusy => _isSubmitting || _isGoogleSubmitting;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isBusy || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

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
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = _messageFor(error));
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

    setState(() {
      _isGoogleSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.onGoogleSignIn!();
    } on GoogleSignInException catch (error) {
      if (mounted && error.code != GoogleSignInExceptionCode.canceled) {
        setState(() {
          _errorMessage =
              error.code == GoogleSignInExceptionCode.clientConfigurationError
              ? 'Google sign-in is not configured correctly.'
              : 'Unable to sign in with Google. Please try again.';
        });
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = _messageFor(error));
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
    setState(() {
      _createAccount = !_createAccount;
      _errorMessage = null;
    });
  }

  String _messageFor(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for this email address.';
      case 'weak-password':
        return 'Choose a stronger password with at least 6 characters.';
      case 'network-request-failed':
        return 'Unable to connect. Check your internet connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      default:
        return 'Unable to ${_createAccount ? 'create your account' : 'sign in'}. Please try again.';
    }
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
    if ((value ?? '').isEmpty) {
      return 'Password is required.';
    }
    if ((value ?? '').length < 6) {
      return 'Password must be at least 6 characters.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final title = _createAccount ? 'Create an Account' : 'Welcome Back';
    final action = _createAccount ? 'Create account' : 'Sign in';

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            key: const Key('settingsButton'),
            tooltip: 'Settings',
            onPressed: widget.onOpenSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
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
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
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
                              : () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(action),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const Key('googleSignInButton'),
                      onPressed: _isBusy || widget.onGoogleSignIn == null
                          ? null
                          : _signInWithGoogle,
                      icon: _isGoogleSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'G',
                              style: TextStyle(fontWeight: FontWeight.bold),
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
  bool _showScanResult = false;
  CameraAccessState _cameraAccess = CameraAccessState.notRequested;

  bool get _usesSidebarNavigation => widget.useSidebarNavigation ?? kIsWeb;

  void _selectDestination(int index) {
    setState(() {
      _selectedIndex = index;
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
    return DashboardScreen(
      email: widget.email,
      displayName: widget.displayName,
      photoUrl: widget.photoUrl,
      now: widget.now,
      bottomPadding: _usesSidebarNavigation ? 32 : 120,
      onViewReport: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => WeeklyReportScreen(weekEnding: widget.now),
          ),
        );
      },
      onAddMedication: () async {
        final selections = await showAddMedicationScreen(context);
        return selections?.map((medication) => medication.name).toList();
      },
    );
  }

  Widget _buildLibrary(BuildContext context) {
    return MedicationLibraryScreen(
      bottomPadding: _usesSidebarNavigation ? 32 : 128,
      onOpenMedication: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => const MedicationDetailScreen(),
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
          email: widget.email,
          displayName: widget.displayName,
          photoUrl: widget.photoUrl,
          pageTitle: 'Account',
          onBack: () => Navigator.of(accountContext).maybePop(),
          onOpenLibrary: () {
            Navigator.of(accountContext).pop();
            if (mounted) setState(() => _selectedIndex = 3);
          },
          onSignOut: widget.onSignOut,
          bottomPadding: 32,
        ),
      ),
    );
  }

  Widget _buildSettings(BuildContext context) {
    return SettingsScreen(
      embedded: true,
      appearanceMode: widget.appearanceMode,
      onAppearanceModeChanged: widget.onAppearanceModeChanged ?? (_) {},
      accentColor: widget.accentColor,
      onAccentColorChanged: widget.onAccentColorChanged ?? (_) {},
      accountEmail: widget.email,
      accountDisplayName: widget.displayName,
      accountPhotoUrl: widget.photoUrl,
      onOpenAccount: () => _openAccount(context),
      bottomPadding: _usesSidebarNavigation ? 32 : 120,
    );
  }

  Widget _buildScanner(BuildContext context) {
    if (_showScanResult) {
      return ScanResultScreen(
        onBack: () => setState(() => _showScanResult = false),
        onScanAgain: () => setState(() => _showScanResult = false),
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
        _selectedIndex = 0;
        _showScanResult = false;
      }),
      onCapture: () => setState(() => _showScanResult = true),
      onOpenSettings: widget.onOpenCameraSettings ?? openAppSettings,
      bottomNavigationInset: _usesSidebarNavigation ? 16 : 112,
    );
  }

  Widget _buildCalendar(BuildContext context) {
    return CalendarScreen(
      initialDate: widget.now,
      bottomPadding: _usesSidebarNavigation ? 32 : 120,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = IndexedStack(
      index: _selectedIndex,
      children: [
        _buildDashboard(context),
        _buildCalendar(context),
        TickerMode(enabled: _selectedIndex == 2, child: _buildScanner(context)),
        _buildLibrary(context),
        _buildSettings(context),
      ],
    );

    if (_usesSidebarNavigation) {
      return Scaffold(
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
