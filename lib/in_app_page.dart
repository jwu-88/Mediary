import 'package:flutter/material.dart';

import 'app_interactions.dart';
import 'app_layout.dart';
import 'liquid_glass_back_button.dart';

/// Opens app-owned content as a full routed page instead of a platform dialog
/// or bottom sheet.
Future<T?> pushInAppPage<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      opaque: true,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 230),
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, .035),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

/// Shared page shell for former popup content.
class InAppPageScaffold extends StatelessWidget {
  const InAppPageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.maxContentWidth = 680,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 24),
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final double maxContentWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 68,
        leadingWidth: 68,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: LiquidGlassBackButton(
              semanticLabel: 'Back from $title',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
        titleSpacing: 4,
        centerTitle: false,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -.35,
          ),
        ),
        actions: actions,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: responsiveContentWidth(
                context,
                nativeMaxWidth: maxContentWidth,
              ),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

@immutable
class InAppPageOption<T> {
  const InAppPageOption({
    required this.label,
    required this.value,
    this.detail,
    this.icon,
    this.destructive = false,
    this.selected = false,
  });

  final String label;
  final T value;
  final String? detail;
  final IconData? icon;
  final bool destructive;
  final bool selected;
}

/// A responsive, app-owned replacement for short action sheets and option
/// dialogs. Selecting a row returns its value to the previous page.
class InAppOptionPage<T> extends StatelessWidget {
  const InAppOptionPage({
    super.key,
    required this.title,
    required this.options,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<InAppPageOption<T>> options;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InAppPageScaffold(
      title: title,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (subtitle != null) ...[
            Text(
              subtitle!,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
          ],
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: .55),
                width: .7,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  for (var index = 0; index < options.length; index++) ...[
                    _InAppOptionRow<T>(option: options[index]),
                    if (index < options.length - 1)
                      Divider(
                        height: 1,
                        thickness: .5,
                        indent: options[index].icon == null ? 16 : 56,
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InAppOptionRow<T> extends StatelessWidget {
  const _InAppOptionRow({required this.option});

  final InAppPageOption<T> option;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = option.destructive ? colors.error : colors.onSurface;
    return AppPressable(
      key: ValueKey('inAppOption-${option.label}'),
      onPressed: () => Navigator.of(context).pop(option.value),
      semanticLabel: option.label,
      haptic: option.destructive
          ? AppHapticKind.primaryAction
          : AppHapticKind.selection,
      borderRadius: BorderRadius.zero,
      hoverScale: 1,
      pressedScale: .99,
      hoverOffset: Offset.zero,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 58),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              if (option.icon != null) ...[
                Icon(option.icon, color: foreground, size: 21),
                const SizedBox(width: 18),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      option.label,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (option.detail != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        option.detail!,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (option.selected)
                Icon(Icons.check_rounded, color: colors.primary, size: 21)
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                  size: 21,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
