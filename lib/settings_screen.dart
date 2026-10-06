import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app_controls.dart';
import 'app_theme.dart';
import 'app_legal.dart';
import 'app_interactions.dart';
import 'app_layout.dart';
import 'data/mediary_models.dart';
import 'in_app_page.dart';
import 'liquid_glass_back_button.dart';
import 'liquid_glass_switch.dart';
import 'profile_image_policy.dart';
import 'time_formatting.dart';

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
    this.timeDisplayFormat = TimeDisplayFormat.twelveHour,
    this.onTimeDisplayFormatChanged,
    this.onSendTestNotification,
    this.onReadNotificationPermission,
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
  final TimeDisplayFormat timeDisplayFormat;
  final ValueChanged<TimeDisplayFormat>? onTimeDisplayFormatChanged;
  final Future<void> Function()? onSendTestNotification;
  final Future<String> Function()? onReadNotificationPermission;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late ThemeMode _appearanceMode = widget.appearanceMode;
  late AppAccentColor _accentColor = widget.accentColor;
  late bool _doseNotifications =
      widget.initialPreferences?.doseNotifications ?? true;
  late bool _followUpAlerts = widget.initialPreferences?.followUpAlerts ?? true;
  bool _isExportingData = false;
  String? _exportStatusMessage;
  String? _notificationStatusMessage;
  String _notificationPermissionState = 'unknown';
  late String _reminderSound =
      widget.initialPreferences?.reminderSound ?? 'Gentle Chime';
  late String _units = widget.initialPreferences?.units ?? 'Metric';
  late TimeDisplayFormat _timeDisplayFormat = widget.timeDisplayFormat;

  @override
  void initState() {
    super.initState();
    unawaited(_readNotificationPermission());
  }

  Future<void> _readNotificationPermission() async {
    final callback = widget.onReadNotificationPermission;
    if (callback == null) return;
    final state = await callback();
    if (mounted) setState(() => _notificationPermissionState = state);
  }

  String get _appearanceLabel => switch (_appearanceMode) {
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
    ThemeMode.system => 'System',
  };

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
    if (oldWidget.timeDisplayFormat != widget.timeDisplayFormat) {
      _timeDisplayFormat = widget.timeDisplayFormat;
    }
    final oldPreferences = oldWidget.initialPreferences;
    final preferences = widget.initialPreferences;
    if (preferences != null &&
        (oldPreferences == null ||
            oldPreferences.doseNotifications != preferences.doseNotifications ||
            oldPreferences.followUpAlerts != preferences.followUpAlerts ||
            oldPreferences.reminderSound != preferences.reminderSound ||
            oldPreferences.units != preferences.units ||
            oldPreferences.timeFormat != preferences.timeFormat)) {
      _doseNotifications = preferences.doseNotifications;
      _followUpAlerts = preferences.followUpAlerts;
      _reminderSound = preferences.reminderSound;
      _units = preferences.units;
      _timeDisplayFormat = TimeDisplayFormat.fromPreference(
        preferences.timeFormat,
      );
    }
  }

  void _setAppearanceMode(ThemeMode mode) {
    if (mode == _appearanceMode) return;
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
    if (accent == _accentColor) return;
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

  Future<void> _sendTestNotification() async {
    final callback = widget.onSendTestNotification;
    if (callback == null) return;
    try {
      await callback();
      if (mounted) {
        setState(() => _notificationStatusMessage = 'Test notification sent');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _notificationStatusMessage = 'Unable to send test notification',
        );
      }
    }
  }

  Future<String?> _chooseOption({
    required String title,
    required List<String> options,
    required String selected,
    bool dismissOnSelect = true,
    bool showUnselectedIndicator = false,
    ValueChanged<String>? onChanged,
  }) {
    return pushInAppPage<String>(
      context,
      builder: (context) => InAppOptionPage<String>(
        title: title,
        dismissOnSelect: dismissOnSelect,
        showUnselectedIndicator: showUnselectedIndicator,
        onChanged: onChanged,
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

  Future<void> _chooseTimeFormat() async {
    final selected = await _chooseOption(
      title: 'Time Format',
      options: const ['12-hour', '24-hour'],
      selected: _timeDisplayFormat.label,
    );
    if (selected == null || !mounted) return;
    final next = TimeDisplayFormat.fromPreference(selected);
    if (next == _timeDisplayFormat) return;
    setState(() => _timeDisplayFormat = next);
    widget.onTimeDisplayFormatChanged?.call(next);
    unawaited(_persistPreference('timeFormat', next.preferenceValue));
  }

  Future<void> _chooseAppearance() async {
    await _chooseOption(
      title: 'Appearance',
      options: const ['Light', 'Dark', 'System'],
      selected: _appearanceLabel,
      dismissOnSelect: false,
      showUnselectedIndicator: false,
      onChanged: (appearance) => _setAppearanceMode(switch (appearance) {
        'Light' => ThemeMode.light,
        'Dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      }),
    );
  }

  Future<void> _chooseAccentColor() async {
    await _chooseOption(
      title: 'Accent Color',
      options: [for (final accent in AppAccentColor.values) accent.label],
      selected: _accentColor.label,
      dismissOnSelect: false,
      showUnselectedIndicator: false,
      onChanged: (accentLabel) {
        final accent = AppAccentColor.values.firstWhere(
          (value) => value.label == accentLabel,
          orElse: () => _accentColor,
        );
        _setAccentColor(accent);
      },
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

  void _openLegalPage(Widget page) {
    unawaited(pushInAppPage<void>(context, builder: (_) => page));
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
              centerTitle: false,
              titleSpacing: 4,
              toolbarHeight:
                  64 +
                  (MediaQuery.textScalerOf(context).scale(22) - 22).clamp(
                    0,
                    44,
                  ),
              leadingWidth: 64,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.pageTitle.copyWith(color: _ink),
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
                maxWidth: responsiveContentWidth(context, nativeMaxWidth: 1120),
              ),
              child: ListView(
                key: const PageStorageKey<String>('settingsScrollPosition'),
                scrollCacheExtent: const ScrollCacheExtent.pixels(5000),
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.pageGutterOf(context),
                  AppSpacing.sm,
                  AppSpacing.pageGutterOf(context),
                  widget.bottomPadding,
                ),
                children: [
                  if (widget.embedded)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      child: Text(
                        'Settings',
                        key: const Key('settingsPageTitle'),
                        style: AppTextStyles.pageTitle.copyWith(color: _ink),
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
                      subtitle:
                          _notificationStatusMessage ??
                          switch (_notificationPermissionState) {
                            'granted' => 'Browser alerts enabled',
                            'denied' => 'Browser alerts blocked; in-app reminders stay on',
                            'default' => 'Permission needed for browser alerts',
                            'available' => 'Device alerts available',
                            _ => 'At scheduled times',
                          },
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
                    if (widget.onSendTestNotification != null)
                      _SettingsRow(
                        key: const Key('sendTestNotificationRow'),
                        icon: CupertinoIcons.bell_circle_fill,
                        iconColor: _accent,
                        title: 'Send Test Notification',
                        subtitle: 'Verify alerts on this device',
                        trailing: _chevron(),
                        onTap: _sendTestNotification,
                      ),
                  ]),
                  _sectionTitle(
                    'App Preferences',
                    key: const Key('settingsAppPreferencesSectionTitle'),
                  ),
                  _group(key: const Key('settingsAppPreferencesGroup'), [
                    _SettingsRow(
                      icon: CupertinoIcons.gauge,
                      iconColor: _accent,
                      title: 'Units',
                      subtitle: 'Measurements',
                      trailing: _value(_units),
                      onTap: _chooseUnits,
                    ),
                    _SettingsRow(
                      key: const Key('timeFormatSettingRow'),
                      icon: CupertinoIcons.clock,
                      iconColor: _accent,
                      title: 'Time Format',
                      subtitle: 'How medication times are displayed',
                      trailing: _value(_timeDisplayFormat.label),
                      onTap: _chooseTimeFormat,
                    ),
                  ]),
                  _sectionTitle(
                    'Appearance',
                    key: const Key('settingsAppearanceSectionTitle'),
                  ),
                  _group(key: const Key('settingsAppearanceGroup'), [
                    _SettingsRow(
                      key: const Key('appearanceSettingRow'),
                      icon: CupertinoIcons.circle_lefthalf_fill,
                      iconColor: _accent,
                      title: 'Theme',
                      subtitle: 'Light, dark, or system',
                      trailing: _value(_appearanceLabel),
                      onTap: _chooseAppearance,
                    ),
                    _SettingsRow(
                      key: const Key('accentColorSettingRow'),
                      icon: CupertinoIcons.paintbrush_fill,
                      iconColor: _accent,
                      title: 'Accent Color',
                      subtitle: 'Customize the app color',
                      trailing: _value(_accentColor.label),
                      onTap: _chooseAccentColor,
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
                      subtitle: 'Camera and data preferences',
                      trailing: _chevron(),
                      onTap: _showPrivacyControls,
                    ),
                    if (kIsWeb)
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
                                dimension:
                                    AppButtonMetrics.loadingIndicatorSize,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _accent,
                                ),
                              )
                            : _exportStatusMessage != null
                            ? Icon(
                                key: const Key('exportDataStatusIndicator'),
                                _exportStatusMessage ==
                                        'Copied to device clipboard'
                                    ? CupertinoIcons.check_mark_circled_solid
                                    : CupertinoIcons
                                          .exclamationmark_circle_fill,
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
                  _sectionTitle(
                    'Legal & Support',
                    key: const Key('settingsLegalSectionTitle'),
                  ),
                  _group(key: const Key('settingsLegalGroup'), [
                    _SettingsRow(
                      icon: CupertinoIcons.doc_text,
                      iconColor: _accent,
                      title: 'Privacy Policy',
                      subtitle: 'How Mediary handles information',
                      trailing: _chevron(),
                      onTap: () => _openLegalPage(const PrivacyPolicyPage()),
                    ),
                    _SettingsRow(
                      icon: CupertinoIcons.doc_plaintext,
                      iconColor: _accent,
                      title: 'Terms of Use',
                      subtitle: 'Rules for using Mediary',
                      trailing: _chevron(),
                      onTap: () => _openLegalPage(const TermsPage()),
                    ),
                    _SettingsRow(
                      icon: CupertinoIcons.mail,
                      iconColor: _accent,
                      title: 'Contact Support',
                      subtitle: mediarySupportEmail.isEmpty
                          ? 'Support contact not configured'
                          : mediarySupportEmail,
                      trailing: _chevron(),
                      onTap: () => _openLegalPage(const ContactSupportPage()),
                    ),
                  ]),
                  const SizedBox(height: 13),
                  Text(
                    'Mediary 1.0.0 · Reference only',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
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
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
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
      child: WebAwareBlur(
        sigma: 18,
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: AppTextStyles.caption.copyWith(color: _muted),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          _chevron(),
        ],
      ),
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
        AppButton(
          key: const Key('privacyControlsDoneButton'),
          label: 'Done',
          compact: true,
          variant: AppButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 8),
      ],
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Text(
            'Camera access is managed by your device. Integrations that are '
            'not configured remain off.',
            style: AppTextStyles.body.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.standard),
            child: Material(
              color: colors.surface,
              child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final action = AppButton(
                        label: _cameraAccess ? 'Manage' : 'Allow',
                        variant: AppButtonVariant.secondary,
                        compact: true,
                        busy: _cameraBusy,
                        loadingLabel: 'Updating',
                        onPressed: _cameraBusy ? null : _manageCameraAccess,
                      );
                      final description =
                          _cameraStatus ??
                          (_cameraAccess
                              ? 'Allowed by device settings'
                              : 'Off until you allow it');
                      if (MediaQuery.textScalerOf(context).scale(15) > 21) {
                        return Padding(
                          key: const Key('cameraAccessControl'),
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Camera Access',
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                description,
                                style: AppTextStyles.body.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              action,
                            ],
                          ),
                        );
                      }
                      return ListTile(
                        key: const Key('cameraAccessControl'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        hoverColor: colors.primary.withValues(alpha: .07),
                        focusColor: colors.primary.withValues(alpha: .10),
                        splashColor: colors.primary.withValues(alpha: .12),
                        title: const Text('Camera Access'),
                        subtitle: Text(description),
                        trailing: action,
                        onTap: _cameraBusy ? null : _manageCameraAccess,
                      );
                    },
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
                          style: TextStyle(color: muted, fontSize: 12),
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
          semanticLabel: 'Account profile photo',
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
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;
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
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final text = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.body.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
                final identity = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 28,
                      child: Center(
                        child: Icon(icon, color: iconColor, size: 20),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: text),
                  ],
                );
                if (MediaQuery.textScalerOf(context).scale(15) > 21) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      identity,
                      const SizedBox(height: AppSpacing.sm),
                      Align(alignment: Alignment.centerRight, child: trailing),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: AppSpacing.sm),
                    trailing,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
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
