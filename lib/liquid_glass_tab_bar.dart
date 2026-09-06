import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_interactions.dart';

class LiquidGlassTabBar extends StatelessWidget {
  const LiquidGlassTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    (
      CupertinoIcons.rectangle_grid_2x2,
      CupertinoIcons.rectangle_grid_2x2_fill,
      'Dashboard',
    ),
    (CupertinoIcons.calendar, CupertinoIcons.calendar, 'Calendar'),
    (CupertinoIcons.camera, CupertinoIcons.camera_fill, 'Scan'),
    (CupertinoIcons.book, CupertinoIcons.book_fill, 'Library'),
    (CupertinoIcons.gear, CupertinoIcons.gear_solid, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final mediaQuery = MediaQuery.maybeOf(context);
    final highContrast = mediaQuery?.highContrast ?? false;
    final reduceMotion = mediaQuery?.disableAnimations ?? false;
    final active = highContrast
        ? Color.lerp(primary, dark ? Colors.white : Colors.black, .22)!
        : primary;
    // Keep the navigation surface opaque. The scanner intentionally uses a
    // black camera canvas, so a translucent base here would let that canvas
    // bleed through and produce a noisy, dithered-looking texture. The
    // selected destination still carries the glass treatment below.
    final surfaceColor = dark
        ? const Color(0xFF1B1D22)
        : const Color(0xFFF3F5F8);
    final inactive = dark
        ? (highContrast ? const Color(0xFFF2F2F7) : const Color(0xFFC7C7CC))
        : Colors.black;
    final selectedIndex = currentIndex < 0
        ? 0
        : currentIndex >= _items.length
        ? _items.length - 1
        : currentIndex;
    final motionDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 320);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 9),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? .26 : .13),
              blurRadius: dark ? 30 : 26,
              spreadRadius: -6,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
            child: Container(
              key: const Key('liquidGlassTabBar'),
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                color: surfaceColor,
                border: Border.all(
                  color: dark
                      ? Colors.white.withValues(alpha: highContrast ? .34 : .18)
                      : Colors.white.withValues(
                          alpha: highContrast ? .98 : .82,
                        ),
                  width: 1,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final tabWidth = constraints.maxWidth / _items.length;
                      final indicatorWidth = (tabWidth - 10)
                          .clamp(58.0, 66.0)
                          .toDouble();
                      final indicatorLeft =
                          (tabWidth * selectedIndex) +
                          (tabWidth - indicatorWidth) / 2;

                      return Stack(
                        children: [
                          AnimatedPositioned(
                            key: const Key('liquidGlassSelectionLens'),
                            left: indicatorLeft,
                            top: 8,
                            width: indicatorWidth,
                            height: 48,
                            duration: motionDuration,
                            curve: Curves.easeOutQuart,
                            child: IgnorePointer(
                              child: _SlidingGlassIndicator(
                                activeColor: active,
                                dark: dark,
                                highContrast: highContrast,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              for (
                                var index = 0;
                                index < _items.length;
                                index++
                              )
                                Expanded(
                                  child: _GlassTabItem(
                                    icon: selectedIndex == index
                                        ? _items[index].$2
                                        : _items[index].$1,
                                    label: _items[index].$3,
                                    semanticPosition:
                                        '${index + 1} of ${_items.length}',
                                    selected: selectedIndex == index,
                                    activeColor: active,
                                    inactiveColor: inactive,
                                    reduceMotion: reduceMotion,
                                    onTap: () => onTap(index),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlidingGlassIndicator extends StatelessWidget {
  const _SlidingGlassIndicator({
    required this.activeColor,
    required this.dark,
    required this.highContrast,
  });

  final Color activeColor;
  final bool dark;
  final bool highContrast;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: activeColor.withValues(alpha: dark ? .17 : .12),
            blurRadius: 18,
            spreadRadius: -6,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: DecoratedBox(
            key: const Key('liquidGlassSelectedGradient'),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? [
                        Colors.white.withValues(
                          alpha: highContrast ? .16 : .08,
                        ),
                        Color.lerp(
                          activeColor,
                          Colors.white,
                          .18,
                        )!.withValues(alpha: highContrast ? .30 : .20),
                        Color.lerp(
                          activeColor,
                          Colors.black,
                          .12,
                        )!.withValues(alpha: highContrast ? .26 : .17),
                      ]
                    : [
                        Color.lerp(
                          activeColor,
                          Colors.white,
                          .72,
                        )!.withValues(alpha: highContrast ? .88 : .66),
                        Color.lerp(
                          activeColor,
                          Colors.white,
                          .25,
                        )!.withValues(alpha: highContrast ? .66 : .48),
                        Color.lerp(
                          activeColor,
                          Colors.black,
                          .08,
                        )!.withValues(alpha: highContrast ? .58 : .38),
                      ],
              ),
              border: Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: .14)
                    : Colors.white.withValues(alpha: highContrast ? .92 : .68),
                width: .8,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-.78, -1),
                      radius: 1.15,
                      colors: [
                        Colors.white.withValues(
                          alpha: dark
                              ? (highContrast ? .22 : .13)
                              : (highContrast ? .62 : .42),
                        ),
                        Colors.transparent,
                      ],
                      stops: const [0, 1],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(.9, .9),
                      radius: 1.1,
                      colors: [
                        activeColor.withValues(alpha: dark ? .13 : .16),
                        Colors.transparent,
                      ],
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

class _GlassTabItem extends StatelessWidget {
  const _GlassTabItem({
    required this.icon,
    required this.label,
    required this.semanticPosition,
    required this.selected,
    required this.activeColor,
    required this.inactiveColor,
    required this.reduceMotion,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String semanticPosition;
  final bool selected;
  final Color activeColor;
  final Color inactiveColor;
  final bool reduceMotion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? activeColor : inactiveColor;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      value: semanticPosition,
      inMutuallyExclusiveGroup: true,
      onTap: onTap,
      child: ExcludeSemantics(
        child: AppPressable(
          onPressed: onTap,
          haptic: AppHapticKind.selection,
          hoverScale: 1.025,
          pressedScale: .94,
          hoverOffset: const Offset(0, -1),
          borderRadius: BorderRadius.circular(24),
          hoverOverlayColor: activeColor.withValues(alpha: .06),
          pressedOverlayColor: activeColor.withValues(alpha: .12),
          child: SizedBox.expand(
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: selected ? 1 : 0),
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                builder: (context, selection, child) => Transform.translate(
                  offset: Offset(0, -selection),
                  child: Transform.scale(
                    scale: .97 + (.03 * selection),
                    child: child,
                  ),
                ),
                child: SizedBox(
                  width: 58,
                  height: 48,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        key: Key('liquidGlassTabIcon-$label'),
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 170),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween(
                              begin: .92,
                              end: 1.0,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: Icon(
                          icon,
                          key: ValueKey(icon),
                          size: selected ? 20.5 : 20,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 3),
                      AnimatedDefaultTextStyle(
                        key: Key('liquidGlassTabLabelStyle-$label'),
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        style: TextStyle(
                          color: color,
                          fontSize: 9.5,
                          height: 1,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          letterSpacing: -.1,
                        ),
                        child: Text(label, key: ValueKey(label), maxLines: 1),
                      ),
                    ],
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
