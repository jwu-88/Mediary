import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

abstract final class AppBreakpoints {
  static const mobile = 600.0;
  static const desktop = 900.0;
  static const webMaxContentWidth = 1120.0;
  static const webPageGutter = 48.0;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobile;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;
}

/// Returns the content width used by a destination page.
///
/// Native screens keep their deliberately narrow reading width. Desktop web
/// screens use a shared landscape cap so pages can make use of the browser's
/// horizontal space without becoming difficult to scan.
double responsiveContentWidth(
  BuildContext context, {
  required double nativeMaxWidth,
  double? webMaxWidth,
}) {
  if (!kIsWeb) return nativeMaxWidth;
  final viewportWidth = MediaQuery.sizeOf(context).width;
  if (viewportWidth < AppBreakpoints.desktop) return viewportWidth;
  final preferredWidth = webMaxWidth ?? AppBreakpoints.webMaxContentWidth;
  final availableWidth = viewportWidth > AppBreakpoints.webPageGutter
      ? viewportWidth - AppBreakpoints.webPageGutter
      : viewportWidth;
  return availableWidth < preferredWidth ? availableWidth : preferredWidth;
}
