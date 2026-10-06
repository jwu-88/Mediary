import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_controls.dart';
import 'app_interactions.dart';
import 'app_layout.dart';
import 'dose_action_error.dart';
import 'in_app_page.dart';
import 'medication_artwork.dart';
import 'profile_image_policy.dart';
import 'text_formatting.dart';

const _dashboardNativeContentWidth = 520.0;
const _dashboardDesktopContentWidth = 1120.0;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.now,
    this.bottomPadding = 120,
    this.onViewReport,
    this.onOpenCalendar,
    this.onOpenAccount,
    this.initialDoses = const [],
    this.weeklyTaken = 0,
    this.weeklyScheduled = 0,
    this.onDoseStatusChanged,
    this.onRemoveMedication,
  });

  final String email;
  final String? displayName;
  final String? photoUrl;
  final DateTime? now;
  final double bottomPadding;
  final VoidCallback? onViewReport;
  final VoidCallback? onOpenCalendar;
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
  final Future<void> Function(String medicationId)? onRemoveMedication;

  static const _lightTaken = Color(0xFF279F49);
  static const _darkTaken = Color(0xFF30D158);

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

  String _greetingFor(DateTime date) {
    if (date.hour < 12) return 'Good Morning';
    if (date.hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

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
  String? _announcement;
  bool _announcementForReport = false;
  final Set<String> _removedDoseIds = <String>{};
  _RemovedDashboardDose? _undoDose;
  Timer? _undoTimer;

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

  @override
  void dispose() {
    _undoTimer?.cancel();
    super.dispose();
  }

  void _syncInitialDoses() {
    _doses = [
      for (final dose in widget.initialDoses)
        if (dose.status != 'cancelled' && !_removedDoseIds.contains(dose.id))
          _DashboardDose(
            id: dose.id,
            medicationId: dose.medicationId,
            name: dose.name,
            details: dose.details,
            status: dose.displayStatus,
            firestoreStatus: dose.status,
            snoozedUntil: dose.snoozedUntil,
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
    if (prepared == true && mounted) {
      _showConfirmation('Report Ready', forReport: true);
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

  Future<void> _showDoseActions(int index) async {
    final dose = _doses[index];
    final action = await pushInAppPage<_DoseAction>(
      context,
      builder: (context) => InAppOptionPage<_DoseAction>(
        title: titleCaseDisplay(dose.name),
        subtitle: titleCaseDisplay(dose.details),
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
          final currentIndex = _doses.indexWhere((item) => item.id == dose.id);
          if (currentIndex < 0) return;
          setState(() {
            _doses[currentIndex] = dose.copyWith(
              status: nextStatus == 'taken' ? 'Taken' : 'Due',
              firestoreStatus: nextStatus,
              tone: nextStatus == 'taken' ? _DoseTone.taken : _DoseTone.primary,
            );
          });
          _showConfirmation(
            nextStatus == 'taken' ? 'Dose Taken' : 'Dose Marked Due',
          );
        } catch (error) {
          if (kDebugMode) debugPrint('Dose update failed: $error');
          _showConfirmation(doseActionErrorMessage(error, action: 'update'));
        }
      case _DoseAction.snooze:
        final snoozedUntil = DateTime.now().add(const Duration(minutes: 15));
        try {
          await widget.onDoseStatusChanged?.call(
            dose.id,
            'snoozed',
            snoozedUntil: snoozedUntil,
          );
          if (!mounted) return;
          final currentIndex = _doses.indexWhere((item) => item.id == dose.id);
          if (currentIndex < 0) return;
          setState(() {
            _doses[currentIndex] = dose.copyWith(
              status: 'Later',
              firestoreStatus: 'snoozed',
              snoozedUntil: snoozedUntil,
              tone: _DoseTone.warning,
            );
          });
          _showConfirmation('Reminder Moved');
        } catch (error) {
          if (kDebugMode) debugPrint('Dose snooze failed: $error');
          _showConfirmation(doseActionErrorMessage(error, action: 'update'));
        }
      case _DoseAction.remove:
        await _removeDose(dose);
    }
  }

  Future<void> _removeDose(_DashboardDose dose) async {
    final index = _doses.indexWhere((item) => item.id == dose.id);
    if (index < 0) return;
    final removed = _RemovedDashboardDose(dose: dose, index: index);
    setState(() {
      _removedDoseIds.add(dose.id);
      _doses.removeAt(index);
    });
    try {
      await widget.onDoseStatusChanged?.call(dose.id, 'cancelled');
      if (!mounted) return;
      _setUndoDose(removed);
      _showConfirmation('${titleCaseDisplay(dose.name)} Removed');
    } catch (error) {
      if (kDebugMode) debugPrint('Dose removal failed: $error');
      _restoreRemovedDose(removed);
      _showConfirmation(doseActionErrorMessage(error, action: 'remove'));
    }
  }

  Future<void> _removeDoseAt(int index) async {
    if (index < 0 || index >= _doses.length) return;
    // A schedule row represents one occurrence. Regimen deletion is managed
    // explicitly in Profile, even when this dose has a medication ID.
    await _removeDose(_doses[index]);
  }

  void _showConfirmation(String message, {bool forReport = false}) {
    if (!mounted) return;
    setState(() {
      _announcement = message;
      _announcementForReport = forReport;
    });
  }

  void _setUndoDose(_RemovedDashboardDose removed) {
    _undoTimer?.cancel();
    setState(() => _undoDose = removed);
    _undoTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _undoDose = null);
    });
  }

  void _restoreRemovedDose(_RemovedDashboardDose removed) {
    if (!mounted) return;
    // Rollback belongs to the failed operation, independent of the Undo slot.
    setState(() {
      _removedDoseIds.remove(removed.dose.id);
      if (!_doses.any((dose) => dose.id == removed.dose.id)) {
        final index = removed.index.clamp(0, _doses.length);
        _doses.insert(index, removed.dose);
      }
      if (_undoDose?.dose.id == removed.dose.id) {
        _undoTimer?.cancel();
        _undoDose = null;
      }
    });
  }

  Future<void> _undoRemovedDose() async {
    final removed = _undoDose;
    if (removed == null) return;
    _undoTimer?.cancel();
    setState(() {
      _undoDose = null;
      _removedDoseIds.remove(removed.dose.id);
      final index = removed.index.clamp(0, _doses.length);
      _doses.insert(index, removed.dose);
    });
    try {
      await widget.onDoseStatusChanged?.call(
        removed.dose.id,
        removed.dose.firestoreStatus,
        snoozedUntil: removed.dose.snoozedUntil,
      );
      if (mounted) {
        _showConfirmation('${titleCaseDisplay(removed.dose.name)} Restored');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _removedDoseIds.add(removed.dose.id);
          _doses.removeWhere((dose) => dose.id == removed.dose.id);
        });
        _showConfirmation(doseActionErrorMessage(error, action: 'restore'));
      }
    }
  }

  Widget _buildStatus({bool forReport = false}) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 180),
    child: _announcement == null || _announcementForReport != forReport
        ? const SizedBox.shrink()
        : Padding(
            key: ValueKey(_announcement),
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            child: _DashboardInlineStatus(
              message: _announcement!,
              onDismiss: () => setState(() => _announcement = null),
              onUndo: _undoDose == null ? null : _undoRemovedDose,
            ),
          ),
  );

  @override
  Widget build(BuildContext context) {
    final currentTime = widget.now ?? DateTime.now();
    final today = DateUtils.dateOnly(currentTime);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final completedToday = _doses
        .where((dose) => dose.status == 'Taken')
        .length;
    final nextDoseIndex = _doses.indexWhere((dose) => dose.status != 'Taken');
    final nextDose = nextDoseIndex < 0 ? null : _doses[nextDoseIndex];
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final contentWidth = viewportWidth >= 900
        ? responsiveContentWidth(
            context,
            nativeMaxWidth: _dashboardDesktopContentWidth,
          )
        : _dashboardNativeContentWidth;
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentWidth),
            child: ListView(
              key: const Key('dashboardScrollView'),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.pageGutterOf(context),
                12,
                AppSpacing.pageGutterOf(context),
                widget.bottomPadding,
              ),
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
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '${widget._greetingFor(currentTime)}, '
                            '${widget._greetingName}',
                            key: const Key('dashboardGreeting'),
                            style: AppTextStyles.pageTitle.copyWith(
                              color: colors.onSurface,
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
                const SizedBox(height: AppSpacing.xl),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final focus = _DashboardFocusCard(
                      completedToday: completedToday,
                      scheduledToday: _doses.length,
                      nextDose: nextDose,
                      onReviewNext: nextDose == null
                          ? null
                          : () => unawaited(_showDoseActions(nextDoseIndex)),
                      onOpenCalendar: widget.onOpenCalendar,
                    );
                    final metrics = _DashboardMetricStrip(
                      completedToday: completedToday,
                      scheduledToday: _doses.length,
                      weeklyTaken: widget.weeklyTaken,
                      weeklyScheduled: widget.weeklyScheduled,
                      onOpenCalendar: widget.onOpenCalendar,
                      onViewReport: _handleViewReport,
                    );
                    if (constraints.maxWidth <
                        900 *
                            (MediaQuery.textScalerOf(context).scale(15) / 15)) {
                      return Column(
                        children: [focus, const SizedBox(height: 16), metrics],
                      );
                    }
                    return Row(
                      key: const Key('dashboardLandscapeSummary'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: focus),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: metrics),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                _SectionHeader(
                  key: const Key('dashboardWeeklyProgressHeader'),
                  title: 'Weekly Progress',
                  actionLabel: 'View Report',
                  actionKey: const Key('dashboardViewReportButton'),
                  busy: _isOpeningReport,
                  loadingKey: const Key('dashboardViewReportLoadingIndicator'),
                  onPressed: _handleViewReport,
                ),
                _buildStatus(forReport: true),
                const SizedBox(height: 8),
                _AdherenceSummary(
                  taken: widget.weeklyTaken,
                  scheduled: widget.weeklyScheduled,
                ),
                const SizedBox(height: 24),
                _SectionHeader(
                  key: const Key('dashboardTodayScheduleHeader'),
                  title: 'Today’s Schedule',
                ),
                _buildStatus(),
                const SizedBox(height: 12),
                _CalendarManagementHint(onOpenCalendar: widget.onOpenCalendar),
                const SizedBox(height: 16),
                _ScheduleTable(
                  doses: _doses,
                  onTapDose: _showDoseActions,
                  onRemoveDose: _removeDoseAt,
                ),
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
                          semanticLabel: '$name profile photo',
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
        AppButton(
          label: 'Done',
          compact: true,
          variant: AppButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(false),
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
          AppButton(
            key: const Key('prepareDashboardSummaryButton'),
            label: 'Prepare Summary',
            icon: CupertinoIcons.doc_text,
            expand: true,
            onPressed: () => Navigator.of(context).pop(true),
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
    this.onUndo,
  });

  final String message;
  final VoidCallback onDismiss;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final undo = onUndo == null
                  ? null
                  : AppButton(
                      label: 'Undo',
                      compact: true,
                      variant: AppButtonVariant.tertiary,
                      onPressed: onUndo,
                    );
              final separateUndo =
                  undo != null &&
                  constraints.maxWidth <
                      440 * MediaQuery.textScalerOf(context).scale(15) / 15;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: colors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          message,
                          style: AppTextStyles.body.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (undo != null && !separateUndo) undo,
                      AppIconButton(
                        tooltip: 'Dismiss',
                        onPressed: onDismiss,
                        icon: Icons.close_rounded,
                      ),
                    ],
                  ),
                  if (separateUndo)
                    Align(alignment: Alignment.centerRight, child: undo),
                ],
              );
            },
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
                semanticLabel: '${widget.initials} profile photo',
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
            child: Center(child: avatar),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.actionKey,
    this.loadingKey,
    this.busy = false,
    this.onPressed,
  });

  final String title;
  final String? actionLabel;
  final Key? actionKey;
  final Key? loadingKey;
  final bool busy;
  final FutureOr<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final heading = Text(
      title,
      style: AppTextStyles.sectionTitle.copyWith(color: colors.onSurface),
    );
    if (actionLabel == null || onPressed == null) return heading;
    final action = AppButton(
      key: actionKey,
      label: actionLabel!,
      compact: true,
      variant: AppButtonVariant.tertiary,
      busy: busy,
      loadingIndicatorKey: loadingKey,
      onPressed: onPressed,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final titlePainter = TextPainter(
          text: TextSpan(
            text: title,
            style: Theme.of(context).textTheme.titleMedium
                ?.merge(AppTextStyles.sectionTitle),
          ),
          textScaler: scaler,
          textDirection: Directionality.of(context),
        )..layout();
        final actionPainter = TextPainter(
          text: TextSpan(
            text: actionLabel,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          textScaler: scaler,
          textDirection: Directionality.of(context),
        )..layout();
        final fits =
            titlePainter.width +
                actionPainter.width +
                (busy ? 56 : 28) +
                AppSpacing.lg <=
            constraints.maxWidth;
        titlePainter.dispose();
        actionPainter.dispose();
        return fits
            ? Row(
                children: [
                  Expanded(child: heading),
                  const SizedBox(width: AppSpacing.sm),
                  action,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  heading,
                  const SizedBox(height: AppSpacing.xs),
                  Align(alignment: Alignment.centerRight, child: action),
                ],
              );
      },
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .45)),
      ),
      child: Row(
        children: [
          _ProgressRing(value: ratio),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scheduled == 0
                      ? 'No doses scheduled yet'
                      : 'Doses taken this week',
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

class _DashboardFocusCard extends StatelessWidget {
  const _DashboardFocusCard({
    required this.completedToday,
    required this.scheduledToday,
    required this.nextDose,
    required this.onReviewNext,
    required this.onOpenCalendar,
  });

  final int completedToday;
  final int scheduledToday;
  final _DashboardDose? nextDose;
  final VoidCallback? onReviewNext;
  final VoidCallback? onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final progress = scheduledToday == 0
        ? 0.0
        : (completedToday / scheduledToday).clamp(0.0, 1.0);
    final allDone = scheduledToday > 0 && completedToday >= scheduledToday;
    final action = onReviewNext ?? onOpenCalendar;
    final title = scheduledToday == 0
        ? 'No Doses Scheduled'
        : allDone
        ? 'All Done for Today'
        : nextDose == null
        ? 'Keep Going'
        : 'Next Dose';
    final description = scheduledToday == 0
        ? 'Create a schedule in Calendar to keep your routine on track.'
        : nextDose == null
        ? 'All scheduled doses for today are complete.'
        : '${titleCaseDisplay(nextDose!.name)} · '
              '${titleCaseDisplay(nextDose!.details)}';
    final actionLabel = onReviewNext != null ? 'Review Dose' : 'Open Calendar';
    final progressLabel = scheduledToday == 0
        ? 'Tap Calendar to begin'
        : '$completedToday/$scheduledToday complete';
    final cardStart = Color.lerp(
      colors.surface,
      colors.primary,
      dark ? .24 : .1,
    )!;
    final cardEnd = Color.lerp(
      colors.surface,
      colors.primary,
      dark ? .13 : .035,
    )!;
    final secondary = colors.onSurfaceVariant;

    return Semantics(
      container: true,
      label: '$title. $description',
      child: DecoratedBox(
        key: const Key('dashboardFocusCard'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cardStart, cardEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.primary.withValues(alpha: .18)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Today',
                          style: TextStyle(
                            color: secondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .3,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          title,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 22,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox.square(
                    dimension: 52,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 5,
                          strokeCap: StrokeCap.round,
                          backgroundColor: colors.primary.withValues(
                            alpha: .14,
                          ),
                          color: colors.primary,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(7),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${(progress * 100).round()}%',
                              style: TextStyle(
                                color: colors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: TextStyle(
                  color: secondary,
                  fontSize: 13,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: colors.primary.withValues(alpha: .14),
                        color: colors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    flex: 2,
                    child: Text(
                      progressLabel,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: secondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (action != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: AppButton(
                    key: const Key('dashboardFocusActionButton'),
                    label: actionLabel,
                    onPressed: action,
                    icon: onReviewNext != null
                        ? CupertinoIcons.check_mark_circled
                        : CupertinoIcons.calendar_badge_plus,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardMetricStrip extends StatelessWidget {
  const _DashboardMetricStrip({
    required this.completedToday,
    required this.scheduledToday,
    required this.weeklyTaken,
    required this.weeklyScheduled,
    required this.onOpenCalendar,
    required this.onViewReport,
  });

  final int completedToday;
  final int scheduledToday;
  final int weeklyTaken;
  final int weeklyScheduled;
  final VoidCallback? onOpenCalendar;
  final VoidCallback onViewReport;

  @override
  Widget build(BuildContext context) {
    final weeklyPercent = weeklyScheduled == 0
        ? 0
        : ((weeklyTaken / weeklyScheduled) * 100).round();
    final today = _DashboardMetricTile(
      key: const Key('dashboardTodayMetric'),
      icon: CupertinoIcons.today,
      label: 'Today',
      value: '$completedToday/$scheduledToday',
      detail: scheduledToday == 0 ? 'Start in Calendar' : 'Doses complete',
      onTap: onOpenCalendar,
    );
    final week = _DashboardMetricTile(
      key: const Key('dashboardWeekMetric'),
      icon: CupertinoIcons.chart_bar,
      label: 'This Week',
      value: '$weeklyPercent%',
      detail: weeklyScheduled == 0
          ? 'No doses yet'
          : '$weeklyTaken of $weeklyScheduled taken',
      onTap: onViewReport,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(15) / 15;
        if (constraints.maxWidth < 320 * textScale) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              today,
              const SizedBox(height: AppSpacing.sm),
              week,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: today),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: week),
          ],
        );
      },
    );
  }
}

class _DashboardMetricTile extends StatelessWidget {
  const _DashboardMetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: onTap != null,
      label: '$label: $value. $detail',
      child: ResponsiveCupertinoButton(
        onPressed: onTap,
        minimumSize: Size.zero,
        padding: EdgeInsets.zero,
        semanticLabel: '$label: $value',
        borderRadius: BorderRadius.circular(14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: .55),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(icon, color: colors.primary, size: 17),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(
                    CupertinoIcons.chevron_right,
                    color: colors.onSurfaceVariant,
                    size: 14,
                  ),
              ],
            ),
          ),
        ),
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
          Padding(
            padding: const EdgeInsets.all(8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${(value * 100).round()}%',
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleTable extends StatelessWidget {
  const _ScheduleTable({
    required this.doses,
    required this.onTapDose,
    required this.onRemoveDose,
  });

  final List<_DashboardDose> doses;
  final ValueChanged<int> onTapDose;
  final ValueChanged<int> onRemoveDose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final taken = theme.brightness == Brightness.dark
        ? DashboardScreen._darkTaken
        : DashboardScreen._lightTaken;
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(15) / 15;
        if (textScale > 1.3 && constraints.maxWidth < 360 * textScale) {
          return Semantics(
            key: const Key('dashboardScheduleTable'),
            container: true,
            label: 'Today’s Medication Schedule',
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  for (var index = 0; index < doses.length; index++) ...[
                    _ReadableDoseRow(
                      id: doses[index].id,
                      name: doses[index].name,
                      details: doses[index].details,
                      status: doses[index].status,
                      statusColor: doses[index].tone == _DoseTone.taken
                          ? taken
                          : colors.onSurfaceVariant,
                      onTap: () => onTapDose(index),
                      onRemove: () => onRemoveDose(index),
                    ),
                    if (index < doses.length - 1)
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: colors.outlineVariant.withValues(alpha: .55),
                      ),
                  ],
                ],
              ),
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
                  artworkSeed: doses[index].id,
                  artworkLabel: titleCaseDisplay(doses[index].name),
                  name: doses[index].name,
                  details: doses[index].details,
                  status: doses[index].status,
                  statusColor: doses[index].tone == _DoseTone.taken
                      ? taken
                      : null,
                  onTap: () => onTapDose(index),
                  onRemove: () => onRemoveDose(index),
                  removeTooltip:
                      'Remove ${titleCaseDisplay(doses[index].name)} from today',
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
      },
    );
  }
}

class _CalendarManagementHint extends StatelessWidget {
  const _CalendarManagementHint({required this.onOpenCalendar});

  final VoidCallback? onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      key: const Key('dashboardCalendarGuidance'),
      container: true,
      label: 'Add or manage medications in Calendar.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: .45),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final message = Text(
              'Add or manage medications in Calendar.',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            );
            final openButton = AppButton(
              key: const Key('dashboardCalendarGuidanceButton'),
              label: 'Open Calendar',
              icon: CupertinoIcons.arrow_right,
              compact: true,
              variant: AppButtonVariant.tertiary,
              onPressed: onOpenCalendar,
            );
            if (constraints.maxWidth <
                480 * MediaQuery.textScalerOf(context).scale(15) / 15) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.calendar,
                        size: 18,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: message),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Align(alignment: Alignment.centerRight, child: openButton),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.calendar, size: 18, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(child: message),
                const SizedBox(width: 8),
                openButton,
              ],
            );
          },
        ),
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final metrics = _ScheduleLayoutMetrics.forWidth(
              constraints.maxWidth,
            );
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: metrics.artworkSlotWidth),
                SizedBox(
                  key: const Key('dashboardScheduleMedicationHeaderCell'),
                  width: metrics.medicationWidth,
                  child: Text(
                    'Medication',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style.copyWith(color: color),
                  ),
                ),
                _ScheduleVerticalDivider(
                  dividerKey: const Key(
                    'dashboardScheduleHeaderVerticalDivider0',
                  ),
                  slotWidth: metrics.dividerSlotWidth,
                ),
                SizedBox(
                  key: const Key('dashboardScheduleDoseHeaderCell'),
                  width: metrics.doseTimeWidth,
                  child: Text(
                    'Dose & Time',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style.copyWith(color: color),
                  ),
                ),
                _ScheduleVerticalDivider(
                  dividerKey: const Key(
                    'dashboardScheduleHeaderVerticalDivider1',
                  ),
                  slotWidth: metrics.dividerSlotWidth,
                ),
                SizedBox(
                  key: const Key('dashboardScheduleStatusHeaderCell'),
                  width: metrics.statusWidth,
                  child: Text(
                    'Status',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: style.copyWith(color: color),
                  ),
                ),
                SizedBox(
                  key: const Key('dashboardScheduleActionsHeaderCell'),
                  width: metrics.actionWidth,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScheduleVerticalDivider extends StatelessWidget {
  const _ScheduleVerticalDivider({
    required this.dividerKey,
    this.slotWidth = 17,
  });

  final Key dividerKey;
  final double slotWidth;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: slotWidth,
      child: VerticalDivider(
        key: dividerKey,
        width: 1,
        thickness: .5,
        color: colors.outlineVariant.withValues(alpha: .62),
      ),
    );
  }
}

