import 'dart:io';

import 'package:domain_models/domain_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pagecraft/all_formats.dart' show TextPagesView;
import 'package:readflex/app/routing.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import '../test/support/ui_test_app.dart';
import '../test/support/ui_test_driver.dart';
import 'support/native_ui_frame_probe.dart';

/// Profile-only UI diagnostics; screenshots and GC tracing stay outside samples.
///
/// Use test_driver/ui_driver.dart without READFLEX_NATIVE_DEVICE. Host-attested
/// READFLEX_PHYSICAL_DEVICE and READFLEX_DEVICE_MODEL identify the actual run;
/// emulator smoke tests must leave the physical-device define false.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('warmed native UI frame timings', (tester) async {
    expect(kProfileMode, isTrue, reason: 'Run this target with --profile');
    final previousFramePolicy = binding.framePolicy;
    binding.framePolicy =
        LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;
    addTearDown(() => binding.framePolicy = previousFramePolicy);

    final app = await UiTestApp.create();
    addTearDown(() async {
      try {
        await _withLiveFrames(binding, () => unmountUi(tester));
      } finally {
        await app.dispose();
      }
    });
    await app.bookRepository.markOpened(app.book!.id, DateTime(2026, 11, 12));
    await app.bookRepository.updateReadingPosition(
      app.book!.id,
      cfi: null,
      progress: .42,
    );
    tester.platformDispatcher.defaultRouteNameTestValue = '/';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    await _withLiveFrames(binding, () => tester.pumpWidget(app.widget));
    final card = find.byKey(const ValueKey('libraryContinueReadingCard'));
    await waitForUi(
      tester,
      () => card.evaluate().isNotEmpty,
      description: 'performance Library fixture',
    );
    await _withLiveFrames(
      binding,
      () => _waitForNativeForeground(tester, binding),
    );
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final flows = <String, Object?>{};
    binding.reportData = {
      'nativeUiPerformance': {
        'platform': Platform.operatingSystem,
        'osVersion': Platform.operatingSystemVersion,
        'mode': 'profile',
        'physicalDevice': const bool.fromEnvironment(
          'READFLEX_PHYSICAL_DEVICE',
        ),
        'deviceModel': const String.fromEnvironment(
          'READFLEX_DEVICE_MODEL',
          defaultValue: 'unspecified',
        ),
        'deviceMetadataSource': 'Host dart-defines; not detected in Dart',
        'logicalSize': {'width': size.width, 'height': size.height},
        'devicePixelRatio': tester.view.devicePixelRatio,
        'framePolicy': 'benchmarkLive',
        'warmupCyclesPerFlow': 2,
        'limitations': [
          'Flutter build/raster durations are not end-to-end FPS or input latency',
          'Native keyboard and compositor rendering costs are outside FrameTiming',
          'The fixture isolates UI; production database/network/native I/O are not timed',
          'Refresh budget uses the nominal Flutter display rate',
          'Emulator results cannot establish physical-device performance',
        ],
        'flows': flows,
      },
    };
    final probe = NativeUiFrameProbe(tester);
    const cycles = 12;

    Future<void> searchCycle() async {
      await tapUi(tester, find.byKey(const ValueKey('librarySearchButton')));
      await _waitForKeyboard(tester, visible: true);
      await tapUi(
        tester,
        find.byKey(const ValueKey('libraryCapsuleActionButton')),
      );
      await _waitForKeyboard(tester, visible: false);
    }

    await _repeat(2, searchCycle);
    flows['librarySearch'] = await probe.measure(
      cycles: cycles,
      action: () => _repeat(cycles, searchCycle),
    );
    await tapUi(tester, card);
    final pages = find.byType(TextPagesView);
    await waitForUi(
      tester,
      () =>
          pages.evaluate().isNotEmpty &&
          tester.widget<TextPagesView>(pages).controller.isReady,
      description: 'performance Reader fixture',
    );
    final strings = tester.element(pages).l10n;
    final appearance = find.byTooltip(strings.readerFontAction).hitTestable();
    if (appearance.evaluate().isEmpty) {
      await tester.tapAt(tester.getCenter(pages));
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> chromeCycle() async {
      await tester.tapAt(tester.getCenter(pages));
      await tester.pump(const Duration(milliseconds: 400));
      expect(appearance, findsNothing);
      await tester.tapAt(tester.getCenter(pages));
      await tester.pump(const Duration(milliseconds: 400));
      expect(appearance, findsOneWidget);
    }

    await _repeat(2, chromeCycle);
    flows['readerChrome'] = await probe.measure(
      cycles: cycles,
      action: () => _repeat(cycles, chromeCycle),
    );

    Future<void> appearanceCycle() async {
      await tapUi(tester, appearance);
      final close = find.byTooltip(strings.commonClose).hitTestable();
      await tapUi(tester, close);
      await waitForUi(
        tester,
        () => appearance.evaluate().isNotEmpty,
        description: 'Appearance fully dismissed',
      );
    }

    await _repeat(2, appearanceCycle);
    flows['readerAppearance'] = await probe.measure(
      cycles: cycles,
      action: () => _repeat(cycles, appearanceCycle),
    );

    await _withLiveFrames(binding, () => unmountUi(tester));
    const passage =
        'Returning to a passage should leave room to read the whole thought. '
        'A calm page keeps attention on the text and makes it easy to return '
        'to the source.';
    await app.highlightRepository.addHighlight(
      sourceId: app.book!.id,
      sourceType: SourceType.book,
      text: List.filled(24, passage).join('\n\n'),
      chapterTitle: 'Chapter One',
      note: 'The end of the saved note.',
    );
    await _withLiveFrames(
      binding,
      () => tester.pumpWidget(app.widgetAt(AppRoutes.practiceReview)),
    );
    final viewport = find.byKey(const ValueKey('reviewCardViewport'));
    await waitForUi(
      tester,
      () => find.byKey(const ValueKey('reviewQuote')).evaluate().isNotEmpty,
      description: 'performance long Highlight fixture',
    );
    final scroll = tester.widget<SingleChildScrollView>(viewport).controller!;
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    final source = find.byKey(const ValueKey('reviewLocation'));
    final footer = find.byKey(const ValueKey('reviewControlsPanel'));
    final sourceBounds = tester.getRect(source);
    final footerBounds = tester.getRect(footer);

    Future<void> highlightCycle() async {
      for (final fraction in [.85, .15]) {
        await scroll.animateTo(
          scroll.position.maxScrollExtent * fraction,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.getRect(source), sourceBounds);
      expect(tester.getRect(footer), footerBounds);
    }

    await _repeat(2, highlightCycle);
    flows['highlightScroll'] = await probe.measure(
      cycles: cycles,
      action: () => _repeat(cycles, highlightCycle),
    );
    expect(tester.takeException(), isNull);
    await _withLiveFrames(binding, () => unmountUi(tester));
  }, timeout: const Timeout(Duration(minutes: 8)));
}

