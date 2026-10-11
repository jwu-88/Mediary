import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// requests camera access on platforms where the browser camera api is not
/// available. native permission handling remains owned by permission_handler.
Future<bool> requestWebCameraAccess() async => false;

/// browser frames are unavailable on native platforms.
Future<Uint8List?> captureWebCameraFrame({bool freezePreview = false}) async =>
    null;

Future<bool> waitForWebCameraFrame({
  Duration timeout = const Duration(seconds: 3),
}) async => false;

/// releases any browser camera stream. this is a no-op on native platforms.
void stopWebCamera() {}

/// placeholder used by native builds; native camera rendering is provided by
/// the platform camera integration when it is enabled.
class WebCameraPreview extends StatelessWidget {
  const WebCameraPreview({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
