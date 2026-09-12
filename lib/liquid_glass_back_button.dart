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
    final buttonColor = overImage
        ? Colors.white.withValues(alpha: highContrast ? .22 : .14)
        : dark
        ? Colors.white.withValues(alpha: highContrast ? .18 : .11)
        : Colors.white.withValues(alpha: highContrast ? .62 : .38);

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
                child: WebAwareBlur(
                  sigma: 20,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: buttonColor,
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
                    child: AppPressable(
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
                                Shadow(color: Color(0x66000000), blurRadius: 5),
                              ]
                            : null,
                      ),
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
