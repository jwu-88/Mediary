import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/mediary_models.dart';
import '../data/dose_occurrence_identity.dart';
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
  static const _summaryPayloadPrefix = 'mediary:due:';
  static const _scheduledPayloadPrefix = 'mediary:scheduled:';
  static final _summaryId = notificationIdForDose('mediary:due-summary');
  static const _recentDoseWindow = Duration(minutes: 2);
  static bool _timeZonesInitialized = false;

  final FlutterLocalNotificationsPlugin _plugin;
  final Set<String> _notifiedDoseIds = <String>{};
  final Set<String> _scheduledDoseIds = <String>{};
  final Map<String, DateTime> _reminderTimes = <String, DateTime>{};
  final Map<String, String> _scheduledNames = <String, String>{};
  final Set<int> _legacyDeliveredIds = <int>{};
  final Map<String, String> _doseNotificationKeys = <String, String>{};
  final Set<String> _notifiedOccurrenceKeys = <String>{};
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
    _scheduledNames.remove(doseId);
    _notifiedOccurrenceKeys.remove(_doseNotificationKeys.remove(doseId));
    if (kIsWeb) cancelWebDoseNotification(doseId);
    if (_supportsNativeNotifications) {
      await _cancelNativeRequest(notificationIdForDose(doseId));
      // Simultaneous doses share one pending request. Preserve the other
      // reminders even when cancellation happens after a service restart.
      for (final request in await _plugin.pendingNotificationRequests()) {
        final reminder = _ScheduledReminder.fromPayload(request.payload);
        if (reminder == null || !reminder.doseIds.contains(doseId)) continue;
        await _cancelNativeRequest(request.id, payload: request.payload);
        final remaining = reminder.doses
            .where((dose) => dose.doseId != doseId)
            .toList();
        if (remaining.isNotEmpty) {
          if (reminder.scheduledFor.isAfter(DateTime.now())) {
            await _scheduleReminder(_ScheduledReminder(remaining));
          } else {
            // A delayed request may already be due. Let the next snapshot
            // deliver the remaining doses instead of scheduling in the past.
            _scheduledDoseIds.removeAll(remaining.map((dose) => dose.doseId));
          }
        }
      }
      // A foreground alert can represent several doses. Clear it if one of
      // those doses was taken, snoozed, or removed; the UI retains every dose.
      for (final notification in await _activeNativeNotifications()) {
        if (_doseIdsForPayload(_activePayload(notification)).contains(doseId) &&
            notification.id != null) {
          await _cancelDelivered(notification);
        }
      }
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
        final doseIds = _doseIdsForPayload(_activePayload(notification));
        if (doseIds.isEmpty &&
            notification.channelId != 'medication_reminders') {
          continue;
        }
        _notifiedDoseIds.addAll(doseIds);
        if (notification.id != null) {
          if (doseIds.isEmpty) _legacyDeliveredIds.add(notification.id!);
          await _cancelDelivered(notification);
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
    // Resolve legacy duplicates and terminal states exactly as the UI does,
    // before filtering active doses. A taken duplicate must suppress its due
    // counterpart, including HH:mm versus HH:mm:ss records.
    final activeDoses = uniqueDoseOccurrences(doses)
        .where((dose) => dose.status == 'due' || dose.status == 'snoozed')
        .toList(growable: false);
    final uniqueActiveDoses = activeDoses;
    final activeIds = uniqueActiveDoses.map((dose) => dose.id).toSet();
    for (final dose in doses) {
      _doseNotificationKeys[dose.id] = jsonEncode([
        dose.medicationId,
        dose.scheduleId.isEmpty ? dose.id : dose.scheduleId,
        dose.localDate,
        MedicationTime.fromLocalTime(dose.localTime).localTime,
        scheduledTimes[dose.id]!.microsecondsSinceEpoch,
      ]);
    }
    final activeOccurrenceKeys = activeIds
        .map((id) => _doseNotificationKeys[id]!)
        .toSet();
    final previouslyScheduledIds = _scheduledDoseIds.toSet();
    final delivered = _supportsNativeNotifications
        ? await _activeNativeNotifications()
        : const <ActiveNotification>[];
    // OS alerts survive service recreation. Restore receipts before deciding
    // which doses are new, so opening a second session cannot alert again.
    for (final notification in delivered) {
      final ids = _doseIdsForPayload(_activePayload(notification));
      _notifiedDoseIds.addAll(ids);
      for (final id in ids) {
        final key = _doseNotificationKeys[id];
        if (key != null &&
            !(scheduledTimes[id]?.isAfter(currentTime) ?? false)) {
          _notifiedOccurrenceKeys.add(key);
        }
      }
      if (notification.channelId == 'medication_reminders' &&
          notification.id != null) {
        _legacyDeliveredIds.add(notification.id!);
      }
    }
    final changedReminderIds = <String>{};
    final newlyDue = <MedicationDueNotification>[];
    for (final dose in uniqueActiveDoses) {
      final scheduledFor = scheduledTimes[dose.id] ?? dose.scheduledFor;
      if (_legacyDeliveredIds.contains(notificationIdForDose(dose.id)) &&
          !scheduledFor.isAfter(currentTime)) {
        _notifiedDoseIds.add(dose.id);
      }
      if (scheduledFor.isAfter(currentTime)) {
        // A delivered receipt for the original time must not suppress a
        // later snoozed reminder after recreating the service.
        _notifiedDoseIds.remove(dose.id);
      }
      final previousTime = _reminderTimes[dose.id];
      if (previousTime != null && previousTime != scheduledFor) {
        changedReminderIds.add(dose.id);
        _notifiedDoseIds.remove(dose.id);
        if (_supportsNativeNotifications) {
          await _cancelNativeRequest(notificationIdForDose(dose.id));
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
      final occurrenceKey = _doseNotificationKeys[dose.id]!;
      if (isDue &&
          (_notifiedDoseIds.contains(dose.id) ||
              _notifiedOccurrenceKeys.contains(occurrenceKey))) {
        _notifiedDoseIds.add(dose.id);
        _notifiedOccurrenceKeys.add(occurrenceKey);
      }
      final isRecent =
          currentTime.difference(scheduledFor) <= _recentDoseWindow;
      // Suppression must survive subsequent timer ticks, not just the first
      // snapshot. Otherwise yesterday's reminders flood the next refresh.
      if (isDue && !isRecent) {
        _notifiedDoseIds.add(dose.id);
        _notifiedOccurrenceKeys.add(occurrenceKey);
      }
      if (isDue && !_notifiedDoseIds.contains(dose.id) && isRecent) {
        _notifiedDoseIds.add(dose.id);
        _notifiedOccurrenceKeys.add(occurrenceKey);
        newlyDue.add(notification);
      }
    }

    final noLongerActiveNotifiedIds = _notifiedDoseIds.difference(activeIds);
    if (_supportsNativeNotifications) {
      for (final doseId in noLongerActiveNotifiedIds) {
        await _cancelNativeRequest(notificationIdForDose(doseId));
      }
    }
    _notifiedDoseIds.removeWhere((id) => !activeIds.contains(id));
    _reminderTimes.removeWhere((id, _) => !activeIds.contains(id));
    _legacyDeliveredIds.clear();
    _notifiedOccurrenceKeys.removeWhere(
      (key) => !activeOccurrenceKeys.contains(key),
    );
    _doseNotificationKeys.removeWhere(
      (id, key) => !activeOccurrenceKeys.contains(key),
    );
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

    // Clear stale delivered alerts before scheduling replacements, since
    // cancellation also removes pending requests with the same native ID.
    for (final notification in delivered) {
      final doseIds = _doseIdsForPayload(_activePayload(notification));
      if (doseIds.isEmpty) continue;
      if (!activeIds.containsAll(doseIds) ||
          doseIds.any(
            (id) => scheduledTimes[id]?.isAfter(currentTime) ?? false,
          )) {
        await _cancelDelivered(notification);
      }
    }

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
    final byTime = <int, List<MedicationDueNotification>>{};
    for (final dose in allFutureDoses) {
      final time = scheduledTimes[dose.id]!;
      byTime
          .putIfAbsent(time.millisecondsSinceEpoch, () => [])
          .add(
            MedicationDueNotification(
              doseId: dose.id,
              medicationName:
                  medicationNames[dose.medicationId] ?? 'your medication',
              scheduledFor: time,
            ),
          );
    }
    final allReminders = byTime.values.map(_ScheduledReminder.new);
    // A single request represents each reminder instant, including multiple
    // medications. Keep iOS's nearest 64 requests without a burst of alerts.
    final futureReminders =
        (defaultTargetPlatform == TargetPlatform.iOS
                ? allReminders.take(64)
                : allReminders)
            .toList();
    final futureIds = futureReminders
        .expand((reminder) => reminder.doseIds)
        .toSet();
    final futureNotificationIds = futureReminders
        .map((reminder) => reminder.id)
        .toSet();
    for (final doseId in _scheduledDoseIds.difference(futureIds).toList()) {
      _scheduledDoseIds.remove(doseId);
    }

    // Native pending requests survive an app restart. Reconcile those that
    // were created by an older in-memory service instance as well.
    final pending = await _plugin.pendingNotificationRequests();
    final pendingDoseIds = <String>{};
    final pendingNotificationIds = <int>{};
    final pendingPayloads = <int, String?>{};
    for (final request in pending) {
      final doseIds = _doseIdsForPayload(request.payload);
      if (doseIds.isEmpty) continue;
      pendingDoseIds.addAll(doseIds);
      pendingNotificationIds.add(request.id);
      pendingPayloads[request.id] = request.payload;
      if (!futureNotificationIds.contains(request.id)) {
        await _cancelNativeRequest(request.id, payload: request.payload);
      }
    }
    for (final reminder in futureReminders) {
      if (pendingNotificationIds.contains(reminder.id) &&
          pendingPayloads[reminder.id] == reminder.payload &&
          reminder.doses.every(
            (dose) =>
                previouslyScheduledIds.contains(dose.doseId) &&
                !changedReminderIds.contains(dose.doseId) &&
                _scheduledNames[dose.doseId] == dose.medicationName,
          )) {
        continue;
      }
      await _scheduleReminder(reminder);
    }
    _scheduledNames.removeWhere((id, _) => !futureIds.contains(id));

    // If the app was open when the due time passed, show the native reminder
    // immediately. Background delivery is handled by the scheduled request.
    final immediate = <MedicationDueNotification>[];
    for (final notification in newlyDue) {
      // The OS already owns delivery for a reminder scheduled while the app
      // was active. Showing it again here would play a second sound/banner.
      if (previouslyScheduledIds.contains(notification.doseId) &&
          !pendingDoseIds.contains(notification.doseId)) {
        continue;
      }
      immediate.add(notification);
    }
    if (immediate.isNotEmpty) {
      // Use one foreground alert for a burst, replacing the previous alert
      // instead of adding one tray entry and sound per due medication.
      for (final notification in delivered) {
        if (_doseIdsForPayload(_activePayload(notification)).isNotEmpty &&
            notification.id != null) {
          await _cancelDelivered(notification);
        }
      }
      await _showImmediateNotification(
        id: _summaryId,
        title: immediate.first.title,
        body: immediate.length == 1
            ? immediate.first.body
            : '${immediate.length} medication reminders are due. Open Mediary to review them.',
        payload:
            '$_summaryPayloadPrefix${jsonEncode(immediate.map((dose) => dose.doseId).toList())}',
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
      notificationDetails: _notificationDetails(payload),
      payload: payload,
    );
  }

  Future<void> _scheduleReminder(_ScheduledReminder reminder) async {
    final scheduled = tz.TZDateTime.from(reminder.scheduledFor, tz.local);
    try {
      await _plugin.zonedSchedule(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: scheduled,
        notificationDetails: _notificationDetails(reminder.payload),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: reminder.payload,
      );
    } catch (_) {
      // If Android exact-alarm access was declined or revoked, retain a
      // deliverable reminder rather than dropping it altogether. The normal
      // path remains exact and the active-app sync still catches equality.
      await _plugin.zonedSchedule(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: scheduled,
        notificationDetails: _notificationDetails(reminder.payload),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: reminder.payload,
      );
    }
    _scheduledDoseIds.addAll(reminder.doseIds);
    for (final dose in reminder.doses) {
      _scheduledNames[dose.doseId] = dose.medicationName;
    }
  }

  Future<List<ActiveNotification>> _activeNativeNotifications() async {
    try {
      return await _plugin.getActiveNotifications();
    } catch (_) {
      return const <ActiveNotification>[];
    }
  }

  // Android exposes the tag, but not payload, for delivered notifications.
  // Carry the receipt in its tag so cleanup/restart behavior matches iOS.
  String? _activePayload(ActiveNotification notification) =>
      notification.payload ?? notification.tag;

  Future<void> _cancelDelivered(ActiveNotification notification) async {
    if (notification.id == null) return;
    await _plugin.cancel(id: notification.id!, tag: notification.tag);
  }

  Future<void> _cancelNativeRequest(int id, {String? payload}) async {
    await _plugin.cancel(id: id);
    if (defaultTargetPlatform != TargetPlatform.android) return;
    if (payload != null) await _plugin.cancel(id: id, tag: payload);
    // Also clear an earlier delivery if its receipt/tag changed with the
    // medication name, batch membership, or snooze time.
    for (final notification in await _activeNativeNotifications()) {
      if (notification.id == id && notification.tag != null) {
        await _cancelDelivered(notification);
      }
    }
  }

  Set<String> _doseIdsForPayload(String? payload) {
    if (payload == null) return const {};
    if (payload.startsWith(_payloadPrefix)) {
      return {payload.substring(_payloadPrefix.length)};
    }
    if (payload.startsWith(_summaryPayloadPrefix)) {
      try {
        final decoded = jsonDecode(
          payload.substring(_summaryPayloadPrefix.length),
        );
        if (decoded is List) return decoded.whereType<String>().toSet();
      } on FormatException {
        // Ignore alerts created by an unknown or older payload format.
      }
    }
    if (payload.startsWith(_scheduledPayloadPrefix)) {
      return _ScheduledReminder.fromPayload(payload)?.doseIds ?? const {};
    }
    return const {};
  }

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
    _scheduledNames.clear();
    _legacyDeliveredIds.clear();
    _notifiedOccurrenceKeys.clear();
    _doseNotificationKeys.clear();
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

  NotificationDetails _notificationDetails(String payload) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          'medication_reminders',
          'Medication reminders',
          channelDescription: 'Reminders to take scheduled medications.',
          importance: Importance.high,
          priority: Priority.high,
          onlyAlertOnce: true,
          tag: payload,
        ),
        iOS: const DarwinNotificationDetails(
          // Keep reminders visible even when the app is currently in the
          // foreground. The scheduled notification is still delivered by iOS in
          // the background or after the app is closed.
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: true,
          threadIdentifier: 'mediary_medication_reminders',
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
    _scheduledNames.clear();
    _legacyDeliveredIds.clear();
    _notifiedOccurrenceKeys.clear();
    _doseNotificationKeys.clear();
    if (kIsWeb) clearDeliveredWebNotifications();
  });
}

/// One OS request per instant; its payload retains all constituent dose IDs
/// and enough data to cancel one without dropping the other reminders.
class _ScheduledReminder {
  _ScheduledReminder(List<MedicationDueNotification> values)
    : doses = values.toList()..sort((a, b) => a.doseId.compareTo(b.doseId));

  final List<MedicationDueNotification> doses;
  Set<String> get doseIds => doses.map((dose) => dose.doseId).toSet();
  DateTime get scheduledFor => doses.first.scheduledFor;
  String get title => doses.first.title;
  String get body => doses.length == 1
      ? doses.first.body
      : '${doses.length} medication reminders are due. Open Mediary to review them.';
  int get id => DefaultMedicationNotificationService.notificationIdForDose(
    doses.length == 1
        ? doses.first.doseId
        : 'mediary:time:${scheduledFor.millisecondsSinceEpoch}',
  );
  String get payload => doses.length == 1
      ? '${DefaultMedicationNotificationService._payloadPrefix}${doses.first.doseId}'
      : '${DefaultMedicationNotificationService._scheduledPayloadPrefix}${jsonEncode({
          'at': scheduledFor.toUtc().toIso8601String(),
          'doses': [
            for (final dose in doses) {'id': dose.doseId, 'name': dose.medicationName},
          ],
        })}';

  static _ScheduledReminder? fromPayload(String? payload) {
    const prefix = DefaultMedicationNotificationService._scheduledPayloadPrefix;
    if (payload == null || !payload.startsWith(prefix)) return null;
    try {
      final data = jsonDecode(payload.substring(prefix.length));
      if (data is! Map || data['at'] is! String || data['doses'] is! List) {
        return null;
      }
      final time = DateTime.tryParse(data['at'] as String);
      if (time == null) return null;
      final doses = <MedicationDueNotification>[];
      for (final item in data['doses'] as List) {
        if (item is! Map || item['id'] is! String || item['name'] is! String) {
          return null;
        }
        doses.add(
          MedicationDueNotification(
            doseId: item['id'] as String,
            medicationName: item['name'] as String,
            scheduledFor: time,
          ),
        );
      }
      return doses.isEmpty ? null : _ScheduledReminder(doses);
    } on FormatException {
      return null;
    }
  }
}
