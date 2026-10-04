@TestOn('browser')
library;

import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/web_camera.dart';

class _CaptureRegistry extends ui_web.PlatformViewRegistry {
  final factories = <String, Function>{};
  @override
  bool registerViewFactory(
    String viewType,
    Function viewFactory, {
    bool isVisible = true,
  }) {
    factories[viewType] = viewFactory;
    return super.registerViewFactory(
      viewType,
      viewFactory,
      isVisible: isVisible,
    );
  }
}

void main() {
  testWidgets('browser capture returns the displayed video frame as PNG', (
    tester,
  ) async {
    final registry = _CaptureRegistry();
    ui_web.debugOverridePlatformViewRegistry(registry);
    addTearDown(() => ui_web.debugOverridePlatformViewRegistry(null));
    // The browser runner supplies a synthetic camera device and grants access.
    expect(await tester.runAsync(requestWebCameraAccess), isTrue);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WebCameraPreview(active: true))),
    );
    // Widget tests mock platform-view creation; mount the registered factory
    // so the actual browser video and canvas APIs can be exercised.
    final view = tester.widget<HtmlElementView>(find.byType(HtmlElementView));
    final factory = registry.factories[view.viewType]!;
    final element = factory(123) as web.HTMLElement;
    web.document.body!.append(element);
    addTearDown(() => element.remove());
    List<int>? bytes;
    for (var attempt = 0; attempt < 30; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
      bytes = await captureWebCameraFrame();
      if (bytes != null) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    }
    expect(bytes, isNotNull);
    expect(bytes!.take(8), orderedEquals([137, 80, 78, 71, 13, 10, 26, 10]));
    expect(bytes.length, greaterThan(100));
    stopWebCamera();
    expect(await captureWebCameraFrame(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, skip: !const bool.fromEnvironment('MEDIARY_SYNTHETIC_CAMERA_TEST'));
}
