import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_interactions.dart';

/// A capsule search field that uses the same glass treatment as the native
/// bottom navigator. Web keeps the capsule shape but uses a solid surface.
class LiquidGlassSearchField extends StatefulWidget {
  const LiquidGlassSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.trailing,
    this.textFieldKey,
    this.surfaceKey = const Key('liquidGlassSearchSurface'),
    this.showClearButton = true,
    this.autofocus = false,
    this.useLiquidGlass,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;
  final Key? textFieldKey;
  final Key surfaceKey;
  final bool showClearButton;
  final bool autofocus;

  /// Defaults to native glass and a solid web surface.
  final bool? useLiquidGlass;

  @override
  State<LiquidGlassSearchField> createState() => _LiquidGlassSearchFieldState();
}

class _LiquidGlassSearchFieldState extends State<LiquidGlassSearchField> {
  final FocusNode _focusNode = FocusNode();

  bool get _focused => _focusNode.hasFocus;
  bool get _showClear =>
      widget.showClearButton && widget.controller.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_refresh);
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant LiquidGlassSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_refresh)
      ..dispose();
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _clear() {
    widget.controller.clear();
    widget.onChanged?.call('');
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    final useGlass = widget.useLiquidGlass ?? !kIsWeb;
    const radius = BorderRadius.all(Radius.circular(32));

    final surface = Container(
      key: widget.surfaceKey,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: radius,
        // A restrained solid tint keeps the field glassy without the
        // decorative shading that made it feel overly synthetic.
        color: useGlass
            ? (dark
                  ? const Color(0xFF2C2C2E).withValues(alpha: .90)
                  : const Color(0xFFF2F3F6).withValues(alpha: .90))
            : colors.surfaceContainerHighest,
        border: Border.all(
          color: _focused
              ? colors.primary.withValues(alpha: highContrast ? .9 : .56)
              : useGlass
              ? (dark
                    ? Colors.white.withValues(alpha: highContrast ? .34 : .18)
                    : Colors.white.withValues(alpha: highContrast ? .98 : .82))
              : colors.outlineVariant.withValues(alpha: .72),
          width: _focused ? 1.25 : 1,
        ),
      ),
      child: TextField(
        key: widget.textFieldKey,
        controller: widget.controller,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.search,
        cursorColor: colors.primary,
        style: TextStyle(color: colors.onSurface, fontSize: 16),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(color: colors.onSurfaceVariant, fontSize: 15),
          prefixIcon: Icon(
            CupertinoIcons.search,
            color: colors.onSurfaceVariant,
            size: 20,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 52,
            minHeight: 52,
          ),
          suffixIcon: _buildActions(colors),
          suffixIconConstraints: const BoxConstraints(minHeight: 52),
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          isDense: true,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: useGlass
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? .22 : .10),
                  blurRadius: 22,
                  spreadRadius: -8,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: useGlass
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
                child: surface,
              )
            : surface,
      ),
    );
  }

  Widget? _buildActions(ColorScheme colors) {
    if (!_showClear && widget.trailing == null) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showClear)
          Semantics(
            button: true,
            label: 'Clear search',
            child: ResponsiveCupertinoButton(
              buttonKey: const Key('liquidGlassSearchClearButton'),
              minimumSize: const Size(40, 52),
              padding: EdgeInsets.zero,
              onPressed: _clear,
              semanticLabel: 'Clear search',
              child: Icon(
                CupertinoIcons.xmark_circle_fill,
                color: colors.onSurfaceVariant.withValues(alpha: .72),
                size: 18,
              ),
            ),
          ),
        ?widget.trailing,
        const SizedBox(width: 4),
      ],
    );
  }
}
