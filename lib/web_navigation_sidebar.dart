import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_interactions.dart';

/// An opaque, desktop-style navigation rail for the web app.
///
/// The rail stays compact until the pointer enters it, then smoothly expands to
/// reveal destination labels. It intentionally avoids blur and transparency so
/// the web experience remains crisp and distinct from the iOS glass tab bar.
class WebNavigationSidebar extends StatefulWidget {
  const WebNavigationSidebar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.overlayHoverArea = false,
  });

  static const collapsedWidth = 76.0;
  static const expandedWidth = 224.0;

  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Keeps a full-width invisible hover target while the visual rail is
  /// collapsed. The desktop shell uses this so the pointer can travel from
  /// the icon rail to an expanded label without collapsing the rail.
  final bool overlayHoverArea;

  @override
  State<WebNavigationSidebar> createState() => _WebNavigationSidebarState();
}

class _WebNavigationSidebarState extends State<WebNavigationSidebar> {
  static const _collapsedWidth = WebNavigationSidebar.collapsedWidth;
  static const _expandedWidth = WebNavigationSidebar.expandedWidth;
  static const _animationDuration = Duration(milliseconds: 280);

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

  bool _expanded = false;

  void _setExpanded(bool expanded) {
    if (_expanded == expanded) {
      return;
    }
    setState(() => _expanded = expanded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final background = dark ? const Color(0xFF1A1B20) : const Color(0xFFF9FAFC);
    final divider = dark ? const Color(0xFF303238) : const Color(0xFFE1E4EA);
    final active = theme.colorScheme.primary;
    final inactive = dark ? const Color(0xFFB8BBC4) : const Color(0xFF5E6470);

    final sidebarVisual = AnimatedContainer(
      key: const Key('webNavigationSidebar'),
      width: _expanded ? _expandedWidth : _collapsedWidth,
      duration: _animationDuration,
      curve: Curves.easeOutCubic,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: background,
        border: Border(right: BorderSide(color: divider)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: _expandedWidth,
          maxWidth: _expandedWidth,
          minHeight: constraints.maxHeight,
          maxHeight: constraints.maxHeight,
          child: SafeArea(
            right: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 18),
                _BrandHeader(expanded: _expanded, activeColor: active),
                const SizedBox(height: 22),
                for (var index = 0; index < _items.length; index++) ...[
                  _WebNavigationItem(
                    key: Key('webNavItem-$index'),
                    icon: widget.currentIndex == index
                        ? _items[index].$2
                        : _items[index].$1,
                    label: _items[index].$3,
                    expanded: _expanded,
                    selected: widget.currentIndex == index,
                    activeColor: active,
                    inactiveColor: inactive,
                    dark: dark,
                    onTap: () => widget.onTap(index),
                  ),
                  const SizedBox(height: 6),
                ],
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );

    final hoverRegion = MouseRegion(
      key: const Key('webNavigationSidebarHoverRegion'),
      onEnter: (_) => _setExpanded(true),
      onExit: (_) => _setExpanded(false),
      child: widget.overlayHoverArea
          ? SizedBox(
              width: _expandedWidth,
              child: Align(child: sidebarVisual),
            )
          : sidebarVisual,
    );

    return hoverRegion;
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.expanded, required this.activeColor});

  final bool expanded;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      width: 224,
      child: Row(
        children: [
          const SizedBox(width: 16),
          SizedBox(
            width: 44,
            child: Icon(
              CupertinoIcons.heart_fill,
              color: activeColor,
              size: 25,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AnimatedOpacity(
              key: const Key('webNavigationSidebarBrandLabel'),
              opacity: expanded ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: const Text(
                'Mediary',
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

class _WebNavigationItem extends StatefulWidget {
  const _WebNavigationItem({
    super.key,
    required this.icon,
    required this.label,
    required this.expanded,
    required this.selected,
    required this.activeColor,
    required this.inactiveColor,
    required this.dark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool expanded;
  final bool selected;
  final Color activeColor;
  final Color inactiveColor;
  final bool dark;
  final VoidCallback onTap;

  @override
  State<_WebNavigationItem> createState() => _WebNavigationItemState();
}

class _WebNavigationItemState extends State<_WebNavigationItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selectedBackground = widget.dark
        ? widget.activeColor.withValues(alpha: .18)
        : widget.activeColor.withValues(alpha: .11);
    final hoverBackground = widget.dark
        ? Colors.white.withValues(alpha: .07)
        : const Color(0xFFECEFF4);
    final color = widget.selected ? widget.activeColor : widget.inactiveColor;

    final item = Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: MouseRegion(
        key: Key('webNavItemHover-${widget.label.toLowerCase()}'),
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AppPressable(
          onPressed: widget.onTap,
          enableHaptics: false,
          hoverScale: 1.012,
          pressedScale: .975,
          hoverOffset: Offset.zero,
          borderRadius: BorderRadius.circular(12),
          hoverOverlayColor: Colors.transparent,
          pressedOverlayColor: widget.activeColor.withValues(alpha: .13),
          child: AnimatedContainer(
            height: 52,
            width: 204,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: widget.selected
                  ? selectedBackground
                  : _hovered
                  ? hoverBackground
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: AnimatedScale(
                    scale: _hovered ? 1.06 : 1,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(widget.icon, color: color, size: 23),
                  ),
                ),
                Expanded(
                  child: AnimatedOpacity(
                    key: Key('webNavItemLabel-${widget.label.toLowerCase()}'),
                    opacity: widget.expanded ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: widget.selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (widget.selected)
                  Container(
                    key: Key(
                      'webNavItemSelected-${widget.label.toLowerCase()}',
                    ),
                    width: 3,
                    height: 22,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: widget.activeColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )
                else
                  const SizedBox(width: 15),
              ],
            ),
          ),
        ),
      ),
    );

    return Tooltip(
      message: widget.expanded ? '' : widget.label,
      waitDuration: const Duration(milliseconds: 450),
      child: item,
    );
  }
}
