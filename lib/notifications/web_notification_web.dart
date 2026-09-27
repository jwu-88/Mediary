import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<void> requestWebNotificationPermission() async {
  if (web.Notification.permission == 'default') {
    try {
      await web.Notification.requestPermission().toDart;
    } catch (_) {
      // Browser permission requests can be rejected outside a user gesture.
    }
  }
}

Future<String> webNotificationPermissionState() async {
  try {
    return web.Notification.permission;
  } catch (_) {
    return 'unavailable';
  }
}

void showWebNotification({required String title, required String body}) {
  if (web.Notification.permission != 'granted') return;
  try {
    web.Notification(
      title,
      web.NotificationOptions(body: body, requireInteraction: true),
    );
  } catch (_) {
    // The in-app toast remains the fallback when browser notifications are
    // unavailable or the permission was revoked.
  }
}
