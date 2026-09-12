import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_interactions.dart';

/// A compact iOS-style switch with the same translucent treatment as Mediary's
/// circular glass controls.
class LiquidGlassSwitch extends StatelessWidget {
  const LiquidGlassSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final enabled = onChanged != null;
    final trackColor = value
        ? primary.withValues(alpha: enabled ? .72 : .34)
        : (dark ? const Color(0xFF2C2D32) : const Color(0xFFD9DDE4));

    return Semantics(
      container: true,
      toggled: value,
      enabled: enabled,
      label: semanticLabel,
      child: AppPressable(
        onPressed: enabled ? () => onChanged!(!value) : null,
        enabled: enabled,
        haptic: AppHapticKind.selection,
        hoverScale: 1.02,
        pressedScale: .95,
        hoverOffset: Offset.zero,
        borderRadius: BorderRadius.circular(99),
        child: SizedBox(
          width: 52,
          height: 32,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  color: trackColor,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: dark ? .16 : .58),
                    width: .7,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    alignment: value
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dark ? const Color(0xFFF2F2F7) : Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: dark ? .28 : .16,
                            ),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const SizedBox.square(dimension: 25),
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
