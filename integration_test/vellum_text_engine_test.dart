import 'dart:developer' show Timeline;
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show FramePhase, FrameTiming, TimingsCallback;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vellum/all_formats.dart';

import '../test/support/device_screenshots.dart';

/// vellum's text engine on a device with the app's fonts: real books are
/// prepared, laid out and paginated at the phone's page size, chapter by
/// chapter, with the time each step takes; the first pages of a few
/// chapters are captured. Then a page of the first book is selected with
/// the platform's gestures, handles and magnifier, the selection's
/// details (CFI, words, sentence) are reported, and the book is searched.
///
/// Books come from `--dart-define=VELLUM_BOOKS=/path/a.epub|/path/b.fb2`:
/// the iOS simulator reads host paths; on Android push the books first
/// (`adb push a.epub /data/local/tmp/vellum/`) and pass the device paths.
/// The iOS simulator runs debug builds only. Android can also run
/// `--profile`; neither simulator nor emulator timings establish a
/// physical phone's latency or frame budget. The report separates file
/// opening, section preparation, image probing, initial layout and full
/// layout/pagination, with process RSS after each book and the run's peak.
/// `--dart-define=VELLUM_PERF_SCREENSHOTS=false` excludes screenshot work
/// and retained image payloads from performance-only runs.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const books = String.fromEnvironment('VELLUM_BOOKS');
  const captureScreenshots = bool.fromEnvironment(
    'VELLUM_PERF_SCREENSHOTS',
    defaultValue: true,
  );

  testWidgets(
    'real books lay out within the chapter budget',
    (tester) async {
      final paths = books.split('|').where((p) => p.isNotEmpty).toList();
      if (paths.isEmpty) {
        markTestSkipped('pass VELLUM_BOOKS');
        return;
      }
      final view = tester.view;
      final screen = view.physicalSize / view.devicePixelRatio;
      final side = (screen.width * 0.06).roundToDouble();
      final pageWidth = screen.width - 2 * side;
      final pageHeight = screen.height - 140;
      const fonts = BookFonts(
        serif: 'Literata',
        sansSerif: 'Open Sans',
        fallback: ['Noto Sans Symbols'],
      );
      const style = BookStyle(fontScale: 1.2, fontFamily: 'Literata');

      final results = <Map<String, Object>>[];
      for (final path in paths) {
        final name = path.split('/').last;
        final fileBytes = await File(path).length();
        final open = Stopwatch()..start();
        final book = await tester.runAsync(() => _open(path));
        open.stop();
        final rssAfterOpenBytes = ProcessInfo.currentRss;
        final source = textBookSourceOf(book!);
        final images = BookImageCache(read: source.readImage);
        final preparer = SectionPreparer(source);
        final chapters = <Map<String, Object>>[];
        var screenshots = 0;
        for (var i = 0; i < source.sectionCount && chapters.length < 30; i++) {
          if (!source.isLinear(i)) continue;
          final watch = Stopwatch()..start();
          final section = (await tester.runAsync(
            () => preparer.prepare(i, style),
          ))!;
          watch.stop();
          final prepareUs = watch.elapsedMicroseconds;
          watch
            ..reset()
            ..start();
          await tester.runAsync(() => images.probe(section.imageKeys.values));
          watch.stop();
          final imageProbeUs = watch.elapsedMicroseconds;
          watch
            ..reset()
            ..start();
          final task = ColumnLayoutTask(
            section.boxes,
            width: pageWidth,
            pageHeight: pageHeight,
            bookStyle: style,
            text: TextLayoutEnvironment(
              styler: InlineStyler(bookStyle: style, fonts: fonts),
              imageSize: (src) {
                final key = section.imageKeys[src];
                return key == null ? null : images.sizeOf(key);
              },
              maxImageHeight: pageHeight,
            ),
          );
          // What the reader waits for: the first page decided.
          task.advance(untilHeight: pageHeight * 2);
          final firstPageUs = watch.elapsedMicroseconds;
          task.advance();
          final column = task.column;
          watch.stop();
          final layoutUs = watch.elapsedMicroseconds;
          watch
            ..reset()
            ..start();
          final pages = paginateColumn(column, pageHeight: pageHeight);
          watch.stop();
          final paginateUs = watch.elapsedMicroseconds;
          final textLength = section.boxes.paragraphs.fold<int>(
            0,
            (n, p) => n + p.text.length,
          );
          chapters.add({
            'section': i,
            'textChars': textLength,
            'paragraphs': column.paragraphs.length,
            'pages': pages.length,
            'prepareMs': prepareUs / 1000,
            'imageProbeMs': imageProbeUs / 1000,
            'firstPageMs': firstPageUs / 1000,
            'prepareToFirstPageMs':
                (prepareUs + imageProbeUs + firstPageUs) / 1000,
            'layoutMs': layoutUs / 1000,
            'paginateMs': paginateUs / 1000,
          });
          if (captureScreenshots && screenshots < 2 && textLength > 2000) {
            await tester.pumpWidget(
              _Page(
                column: column,
                page: pages.first,
                images: images,
                imageKeys: section.imageKeys,
                side: side,
              ),
            );
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 300)),
            );
            await tester.pump();
            await takeDeviceScreenshot(
              binding,
              'vellum-${_slug(name)}-s$i-p1',
            );
            screenshots++;
          }
          column.dispose();
        }
        images.dispose();
        await tester.runAsync(source.close);
        results.add({
          'book': name,
          'fileBytes': fileBytes,
          'openMs': open.elapsedMicroseconds / 1000,
          'rssAfterOpenBytes': rssAfterOpenBytes,
          'chapters': chapters,
          ..._summary(chapters),
          // What the process holds once the book is closed.
          'rssMb': _mb(ProcessInfo.currentRss),
          'maxRssBytes': ProcessInfo.maxRss,
        });
        debugPrint('VELLUM ${_summary(chapters)} $name');
      }
      // The binding keeps the screenshots in the report: add to it.
      binding.reportData = {
        ...?binding.reportData,
        'platform': Platform.operatingSystem,
        'mode': kReleaseMode
            ? 'release'
            : kProfileMode
            ? 'profile'
            : 'debug',
        'maxRssMb': _mb(ProcessInfo.maxRss),
        'screenshotsEnabled': captureScreenshots,
        'page': {'width': pageWidth, 'height': pageHeight},
        'books': results,
      };
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );

  testWidgets('a page selects with the platform handles', (tester) async {
    final path = books
        .split('|')
        .firstWhere(
          (p) => p.isNotEmpty,
          orElse: () => '',
        );
    if (path.isEmpty) {
      markTestSkipped('pass VELLUM_BOOKS');
      return;
    }
    final view = tester.view;
    final screen = view.physicalSize / view.devicePixelRatio;
    final side = (screen.width * 0.06).roundToDouble();
    final pageWidth = screen.width - 2 * side;
    final pageHeight = screen.height - 140;
    const fonts = BookFonts(serif: 'Literata', sansSerif: 'Open Sans');
    const style = BookStyle(fontScale: 1.2, fontFamily: 'Literata');
    final book = await tester.runAsync(() => _open(path));
    final source = textBookSourceOf(book!);
    final images = BookImageCache(read: source.readImage);
    final preparer = SectionPreparer(source);
    PreparedSection? section;
    for (var i = 0; i < source.sectionCount; i++) {
      final s = (await tester.runAsync(() => preparer.prepare(i, style)))!;
      final chars = s.boxes.paragraphs.fold<int>(
        0,
        (n, p) => n + p.text.length,
      );
      if (source.isLinear(i) && chars > 3000) {
        section = s;
        break;
      }
    }
    final column = ColumnLayout.layout(
      section!.boxes,
      width: pageWidth,
      pageHeight: pageHeight,
      bookStyle: style,
      text: TextLayoutEnvironment(
        styler: InlineStyler(bookStyle: style, fonts: fonts),
        imageSize: (_) => null,
        maxImageHeight: pageHeight,
      ),
    );
    final page = paginateColumn(column, pageHeight: pageHeight).first;
    final padding = EdgeInsets.fromLTRB(side, 90, side, 50);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: SelectionArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: TextColumnPage(
                column: column,
                page: page,
                images: images,
                imageKey: (src) => section!.imageKeys[src],
                padding: padding,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final render = tester.renderObject<RenderTextColumnPage>(
      find.byType(TextColumnPage),
    );
    final texts = render.debugSelectables;
    final longest = texts.reduce(
      (a, b) => a.end - a.start >= b.end - b.start ? a : b,
    );
    Offset wordIn(PageParagraphSelectable s, double at) {
      final paragraph = s.item.paragraph;
      final offset = s.start + ((s.end - s.start) * at).round();
      final box = paragraph.boxesFor(offset, offset + 1).first.toRect();
      return render.localToGlobal(s.origin + box.center);
    }

    await tester.longPressAt(wordIn(longest, 0.4));
    await tester.pumpAndSettle();
    if (captureScreenshots) {
      await takeDeviceScreenshot(binding, 'vellum-selection-word');
    }
    // From the first paragraph into the third (or the last there is).
    final gesture = await tester.startGesture(wordIn(texts.first, 0.5));
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveTo(wordIn(texts[math.min(2, texts.length - 1)], 0.4));
    await tester.pump(const Duration(milliseconds: 200));
    if (captureScreenshots) {
      await takeDeviceScreenshot(binding, 'vellum-selection-drag');
    }
    await gesture.up();
    await tester.pumpAndSettle();
    if (captureScreenshots) {
      await takeDeviceScreenshot(binding, 'vellum-selection-range');
    }
    final selection = render.selection!;
    final details = TextSelectionDetails.of(
      section,
      TextPointRange(selection.start, selection.end),
      sectionCfi: source.sectionCfi(section.index),
      text: selection.text,
    );
    final locator = TextLocator(
      section,
      column,
      sectionCfi: source.sectionCfi(section.index),
    );
    final report = {
      'text': details.text,
      'cfi': details.cfi,
      'kind': details.kind.wireName,
      'normalizedText': details.normalizedText,
      'contextText': details.contextText,
      'markedContextText': details.markedContextText,
      'cfiOnPage': page.contains(locator.yOfCfi(details.cfi) ?? -1),
    };
    debugPrint('VELLUM selection $report');
    // A whole-book search for a common word, in background isolates.
    final watch = Stopwatch()..start();
    var hits = 0;
    var firstResultMs = -1;
    await tester.runAsync(() async {
      await for (final event in searchTextBook(source, 'the')) {
        if (event is TextSearchResults) {
          if (firstResultMs < 0) firstResultMs = watch.elapsedMilliseconds;
          hits += event.hits.length;
        }
      }
    });
    final search = {
      'query': 'the',
      'sections': source.sectionCount,
      'hits': hits,
      'firstResultMs': firstResultMs,
      'totalMs': watch.elapsedMilliseconds,
    };
    debugPrint('VELLUM search $search');
    binding.reportData = {
      ...?binding.reportData,
      'selection': report,
      'search': search,
    };
    column.dispose();
    images.dispose();
    await tester.runAsync(source.close);
  });

  testWidgets('a book reads page by page in the page view', (tester) async {
    final path = books
        .split('|')
        .firstWhere(
          (p) => p.isNotEmpty,
          orElse: () => '',
        );
    if (path.isEmpty) {
      markTestSkipped('pass VELLUM_BOOKS');
      return;
    }
    final framePolicy = binding.framePolicy;
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
    addTearDown(() => binding.framePolicy = framePolicy);
    const fonts = BookFonts(serif: 'Literata', sansSerif: 'Open Sans');
    const style = BookStyle(fontScale: 1.2, fontFamily: 'Literata');
    final book = await tester.runAsync(() => _open(path));
    final source = textBookSourceOf(book!);
    final images = BookImageCache(read: source.readImage);
    final watch = Stopwatch()..start();
    final controller = TextPagesController(
      source: source,
      style: style,
      fonts: fonts,
      images: images,
      settings: const TextPageSettings(topMargin: 70, bottomMargin: 50),
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: TextPagesView(controller: controller),
      ),
    );
    Future<void> settle(
      bool Function() done, {
      required String description,
    }) async {
      for (var i = 0; i < 600 && !done(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(done(), isTrue, reason: 'Timed out waiting for $description');
    }

    await settle(
      () => find.byType(TextColumnPage).evaluate().isNotEmpty,
      description: 'the first mounted page',
    );
    final firstSpreadMs = watch.elapsedMilliseconds;
    if (captureScreenshots) {
      await takeDeviceScreenshot(binding, 'vellum-pages-open');
    }
    final turns = <int>[];
    final positions = <String>[];
    // The engine's frame timings over the turns (build and raster per
    // frame, frames over budget); the turn times include the test's fling.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1100)),
    );
    final frames = <FrameTiming>[];
    final turnWindows = <(int, int)>[];
    final TimingsCallback watchFrames = frames.addAll;
    binding.addTimingsCallback(watchFrames);
    try {
      for (var i = 0; i < 12; i++) {
        await settle(
          () => controller.spreadAt(1) != null,
          description: 'the next spread before turn ${i + 1}',
        );
        final before = controller.position;
        final startedUs = Timeline.now;
        final turn = Stopwatch()..start();
        await tester.fling(
          find.byType(TextPagesView),
          Offset(controller.rtl ? 200 : -200, 0),
          1500,
        );
        await settle(
          () => controller.position != before,
          description: 'turn ${i + 1} from $before',
        );
        await tester.pumpAndSettle(const Duration(milliseconds: 16));
        turn.stop();
        turnWindows.add((startedUs, Timeline.now));
        turns.add(turn.elapsedMilliseconds);
        positions.add('${controller.position}');
        if (captureScreenshots && i == 2) {
          await takeDeviceScreenshot(binding, 'vellum-pages-turned');
        }
      }
      // Callbacks are batched: flush, then keep only each action's frames.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1100)),
      );
    } finally {
      binding.removeTimingsCallback(watchFrames);
    }
    final turnFrames = frames.where((timing) {
      final start = timing.timestampInMicroseconds(FramePhase.buildStart);
      return turnWindows.any(
        (window) => start >= window.$1 && start <= window.$2,
      );
    }).toList();
    expect(
      turnFrames,
      isNotEmpty,
      reason: 'Native frame timings are required for page-turn measurements',
    );

    const middleFraction = 0.5;
    final progress = SectionProgress(
      [for (var i = 0; i < source.sectionCount; i++) source.sectionSize(i)],
      linear: [
        for (var i = 0; i < source.sectionCount; i++) source.isLinear(i),
      ],
    );
    final (targetSection, inSection) = progress.section(middleFraction);
    final beforeMiddle = controller.position;
    final resumeMiddle = Stopwatch()..start();
    final middleTarget = await tester.runAsync(() async {
      await controller.goToFraction(middleFraction);
      return controller.position;
    });
    expect(
      middleTarget,
      isNotNull,
      reason: 'middle navigation returns a position',
    );
    expect(middleTarget!.section, targetSection);
    expect(middleTarget.spreadCount, isNotNull);
    final spreadCount = middleTarget.spreadCount!;
    final targetSpread = math.min(
      spreadCount - 1,
      (inSection * spreadCount).floor(),
    );
    expect(middleTarget.spread, targetSpread);
    await tester.pump();
    await settle(
      () =>
          controller.isReady &&
          controller.position?.section == targetSection &&
          controller.position?.spread == targetSpread,
      description: 'middle section $targetSection spread $targetSpread',
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 16));
    resumeMiddle.stop();
    expect(controller.error, isNull);
    if (captureScreenshots) {
      await takeDeviceScreenshot(binding, 'vellum-pages-middle');
    }
    final report = {
      'firstSpreadMs': firstSpreadMs,
      'turnMs': turns,
      'positions': positions,
      'resumeMiddleMs': resumeMiddle.elapsedMicroseconds / 1000,
      'middleNavigationSucceeded': true,
      'middleRequestedFraction': middleFraction,
      'middleTargetSection': targetSection,
      'middleTargetSpread': targetSpread,
      'beforeMiddle': '$beforeMiddle',
      'middle': '${controller.position}',
    };
    debugPrint('VELLUM pages $report');
    binding.reportData = {
      ...?binding.reportData,
      'pages': report,
      'turnFrames': FrameTimingSummarizer(turnFrames).summary,
      'turnFrameRefreshRateHz': tester.view.display.refreshRate,
      'turnFrameWindows': [
        for (final (start, end) in turnWindows)
          {'startedAtMonotonicUs': start, 'endedAtMonotonicUs': end},
      ],
      'turnFrameSamples': [
        for (final timing in turnFrames)
          {
            'vsyncStartUs': timing.timestampInMicroseconds(
              FramePhase.vsyncStart,
            ),
            'buildStartUs': timing.timestampInMicroseconds(
              FramePhase.buildStart,
            ),
            'buildUs': timing.buildDuration.inMicroseconds,
            'rasterUs': timing.rasterDuration.inMicroseconds,
            'totalSpanUs': timing.totalSpan.inMicroseconds,
          },
      ],
    };
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    images.dispose();
    await tester.runAsync(source.close);
  });
}

