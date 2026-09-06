import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_interactions.dart';
import 'app_theme.dart';

/// A consistent route-level back control with an adaptive glass treatment.
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

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    final iconColor = overImage
        ? Colors.white
        : dark
        ? const Color(0xFFF2F2F7)
        : AppColors.darkSurface.withValues(alpha: .90);
    final glassColors = overImage
        ? [
            Colors.white.withValues(alpha: highContrast ? .34 : .22),
            Colors.white.withValues(alpha: .08),
            Colors.black.withValues(alpha: highContrast ? .26 : .17),
          ]
        : dark
        ? [
            Colors.white.withValues(alpha: highContrast ? .24 : .14),
            const Color(0xFF7890A8).withValues(alpha: .09),
            Colors.black.withValues(alpha: .12),
          ]
        : [
            Colors.white.withValues(alpha: highContrast ? .62 : .38),
            const Color(0xFFDCEAFF).withValues(alpha: .19),
            Colors.white.withValues(alpha: .13),
          ];

    return Semantics(
      button: true,
      label: semanticLabel,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: Tooltip(
          message: semanticLabel,
          child: SizedBox.square(
            dimension: 44,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: overImage
                          ? .18
                          : dark
                          ? .22
                          : .08,
                    ),
                    blurRadius: 16,
                    spreadRadius: -5,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: glassColors,
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: overImage
                              ? .16
                              : dark
                              ? .14
                              : .52,
                        ),
                        width: .7,
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(-.72, -.9),
                              radius: 1.2,
                              colors: [
                                Colors.white.withValues(
                                  alpha: overImage
                                      ? .22
                                      : dark
                                      ? .14
                                      : .34,
                                ),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        AppPressable(
                          onPressed: onPressed,
                          haptic: AppHapticKind.primaryAction,
                          hoverScale: 1.045,
                          pressedScale: .92,
                          hoverOffset: Offset.zero,
                          borderRadius: BorderRadius.circular(22),
                          hoverOverlayColor: Colors.white.withValues(
                            alpha: overImage ? .13 : .09,
                          ),
                          pressedOverlayColor: Colors.black.withValues(
                            alpha: overImage ? .16 : .09,
                          ),
                          child: Icon(
                            CupertinoIcons.chevron_left,
                            color: iconColor,
                            size: 21,
                            shadows: overImage
                                ? const [
                                    Shadow(
                                      color: Color(0x66000000),
                                      blurRadius: 5,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
