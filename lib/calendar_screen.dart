import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// A native, interactive medication calendar based on the calendar prototype.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, this.initialDate, this.onAdd});

  final DateTime? initialDate;
  final VoidCallback? onAdd;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const _background = Color(0xFFF2F2F7);
  static const _surface = Color(0xFFFFFFFF);
  static const _ink = Color(0xFF1C1C1E);
  static const _muted = Color(0xFF6E6E73);
  static const _separator = Color(0xFFD9D9DE);
  static const _blue = Color(0xFF0A62D0);
  static const _softBlue = Color(0x1A0A62D0);
  static const _green = Color(0xFF34C759);
  static const _red = Color(0xFFFF3B30);

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
    return ColoredBox(
      color: _background,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              key: const Key('calendarScrollView'),
              padding: const EdgeInsets.fromLTRB(16, 7, 16, 120),
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
                  onAdd: widget.onAdd ?? () {},
                ),
                const SizedBox(height: 8),
                const _DoseList(),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR ROUTINE',
                style: TextStyle(
                  color: _CalendarScreenState._muted,
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .45,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Calendar',
                style: TextStyle(
                  color: _CalendarScreenState._ink,
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
          child: const Icon(
            CupertinoIcons.ellipsis,
            color: _CalendarScreenState._blue,
            size: 21,
          ),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 7, 2, 15),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _CalendarScreenState._separator),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$month adherence',
                  style: const TextStyle(
                    color: _CalendarScreenState._muted,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 1),
                const Text(
                  '43 of 50 doses',
                  key: Key('calendarAdherenceCount'),
                  style: TextStyle(
                    color: _CalendarScreenState._ink,
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
    return Semantics(
      label: '86 percent adherence',
      child: SizedBox.square(
        dimension: 48,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const CircularProgressIndicator(
              value: .86,
              strokeWidth: 5.5,
              strokeCap: StrokeCap.round,
              color: _CalendarScreenState._blue,
              backgroundColor: Color(0xFFECEEF5),
            ),
            Center(
              child: Container(
                width: 35,
                height: 35,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: _CalendarScreenState._surface,
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  '86%',
                  style: TextStyle(
                    color: _CalendarScreenState._ink,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _CalendarScreenState._surface,
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
                  style: const TextStyle(
                    color: _CalendarScreenState._ink,
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
          decoration: const BoxDecoration(
            color: _CalendarScreenState._softBlue,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 15, color: _CalendarScreenState._blue),
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
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _CalendarScreenState._muted,
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
            color: selected ? _CalendarScreenState._blue : Colors.transparent,
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
                          ? Colors.white
                          : inVisibleMonth
                          ? _CalendarScreenState._ink
                          : const Color(0xFFC1C5D0),
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
                            ? Colors.white
                            : status == _DoseStatus.taken
                            ? _CalendarScreenState._green
                            : _CalendarScreenState._red,
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
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            key: const Key('calendarSelectedDate'),
            style: const TextStyle(
              color: _CalendarScreenState._ink,
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
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.add, size: 14),
              SizedBox(width: 3),
              Text(
                'Add',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DoseList extends StatelessWidget {
  const _DoseList();

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _CalendarScreenState._surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        children: [
          _DoseRow(
            iconColor: _CalendarScreenState._green,
            iconBackground: Color(0x1C34C759),
            name: 'Vitamin D3',
            details: '1000 IU · 8:00 AM',
            status: 'Taken',
            statusColor: _CalendarScreenState._green,
          ),
          Divider(
            height: 1,
            thickness: 1,
            indent: 62,
            color: _CalendarScreenState._separator,
          ),
          _DoseRow(
            iconColor: _CalendarScreenState._blue,
            iconBackground: Color(0x1A0A62D0),
            name: 'Amoxicillin',
            details: '500 mg · 10:30 AM',
            status: 'Due',
            statusColor: _CalendarScreenState._muted,
          ),
        ],
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
  });

  final Color iconColor;
  final Color iconBackground;
  final String name;
  final String details;
  final String status;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$name, $details, $status',
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
                    style: const TextStyle(
                      color: _CalendarScreenState._ink,
                      fontSize: 14,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    details,
                    style: const TextStyle(
                      color: _CalendarScreenState._muted,
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
          ],
        ),
      ),
    );
  }
}
