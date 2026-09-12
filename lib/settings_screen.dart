import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app_theme.dart';
import 'app_interactions.dart';
import 'app_layout.dart';
import 'data/mediary_models.dart';
import 'in_app_page.dart';
import 'liquid_glass_accent_selector.dart';
import 'liquid_glass_appearance_selector.dart';
import 'liquid_glass_back_button.dart';
import 'liquid_glass_switch.dart';
import 'profile_image_policy.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.appearanceMode,
    required this.onAppearanceModeChanged,
    required this.accentColor,
    required this.onAccentColorChanged,
    this.accountEmail,
    this.onSignOut,
    this.pageTitle = 'Settings',
    this.embedded = false,
    this.bottomPadding = 28,
    this.onOpenAccount,
    this.accountDisplayName,
    this.accountPhotoUrl,
    this.onPreferenceChanged,
    this.initialPreferences,
  });

  final ThemeMode appearanceMode;
  final ValueChanged<ThemeMode> onAppearanceModeChanged;
  final AppAccentColor accentColor;
  final ValueChanged<AppAccentColor> onAccentColorChanged;
  final String? accountEmail;
  final Future<void> Function()? onSignOut;
  final String pageTitle;
  final bool embedded;
  final double bottomPadding;
  final VoidCallback? onOpenAccount;
  final String? accountDisplayName;
  final String? accountPhotoUrl;
  final Future<void> Function(String key, Object value)? onPreferenceChanged;
  final MediaryPreferences? initialPreferences;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late ThemeMode _appearanceMode = widget.appearanceMode;
  late AppAccentColor _accentColor = widget.accentColor;
  late bool _doseNotifications =
      widget.initialPreferences?.doseNotifications ?? true;
  late bool _followUpAlerts = widget.initialPreferences?.followUpAlerts ?? true;
  final bool _appleHealthConnected = false;
  bool _isExportingData = false;
  String? _exportStatusMessage;
  late String _reminderSound =
      widget.initialPreferences?.reminderSound ?? 'Gentle Chime';
  late String _language = widget.initialPreferences?.language ?? 'English';
  late String _units = widget.initialPreferences?.units ?? 'Metric';

  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  ColorScheme get _colors => Theme.of(context).colorScheme;
  Color get _background => Theme.of(context).scaffoldBackgroundColor;
  Color get _ink => _colors.onSurface;
  Color get _muted => _colors.onSurfaceVariant;
  Color get _line => _colors.outlineVariant.withValues(alpha: _dark ? .8 : .55);
  Color get _accent => _colors.primary;
  Color get _success =>
      _dark ? const Color(0xFF30D158) : const Color(0xFF248A3D);

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appearanceMode != widget.appearanceMode) {
      _appearanceMode = widget.appearanceMode;
    }
    if (oldWidget.accentColor != widget.accentColor) {
      _accentColor = widget.accentColor;
    }
    final oldPreferences = oldWidget.initialPreferences;
    final preferences = widget.initialPreferences;
    if (preferences != null &&
        (oldPreferences == null ||
            oldPreferences.doseNotifications != preferences.doseNotifications ||
            oldPreferences.followUpAlerts != preferences.followUpAlerts ||
            oldPreferences.reminderSound != preferences.reminderSound ||
            oldPreferences.language != preferences.language ||
            oldPreferences.units != preferences.units)) {
      _doseNotifications = preferences.doseNotifications;
      _followUpAlerts = preferences.followUpAlerts;
      _reminderSound = preferences.reminderSound;
      _language = preferences.language;
      _units = preferences.units;
    }
  }

  void _setAppearanceMode(ThemeMode mode) {
    final previous = _appearanceMode;
    setState(() => _appearanceMode = mode);
    widget.onAppearanceModeChanged(mode);
    unawaited(
      _persistPreference(
        'theme',
        mode.name,
        rollback: () {
          setState(() => _appearanceMode = previous);
          widget.onAppearanceModeChanged(previous);
        },
      ),
    );
  }

  void _setAccentColor(AppAccentColor accent) {
    final previous = _accentColor;
    setState(() => _accentColor = accent);
    widget.onAccentColorChanged(accent);
    unawaited(
      _persistPreference(
        'accentColor',
        accent.name,
        rollback: () {
          setState(() => _accentColor = previous);
          widget.onAccentColorChanged(previous);
        },
      ),
    );
  }

  Future<void> _persistPreference(
    String key,
    Object value, {
    VoidCallback? rollback,
  }) async {
    try {
      await widget.onPreferenceChanged?.call(key, value);
    } catch (_) {
      rollback?.call();
      if (mounted) {
        setState(() => _exportStatusMessage = 'Setting could not be saved.');
      }
    }
  }

  void _setDoseNotifications(bool value) {
    final previous = _doseNotifications;
    setState(() => _doseNotifications = value);
    unawaited(
      _persistPreference(
        'doseNotifications',
        value,
        rollback: () => setState(() => _doseNotifications = previous),
      ),
    );
  }

  void _setFollowUpAlerts(bool value) {
    final previous = _followUpAlerts;
    setState(() => _followUpAlerts = value);
    unawaited(
      _persistPreference(
        'followUpAlerts',
        value,
        rollback: () => setState(() => _followUpAlerts = previous),
      ),
    );
  }

  Future<String?> _chooseOption({
    required String title,
    required List<String> options,
    required String selected,
  }) {
    return pushInAppPage<String>(
      context,
      builder: (context) => InAppOptionPage<String>(
        title: title,
        options: [
          for (final option in options)
            InAppPageOption<String>(
              label: option,
              value: option,
              selected: option == selected,
            ),
        ],
      ),
    );
  }

  Future<void> _chooseReminderSound() async {
    final sound = await _chooseOption(
      title: 'Reminder Sound',
      options: const ['Gentle Chime', 'Bell', 'Pulse', 'Silent'],
      selected: _reminderSound,
    );
    if (sound != null && mounted) {
      final previous = _reminderSound;
      setState(() => _reminderSound = sound);
      unawaited(
        _persistPreference(
          'reminderSound',
          sound,
          rollback: () => setState(() => _reminderSound = previous),
        ),
      );
    }
  }

  Future<void> _chooseLanguage() async {
    final language = await _chooseOption(
      title: 'Language',
      options: const ['English', 'Spanish', 'French'],
      selected: _language,
    );
    if (language != null && mounted) {
      final previous = _language;
      setState(() => _language = language);
      unawaited(
        _persistPreference(
          'language',
          language,
          rollback: () => setState(() => _language = previous),
        ),
      );
    }
  }

  Future<void> _chooseUnits() async {
    final units = await _chooseOption(
      title: 'Units',
      options: const ['Metric', 'Imperial'],
      selected: _units,
    );
    if (units != null && mounted) {
      final previous = _units;
      setState(() => _units = units);
      unawaited(
        _persistPreference(
          'units',
          units,
          rollback: () => setState(() => _units = previous),
        ),
      );
    }
  }

  Future<void> _manageAppleHealth() async {
    await pushInAppPage<void>(
      context,
      builder: (context) => InAppPageScaffold(
        title: 'Apple Health',
        child: ListView(
          key: const Key('appleHealthInformationPage'),
          padding: EdgeInsets.zero,
          children: [
            Text(
              'Apple Health is not connected.',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              'Mediary will only offer this connection after HealthKit '
              'permissions and protected data handling are configured.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              key: const Key('appleHealthDoneButton'),
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPrivacyControls() {
    return pushInAppPage<void>(
      context,
      builder: (context) => _PrivacyControlsPage(
        cameraAccess: false,
        onReadCameraAccess: () async =>
            (await Permission.camera.status).isGranted,
        onRequestCameraAccess: Permission.camera.request,
        onOpenAppSettings: openAppSettings,
      ),
    );
  }

  Future<void> _exportData() async {
    if (_isExportingData) return;
    setState(() {
      _isExportingData = true;
      _exportStatusMessage = null;
    });
    unawaited(AppHaptics.primaryAction());
    try {
      final export =
          'Mediary Data Export\n'
          'Account: ${widget.accountEmail ?? 'Local account'}\n'
          'Dose Notifications: ${_doseNotifications ? 'On' : 'Off'}\n'
          'Follow-Up Alerts: ${_followUpAlerts ? 'On' : 'Off'}\n'
          'Units: $_units';
      await Clipboard.setData(ClipboardData(text: export));
      if (!mounted) return;
      setState(() => _exportStatusMessage = 'Copied to device clipboard');
    } catch (_) {
      if (mounted) setState(() => _exportStatusMessage = 'Unable to copy data');
    } finally {
      if (mounted) setState(() => _isExportingData = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showAccount = widget.onOpenAccount != null;

    return Scaffold(
      key: const Key('settingsScreen'),
      backgroundColor: _background,
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: _background,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              leading: Center(
                child: LiquidGlassBackButton(
                  semanticLabel: widget.pageTitle == 'Account'
                      ? 'Back to Settings'
                      : 'Back',
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
              title: Text(
                widget.pageTitle,
                style: TextStyle(
                  color: _ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
      body: SafeArea(
        top: widget.embedded,
        bottom: false,
        child: KeyedSubtree(
          key: const Key('settingsScrollView'),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: responsiveContentWidth(context, nativeMaxWidth: 760),
              ),
              child: ListView(
                key: const PageStorageKey<String>('settingsScrollPosition'),
                scrollCacheExtent: const ScrollCacheExtent.pixels(5000),
                padding: EdgeInsets.fromLTRB(16, 2, 16, widget.bottomPadding),
                children: [
                  if (widget.embedded)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
                      child: Text(
                        'Settings',
                        key: const Key('settingsPageTitle'),
                        style: TextStyle(
                          color: _ink,
                          fontSize: 32,
                          height: 1.08,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.8,
                        ),
                      ),
                    ),
                  if (showAccount) ...[
                    _sectionTitle(
                      'Account',
                      key: const Key('settingsAccountSectionTitle'),
                    ),
                    _group(key: const Key('settingsAccountGroup'), [
                      _AccountSettingsRow(
                        key: const Key('settingsAccountRow'),
                        displayName: widget.accountDisplayName,
                        email: widget.accountEmail,
                        photoUrl: widget.accountPhotoUrl,
                        accent: _accent,
                        muted: _muted,
                        onTap: widget.onOpenAccount,
                      ),
                    ]),
                  ],
                  _sectionTitle(
                    'Reminders',
                    key: const Key('settingsRemindersSectionTitle'),
                  ),
                  _group(key: const Key('settingsRemindersGroup'), [
                    _SettingsRow(
                      icon: CupertinoIcons.bell_fill,
                      iconColor: _accent,
                      title: 'Dose Notifications',
                      subtitle: 'At scheduled times',
                      onTap: () => _setDoseNotifications(!_doseNotifications),
                      trailing: _themedSwitch(
                        key: const Key('doseNotificationsSwitch'),
                        value: _doseNotifications,
                        onChanged: _setDoseNotifications,
                      ),
                    ),
                    _SettingsRow(
                      icon: CupertinoIcons.arrow_counterclockwise,
                      iconColor: _accent,
                      title: 'Follow-Up Alert',
                      subtitle: 'After 15 minutes',
                      onTap: () => _setFollowUpAlerts(!_followUpAlerts),
                      trailing: _themedSwitch(
                        key: const Key('followUpAlertSwitch'),
                        value: _followUpAlerts,
                        onChanged: _setFollowUpAlerts,
                      ),
                    ),
                    _SettingsRow(
                      icon: CupertinoIcons.speaker_2_fill,
                      iconColor: _accent,
                      title: 'Reminder Sound',
                      subtitle: _reminderSound,
                      trailing: _chevron(),
                      onTap: _chooseReminderSound,
                    ),
                  ]),
                  _sectionTitle(
                    'App Preferences',
                    key: const Key('settingsAppPreferencesSectionTitle'),
                  ),
                  _group(key: const Key('settingsAppPreferencesGroup'), [
                    _SettingsRow(
                      icon: CupertinoIcons.globe,
                      iconColor: _accent,
                      title: 'Language',
                      subtitle: 'Display language',
                      trailing: _value(_language),
                      onTap: _chooseLanguage,
                    ),
                    _SettingsRow(
                      icon: CupertinoIcons.gauge,
                      iconColor: _accent,
                      title: 'Units',
                      subtitle: 'Measurements',
                      trailing: _value(_units),
                      onTap: _chooseUnits,
                    ),
                  ]),
                  _sectionTitle(
                    'Appearance',
                    key: const Key('settingsAppearanceSectionTitle'),
                  ),
                  _group(key: const Key('settingsAppearanceGroup'), [
                    Column(
                      children: [
                        Padding(
                          key: const Key('appearanceOptionsPanel'),
                          padding: const EdgeInsets.all(12),
                          child: LiquidGlassAppearanceSelector(
                            value: _appearanceMode,
                            onChanged: _setAppearanceMode,
                          ),
                        ),
                        Divider(height: 1, color: _line),
                        Padding(
                          key: const Key('accentColorOptionsPanel'),
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Accent Color',
                                      style: TextStyle(
                                        color: _ink,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _accentColor.label,
                                    key: const Key('selectedAccentColorLabel'),
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              LiquidGlassAccentSelector(
                                value: _accentColor,
                                onChanged: _setAccentColor,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ]),
                  _sectionTitle(
                    'Connected Apps',
                    key: const Key('settingsConnectedAppsSectionTitle'),
                  ),
                  _group(key: const Key('settingsConnectedAppsGroup'), [
                    _SettingsRow(
                      icon: CupertinoIcons.heart_fill,
                      // Apple Health uses a white tile with its red heart mark,
                      // independent of Mediary's current accent color.
                      iconWidget: const _AppleHealthIcon(
                        color: Color(0xFFFF2D55),
                      ),
                      iconColor: const Color(0xFFFF2D55),
                      title: 'Apple Health',
                      subtitle: _appleHealthConnected
                          ? 'Connected'
                          : 'Not connected',
                      trailing: Text(
                        _appleHealthConnected ? 'On' : 'Off',
                        style: TextStyle(
                          color: _appleHealthConnected ? _success : _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: _manageAppleHealth,
                    ),
                  ]),
                  _sectionTitle(
                    'Privacy',
                    key: const Key('settingsPrivacySectionTitle'),
                  ),
                  _group(key: const Key('settingsPrivacyGroup'), [
                    _SettingsRow(
                      icon: CupertinoIcons.lock_fill,
                      iconColor: _accent,
                      title: 'Privacy Controls',
                      subtitle: 'Camera, health, analytics',
                      trailing: _chevron(),
                      onTap: _showPrivacyControls,
                    ),
                    _SettingsRow(
                      key: const Key('exportDataButton'),
                      icon: CupertinoIcons.square_arrow_up_fill,
                      iconColor: _accent,
                      title: 'Export My Data',
                      subtitle:
                          _exportStatusMessage ?? 'Copy an account summary',
                      trailing: _isExportingData
                          ? SizedBox.square(
                              key: const Key('exportDataLoadingIndicator'),
                              dimension: 17,
                              child: CircularProgressIndicator(
                                value: .72,
                                strokeWidth: 1.8,
                                color: _accent,
                              ),
                            )
                          : _exportStatusMessage != null
                          ? Icon(
                              key: const Key('exportDataStatusIndicator'),
                              _exportStatusMessage ==
                                      'Copied to device clipboard'
                                  ? CupertinoIcons.check_mark_circled_solid
                                  : CupertinoIcons.exclamationmark_circle_fill,
                              color:
                                  _exportStatusMessage ==
                                      'Copied to device clipboard'
                                  ? _success
                                  : _colors.error,
                              size: 18,
                            )
                          : _chevron(),
                      onTap: _isExportingData ? null : _exportData,
                    ),
                  ]),
                  const SizedBox(height: 13),
                  Text(
                    'Mediary 1.0.0 · Reference only',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 10, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String label, {Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(2, 20, 2, 8),
      child: Text(
        label,
        style: TextStyle(
          color: _ink,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -.25,
        ),
      ),
    );
  }

  Widget _group(List<Widget> rows, {Key? key}) {
    return ClipRRect(
      key: key,
      borderRadius: BorderRadius.circular(AppRadii.standard),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.standard),
            color: _dark
                ? const Color(0xFF1F2025).withValues(alpha: .92)
                : Colors.white.withValues(alpha: .88),
            border: Border.all(
              color: _dark
                  ? Colors.white.withValues(alpha: .14)
                  : Colors.white.withValues(alpha: .72),
              width: .8,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                for (var index = 0; index < rows.length; index++) ...[
                  rows[index],
                  if (index < rows.length - 1)
                    Divider(height: 1, indent: 52, color: _line),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chevron() =>
      Icon(CupertinoIcons.chevron_right, color: _muted, size: 15);

  Widget _themedSwitch({
    required Key key,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return LiquidGlassSwitch(key: key, value: value, onChanged: onChanged);
  }

  Widget _value(String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: _muted, fontSize: 11)),
        const SizedBox(width: 5),
        _chevron(),
      ],
    );
  }
}

class _PrivacyControlsPage extends StatefulWidget {
  const _PrivacyControlsPage({
    required this.cameraAccess,
    required this.onReadCameraAccess,
    required this.onRequestCameraAccess,
    required this.onOpenAppSettings,
  });

  final bool cameraAccess;
  final Future<bool> Function() onReadCameraAccess;
  final Future<PermissionStatus> Function() onRequestCameraAccess;
  final Future<bool> Function() onOpenAppSettings;

  @override
  State<_PrivacyControlsPage> createState() => _PrivacyControlsPageState();
}

class _PrivacyControlsPageState extends State<_PrivacyControlsPage> {
  late bool _cameraAccess = widget.cameraAccess;
  bool _cameraBusy = false;
  String? _cameraStatus;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshCameraAccess());
  }

  Future<void> _refreshCameraAccess() async {
    try {
      final allowed = await widget.onReadCameraAccess();
      if (mounted && allowed != _cameraAccess) {
        setState(() => _cameraAccess = allowed);
      }
    } catch (_) {
      // Some preview/test platforms do not provide a permission backend.
    }
  }

  Future<void> _manageCameraAccess() async {
    if (_cameraBusy) return;
    setState(() {
      _cameraBusy = true;
      _cameraStatus = null;
    });
    try {
      if (_cameraAccess) {
        final opened = await widget.onOpenAppSettings();
        if (!mounted) return;
        setState(() {
          _cameraStatus = opened
              ? 'Use device settings to review or revoke camera access.'
              : 'Unable to open device settings.';
        });
        return;
      }

      final status = await widget.onRequestCameraAccess();
      if (!mounted) return;
      if (status.isGranted) {
        setState(() {
          _cameraAccess = true;
          _cameraStatus = 'Camera access allowed.';
        });
      } else if (status.isPermanentlyDenied || status.isRestricted) {
        final opened = await widget.onOpenAppSettings();
        if (!mounted) return;
        setState(() {
          _cameraStatus = opened
              ? 'Use device settings to allow camera access.'
              : 'Camera access remains off.';
        });
      } else {
        setState(() => _cameraStatus = 'Camera access remains off.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _cameraStatus = 'Unable to update camera access.');
      }
    } finally {
      if (mounted) setState(() => _cameraBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InAppPageScaffold(
      key: const Key('privacyControlsPage'),
      title: 'Privacy Controls',
      actions: [
        TextButton(
          key: const Key('privacyControlsDoneButton'),
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Done'),
        ),
        const SizedBox(width: 8),
      ],
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Text(
            'Camera access is managed by your device. Integrations that are '
            'not configured remain off.',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.standard),
            child: Material(
              color: colors.surface,
              child: Column(
                children: [
                  ListTile(
                    key: const Key('cameraAccessControl'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    hoverColor: colors.primary.withValues(alpha: .07),
                    focusColor: colors.primary.withValues(alpha: .10),
                    splashColor: colors.primary.withValues(alpha: .12),
                    title: const Text('Camera Access'),
                    subtitle: Text(
                      _cameraStatus ??
                          (_cameraAccess
                              ? 'Allowed by device settings'
                              : 'Off until you allow it'),
                    ),
                    trailing: _cameraBusy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _cameraAccess ? 'Manage' : 'Allow',
                            style: TextStyle(
                              color: colors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                    onTap: _cameraBusy ? null : _manageCameraAccess,
                  ),
                  const _PrivacyDivider(key: Key('privacyControlDivider0')),
                  const _PrivacySwitchRow(
                    title: 'Health Data',
                    subtitle: 'Not connected in this build',
                    value: false,
                    onChanged: null,
                  ),
                  const _PrivacyDivider(key: Key('privacyControlDivider1')),
                  const _PrivacySwitchRow(
                    title: 'Anonymous Analytics',
                    subtitle: 'No analytics service is installed',
                    value: false,
                    onChanged: null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountSettingsRow extends StatelessWidget {
  const _AccountSettingsRow({
    super.key,
    required this.displayName,
    required this.email,
    required this.photoUrl,
    required this.accent,
    required this.muted,
    required this.onTap,
  });

  final String? displayName;
  final String? email;
  final String? photoUrl;
  final Color accent;
  final Color muted;
  final VoidCallback? onTap;

  String get _name {
    final trimmedName = displayName?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) return trimmedName;
    final trimmedEmail = email?.trim();
    if (trimmedEmail != null && trimmedEmail.isNotEmpty) {
      final localPart = trimmedEmail.split('@').first;
      if (localPart.isNotEmpty) return localPart;
    }
    return 'Account';
  }

  String get _initials {
    final parts = _name.split(RegExp(r'\s+'));
    final first = parts.first.isEmpty ? '' : parts.first[0];
    final last = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final trimmedEmail = email?.trim();
    return Semantics(
      button: onTap != null,
      label: 'Open Account',
      child: AppPressable(
        onPressed: onTap,
        semanticLabel: 'Open Account',
        borderRadius: BorderRadius.zero,
        hoverScale: 1,
        hoverOffset: Offset.zero,
        pressedScale: .99,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _AccountAvatar(
                  photoUrl: photoUrl,
                  initials: _initials,
                  accent: accent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _name,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (trimmedEmail != null && trimmedEmail.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          trimmedEmail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: muted, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(CupertinoIcons.chevron_right, color: muted, size: 15),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({
    required this.photoUrl,
    required this.initials,
    required this.accent,
  });

  final String? photoUrl;
  final String initials;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = photoUrl?.trim();
    final profileImage = safeProfileImageProvider(trimmedUrl, cacheWidth: 132);
    final fallback = ColoredBox(
      color: accent.withValues(alpha: .13),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: accent,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
    if (profileImage == null) {
      return SizedBox.square(dimension: 44, child: ClipOval(child: fallback));
    }
    return SizedBox.square(
      dimension: 44,
      child: ClipOval(
        child: Image(
          image: profileImage,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => fallback,
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.iconWidget,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;
  final Widget? iconWidget;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: onTap != null,
      child: AppPressable(
        onPressed: onTap,
        semanticLabel: title,
        borderRadius: BorderRadius.zero,
        hoverScale: 1,
        hoverOffset: Offset.zero,
        pressedScale: .99,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 58),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Center(
                    child: iconWidget ?? Icon(icon, color: iconColor, size: 18),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Native-style Apple Health mark: a white tile, red heart, and ECG pulse.
/// Keeping it dedicated avoids reducing the branded mark to a generic glyph.
class _AppleHealthIcon extends StatelessWidget {
  const _AppleHealthIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      key: const Key('appleHealthIcon'),
      dimension: 24,
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadii.small)),
        child: ColoredBox(
          color: Colors.white,
          child: CustomPaint(painter: _AppleHealthIconPainter(color)),
        ),
      ),
    );
  }
}

class _AppleHealthIconPainter extends CustomPainter {
  const _AppleHealthIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 22;
    final heart = Path()
      ..moveTo(11 * scale, 18 * scale)
      ..cubicTo(
        9.1 * scale,
        16.4 * scale,
        4 * scale,
        13.4 * scale,
        4 * scale,
        8.3 * scale,
      )
      ..cubicTo(
        4 * scale,
        5.8 * scale,
        5.7 * scale,
        4.2 * scale,
        7.8 * scale,
        4.2 * scale,
      )
      ..cubicTo(
        9.1 * scale,
        4.2 * scale,
        10.3 * scale,
        4.9 * scale,
        11 * scale,
        6 * scale,
      )
      ..cubicTo(
        11.7 * scale,
        4.9 * scale,
        12.9 * scale,
        4.2 * scale,
        14.2 * scale,
        4.2 * scale,
      )
      ..cubicTo(
        16.3 * scale,
        4.2 * scale,
        18 * scale,
        5.8 * scale,
        18 * scale,
        8.3 * scale,
      )
      ..cubicTo(
        18 * scale,
        13.4 * scale,
        12.9 * scale,
        16.4 * scale,
        11 * scale,
        18 * scale,
      )
      ..close();

    canvas.drawPath(heart, Paint()..color = color);
    canvas.save();
    canvas.clipPath(heart);
    final pulse = Path()
      ..moveTo(3.5 * scale, 10.1 * scale)
      ..lineTo(7.5 * scale, 10.1 * scale)
      ..lineTo(9.1 * scale, 7.5 * scale)
      ..lineTo(11 * scale, 13.5 * scale)
      ..lineTo(12.7 * scale, 10.1 * scale)
      ..lineTo(18.5 * scale, 10.1 * scale);
    canvas.drawPath(
      pulse,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.15 * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AppleHealthIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _PrivacyDivider extends StatelessWidget {
  const _PrivacyDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: .5,
      indent: 16,
      endIndent: 16,
      color: Theme.of(context).colorScheme.outlineVariant
          .withValues(alpha: .65),
    );
  }
}

class _PrivacySwitchRow extends StatelessWidget {
  const _PrivacySwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}