Future<void> _withLiveFrames(
  IntegrationTestWidgetsFlutterBinding binding,
  Future<void> Function() action,
) async {
  final previousPolicy = binding.framePolicy;
  // benchmarkLive ignores pump requests; fixture replacement must await the
  // actual unmount/build before another root can reuse its element.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  try {
    await action();
  } finally {
    binding.framePolicy = previousPolicy;
  }
}

Future<void> _repeat(int cycles, Future<void> Function() action) async {
  for (var cycle = 0; cycle < cycles; cycle++) {
    await action();
  }
}

Future<void> _waitForNativeForeground(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
) async {
  final deadline = Stopwatch()..start();
  final stable = Stopwatch();
  while (deadline.elapsed < const Duration(seconds: 15)) {
    if (binding.lifecycleState == AppLifecycleState.resumed) {
      if (!stable.isRunning) stable.start();
      if (stable.elapsed >= const Duration(milliseconds: 200)) return;
    } else {
      stable
        ..stop()
        ..reset();
    }
    // Android may present the first Flutter frame before its window/input
    // connection has focus. Observe foreground readiness before any search tap.
    await tester.pump(const Duration(milliseconds: 50));
  }
  fail(
    'Native window did not remain resumed; state: ${binding.lifecycleState}',
  );
}

Future<void> _waitForKeyboard(
  WidgetTester tester, {
  required bool visible,
}) async {
  final watch = Stopwatch()..start();
  var previousInset = -1.0;
  var stableSamples = 0;
  while (watch.elapsed < const Duration(seconds: 8)) {
    await tester.pump(const Duration(milliseconds: 50));
    final inset = tester.view.viewInsets.bottom;
    final matches = visible ? inset > 0 : inset == 0;
    stableSamples = matches && (inset - previousInset).abs() < .5
        ? stableSamples + 1
        : 0;
    if (stableSamples >= 3) return;
    previousInset = inset;
  }
  fail('Native IME did not reach visible=$visible; last inset: $previousInset');
}
