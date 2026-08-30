import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class LiquidGlassTabBar extends StatelessWidget {
  const LiquidGlassTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    (CupertinoIcons.house, CupertinoIcons.house_fill, 'Today'),
    (CupertinoIcons.calendar, CupertinoIcons.calendar, 'Calendar'),
    (CupertinoIcons.camera, CupertinoIcons.camera_fill, 'Scan'),
    (CupertinoIcons.book, CupertinoIcons.book_fill, 'Library'),
    (CupertinoIcons.person, CupertinoIcons.person_fill, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final active = dark ? const Color(0xFF78B7FF) : const Color(0xFF0A62D0);
    final inactive = dark ? const Color(0xFFB8BBC4) : const Color(0xFF747985);
    final selectedIndex = currentIndex < 0
        ? 0
        : currentIndex >= _items.length
        ? _items.length - 1
        : currentIndex;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 9),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            key: const Key('liquidGlassTabBar'),
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(35),
              border: Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: .17)
                    : Colors.white.withValues(alpha: .82),
                width: 1,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? [
                        const Color(0xFF33343A).withValues(alpha: .84),
                        const Color(0xFF1F2025).withValues(alpha: .72),
                      ]
                    : [
                        Colors.white.withValues(alpha: .88),
                        const Color(0xFFEFF3F8).withValues(alpha: .68),
                      ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? .3 : .14),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: dark ? .05 : .7),
                  blurRadius: 1,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const indicatorWidth = 58.0;
                final tabWidth = constraints.maxWidth / _items.length;
                final indicatorLeft =
                    (tabWidth * selectedIndex) +
                    (tabWidth - indicatorWidth) / 2;

                return Stack(
                  children: [
                    Positioned(
                      left: 22,
                      right: 22,
                      top: 1,
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(1),
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(alpha: dark ? .2 : .9),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    AnimatedPositioned(
                      left: indicatorLeft,
                      top: 8,
                      width: indicatorWidth,
                      height: 56,
                      duration: const Duration(milliseconds: 360),
                      curve: Curves.easeOutCubic,
                      child: IgnorePointer(
                        child: _SlidingGlassIndicator(
                          activeColor: active,
                          dark: dark,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var index = 0; index < _items.length; index++)
                          Expanded(
                            child: _GlassTabItem(
                              icon: selectedIndex == index
                                  ? _items[index].$2
                                  : _items[index].$1,
                              label: _items[index].$3,
                              selected: selectedIndex == index,
                              activeColor: active,
                              inactiveColor: inactive,
                              onTap: () => onTap(index),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SlidingGlassIndicator extends StatelessWidget {
  const _SlidingGlassIndicator({required this.activeColor, required this.dark});

  final Color activeColor;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: Colors.white.withValues(alpha: dark ? .16 : .82),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [
                  Colors.white.withValues(alpha: .15),
                  activeColor.withValues(alpha: .18),
                ]
              : [
                  Colors.white.withValues(alpha: .96),
                  activeColor.withValues(alpha: .14),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: activeColor.withValues(alpha: dark ? .2 : .18),
            blurRadius: 14,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: dark ? .06 : .76),
            blurRadius: 2,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Align(
        alignment: const Alignment(0, -1),
        child: Container(
          width: 32,
          height: 1,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(1),
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: dark ? .32 : .95),
                Colors.transparent,
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
    required this.selected,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? activeColor : inactiveColor;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.expand(
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: selected ? 1 : 0),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              builder: (context, selection, child) => Transform.translate(
                offset: Offset(0, -selection),
                child: Transform.scale(
                  scale: .96 + (.04 * selection),
                  child: Opacity(
                    opacity: .84 + (.16 * selection),
                    child: child,
                  ),
                ),
              ),
              child: SizedBox(
                width: 58,
                height: 56,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(scale: animation, child: child),
                      ),
                      child: Icon(
                        icon,
                        key: ValueKey(icon),
                        size: 20,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 3),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
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
                      child: Text(label, maxLines: 1),
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
