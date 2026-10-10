import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/app_controls.dart';
import 'package:mediary/camera_photo_review_screen.dart';
import 'package:mediary/data/mediary_data_store.dart';
import 'package:mediary/data/mediary_models.dart';
import 'package:mediary/data/mediary_repository.dart';
import 'package:mediary/main.dart';
import 'package:mediary/medication_scan.dart';
import 'package:mediary/notifications/medication_notification_service.dart';
import 'package:mediary/web_camera.dart';

import 'support/medication_scan_fixture.dart';

class _Repository extends Fake implements MediaryRepository {}

class _Store extends MediaryDataStore {
  _Store() : super(repository: _Repository());
  final scanWrites = <ScanWrite>[];
  Completer<void>? saving;
  @override
  bool get hasInitialData => true;
  @override
  Future<String> saveScan(ScanWrite scan) async {
    scanWrites.add(scan);
    await saving?.future;
    return 'scan-id';
  }
}

class _Notifications extends Fake implements MedicationNotificationService {
  @override
  Future<void> initialize() async {}
  @override
  Future<void> clearDeliveredNotifications() async {}
  @override
  Future<void> requestPermission() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<List<MedicationDueNotification>> syncDueDoses({
    required List<DoseLogRecord> doses,
    required Map<String, String> medicationNames,
    Map<String, String> scheduleTimezones = const {},
    DateTime? now,
  }) async => [];
}

class _Detector implements MedicationScanDetector {
  final requests = <MedicationScanRequest>[];
  Completer<void>? waiting;
  @override
  Future<MedicationScanResult> detect(MedicationScanRequest request) async {
    requests.add(request);
    await waiting?.future;
    return MedicationScanResult(
      imageUrl: '',
      imageBytes: request.imageBytes,
      extractedText: '',
      detectedMedicationName: '',
      confidence: 0,
    );
  }
}

Future<void> _waitForPhoto(WidgetTester tester) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    if (tester
            .widget<AppButton>(find.byKey(const Key('useCameraPhotoButton')))
            .onPressed !=
        null) {
      return;
    }
  }
  fail('Captured photo did not become ready.');
}

