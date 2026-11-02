import 'dart:developer' show Timeline;
import 'dart:io';
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/foundation.dart' show kDebugMode, kProfileMode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:library_feature/src/library_continue_reading_card.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:pagecraft/article.dart';

import '../test/support/reading_fixture.dart';
import '../test/support/ui_test_app.dart';
import '../test/support/ui_test_driver.dart' show unmountUi;

/// Opt-in saved-article measurements through the production Library/router
/// and reader, against isolated storage. Excludes network extraction and the
/// real application bootstrap. Run on a device with `flutter drive --profile`.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const repeats = int.fromEnvironment(
    'PAGECRAFT_PERF_REPEATS',
    defaultValue: 3,
  );

  testWidgets(
    'measures saving, opening, scrolling and searching an article',
    (
      tester,
    ) async {
      expect(repeats, greaterThan(0));
      final runs = <Map<String, Object?>>[];
      final framePolicy = binding.framePolicy;
      binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
      addTearDown(() => binding.framePolicy = framePolicy);
      tester.platformDispatcher.defaultRouteNameTestValue = '/';
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);

      for (var run = 0; run < repeats; run++) {
        final app = (await tester.runAsync(
          () => UiTestApp.create(withBook: false),
        ))!;
        try {
          final extracted = ReadingFixture.article;
          final beforeSave = _rss();
          final saved = (await tester.runAsync(() async {
            final watch = Stopwatch()..start();
            final article = await app.articleRepository.addExtractedArticle(
              extracted,
            );
            watch.stop();
            return (article, watch.elapsedMicroseconds);
          }))!;
          final (article, saveUs) = saved;
          final afterSave = _rss();

          await tester.pumpWidget(app.widget);
          final beforeOpen = _rss();
          final openUs = await _openArticle(tester, article.id);
          final afterOpen = _rss();
          final controller = _controller(tester);
          await tester.pumpAndSettle();
          expect(controller.maxScroll, greaterThan(0));

          final beforeScroll = _rss();
          final scrolling = await _measureScrolling(
            tester,
            binding,
            controller,
          );
          final afterScroll = _rss();

          final beforeSearch = _rss();
          final indexWatch = Stopwatch()..start();
          final index = ArticleIndex.of(controller.section!.prepared.document);
          indexWatch.stop();
          final search = (await tester.runAsync(() => _measureSearch(index)))!;
          expect(search['hits'], 24);
          final afterSearch = _rss();

          // Set an explicit saved fraction outside timing; reopen measures the
          // production restore path without relying on position-write debounce.
          final reader = tester
              .element(find.byType(TextScrollView))
              .read<ReaderBloc>();
          await unmountUi(tester);
          await tester.runAsync(reader.close);
          await tester.runAsync(
            () => app.articleRepository.updateReadingPosition(
              article.id,
              cfi: null,
              progress: 0.5,
            ),
          );
          await tester.pumpWidget(app.widget);
          final beforeReopen = _rss();
          final reopenUs = await _openArticle(tester, article.id);
          final restored = _controller(tester).position!;
          expect(restored.fraction, closeTo(0.5, 0.05));

          runs.add({
            'run': run + 1,
            'processState': run == 0 ? 'first-in-process' : 'warm-in-process',
            'saveUs': saveUs,
            'libraryTapToPositionUs': openUs,
            'middleReopenTapToPositionUs': reopenUs,
            'restoredFraction': restored.fraction,
            'articleBytes': await File(article.contentHtmlPath).length(),
            'articleTextCharacters': extracted.plainText.length,
            'sentences': index.sentences.length,
            'indexBuildUs': indexWatch.elapsedMicroseconds,
            'engineSearch': search,
            'scrolling': scrolling,
            'rss': {
              'beforeSave': beforeSave,
              'afterSave': afterSave,
              'beforeOpen': beforeOpen,
              'afterOpen': afterOpen,
              'beforeScroll': beforeScroll,
              'afterScroll': afterScroll,
              'beforeSearch': beforeSearch,
              'afterSearch': afterSearch,
              'beforeReopen': beforeReopen,
              'afterReopen': _rss(),
            },
          });
        } finally {
          await unmountUi(tester);
          await tester.runAsync(app.dispose);
        }
      }

      final view = tester.view;
      binding.reportData = {
        ...?binding.reportData,
        'articlePerformance': {
          'schemaVersion': 1,
          'generatedAt': DateTime.now().toUtc().toIso8601String(),
          'platform': Platform.operatingSystem,
          'platformVersion': Platform.operatingSystemVersion,
          'dartVersion': Platform.version,
          'mode': kDebugMode ? 'debug' : (kProfileMode ? 'profile' : 'release'),
          'repeats': repeats,
          'viewport': {
            'width': view.physicalSize.width / view.devicePixelRatio,
            'height': view.physicalSize.height / view.devicePixelRatio,
            'devicePixelRatio': view.devicePixelRatio,
            'displayRefreshRate': view.display.refreshRate,
          },
          'scope': {
            'storage': 'temporary files and in-memory SQLite per repeat',
            'content': 'offline ReadingFixture.article; no images',
            'open': 'direct Library tap to mounted controller position',
            'pollIntervalMs': 8,
            'search': 'laid-out article engine; excludes UI debounce and marks',
            'excluded': [
              'network extraction',
              'real application bootstrap',
              'OS disk-cache coldness',
            ],
            'rss': 'whole process; peak is cumulative across repeats',
          },
          'runs': runs,
        },
      };
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

TextScrollController _controller(WidgetTester tester) =>
    tester.widget<TextScrollView>(find.byType(TextScrollView)).controller;

Future<int> _openArticle(WidgetTester tester, String id) async {
  final target = find.byWidgetPredicate(
    (widget) =>
        widget is LibraryContinueReadingCard ||
        widget.key == ValueKey('library-grid-$id') ||
        widget.key == ValueKey('library-row-$id'),
  );
  await _waitFor(
    tester,
    () => target.hitTestable().evaluate().isNotEmpty,
    'article in the Library',
  );
  final watch = Stopwatch()..start();
  await tester.tap(target.hitTestable().first);
  await tester.pump();
  await _waitFor(
    tester,
    () =>
        find.byType(TextScrollView).evaluate().isNotEmpty &&
        _controller(tester).position != null,
    'article position',
  );
  watch.stop();
  return watch.elapsedMicroseconds;
}

Future<void> _waitFor(
  WidgetTester tester,
  bool Function() ready,
  String description,
) async {
  final watch = Stopwatch()..start();
  while (!ready()) {
    if (watch.elapsed > const Duration(seconds: 30)) {
      fail('Timed out waiting for $description');
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 8)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull, reason: description);
  }
}