Future<Object> _open(String path) async {
  final lower = path.toLowerCase();
  if (lower.endsWith('.epub')) return EpubBook.open(path);
  if (lower.endsWith('.fb2') || lower.endsWith('.fb2.zip')) {
    return Fb2Book.open(path);
  }
  return MobiBook.open(path);
}

String _slug(String name) {
  final slug = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return slug.isEmpty ? 'book' : slug.substring(0, math.min(30, slug.length));
}

/// Per-book statistics, with layout normalised to 100 000 characters of
/// text, the budget's unit.
Map<String, Object> _summary(List<Map<String, Object>> chapters) {
  if (chapters.isEmpty) return {'chapters': 0};
  double percentile(List<double> values, double p) {
    final sorted = [...values]..sort();
    return sorted[((sorted.length - 1) * p).round()];
  }

  final layout = [for (final c in chapters) c['layoutMs']! as double];
  final prepare = [for (final c in chapters) c['prepareMs']! as double];
  final firstPage = [for (final c in chapters) c['firstPageMs']! as double];
  final imageProbe = [for (final c in chapters) c['imageProbeMs']! as double];
  final per100k = [
    for (final c in chapters)
      if ((c['textChars']! as int) > 5000)
        (c['layoutMs']! as double) * 100000 / (c['textChars']! as int),
  ];
  String ms(double v) => v.toStringAsFixed(1);
  return {
    'count': chapters.length,
    'layoutMedianMs': ms(percentile(layout, 0.5)),
    'layoutMaxMs': ms(layout.reduce(math.max)),
    'firstPageMedianMs': ms(percentile(firstPage, 0.5)),
    'firstPageMaxMs': ms(firstPage.reduce(math.max)),
    'prepareMedianMs': ms(percentile(prepare, 0.5)),
    'prepareMaxMs': ms(prepare.reduce(math.max)),
    'imageProbeMedianMs': ms(percentile(imageProbe, 0.5)),
    'imageProbeMaxMs': ms(imageProbe.reduce(math.max)),
    if (per100k.isNotEmpty)
      'layoutPer100kCharsMedianMs': ms(percentile(per100k, 0.5)),
  };
}

class _Page extends StatelessWidget {
  const _Page({
    required this.column,
    required this.page,
    required this.images,
    required this.imageKeys,
    required this.side,
  });

  final ColumnLayout column;
  final ColumnPage page;
  final BookImageCache images;
  final Map<String, String> imageKeys;
  final double side;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: ColoredBox(
      color: Colors.white,
      child: Align(
        alignment: Alignment.topLeft,
        child: TextColumnPage(
          column: column,
          page: page,
          images: images,
          imageKey: (src) => imageKeys[src],
          padding: EdgeInsets.fromLTRB(side, 90, side, 50),
        ),
      ),
    ),
  );
}

/// [bytes] in mebibytes, one decimal.
String _mb(int bytes) => (bytes / (1 << 20)).toStringAsFixed(1);
