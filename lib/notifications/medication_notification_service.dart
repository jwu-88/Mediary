import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/mediary_models.dart';

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

  String get body => 'Time to take $medicationName';
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
  bool _initialized = false;
  bool _nativeAvailable = true;
  bool _disposed = false;
  bool? _isFirstSync;

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
      await _plugin.initialize(
        settings: const InitializationSettings(android: android, iOS: darwin),
      );
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
    if (!_supportsNativeNotifications || _disposed) return;

    if (defaultTargetPlatform == TargetPlatform.android) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  @override
  Future<List<MedicationDueNotification>> syncDueDoses({
    required List<DoseLogRecord> doses,
    required Map<String, String> medicationNames,
    Map<String, String> scheduleTimezones = const <String, String>{},
    DateTime? now,
  }) async {
    await initialize();
    if (_disposed) return const <MedicationDueNotification>[];

    final currentTime = now ?? DateTime.now();
    final scheduledTimes = <String, DateTime>{
      for (final dose in doses)
        dose.id: _scheduledDateFor(dose, scheduleTimezones[dose.scheduleId]),
    };
    final activeDoses = doses
        .where((dose) => dose.status == 'due')
        .where(
          (dose) =>
              dose.snoozedUntil == null ||
              !dose.snoozedUntil!.isAfter(currentTime),
        )
        .toList(growable: false);
    final activeIds = activeDoses.map((dose) => dose.id).toSet();
    final isInitialSync = _isFirstSync ??= true;
    _isFirstSync = false;

    final newlyDue = <MedicationDueNotification>[];
    for (final dose in activeDoses) {
      final scheduledFor = scheduledTimes[dose.id] ?? dose.scheduledFor;
      final notification = MedicationDueNotification(
        doseId: dose.id,
        medicationName: medicationNames[dose.medicationId] ?? 'your medication',
        scheduledFor: scheduledFor,
      );
      final isDue = !scheduledFor.isAfter(currentTime);
      final isRecent =
          currentTime.difference(scheduledFor) <= _recentDoseWindow;
      if (isDue &&
          !_notifiedDoseIds.contains(dose.id) &&
          (!isInitialSync || isRecent)) {
        _notifiedDoseIds.add(dose.id);
        newlyDue.add(notification);
      }
    }

    _notifiedDoseIds.removeWhere((id) => !activeIds.contains(id));

    if (!_supportsNativeNotifications) return newlyDue;

    final futureDoses = activeDoses
        .where(
          (dose) => (scheduledTimes[dose.id] ?? dose.scheduledFor).isAfter(
            currentTime,
          ),
        )
        .toList(growable: false);
    final futureIds = futureDoses.map((dose) => dose.id).toSet();

    for (final dose in futureDoses) {
      await _schedule(
        dose,
        medicationNames[dose.medicationId],
        scheduledDate: scheduledTimes[dose.id] ?? dose.scheduledFor,
      );
    }
    for (final doseId in _scheduledDoseIds.difference(futureIds).toList()) {
      await _plugin.cancel(id: notificationIdForDose(doseId));
      _scheduledDoseIds.remove(doseId);
    }

    // If the app was open when the due time passed, show the native reminder
    // immediately. Background delivery is handled by the scheduled request.
    for (final notification in newlyDue) {
      await _plugin.show(
        id: notificationIdForDose(notification.doseId),
        title: notification.title,
        body: notification.body,
        notificationDetails: _notificationDetails,
        payload: '$_payloadPrefix${notification.doseId}',
      );
    }
    return newlyDue;
  }

  Future<void> _schedule(
    DoseLogRecord dose,
    String? medicationName, {
    required DateTime scheduledDate,
  }) async {
    final notificationId = notificationIdForDose(dose.id);
    await _plugin.zonedSchedule(
      id: notificationId,
      title: 'Medication reminder',
      body: 'Time to take ${medicationName ?? 'your medication'}',
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: '$_payloadPrefix${dose.id}',
    );
    _scheduledDoseIds.add(dose.id);
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
      return tz.TZDateTime(
        location,
        dateParts[0]!,
        dateParts[1]!,
        dateParts[2]!,
        timeParts[0]!,
        timeParts[1]!,
      );
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
    iOS: DarwinNotificationDetails(),
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
  Future<void> dispose() async {
    _disposed = true;
    _notifiedDoseIds.clear();
    _scheduledDoseIds.clear();
  }
}
