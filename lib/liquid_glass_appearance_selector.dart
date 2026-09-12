import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_interactions.dart';
import 'app_theme.dart';

/// A three-way glass selector for the app's light, dark, and system themes.
class LiquidGlassAppearanceSelector extends StatelessWidget {
  const LiquidGlassAppearanceSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  static const _options = [
    (
      mode: ThemeMode.light,
      icon: CupertinoIcons.sun_max_fill,
      label: 'Light',
      key: Key('appearanceOptionLight'),
    ),
    (
      mode: ThemeMode.dark,
      icon: CupertinoIcons.moon_fill,
      label: 'Dark',
      key: Key('appearanceOptionDark'),
    ),
    (
      mode: ThemeMode.system,
      icon: CupertinoIcons.circle_lefthalf_fill,
      label: 'System',
      key: Key('appearanceOptionSystem'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.maybeOf(context);
    final highContrast = mediaQuery?.highContrast ?? false;
    final reduceMotion = mediaQuery?.disableAnimations ?? false;

    final surface = Container(
      key: const Key('appearanceModeSelector'),
      height: 64,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: dark
            ? const Color(0xFF25272B)
                  .withValues(alpha: highContrast ? .96 : .90)
            : const Color(0xFFF3F5F8)
                  .withValues(alpha: highContrast ? .98 : .92),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: highContrast ? .36 : .19)
              : Colors.white.withValues(alpha: highContrast ? .98 : .84),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < _options.length; index++) ...[
            if (index != 0) const SizedBox(width: 5),
            Expanded(
              child: _AppearanceOption(
                key: _options[index].key,
                mode: _options[index].mode,
                icon: _options[index].icon,
                label: _options[index].label,
                selected: value == _options[index].mode,
                dark: dark,
                highContrast: highContrast,
                reduceMotion: reduceMotion,
                onPressed: () {
                  if (value != _options[index].mode) {
                    onChanged(_options[index].mode);
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .20 : .09),
            blurRadius: 22,
            spreadRadius: -7,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: _NativeGlassBlur(sigma: 26, child: surface),
      ),
    );
  }
}

class _AppearanceOption extends StatelessWidget {
  const _AppearanceOption({
    super.key,
    required this.mode,
    required this.icon,
    required this.label,
    required this.selected,
    required this.dark,
    required this.highContrast,
    required this.reduceMotion,
    required this.onPressed,
  });

  final ThemeMode mode;
  final IconData icon;
  final String label;
  final bool selected;
  final bool dark;
  final bool highContrast;
  final bool reduceMotion;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).colorScheme.primary;
    final foregroundColor = selected
        ? activeColor
        : dark
        ? const Color(0xFFF2F2F7)
        : AppColors.darkSurface.withValues(alpha: .90);
    final selectedColor = activeColor.withValues(
      alpha: dark ? (highContrast ? .34 : .22) : (highContrast ? .90 : .68),
    );
    final idleColor = dark
        ? Colors.white.withValues(alpha: highContrast ? .12 : .055)
        : Colors.white.withValues(alpha: highContrast ? .44 : .20);

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      value: selected ? 'Selected' : 'Not selected',
      inMutuallyExclusiveGroup: true,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: _NativeGlassBlur(
            sigma: selected ? 16 : 9,
            child: AnimatedContainer(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                color: selected ? selectedColor : idleColor,
                border: Border.all(
                  color: selected
                      ? Colors.white.withValues(
                          alpha: dark
                              ? .17
                              : highContrast
                              ? .94
                              : .72,
                        )
                      : Colors.white.withValues(
                          alpha: dark
                              ? .075
                              : highContrast
                              ? .58
                              : .28,
                        ),
                  width: selected ? .9 : .7,
                ),
              ),
              child: AppPressable(
                onPressed: onPressed,
                haptic: AppHapticKind.selection,
                hoverScale: 1.018,
                pressedScale: .965,
                hoverOffset: Offset.zero,
                borderRadius: BorderRadius.circular(26),
                hoverOverlayColor: activeColor.withValues(alpha: .07),
                pressedOverlayColor: activeColor.withValues(alpha: .13),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: foregroundColor),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: TextStyle(
                          color: foregroundColor,
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          letterSpacing: -.15,
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
    );
  }
}

class _NativeGlassBlur extends StatelessWidget {
  const _NativeGlassBlur({required this.sigma, required this.child});

  final double sigma;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return child;
    }
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: child,
    );
  }
}
