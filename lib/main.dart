import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app_theme.dart';
import 'dashboard_screen.dart';

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
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _darkModeEnabled = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Account',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _darkModeEnabled ? ThemeMode.dark : ThemeMode.light,
      home: AuthGate(
        auth: FirebaseAuth.instance,
        darkModeEnabled: _darkModeEnabled,
        onDarkModeChanged: (enabled) {
          setState(() => _darkModeEnabled = enabled);
        },
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.auth,
    required this.darkModeEnabled,
    required this.onDarkModeChanged,
  });

  final FirebaseAuth auth;
  final bool darkModeEnabled;
  final ValueChanged<bool> onDarkModeChanged;

  void _openSettings(BuildContext context, {User? user}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsScreen(
          darkModeEnabled: darkModeEnabled,
          onDarkModeChanged: onDarkModeChanged,
          accountEmail: user?.email,
          onSignOut: user == null ? null : () => signOut(auth),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
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
            onOpenSettings: () => _openSettings(context, user: user),
            cameraPermissionRequester: requestCameraAccess,
            onOpenCameraSettings: openAppSettings,
          );
        }

        return AuthForm(
          onOpenSettings: () => _openSettings(context),
          onGoogleSignIn: () => signInWithGoogle(auth),
          onSubmit:
              ({required email, required password, required createAccount}) {
                if (createAccount) {
                  return auth.createUserWithEmailAndPassword(
                    email: email,
                    password: password,
                  );
                }

                return auth.signInWithEmailAndPassword(
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
    final title = _createAccount ? 'Create an account' : 'Welcome back';
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
                          ? 'Use your email address to get started.'
                          : 'Sign in to continue to your account.',
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
                        labelText: 'Email address',
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
    this.now,
    this.cameraPermissionRequester,
    this.onOpenCameraSettings,
  });

  final String email;
  final String? displayName;
  final String? photoUrl;
  final VoidCallback? onOpenSettings;
  final DateTime? now;
  final CameraPermissionRequester? cameraPermissionRequester;
  final Future<bool> Function()? onOpenCameraSettings;

  @override
  State<AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends State<AuthenticatedHome> {
  int _selectedIndex = 0;
  CameraAccessState _cameraAccess = CameraAccessState.notRequested;
  late DateTime _selectedDate = DateUtils.dateOnly(
    widget.now ?? DateTime.now(),
  );

  String get _name {
    final name = widget.displayName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }

    final emailName = widget.email.split('@').first.trim();
    return emailName.isEmpty ? 'there' : emailName;
  }

  String _formatDate(DateTime date) {
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _selectDestination(int index) {
    setState(() => _selectedIndex = index);
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
    );
  }

  Widget _buildLibrary(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.book, size: 52),
          SizedBox(height: 16),
          Text('Medication library'),
        ],
      ),
    );
  }

  Widget _buildProfile(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.person_crop_circle, size: 58),
          const SizedBox(height: 16),
          Text(_name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(widget.email),
          const SizedBox(height: 20),
          TextButton(
            onPressed: widget.onOpenSettings,
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildScanner(BuildContext context) {
    final theme = Theme.of(context);
    final (title, message, icon) = switch (_cameraAccess) {
      CameraAccessState.notRequested => (
        'Camera access required',
        'Allow camera access to use the scanner.',
        Icons.qr_code_scanner,
      ),
      CameraAccessState.requesting => (
        'Requesting camera access',
        'Respond to the permission request to continue.',
        Icons.camera_alt_outlined,
      ),
      CameraAccessState.granted => (
        'Scanner ready',
        'Camera access is enabled.',
        Icons.qr_code_scanner,
      ),
      CameraAccessState.denied => (
        'Camera access denied',
        'Camera permission is needed to scan items.',
        Icons.no_photography_outlined,
      ),
      CameraAccessState.permanentlyDenied => (
        'Enable camera access',
        'Allow camera access from your device settings.',
        Icons.no_photography_outlined,
      ),
      CameraAccessState.error => (
        'Camera unavailable',
        'The camera permission request could not be completed.',
        Icons.error_outline,
      ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_cameraAccess == CameraAccessState.requesting)
              const CircularProgressIndicator()
            else
              Icon(icon, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_cameraAccess == CameraAccessState.notRequested ||
                _cameraAccess == CameraAccessState.denied ||
                _cameraAccess == CameraAccessState.error) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('requestCameraButton'),
                onPressed: _requestCameraAccess,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Allow camera access'),
              ),
            ],
            if (_cameraAccess == CameraAccessState.permanentlyDenied) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('openCameraSettingsButton'),
                onPressed: () async {
                  final openSettings =
                      widget.onOpenCameraSettings ?? openAppSettings;
                  await openSettings();
                },
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Open settings'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar(BuildContext context) {
    final today = DateUtils.dateOnly(widget.now ?? DateTime.now());
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        CalendarDatePicker(
          key: const Key('calendarDatePicker'),
          initialDate: _selectedDate,
          currentDate: today,
          firstDate: DateTime(1900),
          lastDate: DateTime(2100, 12, 31),
          onDateChanged: (date) {
            setState(() => _selectedDate = date);
          },
        ),
        const SizedBox(height: 16),
        Text(
          _formatDate(_selectedDate),
          key: const Key('selectedCalendarDate'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['Today', 'Calendar', 'Scan', 'Library', 'Profile'];
    return Scaffold(
      appBar: _selectedIndex == 0
          ? null
          : AppBar(title: Text(titles[_selectedIndex])),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildDashboard(context),
          _buildCalendar(context),
          _buildScanner(context),
          _buildLibrary(context),
          _buildProfile(context),
        ],
      ),
      bottomNavigationBar: CupertinoTabBar(
        currentIndex: _selectedIndex,
        onTap: _selectDestination,
        activeColor: const Color(0xFF0A62D0),
        inactiveColor: const Color(0xFF8E8E93),
        backgroundColor: const Color(0xEBF9F9F9),
        border: const Border(
          top: BorderSide(color: Color(0x383C3C43), width: .5),
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house),
            activeIcon: Icon(CupertinoIcons.house_fill),
            label: 'Today',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.calendar),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.camera),
            activeIcon: Icon(CupertinoIcons.camera_fill),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.book),
            activeIcon: Icon(CupertinoIcons.book_fill),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person),
            activeIcon: Icon(CupertinoIcons.person_fill),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.darkModeEnabled,
    required this.onDarkModeChanged,
    this.accountEmail,
    this.onSignOut,
  });

  final bool darkModeEnabled;
  final ValueChanged<bool> onDarkModeChanged;
  final String? accountEmail;
  final Future<void> Function()? onSignOut;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _darkModeEnabled = widget.darkModeEnabled;
  bool _isSigningOut = false;

  void _setDarkMode(bool enabled) {
    setState(() => _darkModeEnabled = enabled);
    widget.onDarkModeChanged(enabled);
  }

  Future<void> _signOut() async {
    if (_isSigningOut || widget.onSignOut == null) {
      return;
    }

    setState(() => _isSigningOut = true);
    try {
      await widget.onSignOut!();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  Widget _sectionHeader(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _sectionHeader(context, 'Appearance'),
          SwitchListTile(
            key: const Key('darkModeSwitch'),
            title: const Text('Dark mode'),
            subtitle: const Text('Use a darker appearance throughout the app.'),
            secondary: const Icon(Icons.dark_mode_outlined),
            value: _darkModeEnabled,
            onChanged: _setDarkMode,
          ),
          if (widget.onSignOut != null) ...[
            const Divider(),
            _sectionHeader(context, 'Account'),
            ListTile(
              key: const Key('settingsSignOutButton'),
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              subtitle: widget.accountEmail == null
                  ? null
                  : Text(widget.accountEmail!),
              trailing: _isSigningOut
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              enabled: !_isSigningOut,
              onTap: _signOut,
            ),
          ],
        ],
      ),
    );
  }
}
