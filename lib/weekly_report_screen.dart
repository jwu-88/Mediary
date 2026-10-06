import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_controls.dart';
import 'app_layout.dart';
import 'data/mediary_repository.dart';
import 'in_app_page.dart';
import 'liquid_glass_back_button.dart';

const _weeklyReportNativeContentWidth = 520.0;
const _weeklyReportDesktopContentWidth = 1120.0;
const _weeklyChartHorizontalPadding = 10.0;

/// A weekly medication-adherence report that can be pushed as a standalone
/// route.
///
/// Empty data is rendered as an empty report until stored medication history is
/// supplied by the signed-in user's data store.
class WeeklyReportScreen extends StatelessWidget {
  WeeklyReportScreen({
    super.key,
    this.weekEnding,
    List<int> dailyTaken = const [],
    List<int> dailyScheduled = const [],
    List<int> timingOffsetsMinutes = const [],
    List<int> dailySkipped = const [],
    List<int>? dailyMissed,
    List<int>? timingSampleOffsetsMinutes,
    this.onSaveReport,
  }) : dailyTaken = _normalizeCounts(dailyTaken),
       dailyScheduled = _normalizeCounts(dailyScheduled),
       timingOffsetsMinutes = _normalizeOffsets(timingOffsetsMinutes),
       dailySkipped = _normalizeCounts(dailySkipped),
       dailyMissed = dailyMissed == null ? null : _normalizeCounts(dailyMissed),
       timingSampleOffsetsMinutes = List<int>.unmodifiable(
         timingSampleOffsetsMinutes ?? timingOffsetsMinutes,
       );

  final DateTime? weekEnding;
  final List<int> dailyTaken;
  final List<int> dailyScheduled;
  final List<int> timingOffsetsMinutes;
  final List<int> dailySkipped;

  /// Actual missed counts, excluding pending doses. Legacy callers can omit
  /// these counts to derive missed doses from scheduled, taken, and skipped.
  final List<int>? dailyMissed;

  /// One offset for each taken dose with a known timestamp. An explicit empty
  /// list means timing data is unavailable, including when a chart is padded.
  final List<int> timingSampleOffsetsMinutes;
  final Future<String> Function(ReportWrite report)? onSaveReport;

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

  static List<int> _normalizeCounts(List<int> values) => List<int>.unmodifiable(
    List<int>.generate(
      7,
      (index) => index < values.length ? math.max(0, values[index]) : 0,
    ),
  );

  static List<int> _normalizeOffsets(List<int> values) =>
      List<int>.unmodifiable(
        List<int>.generate(
          7,
          (index) => index < values.length ? values[index] : 0,
        ),
      );

  int get _taken => List<int>.generate(
    7,
    (index) => math.min(dailyTaken[index], dailyScheduled[index]),
  ).fold(0, (sum, value) => sum + value);

  int get _scheduled => dailyScheduled.fold(0, (sum, value) => sum + value);

  int _takenOnDay(int index) =>
      math.min(dailyTaken[index], dailyScheduled[index]);

  int _skippedOnDay(int index) =>
      math.min(dailySkipped[index], dailyScheduled[index] - _takenOnDay(index));

  int _missedOnDay(int index) {
    final remaining =
        dailyScheduled[index] - _takenOnDay(index) - _skippedOnDay(index);
    return math.min(dailyMissed?[index] ?? remaining, remaining);
  }

  int get _skipped =>
      List<int>.generate(7, _skippedOnDay).fold(0, (sum, value) => sum + value);

  int get _missed =>
      List<int>.generate(7, _missedOnDay).fold(0, (sum, value) => sum + value);

  int get _adherence {
    if (_scheduled == 0) return 0;
    return ((_taken / _scheduled) * 100).round().clamp(0, 100);
  }

  int get _averageTiming {
    if (timingSampleOffsetsMinutes.isEmpty) return 0;
    final total = timingSampleOffsetsMinutes.fold<int>(
      0,
      (sum, value) => sum + value.abs(),
    );
    return (total / timingSampleOffsetsMinutes.length).round();
  }

  List<String> _labelsFor(DateTime ending, {bool accessible = false}) {
    final names = accessible ? _accessibleDayLabels : _dayLabels;
    return List<String>.generate(7, (index) {
      final date = DateTime(ending.year, ending.month, ending.day - 6 + index);
      return names[date.weekday - 1];
    });
  }

  String _missedDoseDescription(DateTime ending) {
    final labels = _labelsFor(ending);
    final missedDays = <String>[];
    for (var index = 0; index < dailyScheduled.length; index++) {
      if (_missedOnDay(index) > 0) {
        missedDays.add(labels[index]);
      }
    }
    if (missedDays.isEmpty) return 'No missed doses';
    final dosePhrase = '$_missed missed ${_missed == 1 ? 'dose' : 'doses'}';
    if (missedDays.length == 1) return '$dosePhrase on ${missedDays.first}';
    return '$dosePhrase this week';
  }

