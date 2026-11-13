import 'dart:developer' show Timeline;
import 'dart:io';
import 'dart:ui' show FramePhase;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show EditableText;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pagecraft/all_formats.dart' show TextPagesView;
import 'package:readflex/app/routing.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import '../test/support/native_screenshots.dart';
import '../test/support/ui_test_app.dart';
import '../test/support/ui_test_driver.dart';

/// Native font/IME/surface inspection complements portable widget goldens.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native surfaces retain navigation, editing and reading', (
    tester,
  ) async {
    final app = await UiTestApp.create(withBook: true);
    addTearDown(app.dispose);
    await app.bookRepository.markOpened(app.book!.id, DateTime(2026, 11, 12));
    await app.bookRepository.updateReadingPosition(
      app.book!.id,
      cfi: null,
      progress: .42,
    );
    tester.platformDispatcher.defaultRouteNameTestValue = '/';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(app.widget);
    final card = find.byKey(const ValueKey('libraryContinueReadingCard'));
    await waitForUi(
      tester,
      () => card.evaluate().isNotEmpty,
      description: 'native Library fixture',
    );
    final logicalSize = tester.view.physicalSize / tester.view.devicePixelRatio;
    final profile =
        '${Platform.operatingSystem}-${logicalSize.width >= 840 ? 'tablet' : 'phone'}';
    Future<void> capture(String scene, {VoidCallback? verifyReady}) async {
      await tester.pumpAndSettle();
      // Flutter's frame completes before the OS compositor presents it.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      // IME metrics may arrive during that native pause. Lay out the updated
      // window before giving the OS another presentation opportunity.
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 32)),
      );
      verifyReady?.call();
      await captureNativeScreenshot('$profile-$scene');
    }

    await capture('library');
    await tapUi(
      tester,
      find.byKey(const ValueKey('libraryHeaderDisplayButton')),
    );
    await capture('display');
    var strings = tester.element(card).l10n;
    await tapUi(tester, find.byTooltip(strings.commonClose).hitTestable());

    await tester.longPress(card);
    await tester.pumpAndSettle();
    await capture('selection');
    await tapUi(
      tester,
      find.byKey(const ValueKey('libraryDeleteSelectedButton')),
    );
    final cancelDeletion = find.byKey(
      const ValueKey('appConfirmationCancel'),
    );
    await waitForUi(
      tester,
      () => cancelDeletion.evaluate().isNotEmpty,
      description: 'native deletion confirmation',
    );
    await capture('delete-confirmation');
    await tapUi(tester, cancelDeletion);
    await tapUi(
      tester,
      find.byKey(const ValueKey('libraryCancelSelectionFab')),
    );

    // Warm the editor and keyboard before sampling repeated transitions.
    final search = find.byKey(const ValueKey('librarySearchButton'));
    final action = find.byKey(const ValueKey('libraryCapsuleActionButton'));
    await tapUi(tester, search);
    await tapUi(tester, action);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1100)),
    );
    final frames = <FrameTiming>[];
    void recordFrames(List<FrameTiming> batch) => frames.addAll(batch);
    SchedulerBinding.instance.addTimingsCallback(recordFrames);
    final startedUs = Timeline.now;
    late int endedUs;
    try {
      for (var i = 0; i < 5; i++) {
        await tapUi(tester, search);
        expect(find.byType(AppTextField), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 120));
        await tapUi(tester, action);
        expect(card, findsOneWidget);
      }
      await tester.pump(const Duration(milliseconds: 200));
      endedUs = Timeline.now;
      // Match the other native benchmarks: callbacks arrive in batches.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1100)),
      );
    } finally {
      SchedulerBinding.instance.removeTimingsCallback(recordFrames);
    }
    final transitionFrames = frames.where((frame) {
      final start = frame.timestampInMicroseconds(FramePhase.buildStart);
      return start >= startedUs && start <= endedUs;
    }).toList();
    await tapUi(tester, search);
    await _waitForNativeKeyboard(tester);
    await capture(
      'search',
      verifyReady: () {
        final field = find.byKey(const ValueKey('librarySearchField'));
        final fieldBounds = tester.getRect(field);
        final capsuleBounds = tester.getRect(
          find.byKey(const ValueKey('libraryFloatingActions')),
        );
        final inset = tester.view.viewInsets.bottom;
        final ratio = tester.view.devicePixelRatio;
        final keyboardTop = (tester.view.physicalSize.height - inset) / ratio;
        final editable = tester.widget<EditableText>(
          find.descendant(of: field, matching: find.byType(EditableText)),
        );
        binding.reportData ??= {};
        binding.reportData!['searchKeyboard'] = {
          'insetPhysical': inset,
          'insetLogical': inset / ratio,
          'keyboardTop': keyboardTop,
          'fieldBounds': [
            fieldBounds.left,
            fieldBounds.top,
            fieldBounds.right,
            fieldBounds.bottom,
          ],
          'capsuleBounds': [
            capsuleBounds.left,
            capsuleBounds.top,
            capsuleBounds.right,
            capsuleBounds.bottom,
          ],
          'focused': editable.focusNode.hasFocus,
        };
        expect(inset, greaterThan(0), reason: 'native IME must remain visible');
        expect(editable.focusNode.hasFocus, isTrue);
        expect(field.hitTestable(), findsOneWidget);
        expect(fieldBounds.bottom, lessThanOrEqualTo(keyboardTop));
        expect(capsuleBounds.bottom, lessThanOrEqualTo(keyboardTop));
      },
    );
    await tapUi(tester, action);
    await tapUi(tester, card);
    final pages = find.byType(TextPagesView);
    await waitForUi(
      tester,
      () =>
          pages.evaluate().isNotEmpty &&
          tester.widget<TextPagesView>(pages).controller.isReady,
      description: 'native reader fixture',
    );
    strings = tester.element(pages).l10n;
    if (find
        .byTooltip(strings.readerFontAction)
        .hitTestable()
        .evaluate()
        .isEmpty) {
      await tester.tapAt(tester.getCenter(pages));
      await tester.pumpAndSettle();
    }
    await capture('reader-chrome');
    await tapUi(tester, find.byTooltip(strings.readerFontAction));
    await capture('appearance');
    await tapUi(tester, find.byKey(const ValueKey('reader-font-picker')));
    await capture('font');
    await tester.ensureVisible(
      find.byKey(const ValueKey('reader-font-geist')),
    );
    await capture('font-scrolled');
    await tapUi(tester, find.byTooltip(strings.commonBack).hitTestable());
    final lastControl =
        find
            .byKey(const ValueKey('reader-columns-control'))
            .evaluate()
            .isNotEmpty
        ? find.byKey(const ValueKey('reader-columns-control'))
        : find.byKey(const ValueKey('reader-page-turn-control'));
    await tester.ensureVisible(lastControl);
    await capture('appearance-scrolled');
    await tapUi(tester, find.byTooltip(strings.commonClose).hitTestable());
    await tapUi(tester, find.byTooltip(strings.readerContents));
    await capture('contents');
    await unmountUi(tester);
    const passage =
        'Returning to a passage should leave room to read the whole thought. '
        'A calm page keeps attention on the text and makes it easy to return '
        'to the source.';
    await app.highlightRepository.addHighlight(
      sourceId: app.book!.id,
      sourceType: SourceType.book,
      text: List.filled(12, passage).join('\n\n'),
      chapterTitle: 'Chapter One',
      note: 'The end of the saved note.',
    );
    await tester.pumpWidget(app.widgetAt(AppRoutes.practiceReview));
    final quote = find.byKey(const ValueKey('reviewQuote'));
    await waitForUi(
      tester,
      () => quote.evaluate().isNotEmpty,
      description: 'native Highlight fixture',
    );
    await capture('highlight');
    final source = tester.getRect(find.byKey(const ValueKey('reviewLocation')));
    final footer = tester.getRect(
      find.byKey(const ValueKey('reviewControlsPanel')),
    );
    await tester.drag(
      find.byKey(const ValueKey('reviewCardViewport')),
      const Offset(0, -350),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const ValueKey('reviewLocation'))),
      source,
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('reviewControlsPanel'))),
      footer,
    );
    await capture('highlight-scrolled');
    await tapUi(tester, find.byKey(const ValueKey('reviewRate-keep')));
    final done = find.byKey(const ValueKey('reviewDone'));
    await waitForUi(
      tester,
      () => done.evaluate().isNotEmpty,
      description: 'native session completion',
    );
    expect(tester.getCenter(done).dy, greaterThan(logicalSize.height * .66));
    await capture('completion');
    expect(tester.takeException(), isNull);
    binding.reportData ??= {};
    binding.reportData!.addAll({
      'platform': Platform.operatingSystem,
      'mode': kProfileMode ? 'profile' : 'debug',
      'logicalSize': {'width': logicalSize.width, 'height': logicalSize.height},
      // Emulator timings describe this run, not physical-device frame rates.
      'searchTransitions': {
        'cycles': 5,
        'samplePolicy': 'buildStart within the warmed transition window',
        'frames': transitionFrames.length,
        'buildMicros': _timingSummary(
          transitionFrames.map((f) => f.buildDuration),
        ),
        'rasterMicros': _timingSummary(
          transitionFrames.map((f) => f.rasterDuration),
        ),
      },
    });
    await unmountUi(tester);
  });
}

Future<void> _waitForNativeKeyboard(WidgetTester tester) async {
  final observation = Stopwatch()..start();
  var previousInset = 0.0;
  var stableSamples = 0;
  while (observation.elapsed < const Duration(seconds: 8)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    final inset = tester.view.viewInsets.bottom;
    stableSamples = inset > 0 && (inset - previousInset).abs() < .5
        ? stableSamples + 1
        : 0;
    if (stableSamples >= 3) return;
    previousInset = inset;
  }
  fail('Native IME did not open and stabilize; last inset: $previousInset');
}

Map<String, int> _timingSummary(Iterable<Duration> durations) {
  final values = durations.map((d) => d.inMicroseconds).toList()..sort();
  if (values.isEmpty) return {};
  return {
    'p50': values[((values.length - 1) * .5).round()],
    'p95': values[((values.length - 1) * .95).round()],
    'max': values.last,
  };
}
