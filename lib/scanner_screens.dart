import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_interactions.dart';
import 'app_layout.dart';
import 'data/mediary_repository.dart';
import 'data/medication_catalog_client.dart';
import 'in_app_page.dart';
import 'liquid_glass_back_button.dart';
import 'medication_artwork.dart';
import 'medication_scan.dart';
import 'text_formatting.dart';
import 'web_camera.dart';

/// Camera permission state used by [MedicationScannerScreen].
///
/// This lives outside the application shell so the scanner can be reused
/// without importing the app's authentication or navigation code.
enum ScannerAccessState {
  notRequested,
  requesting,
  granted,
  denied,
  permanentlyDenied,
  error,
}

class _ScannerPalette {
  const _ScannerPalette({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.fieldSurface,
    required this.primaryText,
    required this.secondaryText,
    required this.separator,
    required this.primary,
    required this.success,
    required this.onSuccess,
    required this.actionMaterial,
    required this.warningSurface,
    required this.warningText,
    required this.warningIcon,
  });

  factory _ScannerPalette.of(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return _ScannerPalette(
      isDark: isDark,
      background: theme.scaffoldBackgroundColor,
      surface: colors.surface,
      fieldSurface: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF9F9FB),
      primaryText: colors.onSurface,
      secondaryText: colors.onSurfaceVariant,
      separator: colors.outline.withValues(alpha: isDark ? .90 : .65),
      primary: colors.primary,
      success: isDark ? const Color(0xFF30D158) : const Color(0xFF248A3D),
      onSuccess: isDark ? Colors.black : Colors.white,
      actionMaterial: colors.surface.withValues(alpha: isDark ? .90 : .88),
      warningSurface: isDark
          ? const Color(0xFF392A19)
          : const Color(0xFFFFF6E8),
      warningText: isDark ? const Color(0xFFFFD19A) : const Color(0xFF8B531E),
      warningIcon: isDark ? const Color(0xFFFF9F0A) : const Color(0xFFB06A22),
    );
  }

  final bool isDark;
  final Color background;
  final Color surface;
  final Color fieldSurface;
  final Color primaryText;
  final Color secondaryText;
  final Color separator;
  final Color primary;
  final Color success;
  final Color onSuccess;
  final Color actionMaterial;
  final Color warningSurface;
  final Color warningText;
  final Color warningIcon;
}

class MedicationScannerScreen extends StatefulWidget {
  const MedicationScannerScreen({
    super.key,
    required this.accessState,
    required this.onRequestAccess,
    required this.onCapture,
    this.onChoosePhoto,
    this.onChoosePhotoOptions,
    this.onUseOtherScanOptions,
    this.onOpenSettings,
    this.isActive = true,
    this.bottomNavigationInset = 112,
  });

  final ScannerAccessState accessState;
  final Future<void> Function() onRequestAccess;
  final Future<void> Function() onCapture;
  final Future<void> Function()? onChoosePhoto;
  final Future<void> Function()? onChoosePhotoOptions;
  final Future<void> Function()? onUseOtherScanOptions;
  final Future<bool> Function()? onOpenSettings;
  final bool isActive;
  final double bottomNavigationInset;

  @override
  State<MedicationScannerScreen> createState() =>
      _MedicationScannerScreenState();
}

class _MedicationScannerScreenState extends State<MedicationScannerScreen> {
  bool _isAnalyzing = false;
  bool _barcodeMode = false;

