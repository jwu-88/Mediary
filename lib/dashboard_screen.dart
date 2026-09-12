import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_interactions.dart';
import 'app_layout.dart';
import 'in_app_page.dart';
import 'profile_image_policy.dart';

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
    this.onOpenAccount,
    this.initialDoses = const [],
    this.weeklyTaken = 0,
    this.weeklyScheduled = 0,
    this.onDoseStatusChanged,
  });

  final String email;
  final String? displayName;
  final String? photoUrl;
  final DateTime? now;
  final double bottomPadding;
  final VoidCallback? onViewReport;
  final Future<List<String>?> Function()? onAddMedication;
  final VoidCallback? onOpenAccount;
  final List<DashboardDoseData> initialDoses;
  final int weeklyTaken;
  final int weeklyScheduled;
  final Future<void> Function(
    String doseId,
    String status, {
    DateTime? snoozedUntil,
  })?
  onDoseStatusChanged;

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
  bool _isOpeningReport = false;
  bool _isAddingMedication = false;
  String? _announcement;

  late List<_DashboardDose> _doses = const [];

  @override
  void initState() {
    super.initState();
    _syncInitialDoses();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDoses != oldWidget.initialDoses) _syncInitialDoses();
  }

  void _syncInitialDoses() {
    _doses = [
      for (final dose in widget.initialDoses)
        _DashboardDose(
          id: dose.id,
          name: dose.name,
          details: dose.details,
          status: dose.displayStatus,
          firestoreStatus: dose.status,
          tone: dose.status == 'taken' ? _DoseTone.taken : _DoseTone.primary,
        ),
    ];
  }

  Future<void> _showProfile() async {
    await pushInAppPage<void>(
      context,
      builder: (context) => _DashboardProfilePage(
        name: widget._name,
        email: widget.email,
        photoUrl: widget.photoUrl,
      ),
    );
  }

  Future<void> _showWeeklyReport() async {
    final prepared = await pushInAppPage<bool>(
      context,
      builder: (context) => _DashboardReportPage(
        taken: widget.weeklyTaken,
        scheduled: widget.weeklyScheduled,
      ),
    );
    if (prepared == true && mounted) _showConfirmation('Report Ready');
  }

  Future<void> _showAddMedication() async {
    await pushInAppPage<void>(
      context,
      builder: (context) => const _CatalogUnavailablePage(),
    );
  }

  Future<void> _handleAddMedication() async {
    if (_isAddingMedication) return;
    setState(() => _isAddingMedication = true);
    unawaited(AppHaptics.primaryAction());
    try {
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
    } finally {
      if (mounted) setState(() => _isAddingMedication = false);
    }
  }

  Future<void> _handleViewReport() async {
    if (_isOpeningReport) return;
    setState(() => _isOpeningReport = true);
    unawaited(AppHaptics.primaryAction());
    try {
      final openReport = widget.onViewReport;
      if (openReport == null) {
        await _showWeeklyReport();
      } else {
        openReport();
        // A supplied callback commonly pushes a route synchronously. Keep the
        // source action locked through that transition so two rapid clicks
        // cannot add duplicate report routes to the navigator.
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    } finally {
      if (mounted) setState(() => _isOpeningReport = false);
    }
  }

  _DashboardDose _doseForSelection(String name) => _DashboardDose(
    name: name,
    details: 'Dose not set · Today',
    status: 'Today',
    tone: _DoseTone.primary,
  );

  Future<void> _showDoseActions(int index) async {
    final dose = _doses[index];
    final action = await pushInAppPage<_DoseAction>(
      context,
      builder: (context) => InAppOptionPage<_DoseAction>(
        title: dose.name,
        subtitle: dose.details,
        options: [
          InAppPageOption(
            label: dose.status == 'Taken' ? 'Mark As Due' : 'Mark As Taken',
            value: _DoseAction.toggleTaken,
            icon: dose.status == 'Taken'
                ? CupertinoIcons.arrow_counterclockwise
                : CupertinoIcons.check_mark_circled,
          ),
          const InAppPageOption(
            label: 'Remind Me Later',
            value: _DoseAction.snooze,
            icon: CupertinoIcons.clock,
          ),
          const InAppPageOption(
            label: 'Remove From Today',
            value: _DoseAction.remove,
            icon: CupertinoIcons.trash,
            destructive: true,
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _DoseAction.toggleTaken:
        final nextStatus = dose.status == 'Taken' ? 'due' : 'taken';
        try {
          await widget.onDoseStatusChanged?.call(dose.id, nextStatus);
          if (!mounted) return;
          setState(() {
            _doses[index] = dose.copyWith(
              status: nextStatus == 'taken' ? 'Taken' : 'Due',
              firestoreStatus: nextStatus,
              tone: nextStatus == 'taken' ? _DoseTone.taken : _DoseTone.primary,
            );
          });
          _showConfirmation(
            nextStatus == 'taken' ? 'Dose Taken' : 'Dose Marked Due',
          );
        } catch (_) {
          _showConfirmation('Dose could not be updated');
        }
      case _DoseAction.snooze:
        try {
          await widget.onDoseStatusChanged?.call(
            dose.id,
            'snoozed',
            snoozedUntil: DateTime.now().add(const Duration(minutes: 15)),
          );
          if (!mounted) return;
          setState(() {
            _doses[index] = dose.copyWith(
              status: 'Later',
              firestoreStatus: 'snoozed',
              tone: _DoseTone.warning,
            );
          });
          _showConfirmation('Reminder Moved');
        } catch (_) {
          _showConfirmation('Reminder could not be saved');
        }
      case _DoseAction.remove:
        try {
          await widget.onDoseStatusChanged?.call(dose.id, 'cancelled');
          if (!mounted) return;
          setState(() => _doses.removeAt(index));
          _showConfirmation('${dose.name} Removed');
        } catch (_) {
          _showConfirmation('Dose could not be removed');
        }
    }
  }

  void _showConfirmation(String message) {
    if (!mounted) return;
    setState(() => _announcement = message);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(widget.now ?? DateTime.now());
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final contentWidth = viewportWidth >= 900
        ? responsiveContentWidth(context, nativeMaxWidth: 760)
        : 520.0;
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentWidth),
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
                      displayName: widget._name,
                      onPressed: widget.onOpenAccount ?? _showProfile,
                    ),
                  ],
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _announcement == null
                      ? const SizedBox.shrink()
                      : Padding(
                          key: ValueKey(_announcement),
                          padding: const EdgeInsets.only(top: 18),
                          child: _DashboardInlineStatus(
                            message: _announcement!,
                            onDismiss: () =>
                                setState(() => _announcement = null),
                          ),
                        ),
                ),
                const SizedBox(height: 28),
                _SectionHeader(
                  title: 'Weekly Progress',
                  actionLabel: 'View Report',
                  actionKey: const Key('dashboardViewReportButton'),
                  busy: _isOpeningReport,
                  loadingKey: const Key('dashboardViewReportLoadingIndicator'),
                  onPressed: _handleViewReport,
                ),
                const SizedBox(height: 6),
                _AdherenceSummary(
                  taken: widget.weeklyTaken,
                  scheduled: widget.weeklyScheduled,
                ),
                const SizedBox(height: 28),
                _SectionHeader(
                  title: 'Today’s Schedule',
                  actionLabel: 'Add',
                  actionIcon: CupertinoIcons.add,
                  actionKey: const Key('dashboardAddButton'),
                  busy: _isAddingMedication,
                  loadingKey: const Key('dashboardAddLoadingIndicator'),
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

class _DashboardProfilePage extends StatelessWidget {
  const _DashboardProfilePage({
    required this.name,
    required this.email,
    required this.photoUrl,
  });

  final String name;
  final String email;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final profileImage = safeProfileImageProvider(photoUrl, cacheWidth: 216);
    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();
    final fallback = ColoredBox(
      color: colors.primary.withValues(alpha: .14),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: colors.primary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
    return InAppPageScaffold(
      title: 'Your Profile',
      child: ListView(
        children: [
          Row(
            children: [
              ClipOval(
                child: SizedBox.square(
                  dimension: 72,
                  child: profileImage == null
                      ? fallback
                      : Image(
                          image: profileImage,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => fallback,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Divider(color: colors.outlineVariant),
          const SizedBox(height: 16),
          Text(
            'Account information is managed from Settings.',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogUnavailablePage extends StatelessWidget {
  const _CatalogUnavailablePage();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InAppPageScaffold(
      title: 'Add Medication',
      child: Center(
        child: Text(
          'Search the medication catalog to add a medication.',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 15),
        ),
      ),
    );
  }
}

class _DashboardReportPage extends StatelessWidget {
  const _DashboardReportPage({required this.taken, required this.scheduled});

  final int taken;
  final int scheduled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final adherence = scheduled == 0 ? 0 : ((taken / scheduled) * 100).round();
    return InAppPageScaffold(
      title: 'Weekly Report',
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Done'),
        ),
        const SizedBox(width: 8),
      ],
      child: ListView(
        children: [
          Text(
            '$adherence%',
            style: TextStyle(
              color: colors.primary,
              fontSize: 48,
              height: 1,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            scheduled == 0
                ? 'No scheduled doses yet'
                : '$taken of $scheduled scheduled doses completed',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 16,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Divider(color: colors.outlineVariant),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('prepareDashboardSummaryButton'),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(CupertinoIcons.doc_text, size: 19),
            label: const Text('Prepare Summary'),
          ),
        ],
      ),
    );
  }
}

class _DashboardInlineStatus extends StatelessWidget {
  const _DashboardInlineStatus({
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, color: colors.primary, size: 19),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatefulWidget {
  const _ProfileAvatar({
    required this.photoUrl,
    required this.initials,
    required this.displayName,
    required this.onPressed,
  });

  final String? photoUrl;
  final String initials;
  final String displayName;
  final VoidCallback onPressed;

  @override
  State<_ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<_ProfileAvatar> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final profileImage = safeProfileImageProvider(
      widget.photoUrl,
      cacheWidth: 126,
    );
    final fallback = ColoredBox(
      color: colors.primary.withValues(alpha: .14),
      child: Center(
        child: Text(
          widget.initials,
          style: TextStyle(
            color: colors.primary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    final avatar = ClipOval(
      child: SizedBox.square(
        dimension: 42,
        child: profileImage == null
            ? fallback
            : Image(
                image: profileImage,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback,
              ),
      ),
    );
    return Semantics(
      button: true,
      label: 'Open Account Settings',
      child: MouseRegion(
        key: const Key('dashboardProfileHoverRegion'),
        onEnter: kIsWeb ? (_) => setState(() => _hovered = true) : null,
        onExit: kIsWeb ? (_) => setState(() => _hovered = false) : null,
        child: ResponsiveCupertinoButton(
          buttonKey: const Key('dashboardProfileButton'),
          onPressed: widget.onPressed,
          minimumSize: const Size(44, 44),
          padding: EdgeInsets.zero,
          semanticLabel: 'Open Account Settings',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 44,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: _hovered
                  ? colors.surface.withValues(alpha: .92)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              border: _hovered
                  ? Border.all(
                      color: colors.outlineVariant.withValues(alpha: .55),
                    )
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [avatar],
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
    this.loadingKey,
    this.busy = false,
    required this.onPressed,
  });

  final String title;
  final String actionLabel;
  final IconData? actionIcon;
  final Key? actionKey;
  final Key? loadingKey;
  final bool busy;
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
          onPressed: busy ? null : onPressed,
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            foregroundColor: colors.primary,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: busy || actionIcon == null
              ? const SizedBox.shrink()
              : Icon(actionIcon, size: 15),
          label: busy
              ? SizedBox.square(
                  key: loadingKey,
                  dimension: 15,
                  child: CircularProgressIndicator(
                    value: .72,
                    strokeWidth: 1.8,
                    color: colors.primary,
                  ),
                )
              : Text(
                  actionLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }
}

class _AdherenceSummary extends StatelessWidget {
  const _AdherenceSummary({required this.taken, required this.scheduled});

  final int taken;
  final int scheduled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ratio = scheduled == 0 ? 0.0 : (taken / scheduled).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
      child: Row(
        children: [
          _ProgressRing(value: ratio),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scheduled == 0 ? 'No doses scheduled yet' : 'Weekly progress',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  scheduled == 0
                      ? 'Add a medication and schedule a dose to begin.'
                      : '$taken of $scheduled doses taken this week',
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
      child: ResponsiveCupertinoButton(
        onPressed: onTap,
        minimumSize: Size.zero,
        padding: EdgeInsets.zero,
        semanticLabel: '$name, $details, $status',
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
    this.id = '',
    required this.name,
    required this.details,
    required this.status,
    this.firestoreStatus = 'due',
    required this.tone,
  });

  final String id;
  final String name;
  final String details;
  final String status;
  final String firestoreStatus;
  final _DoseTone tone;

  _DashboardDose copyWith({
    String? status,
    String? firestoreStatus,
    _DoseTone? tone,
  }) {
    return _DashboardDose(
      id: id,
      name: name,
      details: details,
      status: status ?? this.status,
      firestoreStatus: firestoreStatus ?? this.firestoreStatus,
      tone: tone ?? this.tone,
    );
  }
}

class DashboardDoseData {
  const DashboardDoseData({
    required this.id,
    required this.name,
    required this.details,
    required this.status,
  });

  final String id;
  final String name;
  final String details;
  final String status;

  String get displayStatus => switch (status) {
    'taken' => 'Taken',
    'snoozed' => 'Later',
    'missed' => 'Missed',
    'cancelled' => 'Cancelled',
    _ => 'Due',
  };
}