Future<void> _startCapture(
  WidgetTester tester,
  _Detector detector,
  _Store store, {
  Future<MedicationScanRequest?> Function()? capture,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AuthenticatedHome(
        email: 'camera@example.com',
        useSidebarNavigation: false,
        dataStore: store,
        scanDetector: detector,
        notificationService: _Notifications(),
        cameraPermissionRequester: () async => CameraAccessState.granted,
        cameraCapture: capture ?? () async => medicationScanFixture,
      ),
    ),
  );
  await tester.tap(find.text('Scan'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('captureMedicationButton')));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  testWidgets(
    'shutter freezes the photo without OCR or scan writes until use',
    (tester) async {
      final detector = _Detector();
      final store = _Store();
      addTearDown(store.dispose);
      await _startCapture(tester, detector, store);
      await _waitForPhoto(tester);
      expect(find.text('Review photo'), findsOneWidget);
      expect(find.byKey(const Key('frozenCameraPhoto')), findsOneWidget);
      expect(detector.requests, isEmpty);
      expect(store.scanWrites, isEmpty);
      final preview = tester.widget<WebCameraPreview>(
        find.byKey(const Key('scannerWebCameraPreview'), skipOffstage: false),
      );
      expect(preview.active, isFalse);
      await confirmCameraPhoto(tester);
      expect(detector.requests, hasLength(1));
      expect(
        detector.requests.single.imageBytes,
        same(medicationScanFixture.imageBytes),
      );
      expect(store.scanWrites, hasLength(1));
      expect(find.text('Review Medication'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'retake discards the preview and restores the camera without scanning',
    (tester) async {
      final detector = _Detector();
      final store = _Store();
      addTearDown(store.dispose);
      await _startCapture(tester, detector, store);
      await _waitForPhoto(tester);
      final image = tester.widget<Image>(
        find.byKey(const Key('frozenCameraPhoto')),
      );
      final key = await image.image.obtainKey(const ImageConfiguration());
      await tester.ensureVisible(
        find.byKey(const Key('retakeCameraPhotoButton')),
      );
      await tester.tap(find.byKey(const Key('retakeCameraPhotoButton')));
      await tester.pumpAndSettle();
      expect(find.text('Review photo'), findsNothing);
      expect(detector.requests, isEmpty);
      expect(store.scanWrites, isEmpty);
      expect(
        tester.widget<WebCameraPreview>(find.byType(WebCameraPreview)).active,
        isTrue,
      );
      expect(PaintingBinding.instance.imageCache.containsKey(key), isFalse);
      await tester.tap(find.byKey(const Key('captureMedicationButton')));
      await tester.pumpAndSettle();
      expect(find.text('Review photo'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('system back discards an unapproved photo', (tester) async {
    final detector = _Detector();
    final store = _Store();
    addTearDown(store.dispose);
    await _startCapture(tester, detector, store);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Review photo'), findsNothing);
    expect(detector.requests, isEmpty);
    expect(store.scanWrites, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'a slow scan save does not block recognition or showing the result',
    (tester) async {
      final detector = _Detector();
      final store = _Store()..saving = Completer<void>();
      addTearDown(store.dispose);
      await _startCapture(tester, detector, store);
      await _waitForPhoto(tester);
      final use = find.byKey(const Key('useCameraPhotoButton'));
      await tester.ensureVisible(use);
      await tester.tap(use);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(detector.requests, hasLength(1));
      expect(find.text('Review photo'), findsNothing);
      expect(find.text('Review Medication'), findsOneWidget);
      expect(store.scanWrites, hasLength(1));
      expect(store.scanWrites.single.status, 'needsReview');
      store.saving!.complete();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'double use runs one scan and retains the frozen image while busy',
    (tester) async {
      final detector = _Detector()..waiting = Completer<void>();
      final store = _Store();
      addTearDown(store.dispose);
      await _startCapture(tester, detector, store);
      await _waitForPhoto(tester);
      final use = find.byKey(const Key('useCameraPhotoButton'));
      await tester.ensureVisible(use);
      await tester.tap(use);
      await tester.pump();
      await tester.tap(use);
      await tester.pump();
      expect(detector.requests, hasLength(1));
      expect(find.byKey(const Key('frozenCameraPhoto')), findsOneWidget);
      expect(find.text('Analyzing photo'), findsOneWidget);
      expect(
        tester
            .widget<AppButton>(find.byKey(const Key('retakeCameraPhotoButton')))
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Review photo'), findsOneWidget);
      detector.waiting!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Review Medication'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('a canceled native capture does not open review or run OCR', (
    tester,
  ) async {
    final detector = _Detector();
    final store = _Store();
    addTearDown(store.dispose);
    await _startCapture(tester, detector, store, capture: () async => null);
    expect(find.text('Review photo'), findsNothing);
    expect(detector.requests, isEmpty);
    expect(store.scanWrites, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a late photo does not interrupt another destination', (
    tester,
  ) async {
    final detector = _Detector();
    final store = _Store();
    final capture = Completer<MedicationScanRequest?>();
    addTearDown(store.dispose);
    await _startCapture(
      tester,
      detector,
      store,
      capture: () => capture.future,
      settle: false,
    );
    await tester.tap(find.text('Calendar').last);
    await tester.pump(const Duration(milliseconds: 300));
    capture.complete(medicationScanFixture);
    await tester.pumpAndSettle();
    expect(find.text('Review photo'), findsNothing);
    expect(detector.requests, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final size in [
      const Size(320, 640),
      const Size(402, 874),
      const Size(568, 320),
    ]) {
      for (final scale in [1.0, 3.0]) {
        testWidgets(
          'photo review is usable on $platform at $size with ${scale}x text',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.pumpWidget(
              MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: CameraPhotoReviewScreen(
                  imageBytes: medicationScanFixture.imageBytes!,
                  onUsePhoto: () async {},
                ),
              ),
            );
            await _waitForPhoto(tester);
            expect(tester.takeException(), isNull);
            final image = tester.widget<Image>(
              find.byKey(const Key('frozenCameraPhoto')),
            );
            final provider = image.image as ResizeImage;
            expect(provider.policy, ResizeImagePolicy.fit);
            expect(provider.width, lessThanOrEqualTo(1600));
            expect(provider.height, lessThanOrEqualTo(1600));
            for (final name in [
              'useCameraPhotoButton',
              'retakeCameraPhotoButton',
            ]) {
              final button = find.byKey(Key(name));
              if (scale == 1 && size.height > 400) {
                expect(
                  button.hitTestable(),
                  findsOneWidget,
                  reason: 'Normal phone actions should be visible without scrolling.',
                );
              }
              await tester.ensureVisible(button);
              await tester.pumpAndSettle();
              expect(button.hitTestable(), findsOneWidget);
              expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          },
          variant: TargetPlatformVariant({platform}),
        );
      }
    }
  }

  testWidgets('invalid photo cannot be approved and offers retake', (
    tester,
  ) async {
    var scans = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CameraPhotoReviewScreen(
          imageBytes: Uint8List.fromList([1, 2, 3]),
          onUsePhoto: () async => scans++,
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('could not be displayed'), findsOneWidget);
    expect(
      tester
          .widget<AppButton>(find.byKey(const Key('useCameraPhotoButton')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<AppButton>(find.byKey(const Key('retakeCameraPhotoButton')))
          .onPressed,
      isNotNull,
    );
    expect(scans, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed approval can retry the same photo without a stuck button',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CameraPhotoReviewScreen(
            imageBytes: medicationScanFixture.imageBytes!,
            onUsePhoto: () async {
              attempts++;
              if (attempts == 1) throw StateError('Temporary failure');
            },
          ),
        ),
      );
      await _waitForPhoto(tester);
      final use = find.byKey(const Key('useCameraPhotoButton'));
      await tester.ensureVisible(use);
      await tester.tap(use);
      await tester.pumpAndSettle();
      expect(find.textContaining('could not analyze'), findsOneWidget);
      expect(tester.widget<AppButton>(use).onPressed, isNotNull);
      expect(
        tester
            .widget<AppButton>(find.byKey(const Key('retakeCameraPhotoButton')))
            .onPressed,
        isNotNull,
      );
      await tester.tap(use);
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