  Future<void> _capture() async {
    if (_isAnalyzing) return;
    setState(() => _isAnalyzing = true);
    unawaited(AppHaptics.primaryAction());
    await Future<void>.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;
    try {
      await widget.onCapture();
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _choosePhoto() async {
    if (_isAnalyzing) return;
    setState(() {
      _barcodeMode = false;
      _isAnalyzing = true;
    });
    if (!mounted) return;
    try {
      // Keep the file chooser in the original pointer-activation turn. Web
      // browsers reject a file dialog opened after an asynchronous delay.
      await (widget.onChoosePhotoOptions ??
          widget.onChoosePhoto ??
          widget.onCapture)();
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _toggleBarcodeMode() {
    if (_isAnalyzing) return;
    setState(() => _barcodeMode = !_barcodeMode);
  }

  @override
  Widget build(BuildContext context) {
    final palette = _ScannerPalette.of(context);
    if (widget.accessState != ScannerAccessState.granted) {
      return _PermissionView(
        accessState: widget.accessState,
        onRequestAccess: widget.onRequestAccess,
        onUseOtherScanOptions: widget.onUseOtherScanOptions,
        onOpenSettings: widget.onOpenSettings,
        bottomNavigationInset: widget.bottomNavigationInset,
      );
    }

    return ColoredBox(
      color: palette.background,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, pageConstraints) {
            // Keep the camera surface above the app navigation area. The
            // shell uses an extended body on iOS, so a full-height camera
            // panel would otherwise continue behind the toolbar and make its
            // black canvas appear to interfere with the navigation surface.
            final availableHeight =
                (pageConstraints.maxHeight - widget.bottomNavigationInset - 8)
                    .clamp(0.0, double.infinity);
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                widget.bottomNavigationInset,
              ),
              // Keep the camera surface centered independently of the
              // navigation inset so the redesigned Scan destination remains
              // balanced on both compact phones and wider web viewports.
              child: Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: responsiveContentWidth(
                      context,
                      nativeMaxWidth: 390,
                    ),
                  ),
                  child: SizedBox(
                    height: availableHeight,
                    width: double.infinity,
                    child: DecoratedBox(
                      key: const Key('scannerCameraPanel'),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .16),
                          width: .8,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const ColoredBox(
                              key: Key('scannerCameraBackground'),
                              color: Colors.black,
                            ),
                            Positioned.fill(
                              child: WebCameraPreview(
                                key: const Key('scannerWebCameraPreview'),
                                active: widget.isActive,
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 22,
                              child: _ScannerControlBar(
                                barcodeMode: _barcodeMode,
                                isAnalyzing: _isAnalyzing,
                                onCapture: _capture,
                                onChoosePhoto: _choosePhoto,
                                onToggleBarcode: _toggleBarcodeMode,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PermissionView extends StatelessWidget {
  const _PermissionView({
    required this.accessState,
    required this.onRequestAccess,
    this.onUseOtherScanOptions,
    this.onOpenSettings,
    required this.bottomNavigationInset,
  });

  final ScannerAccessState accessState;
  final Future<void> Function() onRequestAccess;
  final Future<void> Function()? onUseOtherScanOptions;
  final Future<bool> Function()? onOpenSettings;
  final double bottomNavigationInset;

  @override
  Widget build(BuildContext context) {
    final palette = _ScannerPalette.of(context);
    final (title, message, icon) = switch (accessState) {
      ScannerAccessState.notRequested => (
        'Camera Access Required',
        'Allow camera access to scan medication labels and barcodes.',
        CupertinoIcons.camera,
      ),
      ScannerAccessState.requesting => (
        'Requesting Camera Access',
        'Respond to the system permission prompt to continue.',
        CupertinoIcons.camera_rotate,
      ),
      ScannerAccessState.denied => (
        'Camera Access Denied',
        'The scanner needs camera access. You can try the permission request again.',
        CupertinoIcons.camera,
      ),
      ScannerAccessState.permanentlyDenied => (
        'Enable Camera Access',
        'Open Settings and allow camera access for this app, then return here.',
        CupertinoIcons.camera,
      ),
      ScannerAccessState.error => (
        'Camera Unavailable',
        'The camera permission request could not be completed. Please try again.',
        CupertinoIcons.exclamationmark_triangle,
      ),
      ScannerAccessState.granted => throw StateError('Unexpected state'),
    };
    final isRequesting = accessState == ScannerAccessState.requesting;
    final needsSettings =
        accessState == ScannerAccessState.permanentlyDenied &&
        onOpenSettings != null;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomNavigationInset),
          child: Stack(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isRequesting)
                          SizedBox.square(
                            dimension: 50,
                            child: CupertinoActivityIndicator(
                              radius: 18,
                              color: palette.primary,
                            ),
                          )
                        else
                          Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              color: palette.primary.withValues(
                                alpha: palette.isDark ? .20 : .10,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, size: 32, color: palette.primary),
                          ),
                        const SizedBox(height: 24),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: palette.primaryText,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -.5,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: palette.secondaryText,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 28),
                        if (!isRequesting)
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton.icon(
                              key: Key(
                                needsSettings
                                    ? 'openCameraSettingsButton'
                                    : 'requestCameraButton',
                              ),
                              onPressed: needsSettings
                                  ? () async => onOpenSettings!.call()
                                  : onRequestAccess,
                              icon: Icon(
                                needsSettings
                                    ? CupertinoIcons.settings
                                    : CupertinoIcons.camera,
                                size: 18,
                              ),
                              label: Text(
                                needsSettings
                                    ? 'Open Settings'
                                    : 'Allow Camera Access',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: palette.primary,
                                foregroundColor: Theme.of(context)
                                    .colorScheme
                                    .onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        if (!isRequesting && onUseOtherScanOptions != null) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: OutlinedButton.icon(
                              key: const Key('cameraNoAccessButton'),
                              onPressed: onUseOtherScanOptions,
                              icon: const Icon(
                                CupertinoIcons.photo_on_rectangle,
                                size: 18,
                              ),
                              label: const Text("I don't have camera access"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: palette.primary,
                                side: BorderSide(
                                  color: palette.primary.withValues(alpha: .65),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptureSideControl extends StatelessWidget {
  const _CaptureSideControl({
    super.key,
    required this.icon,
    required this.label,
    this.webLabel,
    required this.onPressed,
    this.isSelected = false,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final String? webLabel;
  final VoidCallback onPressed;
  final bool isSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final displayLabel = kIsWeb ? webLabel ?? label : label;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: isSelected,
        label: label,
        child: ResponsiveCupertinoButton(
          padding: const EdgeInsets.all(8),
          minimumSize: Size(kIsWeb ? 0 : 48, kIsWeb ? 64 : 48),
          onPressed: enabled ? onPressed : null,
          semanticLabel: label,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: kIsWeb ? double.infinity : 46,
            height: kIsWeb ? 60 : 46,
            padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 18 : 0),
            decoration: BoxDecoration(
              color: isSelected
                  ? colors.primary
                  : Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(kIsWeb ? 16 : 99),
              border: Border.all(
                color: Colors.white.withValues(alpha: isSelected ? .38 : .14),
                width: .7,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: kIsWeb ? MainAxisSize.max : MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: enabled
                      ? isSelected
                            ? colors.onPrimary
                            : Colors.white
                      : Colors.white.withValues(alpha: .42),
                  size: kIsWeb ? 23 : 21,
                ),
                if (kIsWeb) ...[
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      displayLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: enabled
                            ? isSelected
                                  ? colors.onPrimary
                                  : Colors.white
                            : Colors.white.withValues(alpha: .42),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScannerControlBar extends StatelessWidget {
  const _ScannerControlBar({
    required this.barcodeMode,
    required this.isAnalyzing,
    required this.onCapture,
    required this.onChoosePhoto,
    required this.onToggleBarcode,
  });

  final bool barcodeMode;
  final bool isAnalyzing;
  final VoidCallback onCapture;
  final VoidCallback onChoosePhoto;
  final VoidCallback onToggleBarcode;

  @override
  Widget build(BuildContext context) {
    final controls = Row(
      children: [
        Expanded(
          child: _CaptureSideControl(
            key: const Key('openScannerPhotosButton'),
            icon: CupertinoIcons.photo,
            label: 'Choose a medication photo',
            webLabel: 'Choose Photo',
            onPressed: onChoosePhoto,
            enabled: !isAnalyzing,
          ),
        ),
        SizedBox(width: kIsWeb ? 16 : 0),
        _ScannerCaptureButton(isAnalyzing: isAnalyzing, onPressed: onCapture),
        SizedBox(width: kIsWeb ? 16 : 0),
        Expanded(
          child: _CaptureSideControl(
            key: const Key('scannerBarcodeButton'),
            icon: CupertinoIcons.barcode_viewfinder,
            label: barcodeMode ? 'Scan a medication label' : 'Scan a barcode',
            webLabel: barcodeMode ? 'Scan Label' : 'Scan Barcode',
            isSelected: barcodeMode,
            onPressed: onToggleBarcode,
            enabled: !isAnalyzing,
          ),
        ),
      ],
    );

    final constrainedControls = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: SizedBox(width: double.infinity, child: controls),
      ),
    );
    return kIsWeb ? constrainedControls : controls;
  }
}

class _ScannerCaptureButton extends StatelessWidget {
  const _ScannerCaptureButton({
    required this.isAnalyzing,
    required this.onPressed,
  });

  final bool isAnalyzing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = isAnalyzing ? 'Analyzing' : 'Capture';
    return Tooltip(
      message: isAnalyzing ? 'Analyzing medication' : 'Capture medication',
      child: Semantics(
        button: true,
        enabled: !isAnalyzing,
        label: isAnalyzing ? 'Analyzing medication' : 'Capture medication',
        child: AppPressable(
          key: const Key('captureMedicationButton'),
          onPressed: isAnalyzing ? null : onPressed,
          busy: isAnalyzing,
          semanticLabel: 'Capture medication',
          borderRadius: BorderRadius.circular(kIsWeb ? 16 : 99),
          hoverScale: 1.04,
          pressedScale: .92,
          hoverOffset: Offset.zero,
          haptic: AppHapticKind.primaryAction,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: kIsWeb ? 176 : 70,
            height: kIsWeb ? 60 : 70,
            padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 20 : 5),
            decoration: BoxDecoration(
              color: kIsWeb
                  ? Colors.white
                  : Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(kIsWeb ? 16 : 99),
              border: kIsWeb ? null : Border.all(color: Colors.white, width: 4),
            ),
            child: kIsWeb
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        CupertinoIcons.camera,
                        color: Colors.black,
                        size: 23,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                : DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isAnalyzing
                          ? Colors.white.withValues(alpha: .65)
                          : Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class ScanResultScreen extends StatefulWidget {
  const ScanResultScreen({
    super.key,
    this.onBack,
    this.onScanAgain,
    this.onAdded,
    this.onScanReady,
    this.onScheduleConfirmed,
    this.medication,
    this.scanResult,
    this.scanRecordId,
    this.onSearchMedication,
    this.bottomNavigationInset = 106,
  });

  final VoidCallback? onBack;
  final VoidCallback? onScanAgain;
  final VoidCallback? onAdded;
  final Future<String> Function(ScanWrite scan)? onScanReady;
  final Future<bool> Function(ScanScheduleData schedule)? onScheduleConfirmed;
  final MedicationCatalogRecord? medication;
  final MedicationScanResult? scanResult;
  final String? scanRecordId;
  final VoidCallback? onSearchMedication;
  final double bottomNavigationInset;

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  String _dose = '1 capsule';
  String _frequency = 'Every 8 hours';
  String _duration = '7 days';
  late DateTime _startDate;
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  bool _isAdded = false;

  @override
  void initState() {
    super.initState();
    _startDate = DateUtils.dateOnly(DateTime.now());
    unawaited(_saveScanResult());
  }

  Future<void> _saveScanResult() async {
    final scan = widget.scanResult;
    final status = scan?.hasError == true
        ? 'failed'
        : widget.medication == null
        ? 'needsReview'
        : 'complete';
    await widget.onScanReady?.call(
      ScanWrite(
        id: widget.scanRecordId,
        status: status,
        detectedMedicationName:
            scan?.detectedMedicationName ?? widget.medication?.name ?? '',
        extractedText:
            scan?.extractedText ??
            (widget.medication == null
                ? ''
                : '${widget.medication!.name} ${widget.medication!.doseDescription}'),
        confidence: scan?.confidence ?? (widget.medication == null ? 0 : 1),
        errorMessage: scan?.errorMessage ?? '',
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _chooseOption({
    required String title,
    required List<String> options,
    required ValueChanged<String> onSelected,
  }) async {
    final selected = await pushInAppPage<String>(
      context,
      builder: (context) => InAppOptionPage<String>(
        title: title,
        options: [
          for (final option in options)
            InAppPageOption(
              label: option,
              value: option,
              selected: switch (title) {
                'Dose' => option == _dose,
                'Frequency' => option == _frequency,
                'Duration' => option == _duration,
                _ => false,
              },
            ),
        ],
      ),
    );
    if (selected != null && mounted) onSelected(selected);
  }

  Future<void> _chooseStartDate() async {
    var draft = _startDate;
    final selected = await pushInAppPage<DateTime>(
      context,
      builder: (pageContext) => InAppPageScaffold(
        title: 'Start Date',
        actions: [
          TextButton(
            key: const Key('confirmStartDateButton'),
            onPressed: () => Navigator.of(pageContext).pop(draft),
            child: const Text('Done'),
          ),
          const SizedBox(width: 8),
        ],
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: _startDate,
              minimumDate: DateTime(2020),
              maximumDate: DateTime(2100),
              onDateTimeChanged: (value) => draft = value,
            ),
          ),
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _startDate = selected);
  }

  Future<void> _chooseTime() async {
    final selected = await showTimePicker(context: context, initialTime: _time);
    if (selected != null && mounted) setState(() => _time = selected);
  }

  Future<void> _addToCalendar() async {
    if (_isAdded) return;
    try {
      final added =
          await widget.onScheduleConfirmed?.call(
            ScanScheduleData(
              dose: _dose,
              frequency: _frequency,
              duration: _duration,
              startDate: _startDate,
              time: _time,
            ),
          ) ??
          true;
      if (!added) return;
      if (!mounted) return;
      setState(() => _isAdded = true);
      widget.onAdded?.call();
    } catch (_) {
      // Keep the CTA available so the user can retry after a failed write.
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _ScannerPalette.of(context);
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final contentWidth = viewportWidth >= 900
        ? responsiveContentWidth(context, nativeMaxWidth: 720)
        : 520.0;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentWidth),
            child: Stack(
              children: [
                Column(
                  children: [
                    SizedBox(
                      height: 62,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 62,
                            child: Center(
                              child: LiquidGlassBackButton(
                                key: const Key('scanResultBackButton'),
                                semanticLabel: 'Back from Scan Result',
                                onPressed:
                                    widget.onBack ??
                                    () => Navigator.maybePop(context),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Review Medication',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: palette.primaryText,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -.2,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 62,
                            child: Tooltip(
                              message: 'Scan Again',
                              child: ResponsiveCupertinoButton(
                                buttonKey: const Key('scanAgainButton'),
                                padding: EdgeInsets.zero,
                                minimumSize: const Size.square(44),
                                onPressed:
                                    widget.onScanAgain ??
                                    () => Navigator.maybePop(context),
                                semanticLabel: 'Scan Again',
                                child: Icon(
                                  CupertinoIcons.arrow_clockwise,
                                  color: palette.primary,
                                  size: 19,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        key: const Key('scanResultScrollView'),
                        padding: EdgeInsets.fromLTRB(
                          16,
                          4,
                          16,
                          96 + widget.bottomNavigationInset,
                        ),
                        children: [
                          _ResultHero(
                            medication: widget.medication,
                            scanResult: widget.scanResult,
                          ),
                          const SizedBox(height: 18),
                          _InfoGrid(medication: widget.medication),
                          if (widget.scanResult != null) ...[
                            const SizedBox(height: 16),
                            _ExtractedTextCard(result: widget.scanResult!),
                          ],
                          if (widget.medication != null) ...[
                            const SizedBox(height: 16),
                            _CatalogDetailsCard(medication: widget.medication!),
                          ],
                          const SizedBox(height: 16),
                          const _SafetyNotice(),
                          const SizedBox(height: 16),
                          if (widget.medication != null)
                            Container(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                18,
                              ),
                              decoration: BoxDecoration(
                                color: palette.surface,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SET YOUR SCHEDULE',
                                    style: TextStyle(
                                      color: palette.primaryText,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -.25,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _ScheduleField(
                                          label: 'DOSE',
                                          value: _dose,
                                          onTap: () => _chooseOption(
                                            title: 'Dose',
                                            options: const [
                                              '½ capsule',
                                              '1 capsule',
                                              '2 capsules',
                                            ],
                                            onSelected: (value) =>
                                                setState(() => _dose = value),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _ScheduleField(
                                          label: 'FREQUENCY',
                                          value: _frequency,
                                          onTap: () => _chooseOption(
                                            title: 'Frequency',
                                            options: const [
                                              'Once daily',
                                              'Every 8 hours',
                                              'Every 12 hours',
                                              'As needed',
                                            ],
                                            onSelected: (value) => setState(
                                              () => _frequency = value,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 13),
                                  _ScheduleField(
                                    label: 'TIME',
                                    value: _time.format(context),
                                    onTap: _chooseTime,
                                    icon: CupertinoIcons.time,
                                  ),
                                  const SizedBox(height: 13),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _ScheduleField(
                                          label: 'START DATE',
                                          value: _formatDate(_startDate),
                                          onTap: _chooseStartDate,
                                          icon: CupertinoIcons.calendar,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _ScheduleField(
                                          label: 'DURATION',
                                          value: _duration,
                                          onTap: () => _chooseOption(
                                            title: 'Duration',
                                            options: const [
                                              '5 days',
                                              '7 days',
                                              '10 days',
                                              '14 days',
                                            ],
                                            onSelected: (value) => setState(
                                              () => _duration = value,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          if (widget.medication == null)
                            _PendingReviewCard(
                              onSearch: widget.onSearchMedication,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ClipRect(
                    child: WebAwareBlur(
                      sigma: 20,
                      child: Container(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          10,
                          16,
                          MediaQuery.paddingOf(context).bottom +
                              widget.bottomNavigationInset,
                        ),
                        decoration: BoxDecoration(
                          color: palette.actionMaterial,
                          border: Border(
                            top: BorderSide(
                              color: palette.separator,
                              width: .5,
                            ),
                          ),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            key: const Key('addScanResultButton'),
                            onPressed: widget.medication == null
                                ? widget.onSearchMedication
                                : _addToCalendar,
                            style: FilledButton.styleFrom(
                              backgroundColor: _isAdded
                                  ? palette.success
                                  : palette.primary,
                              foregroundColor: _isAdded
                                  ? palette.onSuccess
                                  : Theme.of(context).colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            icon: Icon(
                              widget.medication == null
                                  ? CupertinoIcons.search
                                  : _isAdded
                                  ? CupertinoIcons.check_mark_circled_solid
                                  : CupertinoIcons.calendar_badge_plus,
                              size: 18,
                            ),
                            label: Text(
                              widget.medication == null
                                  ? 'Search RxNorm to confirm'
                                  : _isAdded
                                  ? 'Added to Calendar'
                                  : 'Add to Calendar',
                            ),
                          ),
                        ),
                      ),
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

class _ResultHero extends StatelessWidget {
  const _ResultHero({required this.medication, this.scanResult});

  final MedicationCatalogRecord? medication;
  final MedicationScanResult? scanResult;

  @override
  Widget build(BuildContext context) {
    final palette = _ScannerPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 18),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.separator, width: .5)),
      ),
      child: Row(
        children: [
          scanResult?.imageUrl.isNotEmpty == true
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox.square(
                    dimension: 82,
                    child: Image.network(
                      scanResult!.imageUrl,
                      fit: BoxFit.cover,
                      cacheWidth: 328,
                      cacheHeight: 328,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (context, error, stackTrace) =>
                          const _MedicationImageFallback(),
                    ),
                  ),
                )
              : scanResult?.imageBytes?.isNotEmpty == true
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox.square(
                    dimension: 82,
                    child: Image.memory(
                      scanResult!.imageBytes!,
                      fit: BoxFit.cover,
                      cacheWidth: 328,
                      cacheHeight: 328,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (context, error, stackTrace) =>
                          const _MedicationImageFallback(),
                    ),
                  ),
                )
              : medication == null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox.square(
                    dimension: 82,
                    child: Image.asset(
                      'assets/images/medication_auth_background.jpg',
                      fit: BoxFit.cover,
                      cacheWidth: 328,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (context, error, stackTrace) =>
                          const ColoredBox(
                            color: Color(0xFFF0E5EF),
                            child: Icon(
                              CupertinoIcons.capsule_fill,
                              color: Color(0xFFEA3C86),
                              size: 34,
                            ),
                          ),
                    ),
                  ),
                )
              : MedicationArtwork(
                  key: Key('scannerMedicationArtwork_${medication!.rxcui}'),
                  seed: medication!.rxcui,
                  label: titleCaseDisplay(medication!.name),
                  size: 82,
                ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.check_mark_circled_solid,
                      size: 13,
                      color: palette.success,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      medication == null
                          ? 'MANUAL REVIEW REQUIRED'
                          : 'CATALOG MATCH',
                      style: TextStyle(
                        color: palette.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  titleCaseDisplay(
                    medication?.name ??
                        (scanResult?.detectedMedicationName.trim().isNotEmpty ==
                                true
                            ? scanResult!.detectedMedicationName
                            : 'Medication not identified'),
                  ),
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  medication == null
                      ? 'SEARCH RXNORM TO CONFIRM THE MEDICATION'
                      : titleCaseDisplay(medication!.doseDescription)
                            .toUpperCase(),
                  style: TextStyle(color: palette.secondaryText, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ScanScheduleData {
  const ScanScheduleData({
    required this.dose,
    required this.frequency,
    required this.duration,
    required this.startDate,
    required this.time,
  });

  final String dose;
  final String frequency;
  final String duration;
  final DateTime startDate;
  final TimeOfDay time;
}

class _ExtractedTextCard extends StatelessWidget {
  const _ExtractedTextCard({required this.result});

  final MedicationScanResult result;

  @override
  Widget build(BuildContext context) {
    final palette = _ScannerPalette.of(context);
    final confidence = '${(result.confidence * 100).round()}% CONFIDENCE';
    return Container(
      key: const Key('scanExtractedTextCard'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.doc_text, color: palette.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'DETECTED LABEL TEXT',
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  confidence,
                  textAlign: TextAlign.end,
                  style: TextStyle(color: palette.secondaryText, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            result.hasError ? result.errorMessage : result.extractedText,
            style: TextStyle(
              color: result.hasError
                  ? palette.warningText
                  : palette.primaryText,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogDetailsCard extends StatelessWidget {
  const _CatalogDetailsCard({required this.medication});

  final MedicationCatalogRecord medication;

  @override
  Widget build(BuildContext context) {
    final palette = _ScannerPalette.of(context);
    final rows = <String, String>{
      if (medication.genericName.isNotEmpty)
        'Generic name': medication.genericName,
      if (medication.route.isNotEmpty) 'Route': medication.route,
    };
    final indications = medication.indications.take(2).join(' ');
    final warnings = medication.warnings.take(2).join(' ');
    return Container(
      key: const Key('scanMedicationDetailsCard'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MEDICATION INFORMATION',
            style: TextStyle(
              color: palette.primaryText,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          for (final entry in rows.entries) ...[
            const SizedBox(height: 8),
            _DetailRow(label: entry.key, value: entry.value),
          ],
          if (indications.isNotEmpty) ...[
            const SizedBox(height: 12),
            _DetailRow(label: 'Common uses', value: indications),
          ],
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            _DetailRow(label: 'Warnings', value: warnings, warning: true),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.warning = false,
  });

  final String label;
  final String value;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final palette = _ScannerPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: warning ? palette.warningText : palette.secondaryText,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: warning ? palette.warningText : palette.primaryText,
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _MedicationImageFallback extends StatelessWidget {
  const _MedicationImageFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF0E5EF),
      child: Icon(
        CupertinoIcons.capsule_fill,
        color: Color(0xFFEA3C86),
        size: 34,
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.medication});

  final MedicationCatalogRecord? medication;

  @override
  Widget build(BuildContext context) {
    final palette = _ScannerPalette.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ColoredBox(
        color: palette.surface,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _InfoTile(
                    label: 'IDENTIFIER',
                    value: 'Pending',
                    rightBorder: true,
                    bottomBorder: true,
                  ),
                ),
                Expanded(
                  child: _InfoTile(
                    label: 'SOURCE',
                    value: 'RxNorm',
                    bottomBorder: true,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _InfoTile(
                    label: 'FORM',
                    value: medication?.form.isNotEmpty == true
                        ? medication!.form
                        : 'Not available',
                    rightBorder: true,
                  ),
                ),
                Expanded(
                  child: _InfoTile(
                    label: 'STRENGTH',
                    value: medication?.strength.isNotEmpty == true
                        ? medication!.strength
                        : 'Not available',
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

class _PendingReviewCard extends StatelessWidget {
  const _PendingReviewCard({required this.onSearch});

  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    final palette = _ScannerPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MANUAL REVIEW NEEDED',
            style: TextStyle(
              color: palette.primaryText,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'The label text was detected, but it could not be confidently matched to a catalog product. Search RxNorm and confirm the exact product before creating a schedule.',
            style: TextStyle(
              color: palette.secondaryText,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onSearch,
            icon: const Icon(CupertinoIcons.search, size: 17),
            label: const Text('Search medication database'),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    this.rightBorder = false,
    this.bottomBorder = false,
  });

  final String label;
  final String value;
  final bool rightBorder;
  final bool bottomBorder;

  @override
  Widget build(BuildContext context) {
    final palette = _ScannerPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          right: rightBorder
              ? BorderSide(color: palette.separator, width: .5)
              : BorderSide.none,
          bottom: bottomBorder
              ? BorderSide(color: palette.separator, width: .5)
              : BorderSide.none,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: palette.secondaryText,
              fontSize: 9,
              fontWeight: FontWeight.w500,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.primaryText,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice();

  @override
  Widget build(BuildContext context) {
    final palette = _ScannerPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: palette.warningSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              CupertinoIcons.exclamationmark_triangle_fill,
              color: palette.warningIcon,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Confirm the package and prescription label before adding. AI identification does not replace advice from your pharmacist.',
              style: TextStyle(
                color: palette.warningText,
                fontSize: 11,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleField extends StatelessWidget {
  const _ScheduleField({
    required this.label,
    required this.value,
    required this.onTap,
    this.icon,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = _ScannerPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: palette.secondaryText,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: .35,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: palette.fieldSurface,
          borderRadius: BorderRadius.circular(10),
          child: AppPressable(
            onPressed: onTap,
            semanticLabel: '$label, $value',
            borderRadius: BorderRadius.circular(10),
            hoverScale: 1,
            hoverOffset: Offset.zero,
            pressedScale: .98,
            child: Container(
              height: 43,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                border: Border.all(color: palette.separator, width: .7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 14, color: palette.primary),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (icon == null)
                    Icon(
                      CupertinoIcons.chevron_down,
                      size: 12,
                      color: palette.secondaryText,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
