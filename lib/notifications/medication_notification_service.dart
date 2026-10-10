import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/mediary_models.dart';
import '../text_formatting.dart';
import '../time_formatting.dart';
import 'web_notification_stub.dart'
    if (dart.library.html) 'web_notification_web.dart';

/// A due dose that can be presented by a native notification or the web UI.
class MedicationDueNotification {
  const MedicationDueNotification({
    required this.doseId,
    required this.medicationName,
    required this.scheduledFor,
  });

  final String doseId;
  final String medicationName;
  final DateTime scheduledFor;

  String get title => 'Medication reminder';

  String get body => 'Time to take ${titleCaseDisplay(medicationName)}';
}

/// Platform-independent notification contract used by the authenticated shell.
///
/// The web implementation is intentionally an in-app notification. Browsers
/// require a user gesture before requesting notification permission and do not
/// reliably support background scheduled notifications, so the web shell shows
/// a short-lived toast instead.
abstract interface class MedicationNotificationService {
  Future<void> initialize();

  Future<void> requestPermission();

  /// Returns a user-facing permission state such as granted, denied, or
  /// unavailable. Web reads this without requesting permission.
  Future<String> permissionState();

  /// Cancels one dose reminder without requiring a full data synchronization.
  Future<void> cancelDose(String doseId);

  /// Clears delivered alerts when the app opens, without cancelling future
  /// reminders or changing whether a dose has been taken.
  Future<void> clearDeliveredNotifications();

  /// Synchronizes notifications for the current dose-log snapshot.
  ///
  /// On web, the returned records are newly due doses that the UI should show.
  /// On mobile, they are also surfaced when a dose became due while the app was
  /// active; future doses are scheduled natively and normally return no record.
  Future<List<MedicationDueNotification>> syncDueDoses({
    required List<DoseLogRecord> doses,
    required Map<String, String> medicationNames,
    Map<String, String> scheduleTimezones = const <String, String>{},
    DateTime? now,
  });

  Future<void> dispose();
}

