import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A backdrop blur that is skipped on web.
///
/// `BackdropFilter` forces a `saveLayer` + backdrop read every frame. On the
/// CanvasKit/Skwasm web renderer this is a major source of jank, so web falls
/// back to the surrounding tint alone (matching the native design).
class WebAwareBlur extends StatelessWidget {
  const WebAwareBlur({super.key, required this.sigma, required this.child});

  final double sigma;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return child;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: child,
    );
  }
}

/// The kind of native tactile response produced by an [AppPressable].
enum AppHapticKind { none, selection, primaryAction }

/// Controls how progress is presented while an [AppPressable] is busy.
enum AppPressableLoadingPresentation { replace, overlay }

/// A Cupertino-style button with the same hover, focus, press, and loading
/// feedback as the rest of the web shell.
///
/// Flutter's [CupertinoButton] provides excellent touch feedback, but its web
/// hover state is intentionally minimal. This adapter keeps its iOS padding,
/// colors, and typography while adding the same interaction feedback used by
/// [AppPressable].
class ResponsiveCupertinoButton extends StatelessWidget {
  const ResponsiveCupertinoButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.buttonKey,
    this.minimumSize,
    this.padding,
    this.color,
    this.borderRadius,
    this.semanticLabel,
    this.busy = false,
  });

  final Widget child;
  final FutureOr<void> Function()? onPressed;
  final Key? buttonKey;
  final Size? minimumSize;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final BorderRadius? borderRadius;
  final String? semanticLabel;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = borderRadius ?? BorderRadius.circular(12);
    final minimumSize = this.minimumSize ?? Size.zero;
    final padding = this.padding ?? EdgeInsets.zero;
    final content = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minimumSize.width,
        minHeight: minimumSize.height,
      ),
      child: Padding(
        padding: padding,
        child: color == null
            ? child
            : DecoratedBox(
                decoration: BoxDecoration(color: color, borderRadius: radius),
                child: child,
              ),
      ),
    );

    return AppPressable(
      key: buttonKey,
      onPressed: onPressed,
      busy: busy,
      semanticLabel: semanticLabel,
      borderRadius: radius,
      haptic: AppHapticKind.selection,
      hoverScale: 1.018,
      pressedScale: .965,
      hoverOverlayColor: colors.primary.withValues(alpha: .08),
      pressedOverlayColor: colors.primary.withValues(alpha: .13),
      busyOverlayColor: colors.surface.withValues(alpha: .68),
      loadingIndicator: SizedBox.square(
        key: const Key('responsiveCupertinoLoadingIndicator'),
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
      ),
      child: content,
    );
  }
}

/// Platform-safe haptic feedback for Mediary interactions.
///
/// Calls are intentionally ignored on web and desktop platforms. This keeps
/// browser clicks silent and avoids invoking unsupported platform channels.
abstract final class AppHaptics {
  static bool get isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  static Future<void> selection() => trigger(AppHapticKind.selection);

  static Future<void> primaryAction() => trigger(AppHapticKind.primaryAction);

  static Future<void> trigger(AppHapticKind kind) async {
    if (!isSupported || kind == AppHapticKind.none) return;

    switch (kind) {
      case AppHapticKind.none:
        return;
      case AppHapticKind.selection:
        await HapticFeedback.selectionClick();
      case AppHapticKind.primaryAction:
        await HapticFeedback.mediumImpact();
    }
  }
}

/// A cross-platform interaction wrapper for custom tappable surfaces.
///
/// It adds pointer hover, press, keyboard, loading, semantics, and optional
/// native haptic feedback without imposing a visual card style on [child].
class AppPressable extends StatefulWidget {
  const AppPressable({
    super.key,
    required this.child,
    required this.onPressed,
    this.enabled = true,
    this.busy = false,
    this.autoManageBusy = true,
    this.loadingPresentation = AppPressableLoadingPresentation.overlay,
    this.loadingIndicator,
    this.busyOverlayColor,
    this.haptic = AppHapticKind.selection,
    this.enableHaptics = true,
    this.enableHoverEffect = true,
    this.hoverScale = 1.012,
    this.pressedScale = 0.985,
    this.hoverOffset = const Offset(0, -1),
    this.motionDuration = const Duration(milliseconds: 140),
    this.motionCurve = Curves.easeOutCubic,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.hoverOverlayColor,
    this.pressedOverlayColor,
    this.focusOverlayColor,
    this.disabledOpacity = .46,
    this.mouseCursor,
    this.semanticLabel,
    this.semanticHint,
    this.excludeFromSemantics = false,
    this.focusNode,
    this.autofocus = false,
    this.onError,
  });

