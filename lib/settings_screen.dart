import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'liquid_glass_accent_selector.dart';
import 'liquid_glass_appearance_selector.dart';
import 'liquid_glass_back_button.dart';

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

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late ThemeMode _appearanceMode = widget.appearanceMode;
  late AppAccentColor _accentColor = widget.accentColor;
  bool _doseNotifications = true;
  bool _followUpAlerts = true;
  bool _appleHealthConnected = true;
  bool _cameraAccess = true;
  bool _healthDataAccess = true;
  bool _analyticsEnabled = false;
  String _reminderSound = 'Gentle Chime';
  String _language = 'English';
  String _units = 'Metric';

  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  ColorScheme get _colors => Theme.of(context).colorScheme;
  Color get _background => Theme.of(context).scaffoldBackgroundColor;
  Color get _surface => _colors.surface;
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
  }

  void _setAppearanceMode(ThemeMode mode) {
    setState(() => _appearanceMode = mode);
    widget.onAppearanceModeChanged(mode);
  }

  void _setAccentColor(AppAccentColor accent) {
    setState(() => _accentColor = accent);
    widget.onAccentColorChanged(accent);
  }

  Future<String?> _chooseOption({
    required String title,
    required List<String> options,
    required String selected,
  }) {
    return showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(title),
        actions: [
          for (final option in options)
            CupertinoActionSheetAction(
              isDefaultAction: option == selected,
              onPressed: () => Navigator.pop(context, option),
              child: Text(option),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _chooseReminderSound() async {
    final sound = await _chooseOption(
      title: 'Reminder Sound',
      options: const ['Gentle Chime', 'Bell', 'Pulse', 'Silent'],
      selected: _reminderSound,
    );
    if (sound != null && mounted) setState(() => _reminderSound = sound);
  }

  Future<void> _chooseLanguage() async {
    final language = await _chooseOption(
      title: 'Language',
      options: const ['English', 'Spanish', 'French'],
      selected: _language,
    );
    if (language != null && mounted) setState(() => _language = language);
  }

  Future<void> _chooseUnits() async {
    final units = await _chooseOption(
      title: 'Units',
      options: const ['Metric', 'Imperial'],
      selected: _units,
    );
    if (units != null && mounted) setState(() => _units = units);
  }

  Future<void> _manageAppleHealth() async {
    final change = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Apple Health'),
        message: Text(
          _appleHealthConnected
              ? 'Mediary can read health data you approve.'
              : 'Connect to share approved health data with Mediary.',
        ),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: _appleHealthConnected,
            onPressed: () => Navigator.pop(context, !_appleHealthConnected),
            child: Text(_appleHealthConnected ? 'Disconnect' : 'Connect'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (change != null && mounted) {
      setState(() => _appleHealthConnected = change);
    }
  }

  Future<void> _showPrivacyControls() {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Privacy Controls',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              _PrivacySwitchRow(
                title: 'Camera Access',
                value: _cameraAccess,
                onChanged: (value) {
                  setState(() => _cameraAccess = value);
                  setSheetState(() {});
                },
              ),
              _PrivacyDivider(key: Key('privacyControlDivider0')),
              _PrivacySwitchRow(
                title: 'Health Data',
                value: _healthDataAccess,
                onChanged: (value) {
                  setState(() => _healthDataAccess = value);
                  setSheetState(() {});
                },
              ),
              _PrivacyDivider(key: Key('privacyControlDivider1')),
              _PrivacySwitchRow(
                title: 'Anonymous Analytics',
                value: _analyticsEnabled,
                onChanged: (value) {
                  setState(() => _analyticsEnabled = value);
                  setSheetState(() {});
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportData() async {
    final export =
        'Mediary Data Export\n'
        'Account: ${widget.accountEmail ?? 'Local account'}\n'
        'Dose Notifications: ${_doseNotifications ? 'On' : 'Off'}\n'
        'Follow-Up Alerts: ${_followUpAlerts ? 'On' : 'Off'}\n'
        'Units: $_units';
    await Clipboard.setData(ClipboardData(text: export));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Data copied securely')));
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
                  onTap: () =>
                      setState(() => _doseNotifications = !_doseNotifications),
                  trailing: _themedSwitch(
                    key: const Key('doseNotificationsSwitch'),
                    value: _doseNotifications,
                    onChanged: (value) =>
                        setState(() => _doseNotifications = value),
                  ),
                ),
                _SettingsRow(
                  icon: CupertinoIcons.arrow_counterclockwise,
                  iconColor: _accent,
                  title: 'Follow-Up Alert',
                  subtitle: 'After 15 minutes',
                  onTap: () =>
                      setState(() => _followUpAlerts = !_followUpAlerts),
                  trailing: _themedSwitch(
                    key: const Key('followUpAlertSwitch'),
                    value: _followUpAlerts,
                    onChanged: (value) =>
                        setState(() => _followUpAlerts = value),
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
                  iconColor: _success,
                  title: 'Apple Health',
                  subtitle: _appleHealthConnected
                      ? 'Connected'
                      : 'Not connected',
                  trailing: Text(
                    _appleHealthConnected ? 'On' : 'Off',
                    style: TextStyle(
                      color: _success,
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
                  subtitle: 'Copy a secure summary',
                  trailing: _chevron(),
                  onTap: _exportData,
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
      borderRadius: BorderRadius.circular(14),
      child: ColoredBox(
        color: _surface,
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
    );
  }

  Widget _chevron() =>
      Icon(CupertinoIcons.chevron_right, color: _muted, size: 15);

  CupertinoSwitch _themedSwitch({
    required Key key,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return CupertinoSwitch(
      key: key,
      value: value,
      activeTrackColor: _accent,
      inactiveTrackColor: _dark
          ? const Color(0xFF48484A)
          : const Color(0xFFE5E5EA),
      thumbColor: _dark ? const Color(0xFFF2F2F7) : Colors.white,
      onChanged: onChanged,
    );
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
      child: InkWell(
        onTap: onTap,
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
    if (trimmedUrl == null || trimmedUrl.isEmpty) {
      return SizedBox.square(dimension: 44, child: ClipOval(child: fallback));
    }
    return SizedBox.square(
      dimension: 44,
      child: ClipOval(
        child: Image.network(
          trimmedUrl,
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
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 58),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Icon(icon, color: iconColor, size: 18),
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
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }
}
