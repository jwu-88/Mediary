import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'liquid_glass_back_button.dart';

/// A weekly medication-adherence report that can be pushed as a standalone
/// route.
///
/// The default values are realistic preview data. Pass seven entries for each
/// data series when connecting this screen to stored medication history.
class WeeklyReportScreen extends StatelessWidget {
  const WeeklyReportScreen({
    super.key,
    this.weekEnding,
    this.dailyTaken = const [2, 2, 2, 1, 2, 1, 1],
    this.dailyScheduled = const [2, 2, 2, 2, 2, 1, 1],
    this.timingOffsetsMinutes = const [2, -1, 5, 12, 4, 8, 9],
  });

  final DateTime? weekEnding;
  final List<int> dailyTaken;
  final List<int> dailyScheduled;
  final List<int> timingOffsetsMinutes;

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _accessibleDayLabels = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _green = Color(0xFF22A447);

  int get _taken => dailyTaken.fold(0, (sum, value) => sum + value);

  int get _scheduled => dailyScheduled.fold(0, (sum, value) => sum + value);

  int get _adherence {
    if (_scheduled == 0) return 0;
    return ((_taken / _scheduled) * 100).round().clamp(0, 100);
  }

  int get _averageTiming {
    if (timingOffsetsMinutes.isEmpty) return 0;
    final total = timingOffsetsMinutes.fold<int>(
      0,
      (sum, value) => sum + value.abs(),
    );
    return (total / timingOffsetsMinutes.length).round();
  }

  String get _missedDoseDescription {
    final missedDays = <String>[];
    for (var index = 0; index < dailyScheduled.length; index++) {
      if (dailyTaken[index] < dailyScheduled[index]) {
        missedDays.add(_dayLabels[index]);
      }
    }
    if (missedDays.isEmpty) return 'No missed doses';
    if (missedDays.length == 1) return '1 missed dose on ${missedDays.first}';
    return '${missedDays.length} missed doses this week';
  }

  String get _dailyDoseSemantics {
    final dailyDetails = List<String>.generate(7, (index) {
      final taken = math.max(0, dailyTaken[index]);
      final scheduled = math.max(0, dailyScheduled[index]);
      return '${_accessibleDayLabels[index]}: $taken of $scheduled taken';
    });
    return 'Daily dose chart. ${dailyDetails.join('; ')}.';
  }

  String _monthName(int month) => const [
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
  ][month - 1];

  String _formatDate(DateTime date) =>
      '${_monthName(date.month)} ${date.day}, ${date.year}';

  String _summary(DateTime ending) {
    final missed = _scheduled - _taken;
    final dosePhrase = missed <= 0
        ? 'No scheduled doses were missed.'
        : '$missed scheduled ${missed == 1 ? 'dose was' : 'doses were'} missed.';
    return 'For the week ending ${_formatDate(ending)}, '
        '$_taken of $_scheduled scheduled doses were taken '
        '($_adherence% adherence). $dosePhrase Doses were taken an average '
        'of $_averageTiming minutes from their scheduled time.';
  }

