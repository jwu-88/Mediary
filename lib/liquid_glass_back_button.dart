import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_controls.dart';
import 'app_theme.dart' show AppButtonMetrics;
import 'app_interactions.dart';

/// A route-level back action with the same geometry and feedback as toolbars.
class LiquidGlassBackButton extends StatelessWidget {
  const LiquidGlassBackButton({
    super.key,
    required this.onPressed,
    this.semanticLabel = 'Back',
    this.overImage = false,
  });
  final VoidCallback onPressed;
  final String semanticLabel;
  final bool overImage;

  void _semanticPress() {
    unawaited(AppHaptics.primaryAction());
    onPressed();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticLabel,
    onTap: _semanticPress,
    child: ExcludeSemantics(
      child: SizedBox.square(
        dimension: AppButtonMetrics.iconButtonSize,
        child: AppIconButton(
          icon: CupertinoIcons.chevron_left,
          tooltip: semanticLabel,
          onPressed: onPressed,
          overImage: overImage,
          haptic: AppHapticKind.primaryAction,
          backgroundColor: overImage
              ? null
              : Theme.of(context).colorScheme.surface,
          foregroundColor: overImage
              ? null
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    ),
  );
}
