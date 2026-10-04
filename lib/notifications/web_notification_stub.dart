Future<void> requestWebNotificationPermission() async {}

Future<String> webNotificationPermissionState() async => 'unavailable';

void showWebNotification({
  required String title,
  required String body,
  Set<String> doseIds = const {},
}) {}

void cancelWebDoseNotification(String doseId) {}

void reconcileWebDoseNotifications(Set<String> activeIds) {}

Set<String> clearDeliveredWebNotifications() => {};
