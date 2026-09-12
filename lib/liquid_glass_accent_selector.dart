import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_interactions.dart';
import 'app_theme.dart';

/// A compact glass swatch selector for Mediary's supported accent palettes.
class LiquidGlassAccentSelector extends StatelessWidget {
  const LiquidGlassAccentSelector({
    super.key,
    this.value = AppAccentColor.blue,
    required this.onChanged,
  });

  final AppAccentColor value;
  final ValueChanged<AppAccentColor> onChanged;

  static const _options = [
    (accent: AppAccentColor.blue, key: Key('accentOptionBlue')),
    (accent: AppAccentColor.indigo, key: Key('accentOptionIndigo')),
    (accent: AppAccentColor.purple, key: Key('accentOptionPurple')),
    (accent: AppAccentColor.teal, key: Key('accentOptionTeal')),
    (accent: AppAccentColor.orange, key: Key('accentOptionOrange')),
  ];

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;
    final mediaQuery = MediaQuery.maybeOf(context);
    final highContrast = mediaQuery?.highContrast ?? false;
    final reduceMotion = mediaQuery?.disableAnimations ?? false;

    final surface = Container(
      key: const Key('accentColorSelector'),
      height: 68,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        color: dark
            ? const Color(0xFF25272B)
                  .withValues(alpha: highContrast ? .96 : .90)
            : const Color(0xFFF3F5F8)
                  .withValues(alpha: highContrast ? .98 : .92),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: highContrast ? .38 : .19)
              : Colors.white.withValues(alpha: highContrast ? 1 : .86),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final option in _options)
            Expanded(
              child: Center(
                child: _AccentOption(
                  key: option.key,
                  accent: option.accent,
                  selected: value == option.accent,
                  brightness: brightness,
                  highContrast: highContrast,
                  reduceMotion: reduceMotion,
                  onPressed: () {
                    if (value != option.accent) {
                      onChanged(option.accent);
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
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
        borderRadius: BorderRadius.circular(34),
        child: _NativeGlassBlur(sigma: 26, child: surface),
      ),
    );
  }
}

class _AccentOption extends StatelessWidget {
  const _AccentOption({
    super.key,
    required this.accent,
    required this.selected,
    required this.brightness,
    required this.highContrast,
    required this.reduceMotion,
    required this.onPressed,
  });

  final AppAccentColor accent;
  final bool selected;
  final Brightness brightness;
  final bool highContrast;
  final bool reduceMotion;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final dark = brightness == Brightness.dark;
    final swatch = accent.resolve(brightness);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: accent.label,
      value: selected ? 'Selected' : 'Not selected',
      inMutuallyExclusiveGroup: true,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: Tooltip(
          message: accent.label,
          child: AppPressable(
            onPressed: onPressed,
            haptic: AppHapticKind.selection,
            hoverScale: 1.06,
            pressedScale: .91,
            hoverOffset: const Offset(0, -1),
            borderRadius: BorderRadius.circular(26),
            hoverOverlayColor: swatch.withValues(alpha: .10),
            pressedOverlayColor: swatch.withValues(alpha: .18),
            child: ClipOval(
              child: _NativeGlassBlur(
                sigma: selected ? 16 : 10,
                child: AnimatedContainer(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: 50,
                  height: 50,
                  padding: EdgeInsets.all(selected ? 4 : 5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dark
                        ? Colors.white.withValues(alpha: selected ? .10 : .06)
                        : Colors.white.withValues(alpha: selected ? .52 : .27),
                    border: Border.all(
                      color: selected
                          ? swatch
                          : Colors.white.withValues(
                              alpha: dark
                                  ? highContrast
                                        ? .40
                                        : .17
                                  : highContrast
                                  ? .96
                                  : .69,
                            ),
                      width: selected ? 2.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: selected
                            ? swatch.withValues(alpha: dark ? .34 : .27)
                            : Colors.black.withValues(alpha: dark ? .15 : .08),
                        blurRadius: selected ? 10 : 7,
                        spreadRadius: -2,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: swatch,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: dark ? .32 : .64),
                        width: .8,
                      ),
                    ),
                    child: selected
                        ? const Icon(
                            CupertinoIcons.check_mark,
                            key: Key('accentSelectedCheck'),
                            size: 20,
                            color: Colors.white,
                          )
                        : null,
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
