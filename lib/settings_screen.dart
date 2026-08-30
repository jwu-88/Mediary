import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
  static const _blue = Color(0xFF0A62D0);
  static const _green = Color(0xFF248A3D);
  static const _red = Color(0xFFD12E26);

  late bool _darkModeEnabled = widget.darkModeEnabled;
  bool _doseNotifications = true;
  bool _followUpAlerts = true;
  bool _isSigningOut = false;

  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _background =>
      _dark ? const Color(0xFF101418) : const Color(0xFFF2F2F7);
  Color get _surface => _dark ? const Color(0xFF1C1C1E) : Colors.white;
  Color get _ink => _dark ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E);
  Color get _muted => _dark ? const Color(0xFFB8B8BE) : const Color(0xFF5F5F65);
  Color get _line => _dark ? const Color(0xFF3A3A3C) : const Color(0xFFD9D9DE);

  Future<void> _signOut() async {
    if (_isSigningOut || widget.onSignOut == null) return;
    setState(() => _isSigningOut = true);
    try {
      await widget.onSignOut!();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  void _setDarkMode(bool enabled) {
    setState(() => _darkModeEnabled = enabled);
    widget.onDarkModeChanged(enabled);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Back to profile',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(CupertinoIcons.chevron_left, color: _blue, size: 21),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            color: _ink,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 28),
          children: [
            _sectionTitle('Reminders'),
            _group([
              _SettingsRow(
                icon: CupertinoIcons.bell_fill,
                iconColor: _blue,
                title: 'Dose notifications',
                subtitle: 'Notify at scheduled times',
                trailing: CupertinoSwitch(
                  key: const Key('doseNotificationsSwitch'),
                  value: _doseNotifications,
                  activeTrackColor: _blue,
                  onChanged: (value) =>
                      setState(() => _doseNotifications = value),
                ),
              ),
              _SettingsRow(
                icon: CupertinoIcons.arrow_counterclockwise,
                iconColor: _blue,
                title: 'Follow-up alert',
                subtitle: 'Remind me after 15 minutes',
                trailing: CupertinoSwitch(
                  key: const Key('followUpAlertSwitch'),
                  value: _followUpAlerts,
                  activeTrackColor: _blue,
                  onChanged: (value) => setState(() => _followUpAlerts = value),
                ),
              ),
              _SettingsRow(
                icon: CupertinoIcons.speaker_2_fill,
                iconColor: _blue,
                title: 'Reminder sound',
                subtitle: 'Gentle chime',
                trailing: _chevron(),
              ),
            ]),
            _sectionTitle('App preferences'),
            _group([
              _SettingsRow(
                icon: CupertinoIcons.globe,
                iconColor: _blue,
                title: 'Language',
                subtitle: 'App display language',
                trailing: _value('English'),
              ),
              _SettingsRow(
                icon: CupertinoIcons.gauge,
                iconColor: _blue,
                title: 'Units',
                subtitle: 'Medication measurements',
                trailing: _value('Metric'),
              ),
              _SettingsRow(
                icon: CupertinoIcons.moon_fill,
                iconColor: _blue,
                title: 'Dark appearance',
                subtitle: 'Follow system settings',
                trailing: CupertinoSwitch(
                  key: const Key('darkModeSwitch'),
                  value: _darkModeEnabled,
                  activeTrackColor: _blue,
                  onChanged: _setDarkMode,
                ),
              ),
            ]),
            _sectionTitle('Privacy & integrations'),
            _group([
              _SettingsRow(
                icon: CupertinoIcons.heart_fill,
                iconColor: _green,
                title: 'Apple Health',
                subtitle: 'Connected',
                trailing: const Text(
                  'On',
                  style: TextStyle(
                    color: _green,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _SettingsRow(
                icon: CupertinoIcons.lock_fill,
                iconColor: _blue,
                title: 'Privacy controls',
                subtitle: 'Camera, health data, analytics',
                trailing: _chevron(),
              ),
              _SettingsRow(
                icon: CupertinoIcons.square_arrow_up_fill,
                iconColor: _blue,
                title: 'Export my data',
                subtitle: 'Download a secure copy',
                trailing: _chevron(),
              ),
            ]),
            if (widget.onSignOut != null) ...[
              const SizedBox(height: 16),
              Material(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  key: const Key('settingsSignOutButton'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: _isSigningOut ? null : _signOut,
                  child: SizedBox(
                    height: 48,
                    child: Center(
                      child: _isSigningOut
                          ? const CupertinoActivityIndicator()
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.arrow_right_square,
                                  color: _red,
                                  size: 18,
                                ),
                                SizedBox(width: 7),
                                Text(
                                  'Sign out',
                                  style: TextStyle(
                                    color: _red,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 13),
            Text(
              widget.accountEmail == null
                  ? 'Flutter 1.0.0 · Medical information is for reference only'
                  : '${widget.accountEmail}\nFlutter 1.0.0 · Medical information is for reference only',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 10, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String label) {
    return Padding(
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

  Widget _group(List<Widget> rows) {
    return ClipRRect(
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

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E);
    final muted = dark ? const Color(0xFFB8B8BE) : const Color(0xFF5F5F65);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 58),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            SizedBox(width: 28, child: Icon(icon, color: iconColor, size: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: muted, fontSize: 10)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}