  final Widget child;

  /// May return a [Future]. When [autoManageBusy] is true, an unfinished
  /// future automatically activates the configured loading presentation.
  final FutureOr<void> Function()? onPressed;

  final bool enabled;
  final bool busy;
  final bool autoManageBusy;
  final AppPressableLoadingPresentation loadingPresentation;
  final Widget? loadingIndicator;
  final Color? busyOverlayColor;
  final AppHapticKind haptic;
  final bool enableHaptics;
  final bool enableHoverEffect;

  /// Retained for source compatibility. Hover feedback no longer changes
  /// geometry, so this value is intentionally ignored.
  final double hoverScale;
  final double pressedScale;

  /// Retained for source compatibility. Hover feedback no longer changes
  /// geometry, so this value is intentionally ignored.
  final Offset hoverOffset;
  final Duration motionDuration;
  final Curve motionCurve;
  final BorderRadiusGeometry borderRadius;
  final Color? hoverOverlayColor;
  final Color? pressedOverlayColor;
  final Color? focusOverlayColor;
  final double disabledOpacity;
  final MouseCursor? mouseCursor;
  final String? semanticLabel;
  final String? semanticHint;
  final bool excludeFromSemantics;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Receives callback failures after the interaction has returned to an idle
  /// state. When omitted, unexpected failures are reported to Flutter's error
  /// pipeline instead of becoming unhandled asynchronous errors.
  final void Function(Object error, StackTrace stackTrace)? onError;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;
  bool _awaitingCallback = false;

  bool get _isBusy => widget.busy || _awaitingCallback;

  bool get _isInteractive =>
      widget.enabled && widget.onPressed != null && !_isBusy;

  bool get _supportsHover {
    if (kIsWeb) return true;
    return switch (defaultTargetPlatform) {
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      _ => false,
    };
  }

