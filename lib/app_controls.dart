import 'dart:async';

import 'package:flutter/material.dart';

import 'app_interactions.dart';
import 'app_theme.dart';

export 'app_theme.dart' show AppSpacing, AppTextStyles;

/// Visual priority is shared across routes and platforms.
enum AppButtonVariant {
  primary,
  secondary,
  tertiary,
  destructive,
  destructiveSecondary,
}

/// The standard action control. Text remains visible during asynchronous work,
/// and another activation is blocked until that work finishes.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.leading,
    this.variant = AppButtonVariant.primary,
    this.compact = false,
    this.busy = false,
    this.loadingLabel,
    this.loadingIndicatorKey,
    this.semanticLabel,
    this.expand = false,
    this.haptic,
    this.onError,
  }) : assert(icon == null || leading == null);

  final String label;
  final FutureOr<void> Function()? onPressed;
  final IconData? icon;
  final Widget? leading;
  final AppButtonVariant variant;
  final bool compact;
  final bool busy;
  final String? loadingLabel;
  final Key? loadingIndicatorKey;
  final String? semanticLabel;
  final bool expand;
  final AppHapticKind? haptic;
  final void Function(Object error, StackTrace stackTrace)? onError;

  @override
  State<AppButton> createState() => _AppButtonState();
}

abstract class _ActionState<T extends StatefulWidget> extends State<T> {
  bool _awaitingCallback = false;
  bool get externalBusy;
  FutureOr<void> Function()? get callback;
  AppHapticKind get haptic;
  void Function(Object, StackTrace)? get errorHandler;
  bool get isBusy => externalBusy || _awaitingCallback;
  bool get canActivate => callback != null && !isBusy;

  void _activateAction() {
    if (!canActivate) return;
    // Do not await before invoking the callback. Browser camera, clipboard and
    // file-picker operations require the original pointer's user activation.
    unawaited(AppHaptics.trigger(haptic));
    late final FutureOr<void> result;
    try {
      result = callback!();
    } catch (error, stack) {
      reportError(error, stack);
      return;
    }
    if (result is Future<void>) {
      setState(() => _awaitingCallback = true);
      unawaited(complete(result));
    }
  }

  Future<void> complete(Future<void> result) async {
    try {
      await result;
    } catch (error, stack) {
      reportError(error, stack);
    } finally {
      if (mounted) setState(() => _awaitingCallback = false);
    }
  }

  void reportError(Object error, StackTrace stack) {
    if (errorHandler != null) {
      errorHandler!(error, stack);
    } else {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'Mediary controls',
          context: ErrorDescription('while handling an action'),
        ),
      );
    }
  }
}

class _AppButtonState extends _ActionState<AppButton> {
  @override
  bool get externalBusy => widget.busy;
  @override
  FutureOr<void> Function()? get callback => widget.onPressed;
  @override
  AppHapticKind get haptic =>
      widget.haptic ??
      (widget.variant == AppButtonVariant.primary ||
              widget.variant == AppButtonVariant.destructive
          ? AppHapticKind.primaryAction
          : AppHapticKind.selection);
  @override
  void Function(Object, StackTrace)? get errorHandler => widget.onError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final destructive =
        widget.variant == AppButtonVariant.destructive ||
        widget.variant == AppButtonVariant.destructiveSecondary;
    final filled =
        widget.variant == AppButtonVariant.primary ||
        widget.variant == AppButtonVariant.destructive;
    final outlined =
        widget.variant == AppButtonVariant.secondary ||
        widget.variant == AppButtonVariant.destructiveSecondary;
    final accent = destructive ? colors.error : colors.primary;
    final foreground = filled
        ? (destructive ? colors.onError : colors.onPrimary)
        : accent;
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
        Size(
          AppButtonMetrics.minWidth,
          widget.compact
              ? AppButtonMetrics.compactHeight
              : AppButtonMetrics.height,
        ),
      ),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: widget.compact ? 12 : AppButtonMetrics.horizontalPadding,
          vertical: widget.compact ? 8 : 12,
        ),
      ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AppButtonMetrics.radius),
          ),
        ),
      ),
      textStyle: WidgetStatePropertyAll(
        AppButtonMetrics.labelStyle.copyWith(
          fontFamily: Theme.of(context).textTheme.labelLarge?.fontFamily,
        ),
      ),
      iconSize: const WidgetStatePropertyAll(20),
      elevation: const WidgetStatePropertyAll(0),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (filled) {
          return states.contains(WidgetState.disabled) && !isBusy
              ? accent.withValues(alpha: .12)
              : accent;
        }
        return Colors.transparent;
      }),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) && !isBusy
            ? colors.onSurface.withValues(
                alpha: AppButtonMetrics.disabledForegroundOpacity,
              )
            : foreground,
      ),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return foreground.withValues(alpha: .13);
        }
        if (states.contains(WidgetState.hovered)) {
          return foreground.withValues(alpha: .08);
        }
        return Colors.transparent;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return BorderSide(color: foreground, width: 2);
        }
        if (outlined) {
          return BorderSide(
            color: states.contains(WidgetState.disabled)
                ? colors.outline.withValues(alpha: .45)
                : destructive
                ? accent.withValues(alpha: .55)
                : colors.outlineVariant,
          );
        }
        return BorderSide.none;
      }),
      animationDuration: MediaQuery.maybeOf(context)?.disableAnimations == true
          ? Duration.zero
          : AppButtonMetrics.interactionDuration,
      mouseCursor: WidgetStateProperty.resolveWith(
        (states) => isBusy
            ? SystemMouseCursors.progress
            : states.contains(WidgetState.disabled)
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
      ),
      visualDensity: VisualDensity.standard,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      enableFeedback: false,
    );
    final leading = isBusy
        ? SizedBox.square(
            key:
                widget.loadingIndicatorKey ??
                const Key('appButtonLoadingIndicator'),
            dimension: AppButtonMetrics.loadingIndicatorSize,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        : widget.leading ?? (widget.icon == null ? null : Icon(widget.icon));
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[
          ExcludeSemantics(child: leading),
          const SizedBox(width: AppButtonMetrics.iconGap),
        ],
        Flexible(
          child: Text(
            isBusy ? widget.loadingLabel ?? widget.label : widget.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
    final Widget button;
    if (filled) {
      button = FilledButton(
        onPressed: canActivate ? _activateAction : null,
        style: style,
        child: content,
      );
    } else if (outlined) {
      button = OutlinedButton(
        onPressed: canActivate ? _activateAction : null,
        style: style,
        child: content,
      );
    } else {
      button = TextButton(
        onPressed: canActivate ? _activateAction : null,
        style: style,
        child: content,
      );
    }
    return Semantics(
      liveRegion: isBusy,
      value: isBusy ? 'In progress' : null,
      child: widget.semanticLabel == null
          ? (widget.expand
                ? SizedBox(width: double.infinity, child: button)
                : button)
          : Semantics(
              button: true,
              enabled: canActivate,
              label: widget.semanticLabel,
              onTap: canActivate ? _activateAction : null,
              excludeSemantics: true,
              child: widget.expand
                  ? SizedBox(width: double.infinity, child: button)
                  : button,
            ),
    );
  }
}

/// Toolbar, dismiss, and navigation controls share one circular hit area.
class AppIconButton extends StatefulWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.showTooltip = true,
    required this.onPressed,
    this.busy = false,
    this.selected = false,
    this.overImage = false,
    this.foregroundColor,
    this.backgroundColor,
    this.haptic = AppHapticKind.selection,
    this.onError,
  });
  final IconData icon;
  final String tooltip;
  final bool showTooltip;
  final FutureOr<void> Function()? onPressed;
  final bool busy;
  final bool selected;
  final bool overImage;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final AppHapticKind haptic;
  final void Function(Object, StackTrace)? onError;
  @override
  State<AppIconButton> createState() => _AppIconButtonState();
}

