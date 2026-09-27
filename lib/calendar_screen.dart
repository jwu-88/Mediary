import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_interactions.dart';
import 'app_layout.dart';
import 'dose_action_error.dart';
import 'in_app_page.dart';
import 'medication_artwork.dart';
import 'text_formatting.dart';

const _calendarHorizontalInset = 16.0;
const _calendarNativeContentWidth = 520.0;
const _calendarDesktopContentWidth = 760.0;

/// A native, interactive medication calendar based on the calendar prototype.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    this.initialDate,
    this.onAdd,
    this.onAddDose,
    this.initialDoses = const [],
    this.onDoseStatusChanged,
    this.bottomPadding = 120,
  });

  final DateTime? initialDate;
  final VoidCallback? onAdd;
  final Future<List<CalendarDoseData>?> Function(DateTime selectedDate)?
  onAddDose;
  final List<CalendarDoseData> initialDoses;
  final Future<void> Function(String doseId, String status)?
  onDoseStatusChanged;
  final double bottomPadding;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const _noDoses = <_CalendarDose>[];

  static const _months = [
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

  static const _weekdays = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  late DateTime _referenceDate;
  late DateTime _selectedDate;
  late DateTime _visibleMonth;
  final Map<String, List<_CalendarDose>> _dosesByDate = {};
  // A parent rebuild can briefly provide the old Firestore snapshot while a
  // cancellation is propagating. Keep the local removal authoritative during
  // that window so a dose cannot reappear when the user changes pages.
  final Set<String> _removedDoseIds = <String>{};
  String? _announcement;
  _RemovedCalendarDose? _undoDose;
  Timer? _undoTimer;

  @override
  void initState() {
    super.initState();
    _setInitialDate(widget.initialDate ?? DateTime.now());
  }

  @override
  void didUpdateWidget(covariant CalendarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDate != oldWidget.initialDate &&
        widget.initialDate != null) {
      _setInitialDate(widget.initialDate!);
    }
    if (widget.initialDoses != oldWidget.initialDoses) _loadInitialDoses();
  }

  @override
  void dispose() {
    _undoTimer?.cancel();
    super.dispose();
  }

  void _setInitialDate(DateTime value) {
    _referenceDate = DateUtils.dateOnly(value);
    _selectedDate = _referenceDate;
    _visibleMonth = DateTime(value.year, value.month);
    _loadInitialDoses();
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  void _loadInitialDoses() {
    _dosesByDate.clear();
    for (final dose in widget.initialDoses) {
      if (dose.status == 'cancelled' || _removedDoseIds.contains(dose.id)) {
        continue;
      }
      _dosesByDate
          .putIfAbsent(dose.localDate, () => <_CalendarDose>[])
          .add(
            _CalendarDose(
              id: dose.id,
              name: dose.name,
              details: dose.details,
              status: dose.status,
            ),
          );
    }
  }

  List<_CalendarDose> _dosesFor(DateTime date) {
    return _dosesByDate[_dateKey(date)] ?? _noDoses;
  }

  void _moveMonth(int offset) {
    final targetMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + offset,
    );
    final targetDay = math.min(
      _selectedDate.day,
      DateUtils.getDaysInMonth(targetMonth.year, targetMonth.month),
    );
    setState(() {
      _visibleMonth = targetMonth;
      _selectedDate = DateTime(targetMonth.year, targetMonth.month, targetDay);
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = DateUtils.dateOnly(date);
      if (date.year != _visibleMonth.year ||
          date.month != _visibleMonth.month) {
        _visibleMonth = DateTime(date.year, date.month);
      }
    });
  }

  void _jumpToToday() {
    final today = DateUtils.dateOnly(DateTime.now());
    setState(() {
      _selectedDate = today;
      _visibleMonth = DateTime(today.year, today.month);
    });
  }

  Future<void> _addDose() async {
    if (widget.onAddDose != null) {
      final addedDoses = await widget.onAddDose!(_selectedDate);
      if (!mounted || addedDoses == null || addedDoses.isEmpty) return;
      setState(() {
        for (final dose in addedDoses) {
          _removedDoseIds.remove(dose.id);
          final doses = _dosesByDate.putIfAbsent(
            dose.localDate,
            () => <_CalendarDose>[],
          );
          doses.removeWhere((existing) => existing.id == dose.id);
          doses.add(
            _CalendarDose(
              id: dose.id,
              name: dose.name,
              details: dose.details,
              status: dose.status,
            ),
          );
        }
      });
      _showConfirmation(
        addedDoses.length == 1
            ? '${titleCaseDisplay(addedDoses.single.name)} Scheduled'
            : '${addedDoses.length} Medications Scheduled',
      );
      return;
    }
    if (widget.onAdd != null) {
      widget.onAdd!();
      return;
    }
    await pushInAppPage<void>(
      context,
      builder: (context) => InAppPageScaffold(
        title: 'Add Medication',
        child: Center(
          child: Text(
            'Search the medication catalog to create a schedule.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDoseActions(int index) async {
    final doses = _dosesByDate[_dateKey(_selectedDate)];
    if (doses == null || index < 0 || index >= doses.length) return;
    final dose = doses[index];
    final action = await pushInAppPage<_CalendarDoseAction>(
      context,
      builder: (context) => InAppOptionPage<_CalendarDoseAction>(
        title: titleCaseDisplay(dose.name),
        subtitle: titleCaseDisplay(dose.details),
        options: [
          InAppPageOption(
            label: dose.isTaken ? 'Mark As Due' : 'Mark As Taken',
            value: _CalendarDoseAction.toggleTaken,
            icon: dose.isTaken
                ? CupertinoIcons.arrow_counterclockwise
                : CupertinoIcons.check_mark_circled,
          ),
          const InAppPageOption(
            label: 'Remove From Day',
            value: _CalendarDoseAction.remove,
            icon: CupertinoIcons.trash,
            destructive: true,
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _CalendarDoseAction.toggleTaken:
        final nextStatus = dose.isTaken ? 'due' : 'taken';
        try {
          await widget.onDoseStatusChanged?.call(dose.id, nextStatus);
          if (!mounted) return;
          final currentIndex = doses.indexWhere((item) => item.id == dose.id);
          if (currentIndex < 0) return;
          setState(
            () => doses[currentIndex] = dose.copyWith(status: nextStatus),
          );
          _showConfirmation(dose.isTaken ? 'Dose Marked Due' : 'Dose Taken');
        } catch (error) {
          _showConfirmation(doseActionErrorMessage(error, action: 'update'));
        }
      case _CalendarDoseAction.remove:
        await _removeDose(dose);
    }
  }

  Future<void> _removeDose(_CalendarDose dose) async {
    final removedDateKey = _dateKey(_selectedDate);
    final doses = _dosesByDate[removedDateKey];
    final index = doses?.indexWhere((item) => item.id == dose.id) ?? -1;
    if (index < 0) return;
    setState(() {
      _removedDoseIds.add(dose.id);
      doses!.removeAt(index);
    });
    _setUndoDose(
      _RemovedCalendarDose(dose: dose, dateKey: removedDateKey, index: index),
    );
    try {
      await widget.onDoseStatusChanged?.call(dose.id, 'cancelled');
      if (!mounted) return;
      _showConfirmation('${titleCaseDisplay(dose.name)} Removed');
    } catch (error) {
      _restoreRemovedDose(dose.id);
      _showConfirmation(doseActionErrorMessage(error, action: 'remove'));
    }
  }

  Future<void> _removeDoseAt(int index) async {
    final doses = _dosesByDate[_dateKey(_selectedDate)];
    if (doses == null || index < 0 || index >= doses.length) return;
    await _removeDose(doses[index]);
  }

  void _showConfirmation(String message) {
    if (!mounted) return;
    setState(() => _announcement = message);
  }

  void _setUndoDose(_RemovedCalendarDose removed) {
    _undoTimer?.cancel();
    setState(() => _undoDose = removed);
    _undoTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _undoDose = null);
    });
  }

  void _restoreRemovedDose(String doseId) {
    final removed = _undoDose;
    _undoTimer?.cancel();
    if (!mounted) return;
    if (removed?.dose.id == doseId) {
      setState(() {
        _removedDoseIds.remove(doseId);
        final restored = _dosesByDate.putIfAbsent(
          removed!.dateKey,
          () => <_CalendarDose>[],
        );
        final index = removed.index.clamp(0, restored.length);
        restored.insert(index, removed.dose);
        _undoDose = null;
      });
    } else {
      _removedDoseIds.remove(doseId);
    }
  }

  Future<void> _undoRemovedDose() async {
    final removed = _undoDose;
    if (removed == null) return;
    _undoTimer?.cancel();
    setState(() {
      _undoDose = null;
      _removedDoseIds.remove(removed.dose.id);
      final restored = _dosesByDate.putIfAbsent(
        removed.dateKey,
        () => <_CalendarDose>[],
      );
      final index = removed.index.clamp(0, restored.length);
      restored.insert(index, removed.dose);
    });
    try {
      await widget.onDoseStatusChanged?.call(removed.dose.id, 'due');
      if (mounted) {
        _showConfirmation('${titleCaseDisplay(removed.dose.name)} Restored');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _removedDoseIds.add(removed.dose.id);
          _dosesByDate[removed.dateKey]?.removeWhere(
            (dose) => dose.id == removed.dose.id,
          );
        });
        _showConfirmation(doseActionErrorMessage(error, action: 'restore'));
      }
    }
  }

  Future<void> _showOptions() async {
    final jumpToToday = await pushInAppPage<bool>(
      context,
      builder: (context) => const InAppOptionPage<bool>(
        title: 'Calendar Options',
        options: [
          InAppPageOption(
            label: 'Jump to Today',
            value: true,
            icon: CupertinoIcons.calendar_today,
          ),
        ],
      ),
    );
    if (jumpToToday == true && mounted) _jumpToToday();
  }

  String _monthYear(DateTime date) => '${_months[date.month - 1]} ${date.year}';

  String _longDate(DateTime date) {
    final weekday = _weekdays[date.weekday % 7];
    return '$weekday, ${_months[date.month - 1]} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = _CalendarPalette.of(context);
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final contentWidth = viewportWidth >= 900
        ? responsiveContentWidth(
            context,
            nativeMaxWidth: _calendarDesktopContentWidth,
          )
        : _calendarNativeContentWidth;
    return ColoredBox(
      color: palette.background,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentWidth),
            child: ListView(
              key: const Key('calendarScrollView'),
              padding: EdgeInsets.fromLTRB(
                _calendarHorizontalInset,
                12,
                _calendarHorizontalInset,
                widget.bottomPadding,
              ),
              children: [
                _CalendarHeader(onOptions: _showOptions),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _announcement == null
                      ? const SizedBox.shrink()
                      : Padding(
                          key: ValueKey(_announcement),
                          padding: const EdgeInsets.only(top: 12),
                          child: _CalendarInlineStatus(
                            message: _announcement!,
                            onDismiss: () =>
                                setState(() => _announcement = null),
                            onUndo: _undoDose == null ? null : _undoRemovedDose,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                _AdherenceSummary(
                  month: _months[_visibleMonth.month - 1],
                  taken: _monthTaken,
                  scheduled: _monthScheduled,
                ),
                const SizedBox(height: 24),
                _CalendarCard(
                  visibleMonth: _visibleMonth,
                  selectedDate: _selectedDate,
                  referenceDate: _referenceDate,
                  monthLabel: _monthYear(_visibleMonth),
                  onPreviousMonth: () => _moveMonth(-1),
                  onNextMonth: () => _moveMonth(1),
                  onSelectDate: _selectDate,
                  statusFor: _statusFor,
                ),
                const SizedBox(height: 24),
                _SectionHeader(
                  key: const Key('calendarSelectedDateHeader'),
                  title: _longDate(_selectedDate),
                  onAdd: _addDose,
                ),
                const SizedBox(height: 12),
                _DoseList(
                  doses: _dosesFor(_selectedDate),
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

  int get _monthScheduled => _dosesByDate.entries
      .where((entry) {
        final date = DateTime.tryParse(entry.key);
        return date != null &&
            date.year == _visibleMonth.year &&
            date.month == _visibleMonth.month;
      })
      .expand((entry) => entry.value)
      .where((dose) => dose.status != 'cancelled')
      .length;

  int get _monthTaken => _dosesByDate.entries
      .where((entry) {
        final date = DateTime.tryParse(entry.key);
        return date != null &&
            date.year == _visibleMonth.year &&
            date.month == _visibleMonth.month;
      })
      .expand((entry) => entry.value)
      .where((dose) => dose.status == 'taken')
      .length;

  _DoseStatus? _statusFor(DateTime date) {
    if (date.month != _visibleMonth.month || date.year != _visibleMonth.year) {
      return null;
    }
    final doses = _dosesFor(date);
    if (doses.any((dose) => dose.status == 'taken')) return _DoseStatus.taken;
    if (doses.any((dose) => dose.status == 'skipped')) {
      return _DoseStatus.missed;
    }
    return null;
  }
}

class _CalendarInlineStatus extends StatelessWidget {
  const _CalendarInlineStatus({
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
              if (onUndo != null)
                TextButton(onPressed: onUndo, child: const Text('Undo')),
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

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({required this.onOptions});

  final VoidCallback onOptions;

  @override
  Widget build(BuildContext context) {
    final palette = _CalendarPalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR ROUTINE',
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .45,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Calendar',
                key: const Key('calendarTitle'),
                style: TextStyle(
                  color: palette.ink,
                  fontSize: 28,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.8,
                ),
              ),
            ],
          ),
        ),
        ResponsiveCupertinoButton(
          buttonKey: const Key('calendarOptionsButton'),
          onPressed: onOptions,
          minimumSize: const Size.square(44),
          padding: EdgeInsets.zero,
          semanticLabel: 'Calendar options',
          child: Icon(CupertinoIcons.ellipsis, color: palette.accent, size: 21),
        ),
      ],
    );
  }
}

class _AdherenceSummary extends StatelessWidget {
  const _AdherenceSummary({
    required this.month,
    required this.taken,
    required this.scheduled,
  });

  final String month;
  final int taken;
  final int scheduled;

  @override
  Widget build(BuildContext context) {
    final palette = _CalendarPalette.of(context);
    final ratio = scheduled == 0 ? 0.0 : (taken / scheduled).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 7, 2, 15),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.separator)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$month Adherence',
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  scheduled == 0
                      ? 'No scheduled doses'
                      : '$taken of $scheduled doses',
                  key: const Key('calendarAdherenceCount'),
                  style: TextStyle(
                    color: palette.ink,
                    fontSize: 20,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.35,
                  ),
                ),
              ],
            ),
          ),
          _AdherenceRing(value: ratio),
        ],
      ),
    );
  }
}