  @override
  void didUpdateWidget(AppPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isInteractive && (_pressed || _hovered)) {
      _pressed = false;
      _hovered = false;
    }
  }

  void _setHovered(bool value) {
    final next = value && _supportsHover && widget.enableHoverEffect;
    if (_hovered == next) return;
    setState(() => _hovered = next);
  }

  void _setPressed(bool value) {
    final next = value && _isInteractive;
    if (_pressed == next) return;
    setState(() => _pressed = next);
  }

  void _activate() {
    if (!_isInteractive) return;
    _setPressed(false);

    if (widget.enableHaptics) {
      unawaited(AppHaptics.trigger(widget.haptic));
    }

    late final FutureOr<void> result;
    try {
      result = widget.onPressed!.call();
    } catch (error, stackTrace) {
      _reportCallbackError(error, stackTrace);
      return;
    }
    if (result is! Future<void>) return;
    if (!widget.autoManageBusy) {
      unawaited(_completeCallback(result, manageBusy: false));
      return;
    }

    setState(() => _awaitingCallback = true);
    unawaited(_completeCallback(result, manageBusy: true));
  }

  Future<void> _completeCallback(
    Future<void> callback, {
    required bool manageBusy,
  }) async {
    try {
      await callback;
    } catch (error, stackTrace) {
      _reportCallbackError(error, stackTrace);
    } finally {
      if (manageBusy && mounted) setState(() => _awaitingCallback = false);
    }
  }

  void _reportCallbackError(Object error, StackTrace stackTrace) {
    final handler = widget.onError;
    if (handler != null) {
      handler(error, stackTrace);
      return;
    }
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'Mediary interactions',
        context: ErrorDescription('while handling a press action'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.hoverScale > 0);
    assert(widget.pressedScale > 0);
    assert(widget.disabledOpacity >= 0 && widget.disabledOpacity <= 1);

    final mediaQuery = MediaQuery.maybeOf(context);
    final reduceMotion = mediaQuery?.disableAnimations ?? false;
    final duration = reduceMotion ? Duration.zero : widget.motionDuration;
    final colorScheme = Theme.of(context).colorScheme;
    final highContrast = mediaQuery?.highContrast ?? false;
    final hoverOverlay =
        widget.hoverOverlayColor ??
        colorScheme.primary.withValues(alpha: highContrast ? .12 : .07);
    final pressedOverlay =
        widget.pressedOverlayColor ??
        colorScheme.primary.withValues(alpha: highContrast ? .2 : .13);
    final focusOverlay =
        widget.focusOverlayColor ??
        colorScheme.primary.withValues(alpha: highContrast ? .14 : .09);

    final overlayColor = _pressed
        ? pressedOverlay
        : _hovered
        ? hoverOverlay
        : _focused
        ? focusOverlay
        : Colors.transparent;
    // Hover feedback must not change the button's geometry. Scaling or
    // translating a full-width surface can paint into adjacent UI, especially
    // beside the expanding web sidebar. Keep motion for the intentional press
    // response and use the overlay above for hover feedback instead.
    final scale = _pressed ? widget.pressedScale : 1.0;
    final offset = Offset.zero;
    final effectiveCursor = !_isInteractive
        ? SystemMouseCursors.forbidden
        : widget.mouseCursor ?? SystemMouseCursors.click;

    Widget content = widget.child;
    if (_isBusy) {
      content = _buildBusyContent(context, content);
    }

    content = Stack(
      fit: StackFit.passthrough,
      children: [
        content,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedContainer(
              key: const Key('appPressableFeedbackOverlay'),
              duration: duration,
              curve: widget.motionCurve,
              decoration: BoxDecoration(
                color: overlayColor,
                borderRadius: widget.borderRadius,
              ),
            ),
          ),
        ),
      ],
    );

    content = AnimatedOpacity(
      key: const Key('appPressableOpacity'),
      opacity: widget.enabled ? 1 : widget.disabledOpacity,
      duration: duration,
      curve: widget.motionCurve,
      child: content,
    );

    content = TweenAnimationBuilder<Offset>(
      key: const Key('appPressableTranslation'),
      duration: duration,
      curve: widget.motionCurve,
      tween: Tween(begin: Offset.zero, end: offset),
      builder: (context, value, child) =>
          Transform.translate(offset: value, child: child),
      child: AnimatedScale(
        key: const Key('appPressableScale'),
        scale: scale,
        duration: duration,
        curve: widget.motionCurve,
        child: content,
      ),
    );

    content = FocusableActionDetector(
      enabled: _isInteractive,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      mouseCursor: effectiveCursor,
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _activate();
            return null;
          },
        ),
      },
      onShowHoverHighlight: _setHovered,
      onShowFocusHighlight: (value) {
        if (_focused != value) setState(() => _focused = value);
      },
      child: content,
    );

    content = Semantics(
      container: true,
      button: true,
      enabled: _isInteractive,
      liveRegion: _isBusy,
      label: widget.semanticLabel,
      hint: widget.semanticHint,
      value: _isBusy ? 'Loading' : null,
      onTap: _isInteractive ? _activate : null,
      excludeSemantics: widget.excludeFromSemantics,
      child: content,
    );

    // Keep the gesture detector at the root so a keyed AppPressable resolves
    // to the actual hit target in widget tests and browser automation.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTapDown: _isInteractive ? (_) => _setPressed(true) : null,
      onTapUp: _isInteractive ? (_) => _setPressed(false) : null,
      onTapCancel: _isInteractive ? () => _setPressed(false) : null,
      onTap: _isInteractive ? _activate : null,
      child: content,
    );
  }

  Widget _buildBusyContent(BuildContext context, Widget child) {
    final indicator =
        widget.loadingIndicator ??
        SizedBox.square(
          key: const Key('appPressableLoadingIndicator'),
          dimension: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.primary,
          ),
        );

    return switch (widget.loadingPresentation) {
      AppPressableLoadingPresentation.replace => Stack(
        alignment: Alignment.center,
        children: [
          Opacity(opacity: 0, child: child),
          indicator,
        ],
      ),
      AppPressableLoadingPresentation.overlay => Stack(
        fit: StackFit.passthrough,
        children: [
          child,
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color:
                      widget.busyOverlayColor ??
                      Theme.of(context).colorScheme.surface
                          .withValues(alpha: .68),
                  borderRadius: widget.borderRadius,
                ),
                child: Center(child: indicator),
              ),
            ),
          ),
        ],
      ),
    };
  }
}
