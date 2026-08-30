import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// A native, interactive medication calendar based on the calendar prototype.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    this.initialDate,
    this.onAdd,
    this.bottomPadding = 120,
  });

  final DateTime? initialDate;
  final VoidCallback? onAdd;
  final double bottomPadding;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
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

  @override
  void initState() {
    super.initState();
    _setInitialDate(widget.initialDate ?? DateTime.now());
  }

  @override
  void didUpdateWidget(CalendarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDate != oldWidget.initialDate &&
        widget.initialDate != null) {
      _setInitialDate(widget.initialDate!);
    }
  }

  void _setInitialDate(DateTime value) {
    _referenceDate = DateUtils.dateOnly(value);
    _selectedDate = _referenceDate;
    _visibleMonth = DateTime(value.year, value.month);
    _ensureDoses(_selectedDate);
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  List<_CalendarDose> _ensureDoses(DateTime date) {
    return _dosesByDate.putIfAbsent(
      _dateKey(date),
      () => [
        const _CalendarDose(
          name: 'Vitamin D3',
          details: '1000 IU · 8:00 AM',
          isTaken: true,
        ),
        const _CalendarDose(name: 'Amoxicillin', details: '500 mg · 10:30 AM'),
      ],
    );
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
      _ensureDoses(_selectedDate);
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = DateUtils.dateOnly(date);
      if (date.year != _visibleMonth.year ||
          date.month != _visibleMonth.month) {
        _visibleMonth = DateTime(date.year, date.month);
      }
      _ensureDoses(_selectedDate);
    });
  }

  void _jumpToToday() {
    final today = DateUtils.dateOnly(DateTime.now());
    setState(() {
      _selectedDate = today;
      _visibleMonth = DateTime(today.year, today.month);
      _ensureDoses(_selectedDate);
    });
  }

  Future<void> _addDose() async {
    if (widget.onAdd != null) {
      widget.onAdd!();
      return;
    }
    final dose = await showCupertinoModalPopup<_CalendarDose>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Add Medication'),
        message: Text(_longDate(_selectedDate)),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(
              context,
              const _CalendarDose(
                name: 'Cetirizine',
                details: '10 mg · 8:00 PM',
              ),
            ),
            child: const Text('Cetirizine'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(
              context,
              const _CalendarDose(
                name: 'Ibuprofen',
                details: '200 mg · As Needed',
              ),
            ),
            child: const Text('Ibuprofen'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (!mounted || dose == null) return;
    setState(() => _ensureDoses(_selectedDate).add(dose));
    _showConfirmation('${dose.name} Added');
  }

  Future<void> _showDoseActions(int index) async {
    final doses = _ensureDoses(_selectedDate);
    final dose = doses[index];
    final action = await showCupertinoModalPopup<_CalendarDoseAction>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(dose.name),
        message: Text(dose.details),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () =>
                Navigator.pop(context, _CalendarDoseAction.toggleTaken),
            child: Text(dose.isTaken ? 'Mark As Due' : 'Mark As Taken'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, _CalendarDoseAction.remove),
            child: const Text('Remove From Day'),
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
      case _CalendarDoseAction.toggleTaken:
        setState(() => doses[index] = dose.copyWith(isTaken: !dose.isTaken));
        _showConfirmation(dose.isTaken ? 'Dose Marked Due' : 'Dose Taken');
      case _CalendarDoseAction.remove:
        setState(() => doses.removeAt(index));
        _showConfirmation('${dose.name} Removed');
    }
  }

  void _showConfirmation(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showOptions() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Calendar'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _jumpToToday();
            },
            child: const Text('Jump to Today'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  String _monthYear(DateTime date) => '${_months[date.month - 1]} ${date.year}';

  String _longDate(DateTime date) {
    final weekday = _weekdays[date.weekday % 7];
    return '$weekday, ${_months[date.month - 1]} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = _CalendarPalette.of(context);
    return ColoredBox(
      color: palette.background,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              key: const Key('calendarScrollView'),
              padding: EdgeInsets.fromLTRB(16, 7, 16, widget.bottomPadding),
              children: [
                _CalendarHeader(onOptions: _showOptions),
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
                  doses: _ensureDoses(_selectedDate),
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
        CupertinoButton(
          key: const Key('calendarOptionsButton'),
          onPressed: onOptions,
          minimumSize: const Size.square(44),
          padding: EdgeInsets.zero,
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
      child: CupertinoButton(
        onPressed: onPressed,
        minimumSize: const Size.square(38),
        padding: EdgeInsets.zero,
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
      button: true,
      label: statusLabel == null ? '$date' : '$date, $statusLabel',
      child: CupertinoButton(
        key: Key('calendarDay-$_dateKey'),
        onPressed: onPressed,
        minimumSize: Size.zero,
        padding: EdgeInsets.zero,
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
        CupertinoButton(
          key: const Key('calendarAddButton'),
          onPressed: onAdd,
          minimumSize: const Size.square(44),
          padding: const EdgeInsets.symmetric(horizontal: 4),
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
    return Semantics(
      button: true,
      label: '$name, $details, $status',
      child: CupertinoButton(
        onPressed: onTap,
        minimumSize: Size.zero,
        padding: EdgeInsets.zero,
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
      ),
    );
  }
}

enum _CalendarDoseAction { toggleTaken, remove }

class _CalendarDose {
  const _CalendarDose({
    required this.name,
    required this.details,
    this.isTaken = false,
  });

  final String name;
  final String details;
  final bool isTaken;

  _CalendarDose copyWith({bool? isTaken}) {
    return _CalendarDose(
      name: name,
      details: details,
      isTaken: isTaken ?? this.isTaken,
    );
  }
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
