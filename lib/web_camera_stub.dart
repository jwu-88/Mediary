import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// Requests camera access on platforms where the browser camera API is not
/// available. Native permission handling remains owned by permission_handler.
Future<bool> requestWebCameraAccess() async => false;

/// Browser frames are unavailable on native platforms.
Future<Uint8List?> captureWebCameraFrame() async => null;

/// Releases any browser camera stream. This is a no-op on native platforms.
void stopWebCamera() {}

/// Placeholder used by native builds; native camera rendering is provided by
/// the platform camera integration when it is enabled.
class WebCameraPreview extends StatelessWidget {
  const WebCameraPreview({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
