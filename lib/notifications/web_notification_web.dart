import 'dart:js_interop';

import 'package:web/web.dart' as web;

final _doseNotifications = <String, web.Notification>{};

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

void showWebNotification({
  required String title,
  required String body,
  Set<String> doseIds = const {},
}) {
  try {
    if (web.Notification.permission != 'granted') return;
    final notification = web.Notification(
      title,
      web.NotificationOptions(
        body: body,
        tag: 'mediary-medication-reminder',
        requireInteraction: false,
      ),
    );
    for (final doseId in doseIds) {
      _doseNotifications[doseId] = notification;
    }
  } catch (_) {
    // The in-app toast remains the fallback when browser notifications are
    // unavailable or the permission was revoked.
  }
}

void cancelWebDoseNotification(String doseId) {
  final notification = _doseNotifications.remove(doseId);
  notification?.close();
}

void reconcileWebDoseNotifications(Set<String> activeIds) {
  for (final id in _doseNotifications.keys.toList()) {
    if (!activeIds.contains(id)) cancelWebDoseNotification(id);
  }
}

Set<String> clearDeliveredWebNotifications() {
  final doseIds = _doseNotifications.keys.toSet();
  for (final notification in _doseNotifications.values.toSet()) {
    notification.close();
  }
  _doseNotifications.clear();
  return doseIds;
}