Future<Map<String, Object?>> _measureScrolling(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  TextScrollController controller,
) async {
  // Engine timing callbacks are batched. Flush outside the timed interval,
  // then select only frames whose build started during the scroll workload.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 1100)),
  );
  final timings = <FrameTiming>[];
  void record(List<FrameTiming> values) => timings.addAll(values);
  binding.addTimingsCallback(record);
  final startedUs = Timeline.now;
  final watch = Stopwatch()..start();
  final scrolls = <Map<String, Object?>>[];
  late int endedUs;
  try {
    for (var scroll = 0; scroll < 12; scroll++) {
      final before = controller.scroll.offset;
      final target =
          controller.scroll.position.maxScrollExtent *
          (scroll.isEven ? 0.85 : 0.15);
      final actionWatch = Stopwatch()..start();
      final animation = controller.scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 16));
      await animation;
      actionWatch.stop();
      scrolls.add({
        'from': before,
        'to': controller.scroll.offset,
        'elapsedUs': actionWatch.elapsedMicroseconds,
      });
    }
    watch.stop();
    endedUs = Timeline.now;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1100)),
    );
  } finally {
    binding.removeTimingsCallback(record);
  }
  final measured = timings.where((timing) {
    final start = timing.timestampInMicroseconds(FramePhase.buildStart);
    return start >= startedUs && start <= endedUs;
  }).toList();
  expect(
    measured,
    isNotEmpty,
    reason: 'Native frame timings are required for the scroll measurements',
  );
  final refreshRate = tester.view.display.refreshRate;
  final budgetUs = 1000000 / (refreshRate > 0 ? refreshRate : 60);
  final build = measured.map((t) => t.buildDuration.inMicroseconds).toList();
  final raster = measured.map((t) => t.rasterDuration.inMicroseconds).toList();
  return {
    'kind': '12 ScrollController.animateTo actions, 250ms easeInOut',
    'elapsedUs': watch.elapsedMicroseconds,
    'startedAtMonotonicUs': startedUs,
    'endedAtMonotonicUs': endedUs,
    'frameCount': measured.length,
    'frameBudgetUs': budgetUs,
    'build': _frameSummary(build, budgetUs),
    'raster': _frameSummary(raster, budgetUs),
    'actions': scrolls,
    'frames': [
      for (final timing in measured)
        {
          'vsyncStartUs': timing.timestampInMicroseconds(FramePhase.vsyncStart),
          'buildStartUs': timing.timestampInMicroseconds(FramePhase.buildStart),
          'buildUs': timing.buildDuration.inMicroseconds,
          'rasterUs': timing.rasterDuration.inMicroseconds,
          'totalSpanUs': timing.totalSpan.inMicroseconds,
        },
    ],
  };
}

Map<String, Object?> _frameSummary(List<int> values, double budgetUs) {
  if (values.isEmpty) return {'samples': 0};
  final sorted = [...values]..sort();
  return {
    'samples': values.length,
    'medianUs': sorted[(sorted.length * 0.5).ceil() - 1],
    'p95Us': sorted[(sorted.length * 0.95).ceil() - 1],
    'maxUs': sorted.last,
    'overBudget': values.where((value) => value > budgetUs).length,
  };
}

Future<Map<String, Object?>> _measureSearch(ArticleIndex index) async {
  final watch = Stopwatch()..start();
  int? firstHitsUs;
  var hits = 0;
  await for (final event in searchArticle(index, ReadingFixture.phrase)) {
    if (event is TextSearchResults && event.hits.isNotEmpty) {
      firstHitsUs ??= watch.elapsedMicroseconds;
      hits += event.hits.length;
    }
  }
  watch.stop();
  return {
    'query': ReadingFixture.phrase,
    'firstHitsUs': firstHitsUs,
    'doneUs': watch.elapsedMicroseconds,
    'hits': hits,
  };
}

Map<String, int> _rss() => {
  'currentBytes': ProcessInfo.currentRss,
  'peakBytes': ProcessInfo.maxRss,
};
