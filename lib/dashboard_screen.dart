import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.now,
    this.bottomPadding = 120,
    this.onViewReport,
    this.onAddMedication,
  });

  final String email;
  final String? displayName;
  final String? photoUrl;
  final DateTime? now;
  final double bottomPadding;
  final VoidCallback? onViewReport;
  final Future<List<String>?> Function()? onAddMedication;

  static const _lightTaken = Color(0xFF279F49);
  static const _darkTaken = Color(0xFF30D158);
  static const _lightOrange = Color(0xFFE77B00);
  static const _darkOrange = Color(0xFFFF9F0A);

  String get _name {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final emailName = email.split('@').first.trim();
    return emailName.isEmpty ? 'there' : emailName;
  }

  String get _initial {
    final parts = _name.split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return _name[0].toUpperCase();
  }

  String get _greetingName => _name.split(RegExp(r'\s+')).first;

  String _formatDate(DateTime date) {
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
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}'
        .toUpperCase();
  }

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final List<_DashboardDose> _doses = [
    const _DashboardDose(
      name: 'Vitamin D3',
      details: '1000 IU · 8:00 AM',
      status: 'Taken',
      tone: _DoseTone.taken,
    ),
    const _DashboardDose(
      name: 'Amoxicillin',
      details: '500 mg · 10:30 AM',
      status: 'Up Next',
      tone: _DoseTone.primary,
    ),
    const _DashboardDose(
      name: 'Cetirizine',
      details: '10 mg · 8:00 PM',
      status: 'Tonight',
      tone: _DoseTone.warning,
    ),
  ];

  Future<void> _showProfile() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Your Profile'),
        message: Text('${widget._name}\n${widget.email}'),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ),
    );
  }

  Future<void> _showWeeklyReport() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Weekly Report'),
        message: const Text(
          '92% adherence\n11 of 12 scheduled doses completed',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showConfirmation('Report Ready');
            },
            child: const Text('Prepare Summary'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ),
    );
  }

  Future<void> _showAddMedication() async {
    final medication = await showCupertinoModalPopup<_DashboardDose>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Add Medication'),
        message: const Text('Choose a medication for today'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(
              context,
              const _DashboardDose(
                name: 'Ibuprofen',
                details: '200 mg · 2:00 PM',
                status: 'Today',
                tone: _DoseTone.primary,
              ),
            ),
            child: const Text('Ibuprofen'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(
              context,
              const _DashboardDose(
                name: 'Vitamin C',
                details: '500 mg · 6:00 PM',
                status: 'Tonight',
                tone: _DoseTone.warning,
              ),
            ),
            child: const Text('Vitamin C'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (!mounted || medication == null) return;
    setState(() => _doses.add(medication));
    _showConfirmation('${medication.name} Added');
  }

  Future<void> _handleAddMedication() async {
    final picker = widget.onAddMedication;
    if (picker == null) {
      await _showAddMedication();
      return;
    }

    final selections = await picker();
    if (!mounted || selections == null || selections.isEmpty) return;
    setState(() {
      for (final name in selections) {
        _doses.add(_doseForSelection(name));
      }
    });
    _showConfirmation(
      selections.length == 1
          ? '${selections.single} Added'
          : '${selections.length} Medications Added',
    );
  }

  _DashboardDose _doseForSelection(String name) {
    return switch (name) {
      'Ibuprofen' => const _DashboardDose(
        name: 'Ibuprofen',
        details: '200 mg · 2:00 PM',
        status: 'Today',
        tone: _DoseTone.primary,
      ),
      'Vitamin C' => const _DashboardDose(
        name: 'Vitamin C',
        details: '500 mg · 6:00 PM',
        status: 'Tonight',
        tone: _DoseTone.warning,
      ),
      _ => _DashboardDose(
        name: name,
        details: 'Dose Not Set · Today',
        status: 'Today',
        tone: _DoseTone.primary,
      ),
    };
  }

  Future<void> _showDoseActions(int index) async {
    final dose = _doses[index];
    final action = await showCupertinoModalPopup<_DoseAction>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(dose.name),
        message: Text(dose.details),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, _DoseAction.toggleTaken),
            child: Text(
              dose.status == 'Taken' ? 'Mark As Due' : 'Mark As Taken',
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, _DoseAction.snooze),
            child: const Text('Remind Me Later'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, _DoseAction.remove),
            child: const Text('Remove From Today'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _DoseAction.toggleTaken:
        setState(() {
          _doses[index] = dose.status == 'Taken'
              ? dose.copyWith(status: 'Due', tone: _DoseTone.primary)
              : dose.copyWith(status: 'Taken', tone: _DoseTone.taken);
        });
        _showConfirmation(
          dose.status == 'Taken' ? 'Dose Marked Due' : 'Dose Taken',
        );
      case _DoseAction.snooze:
        setState(() {
          _doses[index] = dose.copyWith(
            status: 'Later',
            tone: _DoseTone.warning,
          );
        });
        _showConfirmation('Reminder Moved');
      case _DoseAction.remove:
        setState(() => _doses.removeAt(index));
        _showConfirmation('${dose.name} Removed');
    }
  }

  void _showConfirmation(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(widget.now ?? DateTime.now());
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              key: const Key('dashboardScrollView'),
              padding: EdgeInsets.fromLTRB(16, 8, 16, widget.bottomPadding),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget._formatDate(today),
                            key: const Key('dashboardDate'),
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: .35,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Good Morning, ${widget._greetingName}',
                            key: const Key('dashboardGreeting'),
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 27,
                              height: 1.12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.7,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _ProfileAvatar(
                      photoUrl: widget.photoUrl,
                      initials: widget._initial,
                      onPressed: _showProfile,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _SectionHeader(
                  title: 'Weekly Progress',
                  actionLabel: 'View Report',
                  actionKey: const Key('dashboardViewReportButton'),
                  onPressed: widget.onViewReport ?? _showWeeklyReport,
                ),
                const SizedBox(height: 6),
                const _AdherenceSummary(),
                const SizedBox(height: 28),
                _SectionHeader(
                  title: 'Today’s Schedule',
                  actionLabel: 'Add',
                  actionIcon: CupertinoIcons.add,
                  actionKey: const Key('dashboardAddButton'),
                  onPressed: _handleAddMedication,
                ),
                const SizedBox(height: 10),
                _ScheduleTable(doses: _doses, onTapDose: _showDoseActions),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.photoUrl,
    required this.initials,
    required this.onPressed,
  });

  final String? photoUrl;
  final String initials;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fallback = ColoredBox(
      color: colors.primary.withValues(alpha: .14),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: colors.primary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: 'Open Profile',
      child: CupertinoButton(
        onPressed: onPressed,
        minimumSize: const Size.square(44),
        padding: const EdgeInsets.all(1),
        child: ClipOval(
          child: SizedBox.square(
            dimension: 42,
            child: photoUrl == null || photoUrl!.isEmpty
                ? fallback
                : Image.network(
                    photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => fallback,
                  ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    this.actionIcon,
    this.actionKey,
    required this.onPressed,
  });

  final String title;
  final String actionLabel;
  final IconData? actionIcon;
  final Key? actionKey;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -.25,
            ),
          ),
        ),
        TextButton.icon(
          key: actionKey,
          onPressed: onPressed,
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            foregroundColor: colors.primary,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: actionIcon == null
              ? const SizedBox.shrink()
              : Icon(actionIcon, size: 15),
          label: Text(
            actionLabel,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _AdherenceSummary extends StatelessWidget {
  const _AdherenceSummary();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
      child: Row(
        children: [
          const _ProgressRing(value: .92),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You’re right on track!',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '11 of 12 doses taken this week',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final taken = theme.brightness == Brightness.dark
        ? DashboardScreen._darkTaken
        : DashboardScreen._lightTaken;
    return SizedBox.square(
      dimension: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.square(
            dimension: 58,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 6,
              strokeCap: StrokeCap.round,
              backgroundColor: colors.outlineVariant,
              color: taken,
            ),
          ),
          Text(
            '${(value * 100).round()}%',
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleTable extends StatelessWidget {
  const _ScheduleTable({required this.doses, required this.onTapDose});

  final List<_DashboardDose> doses;
  final ValueChanged<int> onTapDose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final taken = theme.brightness == Brightness.dark
        ? DashboardScreen._darkTaken
        : DashboardScreen._lightTaken;
    final orange = theme.brightness == Brightness.dark
        ? DashboardScreen._darkOrange
        : DashboardScreen._lightOrange;
    if (doses.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Text(
          'No medications scheduled',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
        ),
      );
    }
    return Semantics(
      key: const Key('dashboardScheduleTable'),
      container: true,
      label: 'Today’s Medication Schedule',
      child: Column(
        children: [
          const _ScheduleHeader(),
          Divider(
            key: const Key('dashboardScheduleHeaderDivider'),
            height: 13,
            thickness: .5,
            indent: 30,
            endIndent: 2,
            color: colors.outlineVariant.withValues(alpha: .72),
          ),
          for (var index = 0; index < doses.length; index++) ...[
            _DoseRow(
              rowIndex: index,
              name: doses[index].name,
              details: doses[index].details,
              status: doses[index].status,
              iconColor: switch (doses[index].tone) {
                _DoseTone.taken => taken,
                _DoseTone.primary => colors.primary,
                _DoseTone.warning => orange,
              },
              statusColor: doses[index].tone == _DoseTone.taken ? taken : null,
              onTap: () => onTapDose(index),
            ),
            if (index < doses.length - 1)
              Divider(
                key: ValueKey('dashboardScheduleRowDivider$index'),
                height: 1,
                thickness: .5,
                indent: 30,
                endIndent: 2,
                color: colors.outlineVariant.withValues(alpha: .58),
              ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleHeader extends StatelessWidget {
  const _ScheduleHeader();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    const style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: .1,
    );
    return SizedBox(
      height: 30,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          children: [
            const SizedBox(width: 28),
            Expanded(
              flex: 5,
              child: Text('Medication', style: style.copyWith(color: color)),
            ),
            const _ScheduleVerticalDivider(
              dividerKey: Key('dashboardScheduleHeaderVerticalDivider0'),
            ),
            Expanded(
              flex: 5,
              child: Text('Dose & Time', style: style.copyWith(color: color)),
            ),
            const _ScheduleVerticalDivider(
              dividerKey: Key('dashboardScheduleHeaderVerticalDivider1'),
            ),
            SizedBox(
              width: 72,
              child: Text(
                'Status',
                textAlign: TextAlign.end,
                style: style.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleVerticalDivider extends StatelessWidget {
  const _ScheduleVerticalDivider({required this.dividerKey});

  final Key dividerKey;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 17,
      child: VerticalDivider(
        key: dividerKey,
        width: 1,
        thickness: .5,
        color: colors.outlineVariant.withValues(alpha: .62),
      ),
    );
  }
}

class _DoseRow extends StatelessWidget {
  const _DoseRow({
    required this.rowIndex,
    required this.name,
    required this.details,
    required this.status,
    required this.iconColor,
    this.statusColor,
    required this.onTap,
  });

  final int rowIndex;
  final String name;
  final String details;
  final String status;
  final Color iconColor;
  final Color? statusColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final resolvedStatusColor = statusColor ?? colors.onSurfaceVariant;
    return Semantics(
      button: true,
      label: '$name, $details, $status',
      child: CupertinoButton(
        onPressed: onTap,
        minimumSize: Size.zero,
        padding: EdgeInsets.zero,
        child: SizedBox(
          height: 62,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Icon(
                    Icons.medication_rounded,
                    color: iconColor,
                    size: 18,
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _ScheduleVerticalDivider(
                  dividerKey: ValueKey(
                    'dashboardScheduleRowVerticalDivider${rowIndex}Column0',
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        details.replaceFirst(' · ', '\n'),
                        maxLines: 2,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                _ScheduleVerticalDivider(
                  dividerKey: ValueKey(
                    'dashboardScheduleRowVerticalDivider${rowIndex}Column1',
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (status == 'Taken') ...[
                        Icon(
                          CupertinoIcons.check_mark_circled_solid,
                          color: resolvedStatusColor,
                          size: 13,
                        ),
                        const SizedBox(width: 3),
                      ],
                      Flexible(
                        child: Text(
                          status,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            color: resolvedStatusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _DoseTone { taken, primary, warning }

enum _DoseAction { toggleTaken, snooze, remove }

class _DashboardDose {
  const _DashboardDose({
    required this.name,
    required this.details,
    required this.status,
    required this.tone,
  });

  final String name;
  final String details;
  final String status;
  final _DoseTone tone;

  _DashboardDose copyWith({String? status, _DoseTone? tone}) {
    return _DashboardDose(
      name: name,
      details: details,
      status: status ?? this.status,
      tone: tone ?? this.tone,
    );
  }
}