class _AdherenceRing extends StatelessWidget {
  const _AdherenceRing({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final palette = _CalendarPalette.of(context);
    return Semantics(
      label: '${(value * 100).round()} percent adherence',
      child: SizedBox.square(
        dimension: 48,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: value,
              strokeWidth: 5.5,
              strokeCap: StrokeCap.round,
              color: palette.accent,
              backgroundColor: palette.progressTrack,
            ),
            Center(
              child: Container(
                width: 35,
                height: 35,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.surface,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${(value * 100).round()}%',
                  style: TextStyle(
                    color: palette.ink,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.visibleMonth,
    required this.selectedDate,
    required this.referenceDate,
    required this.monthLabel,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelectDate,
    required this.statusFor,
  });

  final DateTime visibleMonth;
  final DateTime selectedDate;
  final DateTime referenceDate;
  final String monthLabel;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDate;
  final _DoseStatus? Function(DateTime date) statusFor;

  List<DateTime> get _dates {
    final monthStart = DateTime(visibleMonth.year, visibleMonth.month);
    final daysBefore = monthStart.weekday % 7;
    final gridStart = monthStart.subtract(Duration(days: daysBefore));
    return List.generate(42, (index) => gridStart.add(Duration(days: index)));
  }

  @override
  Widget build(BuildContext context) {
    final palette = _CalendarPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  monthLabel,
                  key: const Key('calendarMonthLabel'),
                  style: TextStyle(
                    color: palette.ink,
                    fontSize: 18,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.25,
                  ),
                ),
              ),
              _MonthControl(
                key: const Key('previousMonthButton'),
                label: 'Previous month',
                icon: CupertinoIcons.chevron_left,
                onPressed: onPreviousMonth,
              ),
              const SizedBox(width: 4),
              _MonthControl(
                key: const Key('nextMonthButton'),
                label: 'Next month',
                icon: CupertinoIcons.chevron_right,
                onPressed: onNextMonth,
              ),
            ],
          ),
          const SizedBox(height: 13),
          const Row(
            children: [
              _WeekdayLabel('SUN'),
              _WeekdayLabel('MON'),
              _WeekdayLabel('TUE'),
              _WeekdayLabel('WED'),
              _WeekdayLabel('THU'),
              _WeekdayLabel('FRI'),
              _WeekdayLabel('SAT'),
            ],
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              final cellWidth = (constraints.maxWidth - 24) / 7;
              return GridView.builder(
                key: const Key('calendarGrid'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: 42,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 6,
                  childAspectRatio: cellWidth / 34,
                ),
                itemBuilder: (context, index) {
                  final date = _dates[index];
                  return _CalendarDay(
                    date: date,
                    inVisibleMonth:
                        date.month == visibleMonth.month &&
                        date.year == visibleMonth.year,
                    selected: DateUtils.isSameDay(date, selectedDate),
                    status: statusFor(date),
                    onPressed: () => onSelectDate(date),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MonthControl extends StatelessWidget {
  const _MonthControl({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = _CalendarPalette.of(context);
    return Semantics(
      button: true,
      label: label,
      child: ResponsiveCupertinoButton(
        onPressed: onPressed,
        minimumSize: const Size.square(38),
        padding: EdgeInsets.zero,
        semanticLabel: label,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: palette.softAccent,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 15, color: palette.accent),
        ),
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = _CalendarPalette.of(context);
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: palette.muted,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: .15,
        ),
      ),
    );
  }
}

enum _DoseStatus { taken, missed }

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.date,
    required this.inVisibleMonth,
    required this.selected,
    required this.status,
    required this.onPressed,
  });

  final DateTime date;
  final bool inVisibleMonth;
  final bool selected;
  final _DoseStatus? status;
  final VoidCallback onPressed;

  String get _dateKey {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    final palette = _CalendarPalette.of(context);
    final statusLabel = switch (status) {
      _DoseStatus.taken => 'Dose taken',
      _DoseStatus.missed => 'Dose missed',
      null => null,
    };
    return Semantics(
      selected: selected,
      child: AppPressable(
        key: Key('calendarDay-$_dateKey'),
        onPressed: onPressed,
        semanticLabel: statusLabel == null ? '$date' : '$date, $statusLabel',
        borderRadius: BorderRadius.circular(9),
        hoverScale: 1.045,
        hoverOffset: Offset.zero,
        pressedScale: .88,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? palette.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: SizedBox.expand(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      color: selected
                          ? palette.onAccent
                          : inVisibleMonth
                          ? palette.ink
                          : palette.outsideMonth,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (status != null)
                  Positioned(
                    bottom: 3,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: selected
                            ? palette.onAccent
                            : status == _DoseStatus.taken
                            ? palette.positive
                            : palette.negative,
                        shape: BoxShape.circle,
                      ),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({super.key, required this.title, required this.onAdd});

  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final palette = _CalendarPalette.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            key: const Key('calendarSelectedDate'),
            style: TextStyle(
              color: palette.ink,
              fontSize: 18,
              height: 1.25,
              fontWeight: FontWeight.w700,
              letterSpacing: -.25,
            ),
          ),
        ),
        ResponsiveCupertinoButton(
          buttonKey: const Key('calendarAddButton'),
          onPressed: onAdd,
          minimumSize: const Size.square(44),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          semanticLabel: 'Add medication',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.add, size: 14, color: palette.accent),
              const SizedBox(width: 3),
              Text(
                'Add',
                style: TextStyle(
                  color: palette.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DoseList extends StatelessWidget {
  const _DoseList({
    required this.doses,
    required this.onTapDose,
    required this.onRemoveDose,
  });

  final List<_CalendarDose> doses;
  final ValueChanged<int> onTapDose;
  final ValueChanged<int> onRemoveDose;

  @override
  Widget build(BuildContext context) {
    final palette = _CalendarPalette.of(context);
    if (doses.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Text(
          'No medications scheduled',
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.muted, fontSize: 13),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 390;
        return Semantics(
          key: const Key('calendarDoseTable'),
          container: true,
          label: 'Medication dose list',
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                _DoseTableHeader(compact: compact),
                Divider(
                  key: const Key('calendarDoseTableHeaderDivider'),
                  height: 1,
                  thickness: 1,
                  indent: compact ? 10 : 12,
                  endIndent: compact ? 10 : 12,
                  color: palette.separator,
                ),
                for (var doseIndex = 0; doseIndex < doses.length; doseIndex++)
                  _DoseRow(
                    artworkSeed: doses[doseIndex].id,
                    artworkLabel: titleCaseDisplay(doses[doseIndex].name),
                    name: doses[doseIndex].name,
                    details: doses[doseIndex].details,
                    status: doses[doseIndex].isTaken ? 'Taken' : 'Due',
                    statusColor: doses[doseIndex].isTaken
                        ? palette.positive
                        : palette.muted,
                    compact: compact,
                    onTap: () => onTapDose(doseIndex),
                    onRemove: () => onRemoveDose(doseIndex),
                    showDivider: doseIndex < doses.length - 1,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DoseTableHeader extends StatelessWidget {
  const _DoseTableHeader({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final artworkColumnWidth = compact ? 40.0 : 48.0;
    final statusColumnWidth = compact ? 58.0 : 68.0;
    const actionColumnWidth = 44.0;
    return SizedBox(
      height: compact ? 34 : 38,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
        child: Row(
          children: [
            SizedBox(width: artworkColumnWidth),
            Expanded(
              flex: compact ? 5 : 6,
              child: _DoseTableHeaderText(
                key: const Key('calendarDoseTableMedicationHeader'),
                label: 'Medication',
              ),
            ),
            _DoseTableVerticalDivider(
              key: const Key('calendarDoseTableHeaderVerticalDivider0'),
            ),
            Expanded(
              flex: compact ? 4 : 5,
              child: _DoseTableHeaderText(
                key: const Key('calendarDoseTableDoseHeader'),
                label: 'Dose & Time',
              ),
            ),
            _DoseTableVerticalDivider(
              key: const Key('calendarDoseTableHeaderVerticalDivider1'),
            ),
            SizedBox(
              width: statusColumnWidth,
              child: _DoseTableHeaderText(
                key: const Key('calendarDoseTableStatusHeader'),
                label: 'Status',
                textAlign: TextAlign.end,
              ),
            ),
            const SizedBox(width: actionColumnWidth),
          ],
        ),
      ),
    );
  }
}

class _DoseTableHeaderText extends StatelessWidget {
  const _DoseTableHeaderText({super.key, required this.label, this.textAlign});

  final String label;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final palette = _CalendarPalette.of(context);
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: TextStyle(
        color: palette.muted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: .1,
      ),
    );
  }
}

class _DoseTableVerticalDivider extends StatelessWidget {
  const _DoseTableVerticalDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = _CalendarPalette.of(context);
    return SizedBox(
      width: 13,
      child: VerticalDivider(width: 1, thickness: .5, color: palette.separator),
    );
  }
}

class _DoseRow extends StatelessWidget {
  const _DoseRow({
    required this.artworkSeed,
    required this.artworkLabel,
    required this.name,
    required this.details,
    required this.status,
    required this.statusColor,
    required this.compact,
    required this.showDivider,
    required this.onTap,
    required this.onRemove,
  });

  final String artworkSeed;
  final String artworkLabel;
  final String name;
  final String details;
  final String status;
  final Color statusColor;
  final bool compact;
  final bool showDivider;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = _CalendarPalette.of(context);
    final artworkColumnWidth = compact ? 40.0 : 48.0;
    final statusColumnWidth = compact ? 58.0 : 68.0;
    const actionColumnWidth = 44.0;
    final row = AppPressable(
      onPressed: onTap,
      autoManageBusy: false,
      semanticLabel:
          '${titleCaseDisplay(name)}, ${titleCaseDisplay(details)}, $status',
      borderRadius: BorderRadius.zero,
      hoverScale: 1,
      hoverOffset: Offset.zero,
      pressedScale: .99,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: compact ? 66 : 72),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 10 : 11,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: artworkColumnWidth,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: MedicationArtwork(
                    key: Key('calendarMedicationArtwork_$artworkSeed'),
                    seed: artworkSeed,
                    label: artworkLabel,
                    size: compact ? 34 : 38,
                  ),
                ),
              ),
              Expanded(
                flex: compact ? 5 : 6,
                child: Text(
                  titleCaseDisplay(name),
                  key: Key('calendarMedicationName_$artworkSeed'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.ink,
                    fontSize: compact ? 12.5 : 13,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _DoseTableVerticalDivider(
                key: Key('calendarDoseTableRowVerticalDivider${artworkSeed}0'),
              ),
              Expanded(
                flex: compact ? 4 : 5,
                child: Text(
                  _detailsForTable(details),
                  key: Key('calendarDoseDetails_$artworkSeed'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: compact ? 10.5 : 11,
                    height: 1.3,
                  ),
                ),
              ),
              _DoseTableVerticalDivider(
                key: Key('calendarDoseTableRowVerticalDivider${artworkSeed}1'),
              ),
              SizedBox(
                width: statusColumnWidth,
                child: Text(
                  status,
                  key: Key('calendarDoseStatus_$artworkSeed'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: compact ? 10.5 : 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(
                width: actionColumnWidth,
                child: IconButton(
                  key: Key('calendarDeleteDose_$artworkSeed'),
                  onPressed: onRemove,
                  tooltip: 'Remove ${titleCaseDisplay(name)} from day',
                  icon: const Icon(CupertinoIcons.trash),
                  iconSize: 17,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: actionColumnWidth,
                    height: 44,
                  ),
                  visualDensity: VisualDensity.compact,
                  color: palette.negative,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Column(
      children: [
        row,
        if (showDivider)
          Divider(
            key: Key('calendarDoseTableRowDivider_$artworkSeed'),
            height: 1,
            thickness: 1,
            indent: compact ? 10 : 12,
            endIndent: compact ? 10 : 12,
            color: palette.separator,
          ),
      ],
    );
  }

  String _detailsForTable(String value) =>
      titleCaseDisplay(value.replaceFirst(' · ', '\n'));
}

enum _CalendarDoseAction { toggleTaken, remove }

class _CalendarDose {
  const _CalendarDose({
    this.id = '',
    required this.name,
    required this.details,
    this.status = 'due',
  });

  final String id;
  final String name;
  final String details;
  final String status;

  bool get isTaken => status == 'taken';

  _CalendarDose copyWith({String? status}) {
    return _CalendarDose(
      id: id,
      name: name,
      details: details,
      status: status ?? this.status,
    );
  }
}

class CalendarDoseData {
  const CalendarDoseData({
    required this.id,
    required this.localDate,
    required this.name,
    required this.details,
    required this.status,
  });

  final String id;
  final String localDate;
  final String name;
  final String details;
  final String status;
}

class _RemovedCalendarDose {
  const _RemovedCalendarDose({
    required this.dose,
    required this.dateKey,
    required this.index,
  });

  final _CalendarDose dose;
  final String dateKey;
  final int index;
}

class _CalendarPalette {
  const _CalendarPalette({
    required this.background,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.separator,
    required this.accent,
    required this.onAccent,
    required this.softAccent,
    required this.progressTrack,
    required this.positive,
    required this.negative,
    required this.outsideMonth,
  });

  factory _CalendarPalette.of(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    return _CalendarPalette(
      background: theme.scaffoldBackgroundColor,
      surface: colors.surface,
      ink: colors.onSurface,
      muted: colors.onSurfaceVariant,
      separator: colors.outlineVariant.withValues(alpha: dark ? .8 : .55),
      accent: colors.primary,
      onAccent: colors.onPrimary,
      softAccent: colors.primary.withValues(alpha: dark ? .2 : .1),
      progressTrack: colors.onSurface.withValues(alpha: dark ? .18 : .08),
      positive: dark ? const Color(0xFF30D158) : const Color(0xFF248A3D),
      negative: dark ? const Color(0xFFFF453A) : const Color(0xFFD12E26),
      outsideMonth: colors.onSurfaceVariant.withValues(alpha: .48),
    );
  }

  final Color background;
  final Color surface;
  final Color ink;
  final Color muted;
  final Color separator;
  final Color accent;
  final Color onAccent;
  final Color softAccent;
  final Color progressTrack;
  final Color positive;
  final Color negative;
  final Color outsideMonth;
}