class _AppIconButtonState extends _ActionState<AppIconButton> {
  @override
  bool get externalBusy => widget.busy;
  @override
  FutureOr<void> Function()? get callback => widget.onPressed;
  @override
  AppHapticKind get haptic => widget.haptic;
  @override
  void Function(Object, StackTrace)? get errorHandler => widget.onError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground =
        widget.foregroundColor ??
        (widget.overImage ? Colors.white : colors.primary);
    final background =
        widget.backgroundColor ??
        (widget.overImage
            ? Colors.white.withValues(alpha: .14)
            : widget.selected
            ? colors.primary.withValues(alpha: .10)
            : Colors.transparent);
    return Semantics(
      label: widget.showTooltip ? null : widget.tooltip,
      excludeSemantics: !widget.showTooltip,
      button: widget.showTooltip ? null : true,
      enabled: widget.showTooltip ? null : canActivate,
      onTap: !widget.showTooltip && canActivate ? _activateAction : null,
      selected: widget.selected ? true : null,
      liveRegion: isBusy,
      value: isBusy ? 'In progress' : null,
      child: IconButton(
        tooltip: widget.showTooltip ? widget.tooltip : null,
        onPressed: canActivate ? _activateAction : null,
        icon: isBusy
            ? SizedBox.square(
                dimension: AppButtonMetrics.loadingIndicatorSize,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            : Icon(
                widget.icon,
                semanticLabel: widget.showTooltip ? null : widget.tooltip,
              ),
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size.square(AppButtonMetrics.iconButtonSize),
          ),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(10)),
          shape: const WidgetStatePropertyAll(CircleBorder()),
          iconSize: const WidgetStatePropertyAll(22),
          backgroundColor: WidgetStatePropertyAll(background),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) && !isBusy
                ? foreground.withValues(
                    alpha: AppButtonMetrics.disabledForegroundOpacity,
                  )
                : foreground,
          ),
          overlayColor: WidgetStateProperty.resolveWith(
            (states) => foreground.withValues(
              alpha: states.contains(WidgetState.pressed)
                  ? .13
                  : states.contains(WidgetState.hovered)
                  ? .08
                  : 0,
            ),
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? BorderSide(color: foreground, width: 2)
                : widget.overImage
                ? BorderSide(color: Colors.white.withValues(alpha: .22))
                : BorderSide.none,
          ),
          animationDuration:
              MediaQuery.maybeOf(context)?.disableAnimations == true
              ? Duration.zero
              : AppButtonMetrics.interactionDuration,
          visualDensity: VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          mouseCursor: WidgetStateProperty.resolveWith(
            (states) => isBusy
                ? SystemMouseCursors.progress
                : states.contains(WidgetState.disabled)
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
          ),
          enableFeedback: false,
        ),
      ),
    );
  }
}
