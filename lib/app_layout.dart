import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Returns the content width used by a destination page.
///
/// Native screens keep their deliberately narrow reading width. The web app
/// already has a persistent sidebar, so leaving the same phone-sized cap in
/// place makes the page appear undersized on desktop browsers. On web, let
/// the destination consume the available viewport and use its own internal
/// padding to preserve readable spacing.
double responsiveContentWidth(
  BuildContext context, {
  required double nativeMaxWidth,
}) {
  if (!kIsWeb) return nativeMaxWidth;
  return MediaQuery.sizeOf(context).width;
}