  String _dailyDoseSemantics(DateTime ending) {
    final labels = _labelsFor(ending, accessible: true);
    final dailyDetails = List<String>.generate(7, (index) {
      final taken = _takenOnDay(index);
      final scheduled = math.max(0, dailyScheduled[index]);
      return '${labels[index]}: $taken of $scheduled taken, '
          '${_skippedOnDay(index)} skipped, ${_missedOnDay(index)} missed';
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
    final dosePhrase = _missed <= 0
        ? 'No scheduled doses were missed.'
        : '$_missed scheduled ${_missed == 1 ? 'dose was' : 'doses were'} missed.';
    final timingPhrase = timingSampleOffsetsMinutes.isEmpty
        ? 'No dose timing data is available.'
        : 'Doses were taken an average of $_averageTiming minutes from their '
              'scheduled time.';
    return 'For the week ending ${_formatDate(ending)}, '
        '$_taken of $_scheduled scheduled doses were taken '
        '($_adherence% adherence). $dosePhrase $timingPhrase';
  }

  Future<void> _prepareSummary(BuildContext context, DateTime ending) async {
    final start = DateTime(ending.year, ending.month, ending.day - 6);
    await onSaveReport?.call(
      ReportWrite(
        id: '${_dateKey(start)}_${_dateKey(ending)}',
        periodStart: _dateKey(start),
        periodEnd: _dateKey(ending),
        doseCount: _scheduled,
        takenCount: _taken,
        missedCount: _missed,
        skippedCount: _skipped,
        adherencePercent: _adherence.toDouble(),
        sourceVersion: 'v1',
      ),
    );
    final summary = _summary(ending);
    if (!context.mounted) return;
    await pushInAppPage<void>(
      context,
      builder: (context) => _PreparedSummaryPage(summary: summary),
    );
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    final ending = DateUtils.dateOnly(weekEnding ?? DateTime.now());
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final missed = _missed;
    final dayLabels = _labelsFor(ending);
    final timingDetail = timingSampleOffsetsMinutes.isEmpty
        ? 'No Timing Data'
        : '$_averageTiming Min Average';
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final contentWidth = viewportWidth >= 900
        ? responsiveContentWidth(
            context,
            nativeMaxWidth: _weeklyReportDesktopContentWidth,
          )
        : _weeklyReportNativeContentWidth;

    return Scaffold(
      appBar: AppBar(
        leading: Center(
          child: LiquidGlassBackButton(
            key: const Key('weeklyReportBackButton'),
            semanticLabel: 'Back from Weekly Report',
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        centerTitle: false,
        titleSpacing: 4,
        toolbarHeight:
            64 + (MediaQuery.textScalerOf(context).scale(22) - 22).clamp(0, 44),
        leadingWidth: 64,
        title: const Text(
          'Weekly Report',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.pageTitle,
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentWidth),
            child: ListView(
              key: const Key('weeklyReportScrollView'),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.pageGutterOf(context),
                AppSpacing.md,
                AppSpacing.pageGutterOf(context),
                AppSpacing.xxl,
              ),
              children: [
                Text(
                  'Week Ending ${_formatDate(ending)}',
                  key: const Key('weeklyReportWeekEnding'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Adherence',
                  key: const Key('weeklyReportAdherenceHeading'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 32),
                _SectionHeading(
                  key: const Key('weeklyReportDailyDosesHeading'),
                  title: 'Daily Doses',
                  detail: _missedDoseDescription(ending),
                ),
                const SizedBox(height: 16),
                Semantics(
                  key: const Key('dailyDoseChartSemantics'),
                  label: _dailyDoseSemantics(ending),
                  child: SizedBox(
                    key: const Key('dailyDoseChart'),
                    height: 184,
                    child: CustomPaint(
                      painter: _DailyDoseChartPainter(
                        completed: dailyTaken,
                        scheduled: dailyScheduled,
                        labels: dayLabels,
                        barColor: _green,
                        trackColor: colors.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                        labelColor: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _SectionHeading(
                  key: const Key('weeklyReportDoseTimingHeading'),
                  title: 'Dose Timing',
                  detail: timingDetail,
                ),
                const SizedBox(height: 16),
                Semantics(
                  label: timingSampleOffsetsMinutes.isEmpty
                      ? 'Dose timing chart. No dose timing data is available.'
                      : 'Dose timing chart. Average timing was $_averageTiming minutes from schedule.',
                  child: SizedBox(
                    key: const Key('doseTimingChart'),
                    height: 168,
                    child: CustomPaint(
                      painter: _TimingChartPainter(
                        offsets: timingOffsetsMinutes,
                        labels: dayLabels,
                        lineColor: colors.primary,
                        gridColor: colors.outlineVariant.withValues(
                          alpha: 0.34,
                        ),
                        labelColor: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Highlights',
                  key: const Key('weeklyReportHighlightsHeading'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 18,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 12),
                _HighlightRow(
                  icon: CupertinoIcons.check_mark_circled_solid,
                  iconColor: _green,
                  title: 'Strong Weekly Adherence',
                  detail: 'You completed $_adherence% of scheduled doses.',
                ),
                const SizedBox(height: 16),
                _HighlightRow(
                  icon: CupertinoIcons.clock_fill,
                  iconColor: colors.primary,
                  title: 'Consistent Timing',
                  detail: timingSampleOffsetsMinutes.isEmpty
                      ? 'No dose timing data is available.'
                      : 'Doses were within $_averageTiming minutes of schedule on average.',
                ),
                const SizedBox(height: 24),
                _PrepareSummaryButton(
                  onPressed: () => _prepareSummary(context, ending),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrepareSummaryButton extends StatefulWidget {
  const _PrepareSummaryButton({required this.onPressed});

  final Future<void> Function() onPressed;

  @override
  State<_PrepareSummaryButton> createState() => _PrepareSummaryButtonState();
}

class _PrepareSummaryButtonState extends State<_PrepareSummaryButton> {
  bool _busy = false;
  String? _error;

  Future<void> _prepare() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onPressed();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Your summary could not be prepared. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(
          key: const Key('prepareSummaryButton'),
          label: 'Prepare Summary',
          icon: CupertinoIcons.doc_text,
          onPressed: _busy ? null : _prepare,
          busy: _busy,
          loadingLabel: 'Preparing Summary',
          loadingIndicatorKey: const Key('prepareSummaryLoadingIndicator'),
          expand: true,
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              key: const Key('prepareSummaryError'),
              style: AppTextStyles.body.copyWith(color: colors.error),
            ),
          ),
        ],
      ],
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
  const _SectionHeading({super.key, required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 18,
              height: 1.25,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
        Flexible(
          child: Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
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

class _PreparedSummaryPage extends StatefulWidget {
  const _PreparedSummaryPage({required this.summary});

  final String summary;

  @override
  State<_PreparedSummaryPage> createState() => _PreparedSummaryPageState();
}

class _PreparedSummaryPageState extends State<_PreparedSummaryPage> {
  var _copyStatus = 'Ready to review and copy';
  var _hasCopied = false;
  var _copyFailed = false;

  Future<void> _copySummary() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.summary));
      if (!mounted) return;
      setState(() {
        _hasCopied = true;
        _copyFailed = false;
        _copyStatus = 'Summary copied';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _copyFailed = true;
          _copyStatus = 'Summary could not be copied. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InAppPageScaffold(
      title: 'Prepared Summary',
      child: ListView(
        key: const Key('preparedSummaryPage'),
        padding: EdgeInsets.zero,
        children: [
          Semantics(
            liveRegion: true,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Row(
                key: ValueKey(_copyStatus),
                children: [
                  Icon(
                    _copyFailed
                        ? CupertinoIcons.exclamationmark_circle_fill
                        : _hasCopied
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.doc_text,
                    size: 18,
                    color: _copyFailed
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _copyStatus,
                      key: const Key('summaryCopyStatus'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SelectableText(
            widget.summary,
            key: const Key('preparedSummaryText'),
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final stackButtons =
                  constraints.maxWidth < 440 ||
                  MediaQuery.textScalerOf(context).scale(15) > 21;
              final copyButton = AppButton(
                key: const Key('copySummaryAgainButton'),
                label: _hasCopied ? 'Copy Again' : 'Copy Summary',
                icon: CupertinoIcons.doc_on_doc,
                variant: AppButtonVariant.secondary,
                onPressed: _copySummary,
                expand: true,
              );
              final doneButton = AppButton(
                key: const Key('closeSummaryButton'),
                label: 'Done',
                onPressed: () => Navigator.pop(context),
                expand: true,
              );
              if (stackButtons) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    copyButton,
                    const SizedBox(height: 12),
                    doneButton,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: copyButton),
                  const SizedBox(width: 12),
                  Expanded(child: doneButton),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
        ],
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
    const chartHorizontalPadding = _weeklyChartHorizontalPadding;
    final plotBottom = size.height - labelBandHeight - labelGap;
    final chartHeight = math.max(0.0, plotBottom - topPadding);
    final chartWidth = size.width - chartHorizontalPadding * 2;
    final columnWidth = chartWidth / labels.length;
    final barWidth = math.min(22.0, columnWidth * 0.4);
    final maxScheduled = math.max(1, scheduled.fold<int>(0, math.max));

    final missedPaint = Paint()..color = trackColor;
    final completedPaint = Paint()..color = barColor;

    for (var index = 0; index < labels.length; index++) {
      final x = labels.length == 1
          ? size.width / 2
          : chartHorizontalPadding + chartWidth * index / (labels.length - 1);
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
          fontSize: 12,
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
    const horizontalPadding = _weeklyChartHorizontalPadding;
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
          fontSize: 12,
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