/// Uses flutter_local_notifications on Android/iOS and an in-app event stream
/// on web. The service only schedules user-owned dose logs; no public catalog or
/// health data is sent anywhere.
class DefaultMedicationNotificationService
    implements MedicationNotificationService {
  DefaultMedicationNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _payloadPrefix = 'mediary:dose:';
  static const _recentDoseWindow = Duration(minutes: 2);
  static bool _timeZonesInitialized = false;

  final FlutterLocalNotificationsPlugin _plugin;
  final Set<String> _notifiedDoseIds = <String>{};
  final Set<String> _scheduledDoseIds = <String>{};
  final Map<String, DateTime> _reminderTimes = <String, DateTime>{};
  Future<void> _operationQueue = Future<void>.value();
  bool _initialized = false;
  bool _nativeAvailable = true;
  bool _disposed = false;

  bool get _supportsNativeNotifications =>
      _nativeAvailable &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    if (!_timeZonesInitialized) {
      tz_data.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation(deviceScheduleTimezone()));
      } catch (_) {
        // Keep the package's default location if the platform zone cannot be
        // mapped to an IANA name.
      }
      _timeZonesInitialized = true;
    }

    if (!_supportsNativeNotifications) {
      _initialized = true;
      return;
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    try {
      final result = await _plugin.initialize(
        settings: const InitializationSettings(android: android, iOS: darwin),
      );
      _nativeAvailable = result != null;
    } catch (_) {
      // Flutter widget tests and desktop hosts do not register a native
      // notifications platform implementation. Keep the web/in-app portion
      // testable and allow the app shell to continue without reminders.
      _nativeAvailable = false;
    }
    _initialized = true;
  }

  @override
  Future<void> requestPermission() async {
    await initialize();
    if (_disposed) return;

    if (kIsWeb) {
      await requestWebNotificationPermission();
      return;
    }
    if (!_supportsNativeNotifications) return;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();
      // Android 12+ can defer inexact alarms by several minutes. Medication
      // reminders need the exact alarm permission so the alert is delivered at
      // the time selected by the user, including while the device is idle.
      await android?.requestExactAlarmsPermission();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  @override
  Future<String> permissionState() async {
    await initialize();
    if (kIsWeb) return webNotificationPermissionState();
    if (!_supportsNativeNotifications) return 'unavailable';
    try {
      final bool? enabled;
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        enabled =
            (await _plugin
                    .resolvePlatformSpecificImplementation<
                      IOSFlutterLocalNotificationsPlugin
                    >()
                    ?.checkPermissions())
                ?.isEnabled;
      } else {
        enabled = await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.areNotificationsEnabled();
      }
      if (enabled == null) return 'unavailable';
      return enabled ? 'granted' : 'denied';
    } catch (_) {
      return 'unavailable';
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _operationQueue.then((_) => action());
    _operationQueue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  @override
  Future<void> cancelDose(String doseId) => _enqueue(() async {
    await initialize();
    _notifiedDoseIds.remove(doseId);
    _scheduledDoseIds.remove(doseId);
    _reminderTimes.remove(doseId);
    if (kIsWeb) cancelWebDoseNotification(doseId);
    if (_supportsNativeNotifications) {
      await _plugin.cancel(id: notificationIdForDose(doseId));
    }
  });

  @override
  Future<void> clearDeliveredNotifications() => _enqueue(() async {
    await initialize();
    if (kIsWeb) {
      _notifiedDoseIds.addAll(clearDeliveredWebNotifications());
    }
    if (!_supportsNativeNotifications) return;
    try {
      for (final notification in await _plugin.getActiveNotifications()) {
        final payload = notification.payload;
        if (payload == null || !payload.startsWith(_payloadPrefix)) continue;
        final doseId = payload.substring(_payloadPrefix.length);
        _notifiedDoseIds.add(doseId);
        if (notification.id != null) {
          await _plugin.cancel(id: notification.id!);
        }
      }
    } catch (_) {
      // Some desktop hosts do not expose an OS notification tray.
    }
  });

  @override
  Future<List<MedicationDueNotification>> syncDueDoses({
    required List<DoseLogRecord> doses,
    required Map<String, String> medicationNames,
    Map<String, String> scheduleTimezones = const <String, String>{},
    DateTime? now,
  }) => _enqueue(
    () => _syncDueDoses(
      doses: doses,
      medicationNames: medicationNames,
      scheduleTimezones: scheduleTimezones,
      now: now,
    ),
  );

  Future<List<MedicationDueNotification>> _syncDueDoses({
    required List<DoseLogRecord> doses,
    required Map<String, String> medicationNames,
    required Map<String, String> scheduleTimezones,
    DateTime? now,
  }) async {
    await initialize();
    if (_disposed) return const <MedicationDueNotification>[];

    final currentTime = now ?? DateTime.now();
    final scheduledTimes = <String, DateTime>{
      for (final dose in doses)
        dose.id:
            dose.snoozedUntil ??
            _scheduledDateFor(dose, scheduleTimezones[dose.scheduleId]),
    };
    final activeDoses = doses
        .where((dose) => dose.status == 'due' || dose.status == 'snoozed')
        .toList(growable: false);
    final uniqueActiveDoses = _deduplicateActiveDoses(activeDoses);
    final activeIds = uniqueActiveDoses.map((dose) => dose.id).toSet();
    final previouslyScheduledIds = _scheduledDoseIds.toSet();
    final newlyDue = <MedicationDueNotification>[];
    for (final dose in uniqueActiveDoses) {
      final scheduledFor = scheduledTimes[dose.id] ?? dose.scheduledFor;
      final previousTime = _reminderTimes[dose.id];
      if (previousTime != null && previousTime != scheduledFor) {
        _notifiedDoseIds.remove(dose.id);
        if (_supportsNativeNotifications) {
          await _plugin.cancel(id: notificationIdForDose(dose.id));
        }
        if (kIsWeb) cancelWebDoseNotification(dose.id);
      }
      _reminderTimes[dose.id] = scheduledFor;
      final notification = MedicationDueNotification(
        doseId: dose.id,
        medicationName: medicationNames[dose.medicationId] ?? 'your medication',
        scheduledFor: scheduledFor,
      );
      final isDue = !scheduledFor.isAfter(currentTime);
      final isRecent =
          currentTime.difference(scheduledFor) <= _recentDoseWindow;
      // Suppression must survive subsequent timer ticks, not just the first
      // snapshot. Otherwise yesterday's reminders flood the next refresh.
      if (isDue && !isRecent) {
        _notifiedDoseIds.add(dose.id);
      }
      if (isDue && !_notifiedDoseIds.contains(dose.id) && isRecent) {
        _notifiedDoseIds.add(dose.id);
        newlyDue.add(notification);
      }
    }

    final noLongerActiveNotifiedIds = _notifiedDoseIds.difference(activeIds);
    if (_supportsNativeNotifications) {
      for (final doseId in noLongerActiveNotifiedIds) {
        await _plugin.cancel(id: notificationIdForDose(doseId));
      }
    }
    _notifiedDoseIds.removeWhere((id) => !activeIds.contains(id));
    _reminderTimes.removeWhere((id, _) => !activeIds.contains(id));
    if (kIsWeb) reconcileWebDoseNotifications(activeIds);

    if (!_supportsNativeNotifications) {
      if (kIsWeb) {
        // Keep browser-level alerts singular per sync pass. The shell still
        // receives the full due list for its deduplicated in-app toast stack,
        // but a burst of simultaneous records must not become a browser alert
        // flood.
        if (newlyDue.isNotEmpty) {
          final notification = newlyDue.first;
          final body = newlyDue.length == 1
              ? notification.body
              : '${newlyDue.length} medication reminders are due. Open '
                    'Mediary to review them.';
          showWebNotification(
            title: notification.title,
            body: body,
            doseIds: newlyDue.map((dose) => dose.doseId).toSet(),
          );
        }
      }
      return newlyDue;
    }

    if (doses.isEmpty) {
      // An empty snapshot is also how sign-out, notification opt-out, and a
      // deleted schedule are represented. Clear alerts that were already
      // delivered as well as requests still waiting in the OS queue.
      await _clearNativeNotifications();
      return newlyDue;
    }

    if (await permissionState() != 'granted') return newlyDue;

    final allFutureDoses = uniqueActiveDoses
        .where(
          (dose) => (scheduledTimes[dose.id] ?? dose.scheduledFor).isAfter(
            currentTime,
          ),
        )
        .toList(growable: false);
    allFutureDoses.sort(
      (first, second) =>
          scheduledTimes[first.id]!.compareTo(scheduledTimes[second.id]!),
    );
    // iOS retains only 64 pending requests. Keep the nearest reminders so a
    // large regimen cannot replace today's alerts with distant future doses.
    final futureDoses = defaultTargetPlatform == TargetPlatform.iOS
        ? allFutureDoses.take(64).toList(growable: false)
        : allFutureDoses;
    final futureIds = futureDoses.map((dose) => dose.id).toSet();
    for (final doseId in _scheduledDoseIds.difference(futureIds).toList()) {
      if (!activeIds.contains(doseId) ||
          scheduledTimes[doseId]!.isAfter(currentTime)) {
        await _plugin.cancel(id: notificationIdForDose(doseId));
      }
      _scheduledDoseIds.remove(doseId);
    }

    for (final dose in futureDoses) {
      await _schedule(
        dose,
        medicationNames[dose.medicationId],
        scheduledDate: scheduledTimes[dose.id] ?? dose.scheduledFor,
      );
    }
    for (final doseId in _scheduledDoseIds.difference(futureIds).toList()) {
      if (!activeIds.contains(doseId)) {
        await _plugin.cancel(id: notificationIdForDose(doseId));
      }
      _scheduledDoseIds.remove(doseId);
    }
    // Native pending requests survive an app restart. Reconcile those that
    // were created by an older in-memory service instance as well.
    final pending = await _plugin.pendingNotificationRequests();
    final pendingDoseIds = <String>{};
    for (final request in pending) {
      final payload = request.payload;
      if (payload == null || !payload.startsWith(_payloadPrefix)) continue;
      final doseId = payload.substring(_payloadPrefix.length);
      pendingDoseIds.add(doseId);
      if (!futureIds.contains(doseId)) {
        await _plugin.cancel(id: request.id);
      }
    }

    // Delivered notifications no longer appear in the pending request list.
    // Remove stale medication alerts from the OS tray as well, including
    // alerts left behind by a medication deleted while the app was closed.
    try {
      final activeNotifications = await _plugin.getActiveNotifications();
      for (final notification in activeNotifications) {
        final payload = notification.payload;
        if (payload == null || !payload.startsWith(_payloadPrefix)) continue;
        final doseId = payload.substring(_payloadPrefix.length);
        final notificationId = notification.id;
        if (notificationId != null && !activeIds.contains(doseId)) {
          await _plugin.cancel(id: notificationId);
        }
      }
    } catch (_) {
      // Active notification lookup is not available on every host version.
    }

    // If the app was open when the due time passed, show the native reminder
    // immediately. Background delivery is handled by the scheduled request.
    for (final notification in newlyDue) {
      // The OS already owns delivery for a reminder scheduled while the app
      // was active. Showing it again here would play a second sound/banner.
      if (previouslyScheduledIds.contains(notification.doseId) &&
          !pendingDoseIds.contains(notification.doseId)) {
        continue;
      }
      await _showImmediateNotification(
        id: notificationIdForDose(notification.doseId),
        title: notification.title,
        body: notification.body,
        payload: '$_payloadPrefix${notification.doseId}',
      );
    }
    return newlyDue;
  }

  Future<void> _showImmediateNotification({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) {
    return _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _notificationDetails,
      payload: payload,
    );
  }

  Future<void> _schedule(
    DoseLogRecord dose,
    String? medicationName, {
    required DateTime scheduledDate,
  }) async {
    final notificationId = notificationIdForDose(dose.id);
    final title = 'Medication reminder';
    final body =
        'Time to take ${titleCaseDisplay(medicationName ?? 'your medication')}';
    final scheduled = tz.TZDateTime.from(scheduledDate, tz.local);
    try {
      await _plugin.zonedSchedule(
        id: notificationId,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: '$_payloadPrefix${dose.id}',
      );
    } catch (_) {
      // If Android exact-alarm access was declined or revoked, retain a
      // deliverable reminder rather than dropping it altogether. The normal
      // path remains exact and the active-app sync still catches equality.
      await _plugin.zonedSchedule(
        id: notificationId,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: '$_payloadPrefix${dose.id}',
      );
    }
    _scheduledDoseIds.add(dose.id);
  }

  List<DoseLogRecord> _deduplicateActiveDoses(Iterable<DoseLogRecord> doses) {
    final byOccurrence = <String, DoseLogRecord>{};
    for (final dose in doses) {
      final key = _occurrenceKey(dose);
      final existing = byOccurrence[key];
      // Prefer the lexically smallest id so a Firestore snapshot reordering
      // cannot make the notification identity change between syncs.
      if (existing == null || dose.id.compareTo(existing.id) < 0) {
        byOccurrence[key] = dose;
      }
    }
    return byOccurrence.values.toList(growable: false);
  }

  String _occurrenceKey(DoseLogRecord dose) =>
      '${dose.scheduleId}|${dose.localDate}|${dose.localTime}';

  Future<void> _clearNativeNotifications() async {
    try {
      // This service is the sole owner of this app's local notifications, so
      // cancelAll also removes medication alerts that were already displayed
      // and are therefore absent from pendingNotificationRequests().
      await _plugin.cancelAll();
    } catch (_) {
      // Cleanup must not prevent the authenticated shell from continuing.
    }
    _notifiedDoseIds.clear();
    _scheduledDoseIds.clear();
  }

  DateTime _scheduledDateFor(DoseLogRecord dose, String? timezone) {
    final normalizedTimezone = timezone?.trim();
    if (normalizedTimezone == null || normalizedTimezone.isEmpty) {
      // Older dose logs do not carry a timezone on the dose document. Their
      // Firestore timestamp is already the source of truth, so preserve it.
      return dose.scheduledFor;
    }
    final location = _locationFor(timezone);
    final dateParts = dose.localDate.split('-').map(int.tryParse).toList();
    final timeParts = dose.localTime.split(':').map(int.tryParse).toList();
    if (dateParts.length == 3 &&
        dateParts.every((part) => part != null) &&
        timeParts.length >= 2 &&
        timeParts.take(2).every((part) => part != null)) {
      final metadataDate = tz.TZDateTime(
        location,
        dateParts[0]!,
        dateParts[1]!,
        dateParts[2]!,
        timeParts[0]!,
        timeParts[1]!,
        timeParts.length > 2 && timeParts[2] != null ? timeParts[2]! : 0,
      );
      if (normalizedTimezone == 'UTC') {
        // Before schedules stored the device's IANA timezone, the app
        // defaulted to UTC while scheduledFor was still written from the
        // device clock. Recognize only that legacy shape; an explicitly
        // selected UTC schedule continues to use its metadata as the source
        // of truth.
        final deviceLocation = _locationFor(deviceScheduleTimezone());
        final deviceTime = tz.TZDateTime.from(
          dose.scheduledFor,
          deviceLocation,
        );
        final matchesLegacyLocalTime =
            deviceTime.year == dateParts[0] &&
            deviceTime.month == dateParts[1] &&
            deviceTime.day == dateParts[2] &&
            deviceTime.hour == timeParts[0] &&
            deviceTime.minute == timeParts[1] &&
            deviceTime.second ==
                (timeParts.length > 2 && timeParts[2] != null
                    ? timeParts[2]
                    : 0);
        if (matchesLegacyLocalTime) return dose.scheduledFor;
      }
      return metadataDate;
    }
    return tz.TZDateTime.from(dose.scheduledFor, location);
  }

  tz.Location _locationFor(String? timezone) {
    final normalized = timezone?.trim();
    if (normalized == null || normalized.isEmpty) return tz.local;
    try {
      return tz.getLocation(normalized);
    } catch (_) {
      return tz.local;
    }
  }

  NotificationDetails get _notificationDetails => const NotificationDetails(
    android: AndroidNotificationDetails(
      'medication_reminders',
      'Medication reminders',
      channelDescription: 'Reminders to take scheduled medications.',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(
      // Keep reminders visible even when the app is currently in the
      // foreground. The scheduled notification is still delivered by iOS in
      // the background or after the app is closed.
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
    ),
  );

  /// Stable positive ID so a Firestore dose update replaces its old request.
  static int notificationIdForDose(String doseId) {
    var hash = 0x811c9dc5;
    for (final codeUnit in doseId.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  @override
  Future<void> dispose() => _enqueue(() async {
    if (_disposed) return;
    if (_supportsNativeNotifications && _initialized) {
      await _clearNativeNotifications();
    }
    _disposed = true;
    _notifiedDoseIds.clear();
    _scheduledDoseIds.clear();
    _reminderTimes.clear();
    if (kIsWeb) clearDeliveredWebNotifications();
  });
}
