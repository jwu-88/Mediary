import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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

class MedicationScannerScreen extends StatefulWidget {
  const MedicationScannerScreen({
    super.key,
    required this.accessState,
    required this.onRequestAccess,
    required this.onClose,
    required this.onCapture,
    this.onOpenSettings,
  });

  final ScannerAccessState accessState;
  final Future<void> Function() onRequestAccess;
  final VoidCallback onClose;
  final VoidCallback onCapture;
  final Future<bool> Function()? onOpenSettings;

  @override
  State<MedicationScannerScreen> createState() =>
      _MedicationScannerScreenState();
}

class _MedicationScannerScreenState extends State<MedicationScannerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanController;
  bool _isAnalyzing = false;
  bool _torchEnabled = false;
  int _selectedMode = 0;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2300),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_isAnalyzing) return;
    setState(() => _isAnalyzing = true);
    await Future<void>.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;
    widget.onCapture();
    if (mounted) setState(() => _isAnalyzing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.accessState != ScannerAccessState.granted) {
      return _PermissionView(
        accessState: widget.accessState,
        onClose: widget.onClose,
        onRequestAccess: widget.onRequestAccess,
        onOpenSettings: widget.onOpenSettings,
      );
    }

    return ColoredBox(
      color: const Color(0xFFF2F2F7),
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, pageConstraints) {
            final panelHeight = (pageConstraints.maxHeight - 120).clamp(
              0.0,
              660.0,
            );
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: SizedBox(
                    height: panelHeight,
                    width: double.infinity,
                    child: ClipRRect(
                      key: const Key('scannerCameraPanel'),
                      borderRadius: BorderRadius.circular(28),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final frameTop = (constraints.maxHeight * .18).clamp(
                            102.0,
                            126.0,
                          );
                          final frameHeight = (constraints.maxHeight * .43)
                              .clamp(224.0, 292.0);
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?auto=format&fit=crop&w=900&q=90',
                                fit: BoxFit.cover,
                                color: const Color(0xFFADB6C2)
                                    .withValues(alpha: .72),
                                colorBlendMode: BlendMode.modulate,
                                errorBuilder: (context, error, stackTrace) =>
                                    const _CameraFallback(),
                              ),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xB3070A10),
                                      Color(0x14070A10),
                                      Color(0x05070A10),
                                      Color(0xE6070A10),
                                    ],
                                    stops: [0, .28, .58, 1],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 42,
                                right: 42,
                                top: frameTop,
                                height: frameHeight,
                                child: _ScanFrame(
                                  animation: _scanController,
                                  isAnalyzing: _isAnalyzing,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  16,
                                  0,
                                ),
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _GlassIconButton(
                                        key: const Key('closeScannerButton'),
                                        icon: CupertinoIcons.xmark,
                                        label: 'Close scanner',
                                        onPressed: widget.onClose,
                                      ),
                                      const Spacer(),
                                      const Padding(
                                        padding: EdgeInsets.only(top: 2),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Scan medication',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: -.2,
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              'Front label',
                                              style: TextStyle(
                                                color: Color(0xADFFFFFF),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Spacer(),
                                      _GlassIconButton(
                                        key: const Key('scannerTorchButton'),
                                        icon: _torchEnabled
                                            ? CupertinoIcons.bolt_fill
                                            : CupertinoIcons.bolt,
                                        label: _torchEnabled
                                            ? 'Turn flashlight off'
                                            : 'Turn flashlight on',
                                        isSelected: _torchEnabled,
                                        onPressed: () => setState(
                                          () => _torchEnabled = !_torchEnabled,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 52,
                                right: 52,
                                bottom: 174,
                                child: Center(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(99),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 10,
                                        sigmaY: 10,
                                      ),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0C1119)
                                              .withValues(alpha: .58),
                                          borderRadius: BorderRadius.circular(
                                            99,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: .12,
                                            ),
                                            width: .5,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            if (_isAnalyzing)
                                              const SizedBox.square(
                                                dimension: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 1.8,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            else
                                              const Icon(
                                                CupertinoIcons.sparkles,
                                                color: Colors.white,
                                                size: 14,
                                              ),
                                            const SizedBox(width: 7),
                                            Flexible(
                                              child: Text(
                                                _isAnalyzing
                                                    ? 'Analyzing medication…'
                                                    : 'Hold steady and keep the label inside the frame',
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                style: const TextStyle(
                                                  color: Color(0xE6FFFFFF),
                                                  fontSize: 11,
                                                  height: 1.25,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 56,
                                child: Row(
                                  children: [
                                    const Expanded(
                                      child: _CaptureSideControl(
                                        icon: CupertinoIcons.photo,
                                        label: 'Photos',
                                      ),
                                    ),
                                    Semantics(
                                      button: true,
                                      enabled: !_isAnalyzing,
                                      label: _isAnalyzing
                                          ? 'Analyzing medication'
                                          : 'Capture medication',
                                      child: GestureDetector(
                                        key: const Key(
                                          'captureMedicationButton',
                                        ),
                                        onTap: _isAnalyzing ? null : _capture,
                                        child: AnimatedScale(
                                          duration: const Duration(
                                            milliseconds: 120,
                                          ),
                                          scale: _isAnalyzing ? .9 : 1,
                                          child: Container(
                                            width: 70,
                                            height: 70,
                                            padding: const EdgeInsets.all(5),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 4,
                                              ),
                                              color: Colors.white.withValues(
                                                alpha: .2,
                                              ),
                                            ),
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: _isAnalyzing
                                                    ? Colors.white.withValues(
                                                        alpha: .65,
                                                      )
                                                    : Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Expanded(
                                      child: _CaptureSideControl(
                                        icon: CupertinoIcons.barcode_viewfinder,
                                        label: 'Barcode',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                left: 64,
                                right: 64,
                                bottom: 6,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: List.generate(3, (index) {
                                    const labels = ['LABEL', 'PILL', 'BARCODE'];
                                    return CupertinoButton(
                                      key: Key('scanMode${labels[index]}'),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 7,
                                      ),
                                      minimumSize: const Size(44, 32),
                                      onPressed: () =>
                                          setState(() => _selectedMode = index),
                                      child: Text(
                                        labels[index],
                                        style: TextStyle(
                                          color: _selectedMode == index
                                              ? Colors.white
                                              : Colors.white.withValues(
                                                  alpha: .46,
                                                ),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: .25,
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ],
                          );
                        },
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
    required this.onClose,
    required this.onRequestAccess,
    this.onOpenSettings,
  });

  final ScannerAccessState accessState;
  final VoidCallback onClose;
  final Future<void> Function() onRequestAccess;
  final Future<bool> Function()? onOpenSettings;

  static const _blue = Color(0xFF0A62D0);

  @override
  Widget build(BuildContext context) {
    final (title, message, icon) = switch (accessState) {
      ScannerAccessState.notRequested => (
        'Camera access required',
        'Allow camera access to scan medication labels and barcodes.',
        CupertinoIcons.camera,
      ),
      ScannerAccessState.requesting => (
        'Requesting camera access',
        'Respond to the system permission prompt to continue.',
        CupertinoIcons.camera_rotate,
      ),
      ScannerAccessState.denied => (
        'Camera access denied',
        'The scanner needs camera access. You can try the permission request again.',
        CupertinoIcons.camera,
      ),
      ScannerAccessState.permanentlyDenied => (
        'Enable camera access',
        'Open Settings and allow camera access for this app, then return here.',
        CupertinoIcons.camera,
      ),
      ScannerAccessState.error => (
        'Camera unavailable',
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
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 112),
          child: Stack(
            children: [
              Positioned(
                top: 4,
                left: 10,
                child: CupertinoButton(
                  key: const Key('closeScannerButton'),
                  padding: const EdgeInsets.all(12),
                  minimumSize: const Size.square(44),
                  onPressed: onClose,
                  child: const Icon(CupertinoIcons.xmark, size: 20),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isRequesting)
                          const SizedBox.square(
                            dimension: 50,
                            child: CupertinoActivityIndicator(radius: 18),
                          )
                        else
                          Container(
                            width: 74,
                            height: 74,
                            decoration: const BoxDecoration(
                              color: Color(0x190A62D0),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, size: 32, color: _blue),
                          ),
                        const SizedBox(height: 24),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF1C1C1E),
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.5,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF6E6E73),
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
                                backgroundColor: _blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
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

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isSelected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size.square(40),
          onPressed: onPressed,
          color: isSelected ? const Color(0xB00A62D0) : const Color(0x7A10141D),
          borderRadius: BorderRadius.circular(99),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

class _CameraFallback extends StatelessWidget {
  const _CameraFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF24323C), Color(0xFF101820), Color(0xFF304A4B)],
        ),
      ),
      child: Center(
        child: Icon(
          CupertinoIcons.capsule_fill,
          color: Color(0x4DFFFFFF),
          size: 108,
        ),
      ),
    );
  }
}

class _CaptureSideControl extends StatelessWidget {
  const _CaptureSideControl({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 19),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xC2FFFFFF),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanFrame extends StatelessWidget {
  const _ScanFrame({required this.animation, required this.isAnalyzing});

  final Animation<double> animation;
  final bool isAnalyzing;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => CustomPaint(
        painter: _ScanFramePainter(
          progress: reduceMotion || isAnalyzing ? .5 : animation.value,
          isAnalyzing: isAnalyzing,
        ),
      ),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  const _ScanFramePainter({required this.progress, required this.isAnalyzing});

  final double progress;
  final bool isAnalyzing;

  @override
  void paint(Canvas canvas, Size size) {
    const cornerLength = 54.0;
    const radius = 22.0;
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0, cornerLength)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..lineTo(cornerLength, 0)
      ..moveTo(size.width - cornerLength, 0)
      ..lineTo(size.width - radius, 0)
      ..quadraticBezierTo(size.width, 0, size.width, radius)
      ..lineTo(size.width, cornerLength)
      ..moveTo(size.width, size.height - cornerLength)
      ..lineTo(size.width, size.height - radius)
      ..quadraticBezierTo(
        size.width,
        size.height,
        size.width - radius,
        size.height,
      )
      ..lineTo(size.width - cornerLength, size.height)
      ..moveTo(cornerLength, size.height)
      ..lineTo(radius, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - radius)
      ..lineTo(0, size.height - cornerLength);
    canvas.drawPath(path, cornerPaint);

    final y = size.height * (.16 + progress * .68);
    final linePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x0076F0CC), Color(0xFF76F0CC), Color(0x0076F0CC)],
      ).createShader(Rect.fromLTWH(14, y - 1, size.width - 28, 2))
      ..strokeWidth = isAnalyzing ? 3 : 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawLine(Offset(14, y), Offset(size.width - 14, y), linePaint);
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.isAnalyzing != isAnalyzing;
}

class ScanResultScreen extends StatefulWidget {
  const ScanResultScreen({
    super.key,
    this.onBack,
    this.onScanAgain,
    this.onAdded,
  });

  final VoidCallback? onBack;
  final VoidCallback? onScanAgain;
  final VoidCallback? onAdded;

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  static const _blue = Color(0xFF0A62D0);
  static const _ink = Color(0xFF1C1C1E);
  static const _muted = Color(0xFF6E6E73);
  static const _line = Color(0xFFD9D9DE);
  static const _surface = Colors.white;
  static const _green = Color(0xFF34C759);

  String _dose = '1 capsule';
  String _frequency = 'Every 8 hours';
  String _duration = '7 days';
  DateTime _startDate = DateTime(2026, 8, 30);
  bool _isAdded = false;

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
    final selected = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(title),
        actions: options
            .map(
              (option) => CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(context, option),
                child: Text(option),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (selected != null && mounted) onSelected(selected);
  }

  Future<void> _chooseStartDate() async {
    var draft = _startDate;
    final selected = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (context) => Container(
        height: 320,
        color: CupertinoDynamicColor.resolve(
          CupertinoColors.systemBackground,
          context,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              SizedBox(
                height: 52,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const Text(
                      'Start date',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    CupertinoButton(
                      onPressed: () => Navigator.pop(context, draft),
                      child: const Text(
                        'Done',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _startDate,
                  minimumDate: DateTime(2020),
                  maximumDate: DateTime(2100),
                  onDateTimeChanged: (value) => draft = value,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _startDate = selected);
  }

  void _addToCalendar() {
    if (_isAdded) return;
    setState(() => _isAdded = true);
    widget.onAdded?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                SizedBox(
                  height: 62,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 62,
                        child: CupertinoButton(
                          key: const Key('scanResultBackButton'),
                          padding: EdgeInsets.zero,
                          minimumSize: const Size.square(44),
                          onPressed:
                              widget.onBack ??
                              () => Navigator.maybePop(context),
                          child: const Icon(
                            CupertinoIcons.chevron_left,
                            size: 21,
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Review medication',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.2,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 62,
                        child: CupertinoButton(
                          key: const Key('scanAgainButton'),
                          padding: EdgeInsets.zero,
                          minimumSize: const Size.square(44),
                          onPressed: widget.onScanAgain,
                          child: const Icon(
                            CupertinoIcons.arrow_clockwise,
                            size: 19,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    key: const Key('scanResultScrollView'),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      const _ResultHero(),
                      const SizedBox(height: 18),
                      const _InfoGrid(),
                      const SizedBox(height: 16),
                      const _SafetyNotice(),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Set your schedule',
                              style: TextStyle(
                                color: _ink,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
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
                                      onSelected: (value) =>
                                          setState(() => _frequency = value),
                                    ),
                                  ),
                                ),
                              ],
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
                                      onSelected: (value) =>
                                          setState(() => _duration = value),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        10,
                        16,
                        MediaQuery.paddingOf(context).bottom + 106,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xE6F9F9F9),
                        border: Border(
                          top: BorderSide(
                            color: const Color(0xFF3C3C43)
                                .withValues(alpha: .2),
                            width: .5,
                          ),
                        ),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          key: const Key('addScanResultButton'),
                          onPressed: _addToCalendar,
                          style: FilledButton.styleFrom(
                            backgroundColor: _isAdded ? _green : _blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          icon: Icon(
                            _isAdded
                                ? CupertinoIcons.check_mark_circled_solid
                                : CupertinoIcons.calendar_badge_plus,
                            size: 18,
                          ),
                          label: Text(
                            _isAdded ? 'Added to calendar' : 'Add to calendar',
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
  const _ResultHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _ScanResultScreenState._line)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox.square(
              dimension: 82,
              child: Image.network(
                'https://images.unsplash.com/photo-1471864190281-a93a3070b6de?auto=format&fit=crop&w=300&q=90',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const ColoredBox(
                  color: Color(0xFFF0E5EF),
                  child: Icon(
                    CupertinoIcons.capsule_fill,
                    color: Color(0xFFEA3C86),
                    size: 34,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.check_mark_circled_solid,
                      size: 13,
                      color: _ScanResultScreenState._green,
                    ),
                    SizedBox(width: 5),
                    Text(
                      '98% match',
                      style: TextStyle(
                        color: _ScanResultScreenState._green,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 7),
                Text(
                  'Amoxicillin',
                  style: TextStyle(
                    color: _ScanResultScreenState._ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.3,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '500 mg capsule · Prescription',
                  style: TextStyle(
                    color: _ScanResultScreenState._muted,
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

class _InfoGrid extends StatelessWidget {
  const _InfoGrid();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: const ColoredBox(
        color: _ScanResultScreenState._surface,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _InfoTile(
                    label: 'IMPRINT',
                    value: 'AMOX 500',
                    rightBorder: true,
                    bottomBorder: true,
                  ),
                ),
                Expanded(
                  child: _InfoTile(
                    label: 'MANUFACTURER',
                    value: 'Sandoz Inc.',
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
                    value: 'Capsule',
                    rightBorder: true,
                  ),
                ),
                Expanded(
                  child: _InfoTile(label: 'COLOR', value: 'Blue / pink'),
                ),
              ],
            ),
          ],
        ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          right: rightBorder
              ? const BorderSide(color: _ScanResultScreenState._line)
              : BorderSide.none,
          bottom: bottomBorder
              ? const BorderSide(color: _ScanResultScreenState._line)
              : BorderSide.none,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _ScanResultScreenState._muted,
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
            style: const TextStyle(
              color: _ScanResultScreenState._ink,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              CupertinoIcons.exclamationmark_triangle_fill,
              color: Color(0xFFB06A22),
              size: 16,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Confirm the package and prescription label before adding. AI identification does not replace advice from your pharmacist.',
              style: TextStyle(
                color: Color(0xFF8B531E),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text(
            label,
            style: const TextStyle(
              color: _ScanResultScreenState._muted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: .35,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 43,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                border: Border.all(color: _ScanResultScreenState._line),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 14, color: _ScanResultScreenState._blue),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ScanResultScreenState._ink,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (icon == null)
                    const Icon(
                      CupertinoIcons.chevron_down,
                      size: 12,
                      color: _ScanResultScreenState._muted,
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