class _ReadableDoseRow extends StatelessWidget {
  const _ReadableDoseRow({
    required this.id,
    required this.name,
    required this.details,
    required this.status,
    required this.statusColor,
    required this.onTap,
    required this.onRemove,
  });

  final String id;
  final String name;
  final String details;
  final String status;
  final Color statusColor;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppPressable(
      onPressed: onTap,
      autoManageBusy: false,
      semanticLabel:
          '${titleCaseDisplay(name)}, ${titleCaseDisplay(details)}, $status',
      borderRadius: BorderRadius.circular(14),
      hoverScale: 1,
      hoverOffset: Offset.zero,
      pressedScale: .99,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MedicationArtwork(
                  seed: id,
                  label: titleCaseDisplay(name),
                  size: 36,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    titleCaseDisplay(name),
                    key: Key('dashboardReadableDoseName_$id'),
                    style: AppTextStyles.body.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                AppIconButton(
                  key: Key('dashboardDeleteDose_$id'),
                  icon: CupertinoIcons.trash,
                  tooltip: 'Remove ${titleCaseDisplay(name)} from day',
                  foregroundColor: colors.error,
                  onPressed: onRemove,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              titleCaseDisplay(details),
              key: Key('dashboardReadableDoseDetails_$id'),
              style: AppTextStyles.body.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              status,
              key: Key('dashboardReadableDoseStatus_$id'),
              style: AppTextStyles.body.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoseRow extends StatelessWidget {
  const _DoseRow({
    required this.rowIndex,
    required this.artworkSeed,
    required this.artworkLabel,
    required this.name,
    required this.details,
    required this.status,
    this.statusColor,
    required this.onTap,
    required this.onRemove,
    required this.removeTooltip,
  });

  final int rowIndex;
  final String artworkSeed;
  final String artworkLabel;
  final String name;
  final String details;
  final String status;
  final Color? statusColor;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final String removeTooltip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final resolvedStatusColor = statusColor ?? colors.onSurfaceVariant;
    return Semantics(
      button: true,
      label:
          '${titleCaseDisplay(name)}, ${titleCaseDisplay(details)}, '
          '${titleCaseDisplay(status)}',
      child: ResponsiveCupertinoButton(
        onPressed: onTap,
        minimumSize: Size.zero,
        padding: EdgeInsets.zero,
        semanticLabel:
            '${titleCaseDisplay(name)}, ${titleCaseDisplay(details)}, '
            '${titleCaseDisplay(status)}',
        child: SizedBox(
          height: 62,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final metrics = _ScheduleLayoutMetrics.forWidth(
                  constraints.maxWidth,
                );
                return Row(
                  children: [
                    SizedBox(
                      width: metrics.artworkSlotWidth,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: metrics.artworkLeadingGap,
                          ),
                          child: MedicationArtwork(
                            key: Key('dashboardMedicationArtwork_$artworkSeed'),
                            seed: artworkSeed,
                            label: artworkLabel,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      key: ValueKey('dashboardScheduleMedicationCell$rowIndex'),
                      width: metrics.medicationWidth,
                      child: Text(
                        titleCaseDisplay(name),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 13,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _ScheduleVerticalDivider(
                      dividerKey: ValueKey(
                        'dashboardScheduleRowVerticalDivider${rowIndex}Column0',
                      ),
                      slotWidth: metrics.dividerSlotWidth,
                    ),
                    SizedBox(
                      key: ValueKey('dashboardScheduleDoseCell$rowIndex'),
                      width: metrics.doseTimeWidth,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          titleCaseDisplay(details.replaceFirst(' · ', '\n')),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                    _ScheduleVerticalDivider(
                      dividerKey: ValueKey(
                        'dashboardScheduleRowVerticalDivider${rowIndex}Column1',
                      ),
                      slotWidth: metrics.dividerSlotWidth,
                    ),
                    SizedBox(
                      key: ValueKey('dashboardScheduleStatusCell$rowIndex'),
                      width: metrics.statusWidth,
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
                              titleCaseDisplay(status),
                              maxLines: 1,
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
                    SizedBox(
                      width: metrics.actionWidth,
                      child: AppIconButton(
                        key: Key('dashboardDeleteDose_$artworkSeed'),
                        onPressed: onRemove,
                        tooltip: removeTooltip,
                        icon: CupertinoIcons.trash,
                        foregroundColor: colors.error,
                      ),
                    ),
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

/// Shared geometry for the schedule header and every dose row.
///
/// Keeping the same metrics in both places prevents the column dividers from
/// drifting and gives the artwork a dedicated slot before medication text.
class _ScheduleLayoutMetrics {
  const _ScheduleLayoutMetrics({
    required this.artworkSlotWidth,
    required this.artworkLeadingGap,
    required this.medicationWidth,
    required this.dividerSlotWidth,
    required this.doseTimeWidth,
    required this.statusWidth,
    required this.actionWidth,
  });

  final double artworkSlotWidth;
  final double artworkLeadingGap;
  final double medicationWidth;
  final double dividerSlotWidth;
  final double doseTimeWidth;
  final double statusWidth;
  final double actionWidth;

  factory _ScheduleLayoutMetrics.forWidth(double width) {
    final compact = width < 420;
    final artworkSlotWidth = compact ? 50.0 : 54.0;
    final artworkLeadingGap = compact ? 8.0 : 12.0;
    final dividerSlotWidth = compact ? 9.0 : 17.0;
    final statusWidth = compact ? 58.0 : 72.0;
    final actionWidth = 44.0;
    final fixedWidth =
        artworkSlotWidth + (dividerSlotWidth * 2) + statusWidth + actionWidth;
    final flexibleWidth = (width - fixedWidth).clamp(0.0, double.infinity);
    final doseTimeWidth = compact
        ? flexibleWidth.clamp(0.0, 96.0)
        : flexibleWidth * .48;
    final medicationWidth = (flexibleWidth - doseTimeWidth).clamp(
      0.0,
      double.infinity,
    );

    return _ScheduleLayoutMetrics(
      artworkSlotWidth: artworkSlotWidth,
      artworkLeadingGap: artworkLeadingGap,
      medicationWidth: medicationWidth,
      dividerSlotWidth: dividerSlotWidth,
      doseTimeWidth: doseTimeWidth,
      statusWidth: statusWidth,
      actionWidth: actionWidth,
    );
  }
}

enum _DoseTone { taken, primary, warning }

enum _DoseAction { toggleTaken, snooze, remove }

class _DashboardDose {
  const _DashboardDose({
    this.id = '',
    this.medicationId,
    required this.name,
    required this.details,
    required this.status,
    this.firestoreStatus = 'due',
    this.snoozedUntil,
    required this.tone,
  });

  final String id;
  final String? medicationId;
  final String name;
  final String details;
  final String status;
  final String firestoreStatus;
  final DateTime? snoozedUntil;
  final _DoseTone tone;

  _DashboardDose copyWith({
    String? status,
    String? firestoreStatus,
    DateTime? snoozedUntil,
    _DoseTone? tone,
  }) {
    return _DashboardDose(
      id: id,
      medicationId: medicationId,
      name: name,
      details: details,
      status: status ?? this.status,
      firestoreStatus: firestoreStatus ?? this.firestoreStatus,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      tone: tone ?? this.tone,
    );
  }
}

class _RemovedDashboardDose {
  const _RemovedDashboardDose({required this.dose, required this.index});

  final _DashboardDose dose;
  final int index;
}

class DashboardDoseData {
  const DashboardDoseData({
    required this.id,
    this.medicationId,
    required this.name,
    required this.details,
    required this.status,
    this.snoozedUntil,
  });

  final String id;
  final String? medicationId;
  final String name;
  final String details;
  final String status;
  final DateTime? snoozedUntil;

  String get displayStatus => switch (status) {
    'taken' => 'Taken',
    'snoozed' => 'Later',
    'missed' => 'Missed',
    'cancelled' => 'Cancelled',
    _ => 'Due',
  };
}
