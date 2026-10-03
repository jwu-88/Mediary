import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_layout.dart';
import 'in_app_page.dart';
import 'time_formatting.dart';

class MedicationTimeSelectionPage extends StatefulWidget {
  const MedicationTimeSelectionPage({
    super.key,
    required this.initialTime,
    this.scheduledDate,
    this.minimumDateTime,
    this.scheduledTimezone,
    this.use24HourFormat = false,
  });

  final TimeOfDay initialTime;
  final DateTime? scheduledDate;
  final DateTime? minimumDateTime;
  final String? scheduledTimezone;
  final bool use24HourFormat;

  @override
  State<MedicationTimeSelectionPage> createState() =>
      _MedicationTimeSelectionPageState();
}

class _MedicationTimeSelectionPageState
    extends State<MedicationTimeSelectionPage> {
  static const _presets = [
    ('Morning', MedicationTime(hour: 8, minute: 0)),
    ('Noon', MedicationTime(hour: 12, minute: 0)),
    ('Evening', MedicationTime(hour: 18, minute: 0)),
    ('Bedtime', MedicationTime(hour: 21, minute: 0)),
  ];

  late int _hour = widget.initialTime.hour;
  late int _minute = widget.initialTime.minute;
  late bool _isPm = _hour >= 12;
  late final FixedExtentScrollController _hourController =
      FixedExtentScrollController(initialItem: _hourWheelIndex);
  late final FixedExtentScrollController _minuteController =
      FixedExtentScrollController(initialItem: _minute);
  late final FixedExtentScrollController _periodController =
      FixedExtentScrollController(initialItem: _isPm ? 1 : 0);

  int get _hourWheelIndex => widget.use24HourFormat
      ? _hour
      : ((_hour % 12 == 0 ? 12 : _hour % 12) - 1);

  MedicationTime get _selectedTime =>
      MedicationTime(hour: _hour, minute: _minute);

  bool get _isPastSelection {
    final date = widget.scheduledDate;
    final minimum = widget.minimumDateTime;
    if (date == null || minimum == null) return false;
    final selectedDateTime = widget.scheduledTimezone == null
        ? _selectedTime.onDate(date)
        : medicationScheduledDate(
            date,
            _selectedTime,
            widget.scheduledTimezone!,
          );
    return !selectedDateTime.isAfter(minimum);
  }

  bool _isSelected(MedicationTime time) =>
      time.hour == _hour && time.minute == _minute;

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  void _setPreset(MedicationTime time) {
    setState(() {
      _hour = time.hour;
      _minute = time.minute;
      _isPm = _hour >= 12;
    });
    _hourController.jumpToItem(_hourWheelIndex);
    _minuteController.jumpToItem(_minute);
    _periodController.jumpToItem(_isPm ? 1 : 0);
  }

  void _setHourWheelValue(int value) {
    if (widget.use24HourFormat) {
      setState(() => _hour = value);
      return;
    }
    final hour12 = value + 1;
    setState(() => _hour = (_isPm ? 12 : 0) + (hour12 % 12));
  }

  void _setPeriod(bool isPm) {
    if (widget.use24HourFormat) return;
    final hour12 = _hour % 12 == 0 ? 12 : _hour % 12;
    setState(() {
      _isPm = isPm;
      _hour = (isPm ? 12 : 0) + (hour12 % 12);
    });
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required List<String> labels,
    required ValueChanged<int> onSelectedItemChanged,
    required String semanticLabel,
  }) {
    return Expanded(
      child: Semantics(
        key: Key('timeWheel_$semanticLabel'),
        label: semanticLabel,
        child: CupertinoPicker(
          scrollController: controller,
          itemExtent: 46,
          diameterRatio: 1.15,
          squeeze: .92,
          selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(
            background: Colors.transparent,
          ),
          onSelectedItemChanged: onSelectedItemChanged,
          children: [
            for (final label in labels)
              Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hourLabels = widget.use24HourFormat
        ? [
            for (var hour = 0; hour < 24; hour++)
              hour.toString().padLeft(2, '0'),
          ]
        : [for (var hour = 1; hour <= 12; hour++) hour.toString()];
    final minuteLabels = [
      for (var minute = 0; minute < 60; minute++)
        minute.toString().padLeft(2, '0'),
    ];
    final selectedLabel = _selectedTime.format(
      widget.use24HourFormat
          ? TimeDisplayFormat.twentyFourHour
          : TimeDisplayFormat.twelveHour,
    );
    final desktopLayout = AppBreakpoints.isDesktop(context);
    final wheelGroupWidth = desktopLayout ? 560.0 : double.infinity;

    return InAppPageScaffold(
      title: 'Choose Time',
      actions: [
        TextButton(
          key: const Key('confirmScheduleTimeButton'),
          onPressed: _isPastSelection
              ? null
              : () => Navigator.of(context).pop(_selectedTime),
          child: const Text('Done'),
        ),
      ],
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Text(
            'Scroll through the wheels to set the reminder time in hours and minutes.',
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.45),
          ),
          if (_isPastSelection) ...[
            const SizedBox(height: 8),
            Text(
              'Choose a future time for this medication.',
              key: const Key('pastScheduleTimeError'),
              style: TextStyle(color: colors.error, height: 1.35),
            ),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: .42),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.primary.withValues(alpha: .22)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  color: colors.primary,
                  size: 26,
                ),
                const SizedBox(height: 8),
                Text(
                  selectedLabel,
                  key: const Key('selectedScheduleTime'),
                  style: TextStyle(
                    color: colors.onPrimaryContainer,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  key: const Key('medicationTimePickerWheelGroup'),
                  width: wheelGroupWidth,
                  height: 184,
                  child: Row(
                    children: [
                      _wheel(
                        controller: _hourController,
                        labels: hourLabels,
                        onSelectedItemChanged: _setHourWheelValue,
                        semanticLabel: 'Hours',
                      ),
                      const Text(':', style: TextStyle(fontSize: 24)),
                      _wheel(
                        controller: _minuteController,
                        labels: minuteLabels,
                        onSelectedItemChanged: (value) =>
                            setState(() => _minute = value),
                        semanticLabel: 'Minutes',
                      ),
                      if (!widget.use24HourFormat) ...[
                        const SizedBox(width: 4),
                        _wheel(
                          controller: _periodController,
                          labels: const ['AM', 'PM'],
                          onSelectedItemChanged: (value) =>
                              _setPeriod(value == 1),
                          semanticLabel: 'AM or PM',
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Quick Choices',
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in _presets)
                ChoiceChip(
                  key: Key('scheduleTimePreset_${preset.$1}'),
                  label: Text(
                    '${preset.$1} · ${preset.$2.format(widget.use24HourFormat ? TimeDisplayFormat.twentyFourHour : TimeDisplayFormat.twelveHour)}',
                  ),
                  selected: _isSelected(preset.$2),
                  onSelected: (_) => _setPreset(preset.$2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Reminder times use hours and minutes.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
