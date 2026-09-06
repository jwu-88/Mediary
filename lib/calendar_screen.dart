import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_interactions.dart';
import 'app_layout.dart';
import 'in_app_page.dart';

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
  final Future<void> Function(DateTime selectedDate)? onAddDose;
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
  String? _announcement;

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

  void _setInitialDate(DateTime value) {
    _referenceDate = DateUtils.dateOnly(value);
    _selectedDate = _referenceDate;
    _visibleMonth = DateTime(value.year, value.month);
    if (widget.initialDoses.isEmpty) _seedPreviewDoses(_referenceDate);
    _loadInitialDoses();
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  void _seedPreviewDoses(DateTime date) {
    _dosesByDate.putIfAbsent(
      _dateKey(date),
      () => [
        const _CalendarDose(
          name: 'Vitamin D3',
          details: '1000 IU · 8:00 AM',
          status: 'taken',
        ),
        const _CalendarDose(name: 'Amoxicillin', details: '500 mg · 10:30 AM'),
      ],
    );
  }

  void _loadInitialDoses() {
    if (widget.initialDoses.isEmpty) return;
    _dosesByDate.clear();
    for (final dose in widget.initialDoses) {
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

  List<_CalendarDose> _editableDosesFor(DateTime date) {
    return _dosesByDate.putIfAbsent(_dateKey(date), () => <_CalendarDose>[]);
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
      await widget.onAddDose!(_selectedDate);
      return;
    }
    if (widget.onAdd != null) {
      widget.onAdd!();
      return;
    }
    final dose = await pushInAppPage<_CalendarDose>(
      context,
      builder: (context) => InAppOptionPage<_CalendarDose>(
        title: 'Add Medication',
        subtitle: _longDate(_selectedDate),
        options: const [
          InAppPageOption(
            label: 'Cetirizine',
            detail: '10 mg · 8:00 PM',
            value: _CalendarDose(
              name: 'Cetirizine',
              details: '10 mg · 8:00 PM',
            ),
          ),
          InAppPageOption(
            label: 'Ibuprofen',
            detail: '200 mg · As Needed',
            value: _CalendarDose(
              name: 'Ibuprofen',
              details: '200 mg · As Needed',
            ),
          ),
        ],
      ),
    );
    if (!mounted || dose == null) return;
    setState(() => _editableDosesFor(_selectedDate).add(dose));
    _showConfirmation('${dose.name} Added');
  }

  Future<void> _showDoseActions(int index) async {
    final doses = _dosesByDate[_dateKey(_selectedDate)];
    if (doses == null || index < 0 || index >= doses.length) return;
    final dose = doses[index];
    final action = await pushInAppPage<_CalendarDoseAction>(
      context,
      builder: (context) => InAppOptionPage<_CalendarDoseAction>(
        title: dose.name,
        subtitle: dose.details,
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
          setState(() => doses[index] = dose.copyWith(status: nextStatus));
          _showConfirmation(dose.isTaken ? 'Dose Marked Due' : 'Dose Taken');
        } catch (_) {
          _showConfirmation('Dose could not be updated');
        }
      case _CalendarDoseAction.remove:
        try {
          await widget.onDoseStatusChanged?.call(dose.id, 'cancelled');
          if (!mounted) return;
          setState(() => doses[index] = dose.copyWith(status: 'cancelled'));
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
        ? responsiveContentWidth(context, nativeMaxWidth: 760)
        : 520.0;
    return ColoredBox(
      color: palette.background,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentWidth),
            child: ListView(
              key: const Key('calendarScrollView'),
              padding: EdgeInsets.fromLTRB(16, 7, 16, widget.bottomPadding),
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
                          ),
                        ),
                ),
                const SizedBox(height: 14),
                _AdherenceSummary(month: _months[_visibleMonth.month - 1]),
                const SizedBox(height: 18),
                _CalendarCard(
                  visibleMonth: _visibleMonth,
                  selectedDate: _selectedDate,
                  referenceDate: _referenceDate,
                  monthLabel: _monthYear(_visibleMonth),
                  onPreviousMonth: () => _moveMonth(-1),
                  onNextMonth: () => _moveMonth(1),
                  onSelectDate: _selectDate,
                ),
                const SizedBox(height: 17),
                _SectionHeader(
                  title: _longDate(_selectedDate),
                  onAdd: _addDose,
                ),
                const SizedBox(height: 8),
                _DoseList(
                  doses: _dosesFor(_selectedDate),
                  onTapDose: _showDoseActions,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarInlineStatus extends StatelessWidget {
  const _CalendarInlineStatus({required this.message, required this.onDismiss});

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
  const _AdherenceSummary({required this.month});

  final String month;

  @override
  Widget build(BuildContext context) {
    final palette = _CalendarPalette.of(context);
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
                  '43 of 50 doses',
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
          const _AdherenceRing(),
        ],
      ),
    );
  }
}

class _AdherenceRing extends StatelessWidget {
  const _AdherenceRing();

  @override
  Widget build(BuildContext context) {
    final palette = _CalendarPalette.of(context);
    return Semantics(
      label: '86 percent adherence',
      child: SizedBox.square(
        dimension: 48,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: .86,
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
                  '86%',
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
  });

  final DateTime visibleMonth;
  final DateTime selectedDate;
  final DateTime referenceDate;
  final String monthLabel;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDate;

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
        borderRadius: BorderRadius.circular(14),
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
                    status: _statusFor(date),
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

  _DoseStatus? _statusFor(DateTime date) {
    if (date.month != visibleMonth.month || date.year != visibleMonth.year) {
      return null;
    }
    if (DateUtils.dateOnly(date).isAfter(referenceDate)) return null;
    if (date.day == 10 || date.day == 18) return _DoseStatus.missed;
    return _DoseStatus.taken;
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
      _DoseStatus.taken => 'dose taken',
      _DoseStatus.missed => 'dose missed',
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
  const _SectionHeader({required this.title, required this.onAdd});

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
  const _DoseList({required this.doses, required this.onTapDose});

  final List<_CalendarDose> doses;
  final ValueChanged<int> onTapDose;

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
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: List.generate(doses.length * 2 - 1, (index) {
          if (index.isOdd) {
            return Divider(
              height: 1,
              thickness: 1,
              indent: 62,
              color: palette.separator,
            );
          }
          final doseIndex = index ~/ 2;
          final dose = doses[doseIndex];
          return _DoseRow(
            iconColor: dose.isTaken ? palette.positive : palette.accent,
            iconBackground: dose.isTaken
                ? palette.positive.withValues(alpha: .12)
                : palette.softAccent,
            name: dose.name,
            details: dose.details,
            status: dose.isTaken ? 'Taken' : 'Due',
            statusColor: dose.isTaken ? palette.positive : palette.muted,
            onTap: () => onTapDose(doseIndex),
          );
        }),
      ),
    );
  }
}

class _DoseRow extends StatelessWidget {
  const _DoseRow({
    required this.iconColor,
    required this.iconBackground,
    required this.name,
    required this.details,
    required this.status,
    required this.statusColor,
    required this.onTap,
  });

  final Color iconColor;
  final Color iconBackground;
  final String name;
  final String details;
  final String status;
  final Color statusColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = _CalendarPalette.of(context);
    return AppPressable(
      onPressed: onTap,
      autoManageBusy: false,
      semanticLabel: '$name, $details, $status',
      borderRadius: BorderRadius.zero,
      hoverScale: 1,
      hoverOffset: Offset.zero,
      pressedScale: .99,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.capsule_fill,
                color: iconColor,
                size: 17,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: palette.ink,
                      fontSize: 14,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    details,
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 5),
            Icon(
              CupertinoIcons.chevron_right,
              color: palette.muted.withValues(alpha: .65),
              size: 12,
            ),
          ],
        ),
      ),
    );
  }
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
