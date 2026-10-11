import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mediary/data/mediary_models.dart';
import 'package:mediary/notifications/medication_notification_service.dart';

class _UnavailableNotificationPlatform
    extends FlutterLocalNotificationsPlatform {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    FlutterLocalNotificationsPlatform.instance =
        _UnavailableNotificationPlatform();
  }
  DoseLogRecord dose({
    required String id,
    required DateTime scheduledFor,
    String status = 'due',
    DateTime? snoozedUntil,
    String? scheduleId,
    String localTime = '09:00',
  }) {
    return DoseLogRecord(
      id: id,
      medicationId: 'medication-1',
      scheduleId: scheduleId ?? 'schedule-$id',
      scheduledFor: scheduledFor,
      localDate: '2026-09-13',
      localTime: localTime,
      status: status,
      snoozedUntil: snoozedUntil,
    );
  }

  test('uses stable positive notification ids for dose ids', () {
    final first = DefaultMedicationNotificationService.notificationIdForDose(
      'dose-1',
    );
    final second = DefaultMedicationNotificationService.notificationIdForDose(
      'dose-1',
    );

    expect(first, greaterThan(0));
    expect(first, second);
    expect(
      DefaultMedicationNotificationService.notificationIdForDose('dose-2'),
      isNot(first),
    );
  });

  test('returns a recent due dose once and ignores duplicates', () async {
    final service = DefaultMedicationNotificationService();
    final now = DateTime(2026, 9, 13, 9, 1);
    final due = dose(id: 'dose-1', scheduledFor: DateTime(2026, 9, 13, 9));

    final first = await service.syncDueDoses(
      doses: [due],
      medicationNames: const {'medication-1': 'Ibuprofen'},
      now: now,
    );
    final second = await service.syncDueDoses(
      doses: [due],
      medicationNames: const {'medication-1': 'Ibuprofen'},
      now: now.add(const Duration(seconds: 15)),
    );

    expect(first.single.body, 'Time to take Ibuprofen');
    expect(second, isEmpty);
    await service.dispose();
  });

  test(
    'changing a legacy record ID does not alert twice for one occurrence',
    () async {
      final service = DefaultMedicationNotificationService();
      final now = DateTime(2026, 9, 13, 9);
      final legacy = dose(
        id: 'legacy-slot',
        scheduledFor: now,
        scheduleId: 'same-slot',
        localTime: '09:00',
      );
      final canonical = dose(
        id: 'canonical-slot',
        scheduledFor: now,
        scheduleId: 'same-slot',
        localTime: '09:00:00',
      );
      expect(
        await service.syncDueDoses(
          doses: [legacy],
          medicationNames: const {},
          now: now,
        ),
        hasLength(1),
      );
      expect(
        await service.syncDueDoses(
          doses: [canonical],
          medicationNames: const {},
          now: now.add(const Duration(seconds: 15)),
        ),
        isEmpty,
      );
      await service.dispose();
    },
  );

  test(
    'does not treat stale doses as new after an empty bootstrap sync',
    () async {
      final service = DefaultMedicationNotificationService();
      final now = DateTime(2026, 9, 13, 12);
      final stale = dose(
        id: 'stale-after-bootstrap',
        scheduledFor: now.subtract(const Duration(hours: 2)),
      );

      expect(
        await service.syncDueDoses(
          doses: const <DoseLogRecord>[],
          medicationNames: const <String, String>{},
          now: now,
        ),
        isEmpty,
      );

      for (var tick = 1; tick <= 5; tick++) {
        expect(
          await service.syncDueDoses(
            doses: [stale],
            medicationNames: const {'medication-1': 'Metformin'},
            now: now.add(Duration(seconds: tick * 15)),
          ),
          isEmpty,
        );
      }
      expect(
        await service.syncDueDoses(
          doses: [stale],
          medicationNames: const {'medication-1': 'Metformin'},
          now: now,
        ),
        isEmpty,
      );

      await service.dispose();
    },
  );

  test('late snapshots do not flood historical reminders', () async {
    final service = DefaultMedicationNotificationService();
    final now = DateTime(2026, 9, 13, 12);
    final upcoming = dose(
      id: 'upcoming',
      scheduledFor: now.add(const Duration(hours: 1)),
    );
    await service.syncDueDoses(
      doses: [upcoming],
      medicationNames: const {},
      now: now,
    );
    final history = [
      for (var index = 0; index < 90; index++)
        dose(
          id: 'old-$index',
          scheduledFor: now.subtract(Duration(hours: index + 1)),
        ),
    ];
    for (var tick = 0; tick < 5; tick++) {
      expect(
        await service.syncDueDoses(
          doses: [upcoming, ...history],
          medicationNames: const {},
          now: now.add(Duration(seconds: tick * 15)),
        ),
        isEmpty,
      );
    }
    await service.dispose();
  });

  test('snoozed dose reminds once at its new time', () async {
    final service = DefaultMedicationNotificationService();
    final now = DateTime(2026, 9, 13, 9);
    final original = dose(id: 'later', scheduledFor: now);
    final until = now.add(const Duration(minutes: 15));
    final snoozed = dose(
      id: 'later',
      scheduledFor: now,
      status: 'snoozed',
      snoozedUntil: until,
    );
    expect(
      await service.syncDueDoses(
        doses: [original],
        medicationNames: const {},
        now: now,
      ),
      hasLength(1),
    );
    expect(
      await service.syncDueDoses(
        doses: [snoozed],
        medicationNames: const {},
        now: now,
      ),
      isEmpty,
    );
    final reminder = await service.syncDueDoses(
      doses: [snoozed],
      medicationNames: const {},
      now: until,
    );
    expect(reminder.single.scheduledFor, until);
    expect(
      await service.syncDueDoses(
        doses: [snoozed],
        medicationNames: const {},
        now: until.add(const Duration(seconds: 15)),
      ),
      isEmpty,
    );
    await service.dispose();
  });

  if (!kIsWeb) {
    for (final platform in [TargetPlatform.iOS]) {
      group('$platform native tray reconciliation', () {
        const channel = MethodChannel(
          'dexterous.com/flutter/local_notifications',
        );
        late List<MethodCall> calls;
        late List<Map<String, Object>> delivered;
        late List<Map<String, Object>> pending;
        late bool permissionEnabled;
        late FlutterLocalNotificationsPlatform previousPlatform;
        setUp(() {
          debugDefaultTargetPlatformOverride = platform;
          previousPlatform = FlutterLocalNotificationsPlatform.instance;
          IOSFlutterLocalNotificationsPlugin.registerWith();
          calls = [];
          delivered = [];
          pending = [];
          permissionEnabled = true;
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, (call) async {
                calls.add(call);
                switch (call.method) {
                  case 'initialize':
                    return true;
                  case 'checkPermissions':
                    return {
                      'isEnabled': permissionEnabled,
                      'isAlertEnabled': permissionEnabled,
                    };
                  case 'getActiveNotifications':
                    return delivered.toList();
                  case 'pendingNotificationRequests':
                    return pending.toList();
                  case 'cancel':
                    final id = call.arguments;
                    delivered.removeWhere((item) => item['id'] == id);
                    pending.removeWhere((item) => item['id'] == id);
                    return null;
                  case 'cancelAll':
                    delivered.clear();
                    pending.clear();
                    return null;
                  default:
                    return null;
                }
              });
        });
        tearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
          debugDefaultTargetPlatformOverride = null;
          FlutterLocalNotificationsPlatform.instance = previousPlatform;
        });

        test(
          'native reminders are scheduled at the selected minute boundary',
          () async {
            final service = DefaultMedicationNotificationService();
            final now = DateTime.now();
            final due = DateTime(
              now.year,
              now.month,
              now.day,
              now.hour,
              now.minute + 2,
            );
            await service.syncDueDoses(
              doses: [dose(id: 'minute-boundary', scheduledFor: due)],
              medicationNames: const {},
              now: now,
            );
            final request = calls.singleWhere(
              (call) => call.method == 'zonedSchedule',
            );
            final arguments = request.arguments as Map;
            final scheduled = DateTime.parse(
              arguments['scheduledDateTime'] as String,
            );
            expect(scheduled.second, 0);
            expect(scheduled.millisecond, 0);
            expect(
              (arguments['platformSpecifics'] as Map)['interruptionLevel'],
              InterruptionLevel.timeSensitive.index,
            );

            await service.dispose();
          },
        );

        test(
          'denied iOS permission skips scheduling and reports denial',
          () async {
            permissionEnabled = false;
            final service = DefaultMedicationNotificationService();
            final now = DateTime(2026, 9, 13, 9);
            expect(await service.permissionState(), 'denied');
            await service.syncDueDoses(
              doses: [
                dose(
                  id: 'denied-future',
                  scheduledFor: now.add(const Duration(hours: 1)),
                ),
              ],
              medicationNames: const {},
              now: now,
            );
            expect(
              calls.where((call) => call.method == 'zonedSchedule'),
              isEmpty,
            );
            await service.dispose();
          },
        );

        test('iOS retains the nearest 64 future reminders from an unsorted regimen', () async {
          final service = DefaultMedicationNotificationService();
          final now = DateTime.now().add(const Duration(days: 1));
          await service.syncDueDoses(
            doses: [
              for (var i = 100; i >= 1; i--)
                dose(
                  id: 'future-$i',
                  scheduledFor: now.add(Duration(minutes: i)),
                ),
            ],
            medicationNames: const {},
            now: now,
          );
          final scheduled = calls
              .where((call) => call.method == 'zonedSchedule')
              .toList();
          expect(scheduled, hasLength(64));
          final payloads = scheduled.map(
            (call) => (call.arguments as Map)['payload'],
          );
          expect(payloads, contains('mediary:dose:future-1'));
          expect(payloads, contains('mediary:dose:future-64'));
          if (platform == TargetPlatform.iOS) {
            expect(payloads, isNot(contains('mediary:dose:future-65')));
          }
          await service.dispose();
        });

        test(
          'opening clears delivered alerts but keeps future requests',
          () async {
            final service = DefaultMedicationNotificationService();
            final now = DateTime.now();
            final due = dose(id: 'opened', scheduledFor: now);
            final future = dose(
              id: 'future-preserved',
              scheduledFor: now.add(const Duration(hours: 1)),
            );
            delivered.add({
              'id': DefaultMedicationNotificationService.notificationIdForDose(
                due.id,
              ),
              'payload': 'mediary:dose:${due.id}',
            });
            pending.add({
              'id': DefaultMedicationNotificationService.notificationIdForDose(
                future.id,
              ),
              'payload': 'mediary:dose:${future.id}',
            });
            await service.clearDeliveredNotifications();
            expect(delivered, isEmpty);
            expect(pending, hasLength(1));
            expect(
              await service.syncDueDoses(
                doses: [due, future],
                medicationNames: const {},
                now: now,
              ),
              isEmpty,
            );
            expect(calls.where((call) => call.method == 'show'), isEmpty);
            expect(pending, hasLength(1));
            await service.dispose();
          },
        );

        test(
          'deleting a dose clears its alert without cancelling its neighbor',
          () async {
            final service = DefaultMedicationNotificationService();
            final removedId =
                DefaultMedicationNotificationService.notificationIdForDose(
                  'removed',
                );
            final neighborId =
                DefaultMedicationNotificationService.notificationIdForDose(
                  'neighbor',
                );
            delivered.addAll([
              {'id': removedId, 'payload': 'mediary:dose:removed'},
              {'id': neighborId, 'payload': 'mediary:dose:neighbor'},
            ]);
            pending.addAll([
              {'id': removedId, 'payload': 'mediary:dose:removed'},
              {'id': neighborId, 'payload': 'mediary:dose:neighbor'},
            ]);
            await service.cancelDose('removed');
            expect(delivered.single['id'], neighborId);
            expect(pending.single['id'], neighborId);
            await service.dispose();
          },
        );

        test(
          'a delayed native request is replaced by one foreground reminder',
          () async {
            final service = DefaultMedicationNotificationService();
            final now = DateTime.now();
            final future = dose(
              id: 'delayed-native',
              scheduledFor: now.add(const Duration(minutes: 1)),
            );
            await service.syncDueDoses(
              doses: [future],
              medicationNames: const {},
              now: now,
            );
            pending.add({
              'id': DefaultMedicationNotificationService.notificationIdForDose(
                future.id,
              ),
              'payload': 'mediary:dose:${future.id}',
            });
            await service.syncDueDoses(
              doses: [future],
              medicationNames: const {},
              now: future.scheduledFor,
            );
            expect(pending, isEmpty);
            expect(calls.where((call) => call.method == 'show'), hasLength(1));
            await service.syncDueDoses(
              doses: [future],
              medicationNames: const {},
              now: future.scheduledFor.add(const Duration(seconds: 15)),
            );
            expect(calls.where((call) => call.method == 'show'), hasLength(1));
            await service.dispose();
          },
        );

        test(
          'a scheduled reminder is not shown again at its due time',
          () async {
            final service = DefaultMedicationNotificationService();
            final now = DateTime.now();
            final future = dose(
              id: 'native-once',
              scheduledFor: now.add(const Duration(minutes: 1)),
            );
            await service.syncDueDoses(
              doses: [future],
              medicationNames: const {},
              now: now,
            );
            expect(
              calls.where((call) => call.method == 'zonedSchedule'),
              hasLength(1),
            );
            expect(
              await service.syncDueDoses(
                doses: [future],
                medicationNames: const {},
                now: future.scheduledFor,
              ),
              hasLength(1),
            );
            expect(calls.where((call) => call.method == 'show'), isEmpty);
            await service.dispose();
          },
        );

        test(
          'simultaneous foreground doses produce one alert and sound',
          () async {
            final service = DefaultMedicationNotificationService();
            final now = DateTime.now();
            final doses = [
              for (var i = 0; i < 8; i++)
                dose(id: 'burst-$i', scheduledFor: now),
            ];
            final first = await service.syncDueDoses(
              doses: doses,
              medicationNames: const {},
              now: now,
            );
            expect(first, hasLength(8));
            final shown =
                calls.where((call) => call.method == 'show').single.arguments
                    as Map;
            expect(
              shown['body'],
              '8 medication reminders are due. Open Mediary to review them.',
            );
            expect(shown['payload'], startsWith('mediary:due:'));
            expect(
              jsonDecode(
                (shown['payload'] as String).substring('mediary:due:'.length),
              ),
              hasLength(8),
            );
            await service.syncDueDoses(
              doses: doses.reversed.toList(),
              medicationNames: const {},
              now: now.add(const Duration(seconds: 15)),
            );
            expect(calls.where((call) => call.method == 'show'), hasLength(1));
            await service.dispose();
          },
        );

        test(
          'simultaneous background doses share one pending request',
          () async {
            final service = DefaultMedicationNotificationService();
            final now = DateTime.now();
            final time = now.add(const Duration(hours: 1));
            final doses = [
              for (var i = 0; i < 8; i++)
                dose(id: 'batch-$i', scheduledFor: time),
            ];
            await service.syncDueDoses(
              doses: doses,
              medicationNames: const {},
              now: now,
            );
            final first =
                calls
                        .where((call) => call.method == 'zonedSchedule')
                        .single
                        .arguments
                    as Map;
            final payload = first['payload'] as String;
            expect(payload, startsWith('mediary:scheduled:'));
            expect(
              (jsonDecode(payload.substring('mediary:scheduled:'.length))
                  as Map)['doses'],
              hasLength(8),
            );
            pending.add({'id': first['id'] as int, 'payload': payload});
            await service.syncDueDoses(
              doses: doses.reversed.toList(),
              medicationNames: const {},
              now: now.add(const Duration(seconds: 15)),
            );
            expect(
              calls.where((call) => call.method == 'zonedSchedule'),
              hasLength(1),
            );
            // removing a dose from a batch must refresh its payload even though
            // the request's time and stable id remain unchanged.
            await service.syncDueDoses(
              doses: doses.skip(1).toList(),
              medicationNames: const {},
              now: now,
            );
            expect(
              calls.where((call) => call.method == 'zonedSchedule'),
              hasLength(2),
            );
            await service.dispose();
          },
        );

        test('cancelling a batch dose after restart preserves its neighbors', () async {
          final service = DefaultMedicationNotificationService();
          final time = DateTime.now().add(const Duration(hours: 1));
          pending.add({
            'id': 12345,
            'payload':
                'mediary:scheduled:${jsonEncode({
                  'at': time.toUtc().toIso8601String(),
                  'doses': [
                    for (final id in ['removed', 'kept-a', 'kept-b']) {'id': id, 'name': 'Medication'},
                  ],
                })}',
          });
          await service.cancelDose('removed');
          expect(pending, isEmpty);
          final replacement =
              calls
                      .where((call) => call.method == 'zonedSchedule')
                      .single
                      .arguments
                  as Map;
          final data = jsonDecode(
            (replacement['payload'] as String).substring(
              'mediary:scheduled:'.length,
            ),
          ) as Map;
          expect((data['doses'] as List).map((item) => (item as Map)['id']), [
            'kept-a',
            'kept-b',
          ]);
          expect(DateTime.parse(data['at'] as String), time.toUtc());
          await service.dispose();
        });

        test(
          'delivered alerts restore receipts before the first sync',
          () async {
            final service = DefaultMedicationNotificationService();
            final now = DateTime.now();
            delivered.add({
              'id': 12345,
              'payload': 'mediary:due:["already-a","already-b"]',
            });
            expect(
              await service.syncDueDoses(
                doses: [
                  dose(id: 'already-a', scheduledFor: now),
                  dose(id: 'already-b', scheduledFor: now),
                ],
                medicationNames: const {},
                now: now,
              ),
              isEmpty,
            );
            expect(calls.where((call) => call.method == 'show'), isEmpty);
            await service.dispose();
          },
        );
        test('cancelling a delayed batch never reschedules in the past', () async {
          final service = DefaultMedicationNotificationService();
          final now = DateTime.now();
          final time = now.subtract(const Duration(minutes: 1));
          pending.add({
            'id': 12345,
            'payload':
                'mediary:scheduled:${jsonEncode({
                  'at': time.toUtc().toIso8601String(),
                  'doses': [
                    for (final id in ['removed', 'remaining']) {'id': id, 'name': 'Medication'},
                  ],
                })}',
          });
          await service.cancelDose('removed');
          expect(
            calls.where((call) => call.method == 'zonedSchedule'),
            isEmpty,
          );
          expect(pending, isEmpty);
          final result = await service.syncDueDoses(
            doses: [dose(id: 'remaining', scheduledFor: time)],
            medicationNames: const {},
            now: now,
          );
          expect(result.single.doseId, 'remaining');
          expect(calls.where((call) => call.method == 'show'), hasLength(1));
          await service.dispose();
        });

        test('an old delivered receipt never suppresses a snoozed time after restart', () async {
          final service = DefaultMedicationNotificationService();
          final now = DateTime.now();
          final until = now.add(const Duration(minutes: 15));
          final snoozed = dose(
            id: 'snoozed-restart',
            scheduledFor: now,
            status: 'snoozed',
            snoozedUntil: until,
          );
          delivered.add({
            'id': DefaultMedicationNotificationService.notificationIdForDose(
              snoozed.id,
            ),
            'payload': 'mediary:dose:${snoozed.id}',
          });
          expect(
            await service.syncDueDoses(
              doses: [snoozed],
              medicationNames: const {},
              now: now,
            ),
            isEmpty,
          );
          expect(delivered, isEmpty);
          expect(
            calls.where((call) => call.method == 'zonedSchedule'),
            hasLength(1),
          );
          expect(
            await service.syncDueDoses(
              doses: [snoozed],
              medicationNames: const {},
              now: until,
            ),
            hasLength(1),
          );
          await service.dispose();
        });
      });
    }
  }

  test(
    'terminal duplicates and legacy time formats agree with UI identity',
    () async {
      final service = DefaultMedicationNotificationService();
      final now = DateTime(2026, 9, 13, 9);
      final due = dose(
        id: 'legacy-due',
        scheduledFor: now,
        scheduleId: 'shared',
        localTime: '09:00',
      );
      final taken = dose(
        id: 'canonical-taken',
        scheduledFor: now,
        scheduleId: 'shared',
        localTime: '09:00:00',
        status: 'taken',
      );
      expect(
        await service.syncDueDoses(
          doses: [due, taken],
          medicationNames: const {},
          now: now,
        ),
        isEmpty,
      );
      expect(
        await service.syncDueDoses(
          doses: [taken, due],
          medicationNames: const {},
          now: now,
        ),
        isEmpty,
      );
      await service.dispose();
    },
  );

  test(
    'does not notify stale initial doses, snoozed doses, or non-due doses',
    () async {
      final service = DefaultMedicationNotificationService();
      final now = DateTime(2026, 9, 13, 12);
      final stale = dose(
        id: 'stale',
        scheduledFor: now.subtract(const Duration(hours: 2)),
      );
      final snoozed = dose(
        id: 'snoozed',
        scheduledFor: now.subtract(const Duration(minutes: 1)),
        snoozedUntil: now.add(const Duration(minutes: 10)),
      );
      final taken = dose(
        id: 'taken',
        scheduledFor: now.subtract(const Duration(minutes: 1)),
        status: 'taken',
      );

      final result = await service.syncDueDoses(
        doses: [stale, snoozed, taken],
        medicationNames: const {'medication-1': 'Metformin'},
        now: now,
      );

      expect(result, isEmpty);
      await service.dispose();
    },
  );

  test('notifies a dose that becomes due after the initial sync', () async {
    final service = DefaultMedicationNotificationService();
    final now = DateTime(2026, 9, 13, 8);
    final future = dose(
      id: 'future',
      scheduledFor: now.add(const Duration(minutes: 5)),
    );

    expect(
      await service.syncDueDoses(
        doses: [future],
        medicationNames: const {'medication-1': 'Cetirizine'},
        now: now,
      ),
      isEmpty,
    );
    final due = await service.syncDueDoses(
      doses: [
        dose(id: 'future', scheduledFor: now.add(const Duration(minutes: 5))),
      ],
      medicationNames: const {'medication-1': 'Cetirizine'},
      now: now.add(const Duration(minutes: 6)),
    );

    expect(due.single.medicationName, 'Cetirizine');
    await service.dispose();
  });

  test(
    'notifies at the exact configured local time, including seconds',
    () async {
      final service = DefaultMedicationNotificationService();
      final now = DateTime.utc(2026, 9, 13, 9, 1, 7);
      final due = DoseLogRecord(
        id: 'exact-time',
        medicationId: 'medication-1',
        scheduleId: 'schedule-exact-time',
        scheduledFor: now,
        localDate: '2026-09-13',
        localTime: '09:01:07',
        status: 'due',
      );

      final result = await service.syncDueDoses(
        doses: [due],
        medicationNames: const {'medication-1': 'Levothyroxine'},
        scheduleTimezones: const {'schedule-exact-time': 'UTC'},
        now: now,
      );

      expect(
        result.single.scheduledFor.millisecondsSinceEpoch,
        now.millisecondsSinceEpoch,
      );
      expect(result.single.body, 'Time to take Levothyroxine');
      await service.dispose();
    },
  );

  test(
    'uses the schedule timezone and local date/time when available',
    () async {
      final service = DefaultMedicationNotificationService();
      final now = DateTime.utc(2026, 9, 13, 9, 1);
      final scheduled = dose(
        id: 'utc-dose',
        // this value is deliberately different; the schedule metadata is the
        // source of truth for newly-created records.
        scheduledFor: DateTime.utc(2026, 9, 13, 9),
      );

      final result = await service.syncDueDoses(
        doses: [scheduled],
        medicationNames: const {'medication-1': 'Aspirin'},
        scheduleTimezones: const {'schedule-utc-dose': 'UTC'},
        now: now,
      );

      expect(result.single.scheduledFor.hour, 9);
      expect(result.single.scheduledFor.timeZoneOffset, Duration.zero);
      await service.dispose();
    },
  );

  test('deduplicates a large dose set and forgets cancelled doses', () async {
    final service = DefaultMedicationNotificationService();
    final now = DateTime(2026, 9, 13, 9, 1);
    final doses = [
      for (var index = 0; index < 1000; index++)
        dose(
          id: 'dose-$index',
          scheduledFor: now.subtract(const Duration(minutes: 1)),
        ),
    ];
    final names = <String, String>{'medication-1': 'Medication'};

    final first = await service.syncDueDoses(
      doses: doses,
      medicationNames: names,
      now: now,
    );
    final duplicate = await service.syncDueDoses(
      doses: doses,
      medicationNames: names,
      now: now.add(const Duration(seconds: 15)),
    );
    final next = await service.syncDueDoses(
      doses: [
        for (final item in doses)
          if (item.id != 'dose-0') item,
      ],
      medicationNames: names,
      now: now.add(const Duration(seconds: 30)),
    );

    expect(first, hasLength(1000));
    expect(duplicate, isEmpty);
    expect(next, isEmpty);
    await service.dispose();
  });

  test(
    'only notifies once for duplicate records of one schedule slot',
    () async {
      final service = DefaultMedicationNotificationService();
      final now = DateTime(2026, 9, 13, 9, 1);
      final first = dose(
        id: 'duplicate-a',
        scheduledFor: now.subtract(const Duration(minutes: 1)),
        scheduleId: 'same-schedule',
      );
      final duplicate = dose(
        id: 'duplicate-b',
        scheduledFor: now.subtract(const Duration(minutes: 1)),
        scheduleId: 'same-schedule',
      );

      final result = await service.syncDueDoses(
        doses: [first, duplicate],
        medicationNames: const {'medication-1': 'Medication'},
        now: now,
      );

      expect(result, hasLength(1));
      await service.dispose();
    },
  );
}