  Future<void> _prepareSummary(BuildContext context, DateTime ending) async {
    final summary = _summary(ending);
    await Clipboard.setData(ClipboardData(text: summary));
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => _PreparedSummarySheet(summary: summary),
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(dailyTaken.length == 7, 'dailyTaken must contain seven values.');
    assert(
      dailyScheduled.length == 7,
      'dailyScheduled must contain seven values.',
    );
    assert(
      timingOffsetsMinutes.length == 7,
      'timingOffsetsMinutes must contain seven values.',
    );
    final ending = DateUtils.dateOnly(weekEnding ?? DateTime.now());
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final missed = math.max(0, _scheduled - _taken);

    return Scaffold(
      appBar: AppBar(
        leading: Center(
          child: LiquidGlassBackButton(
            key: const Key('weeklyReportBackButton'),
            semanticLabel: 'Back from Weekly Report',
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        centerTitle: true,
        title: const Text(
          'Weekly Report',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              key: const Key('weeklyReportScrollView'),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              children: [
                Text(
                  'Week Ending ${_formatDate(ending)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Adherence',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Semantics(
                      label: '$_adherence percent medication adherence',
                      child: SizedBox.square(
                        dimension: 112,
                        child: CustomPaint(
                          key: const Key('adherenceChart'),
                          painter: _AdherenceRingPainter(
                            progress: _adherence / 100,
                            trackColor: colors.outlineVariant.withValues(
                              alpha: 0.28,
                            ),
                            progressColor: _green,
                          ),
                          child: Center(
                            child: Text(
                              '$_adherence%',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.6,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ReportMetric(
                            value: '$_taken of $_scheduled',
                            label: 'Doses Taken',
                          ),
                          const SizedBox(height: 16),
                          _ReportMetric(
                            value: missed == 0 ? 'None' : '$missed',
                            label: 'Missed Doses',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                _SectionHeading(
                  title: 'Daily Doses',
                  detail: _missedDoseDescription,
                ),
                const SizedBox(height: 20),
                Semantics(
                  key: const Key('dailyDoseChartSemantics'),
                  label: _dailyDoseSemantics,
                  child: SizedBox(
                    key: const Key('dailyDoseChart'),
                    height: 184,
                    child: CustomPaint(
                      painter: _DailyDoseChartPainter(
                        completed: dailyTaken,
                        scheduled: dailyScheduled,
                        labels: _dayLabels,
                        barColor: _green,
                        trackColor: colors.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                        labelColor: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 42),
                _SectionHeading(
                  title: 'Dose Timing',
                  detail: '$_averageTiming Min Average',
                ),
                const SizedBox(height: 20),
                Semantics(
                  label:
                      'Dose timing chart. Average timing was $_averageTiming minutes from schedule.',
                  child: SizedBox(
                    key: const Key('doseTimingChart'),
                    height: 168,
                    child: CustomPaint(
                      painter: _TimingChartPainter(
                        offsets: timingOffsetsMinutes,
                        labels: _dayLabels,
                        lineColor: colors.primary,
                        gridColor: colors.outlineVariant.withValues(
                          alpha: 0.34,
                        ),
                        labelColor: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 42),
                Text(
                  'Highlights',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 16),
                _HighlightRow(
                  icon: CupertinoIcons.check_mark_circled_solid,
                  iconColor: _green,
                  title: 'Strong Weekly Adherence',
                  detail: 'You completed $_adherence% of scheduled doses.',
                ),
                const SizedBox(height: 20),
                _HighlightRow(
                  icon: CupertinoIcons.clock_fill,
                  iconColor: colors.primary,
                  title: 'Consistent Timing',
                  detail:
                      'Doses were within $_averageTiming minutes of schedule on average.',
                ),
                const SizedBox(height: 42),
                FilledButton(
                  key: const Key('prepareSummaryButton'),
                  onPressed: () => _prepareSummary(context, ending),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Prepare Summary'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
        Text(
          detail,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _HighlightRow extends StatelessWidget {
  const _HighlightRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 21, color: iconColor),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreparedSummarySheet extends StatelessWidget {
  const _PreparedSummarySheet({required this.summary});

  final String summary;

  Future<void> _copyAgain(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: summary));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Summary Copied')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        4,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prepared Summary',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Copied to your clipboard',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            SelectableText(
              summary,
              key: const Key('preparedSummaryText'),
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('copySummaryAgainButton'),
                    onPressed: () => _copyAgain(context),
                    child: const Text('Copy Again'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('closeSummaryButton'),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdherenceRingPainter extends CustomPainter {
  const _AdherenceRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9;
    final value = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 9;
    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0, 1),
      false,
      value,
    );
  }

  @override
  bool shouldRepaint(covariant _AdherenceRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor;
}

class _DailyDoseChartPainter extends CustomPainter {
  const _DailyDoseChartPainter({
    required this.completed,
    required this.scheduled,
    required this.labels,
    required this.barColor,
    required this.trackColor,
    required this.labelColor,
  });

  final List<int> completed;
  final List<int> scheduled;
  final List<String> labels;
  final Color barColor;
  final Color trackColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    const labelBandHeight = 24.0;
    const labelGap = 10.0;
    const topPadding = 6.0;
    const segmentGap = 5.0;
    final plotBottom = size.height - labelBandHeight - labelGap;
    final chartHeight = math.max(0.0, plotBottom - topPadding);
    final columnWidth = size.width / labels.length;
    final barWidth = math.min(22.0, columnWidth * 0.4);
    final maxScheduled = math.max(1, scheduled.fold<int>(0, math.max));

    final missedPaint = Paint()..color = trackColor;
    final completedPaint = Paint()..color = barColor;

    for (var index = 0; index < labels.length; index++) {
      final x = columnWidth * index + columnWidth / 2;
      final scheduledCount = math.max(0, scheduled[index]);
      final completedCount = math.min(
        math.max(0, completed[index]),
        scheduledCount,
      );
      final missedCount = scheduledCount - completedCount;
      final totalHeight = chartHeight * (scheduledCount / maxScheduled);
      final hasTwoSegments = completedCount > 0 && missedCount > 0;
      final availableSegmentHeight = math.max(
        0.0,
        totalHeight - (hasTwoSegments ? segmentGap : 0),
      );
      final completedHeight = scheduledCount == 0
          ? 0.0
          : availableSegmentHeight * (completedCount / scheduledCount);
      final missedHeight = availableSegmentHeight - completedHeight;

      if (completedHeight > 0) {
        _drawRoundedSegment(
          canvas,
          centerX: x,
          bottom: plotBottom,
          width: barWidth,
          height: completedHeight,
          paint: completedPaint,
        );
      }
      if (missedHeight > 0) {
        _drawRoundedSegment(
          canvas,
          centerX: x,
          bottom:
              plotBottom - completedHeight - (hasTwoSegments ? segmentGap : 0),
          width: barWidth,
          height: missedHeight,
          paint: missedPaint,
        );
      }
      _paintLabel(
        canvas,
        labels[index],
        Offset(x, size.height - labelBandHeight / 2),
        labelColor,
      );
    }
  }

  void _drawRoundedSegment(
    Canvas canvas, {
    required double centerX,
    required double bottom,
    required double width,
    required double height,
    required Paint paint,
  }) {
    final segmentRect = Rect.fromLTRB(
      centerX - width / 2,
      bottom - height,
      centerX + width / 2,
      bottom,
    );
    final radius = Radius.circular(math.min(width / 2, height / 2));
    canvas.drawRRect(RRect.fromRectAndRadius(segmentRect, radius), paint);
  }

  void _paintLabel(Canvas canvas, String text, Offset center, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _DailyDoseChartPainter oldDelegate) =>
      oldDelegate.completed != completed ||
      oldDelegate.scheduled != scheduled ||
      oldDelegate.barColor != barColor ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.labelColor != labelColor;
}

class _TimingChartPainter extends CustomPainter {
  const _TimingChartPainter({
    required this.offsets,
    required this.labels,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
  });

  final List<int> offsets;
  final List<String> labels;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    const horizontalPadding = 10.0;
    const topPadding = 10.0;
    const labelHeight = 30.0;
    final chartHeight = size.height - topPadding - labelHeight;
    final chartWidth = size.width - horizontalPadding * 2;
    final maxMagnitude = math.max(
      15,
      offsets.fold<int>(0, (value, item) => math.max(value, item.abs())),
    );
    final midY = topPadding + chartHeight / 2;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(horizontalPadding, midY),
      Offset(size.width - horizontalPadding, midY),
      gridPaint,
    );

    final points = <Offset>[];
    for (var index = 0; index < offsets.length; index++) {
      final x = horizontalPadding + chartWidth * index / (offsets.length - 1);
      final normalized = offsets[index] / maxMagnitude;
      final y = midY - normalized * chartHeight * 0.42;
      points.add(Offset(x, y));
    }

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, linePaint);

    final dotFill = Paint()..color = lineColor;
    final dotCenter = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    for (var index = 0; index < points.length; index++) {
      canvas.drawCircle(points[index], 5, dotFill);
      canvas.drawCircle(points[index], 2, dotCenter);
      _paintLabel(
        canvas,
        labels[index],
        Offset(points[index].dx, size.height - 14),
        labelColor,
      );
    }
  }

  void _paintLabel(Canvas canvas, String text, Offset center, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _TimingChartPainter oldDelegate) =>
      oldDelegate.offsets != offsets ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.labelColor != labelColor;
}
