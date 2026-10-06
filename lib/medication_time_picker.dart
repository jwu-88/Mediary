import 'app_controls.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
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
  late final _hourInput = TextEditingController(text: _inputHourLabel);
  late final _minuteInput = TextEditingController(
    text: _minute.toString().padLeft(2, '0'),
  );

  String get _inputHourLabel => widget.use24HourFormat
      ? _hour.toString().padLeft(2, '0')
      : (_hour % 12 == 0 ? 12 : _hour % 12).toString();

  bool get _inputValid {
    final hour = int.tryParse(_hourInput.text);
    final minute = int.tryParse(_minuteInput.text);
    return hour != null &&
        minute != null &&
        minute >= 0 &&
        minute <= 59 &&
        hour >= (widget.use24HourFormat ? 0 : 1) &&
        hour <= (widget.use24HourFormat ? 23 : 12);
  }

  void _readInput() {
    setState(() {
      if (!_inputValid) return;
      final hour = int.parse(_hourInput.text);
      _hour = widget.use24HourFormat ? hour : hour % 12 + (_isPm ? 12 : 0);
      _minute = int.parse(_minuteInput.text);
    });
  }

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
    _hourInput.dispose();
    _minuteInput.dispose();
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
    _hourInput.text = _inputHourLabel;
    _minuteInput.text = _minute.toString().padLeft(2, '0');
    if (_hourController.hasClients) _hourController.jumpToItem(_hourWheelIndex);
    if (_minuteController.hasClients) _minuteController.jumpToItem(_minute);
    if (_periodController.hasClients) {
      _periodController.jumpToItem(_isPm ? 1 : 0);
    }
  }

  void _setHourWheelValue(int value) {
    if (widget.use24HourFormat) {
      setState(() => _hour = value);
      _hourInput.text = _inputHourLabel;
      return;
    }
    final hour12 = value + 1;
    setState(() => _hour = (_isPm ? 12 : 0) + (hour12 % 12));
    _hourInput.text = _inputHourLabel;
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

  Widget _keyboardTimeInput() {
    return Row(
      key: const Key('medicationTimeKeyboardInput'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            key: const Key('scheduleHourInput'),
            controller: _hourInput,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Hour',
              hintText: widget.use24HourFormat ? '0–23' : '1–12',
            ),
            onChanged: (_) => _readInput(),
          ),
        ),
        const Padding(padding: EdgeInsets.all(12), child: Text(':')),
        Expanded(
          child: TextFormField(
            key: const Key('scheduleMinuteInput'),
            controller: _minuteInput,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Minute',
              hintText: '0–59',
            ),
            onChanged: (_) => _readInput(),
            onFieldSubmitted: (_) {
              if (_inputValid && !_isPastSelection) {
                Navigator.of(context).pop(_selectedTime);
              }
            },
          ),
        ),
        if (!widget.use24HourFormat) ...[
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<bool>(
              key: ValueKey('schedulePeriod_$_isPm'),
              initialValue: _isPm,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Period'),
              items: const [
                DropdownMenuItem(value: false, child: Text('AM')),
                DropdownMenuItem(value: true, child: Text('PM')),
              ],
              onChanged: (value) {
                if (value != null) _setPeriod(value);
              },
            ),
          ),
        ],
      ],
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
    final keyboardInput = kIsWeb || desktopLayout;
    final wheelGroupWidth = desktopLayout ? 560.0 : double.infinity;

    return InAppPageScaffold(
      title: 'Choose Time',
      actions: [
        AppButton(
          key: const Key('confirmScheduleTimeButton'),
          label: 'Done',
          compact: true,
          variant: AppButtonVariant.tertiary,
          onPressed: _isPastSelection || (keyboardInput && !_inputValid)
              ? null
              : () => Navigator.of(context).pop(_selectedTime),
        ),
      ],
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Text(
            keyboardInput
                ? 'Enter a reminder time or choose a common time below.'
                : 'Scroll through the wheels to set the reminder time in hours and minutes.',
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.45),
          ),
          if (keyboardInput && !_inputValid)
            Text(
              'Enter a valid hour and a minute from 0 to 59.',
              style: TextStyle(color: colors.error),
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
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: desktopLayout ? 760 : double.infinity,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: .42),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: .22),
                  ),
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
                    if (keyboardInput)
                      _keyboardTimeInput()
                    else
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
                              onSelectedItemChanged: (value) {
                                setState(() => _minute = value);
                                _minuteInput.text = value.toString().padLeft(
                                  2,
                                  '0',
                                );
                              },
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
