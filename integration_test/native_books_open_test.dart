import 'dart:io';

import 'package:domain_models/domain_models.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:import_flow/import_flow.dart' show importBookFile;
import 'package:integration_test/integration_test.dart';
import 'package:pagecraft/all_formats.dart';

import '../test/support/device_screenshots.dart';
import '../test/support/ui_test_app.dart';
import '../test/support/ui_test_driver.dart';

/// Every book format reads on pagecraft in the real app, never in the
/// WebView: each book of `--dart-define=PAGECRAFT_BOOKS=a|b|…` (EPUB, FB2,
/// MOBI, AZW3, CBZ or PDF) is imported into an empty library, opened from
/// its tile, shows its first page, turns one page and closes. Reports
/// metadata/cover extraction and persistence together as import time,
/// then tap-to-first-page-mounted time and process RSS. The isolated app
/// uses an in-memory SQLite DB and real temporary book/cover files.
///
/// `--dart-define=PAGECRAFT_PERF_REPEATS=3` repeats each book with a fresh
/// app. `--dart-define=PAGECRAFT_PERF_SCREENSHOTS=false` skips screenshots
/// and their image-settling delay. Repeats share the process and OS caches;
/// first-page-mounted time is not a physical first-pixel measurement.
///
/// `--dart-define=PAGECRAFT_AT=href|…` (in the books' order, empty to skip
/// one) then goes to that place of a book (a section href with an
/// optional `#id`) and saves a screenshot of it: what a layout change is
/// checked on.
///
/// The iOS simulator reads host paths; on Android pass paths pushed with
/// `adb push`. The tool splits `--dart-define` at commas: link files with
/// commas in their names under plain names first.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const books = String.fromEnvironment('PAGECRAFT_BOOKS');
  const places = String.fromEnvironment('PAGECRAFT_AT');
  const repeats = int.fromEnvironment(
    'PAGECRAFT_PERF_REPEATS',
    defaultValue: 1,
  );
  const screenshots = bool.fromEnvironment(
    'PAGECRAFT_PERF_SCREENSHOTS',
    defaultValue: true,
  );

  testWidgets(
    'every book opens and turns on pagecraft',
    (tester) async {
      final paths = books.split('|').where((p) => p.isNotEmpty).toList();
      if (paths.isEmpty) {
        markTestSkipped('pass PAGECRAFT_BOOKS');
        return;
      }
      expect(
        repeats,
        greaterThan(0),
        reason: 'PAGECRAFT_PERF_REPEATS must be positive',
      );
      tester.platformDispatcher.defaultRouteNameTestValue = '/';
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
      final report = <Map<String, Object?>>[];
      final targets = places.split('|');
      for (final (index, path) in paths.indexed) {
        final format = _formatOf(path);
        expect(format, isNotNull, reason: 'a book format: $path');
        final at = index < targets.length ? targets[index] : '';
        for (var repeat = 1; repeat <= repeats; repeat++) {
          report.add(
            await _openAndTurn(
              tester,
              binding,
              index,
              path,
              format!,
              repeat: repeat,
              screenshots: screenshots,
              at: at.isEmpty ? null : at,
            ),
          );
        }
      }
      for (final entry in report) {
        debugPrint('NATIVE BOOK $entry');
      }
      final view = tester.view;
      binding.reportData = {
        ...?binding.reportData,
        'nativeBooks': report,
        'nativeBooksEnvironment': {
          'platform': Platform.operatingSystem,
          'operatingSystemVersion': Platform.operatingSystemVersion,
          'runtime': Platform.version,
          'mode': kReleaseMode
              ? 'release'
              : kProfileMode
              ? 'profile'
              : 'debug',
          'viewport': {
            'width': view.physicalSize.width / view.devicePixelRatio,
            'height': view.physicalSize.height / view.devicePixelRatio,
            'devicePixelRatio': view.devicePixelRatio,
          },
          'repeats': repeats,
          'screenshots': screenshots,
          'storage': 'in-memory SQLite; real temporary book and cover files',
          'openMetric':
              'tap to first page mounted; 30 ms delay plus 30 ms pump per poll',
          'rssBytes': ProcessInfo.currentRss,
          'maxRssBytes': ProcessInfo.maxRss,
        },
      };
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}

/// Opens [path] in a fresh app, goes to [at] when given, turns a page
/// and closes it.
Future<Map<String, Object?>> _openAndTurn(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  int index,
  String path,
  BookFormat format, {
  required int repeat,
  required bool screenshots,
  String? at,
}) async {
  final app = await UiTestApp.create(withBook: false);
  try {
    final name = path.split('/').last;
    final file = File(path);
    final fileBytes = await file.length();
    final rssBeforeImportBytes = ProcessInfo.currentRss;
    var progressUpdates = 0;
    double? lastProgress;
    final importWatch = Stopwatch()..start();
    final book = await tester.runAsync(
      () => importBookFile(
        sourceFile: file,
        bookRepository: app.bookRepository,
        logger: app.logger,
        onProgress: (progress) {
          progressUpdates++;
          lastProgress = progress;
        },
      ),
    );
    importWatch.stop();
    expect(book, isNotNull, reason: 'imports $name');
    expect(book!.format, format, reason: 'imports the expected format');
    expect(
      lastProgress,
      1.0,
      reason: 'the import completes its byte-copy phase',
    );
    final rssAfterImportBytes = ProcessInfo.currentRss;
    await tester.pumpWidget(app.widget);

    final fixed = format == BookFormat.cbz || format == BookFormat.pdf;
    final page = fixed
        ? find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is FixedPagePainter,
          )
        : find.byType(TextColumnPage);
    final view = fixed
        ? find.byType(FixedPagesView)
        : find.byType(TextPagesView);
    // The engine's own place: a cover and the page after it can share
    // the reader's page numbers and chapter title.
    String? place() {
      if (fixed) {
        return '${tester.widget<FixedPagesView>(view).controller.page}';
      }
      final position = tester.widget<TextPagesView>(view).controller.position;
      return position == null ? null : '${position.section}:${position.spread}';
    }

    final tile = find.byKey(ValueKey('library-grid-${book.id}'));
    await waitForUi(
      tester,
      () => tile.hitTestable().evaluate().isNotEmpty,
      description: 'the library tile of $name',
    );
    final open = Stopwatch()..start();
    await tester.tap(tile.hitTestable().first);
    await tester.pump();
    await waitForUi(
      tester,
      () => page.evaluate().isNotEmpty && place() != null,
      description: 'the first page of $name',
      timeout: const Duration(seconds: 60),
    );
    open.stop();
    final openMs = open.elapsedMicroseconds / 1000;
    final rssAtFirstPageBytes = ProcessInfo.currentRss;
    final shot = 'native-book-${index.toString().padLeft(2, '0')}-run-$repeat';
    if (screenshots) {
      await _settleImages(tester);
      await takeDeviceScreenshot(binding, '$shot-${format.name}');
    } else {
      await tester.pumpAndSettle();
    }
    final rssMb = ProcessInfo.currentRss >> 20;
    if (at != null && !fixed) {
      final before = place();
      final moved = await tester.runAsync(
        () => tester.widget<TextPagesView>(view).controller.goToHref(at),
      );
      expect(moved, isTrue, reason: '$name at $at');
      await waitForUi(
        tester,
        () => place() != before,
        description: 'the page of $at',
        timeout: const Duration(seconds: 30),
      );
      if (screenshots) {
        await _settleImages(tester);
        await takeDeviceScreenshot(binding, '$shot-at');
      }
    }

    // The next page lies left of the view in right-to-left books.
    final first = place();
    var turned = false;
    for (final dx in const [-260.0, 260.0]) {
      await tester.fling(view, Offset(dx, 0), 1500);
      try {
        await waitForUi(
          tester,
          () => place() != first,
          description: 'a turn from $first',
          timeout: const Duration(seconds: 10),
        );
        turned = true;
        break;
      } on TestFailure {
        // Try the other way.
      }
    }
    expect(turned, isTrue, reason: 'turns a page of $name');
    await tester.pumpAndSettle();
    final second = place();

    // The reader saves its place after a pause.
    await tester.pump(const Duration(seconds: 1));
    await unmountUi(tester);
    return {
      'book': name,
      'format': format.name,
      'repeat': repeat,
      'fileBytes': fileBytes,
      'importMs': importWatch.elapsedMicroseconds / 1000,
      'importProgressUpdates': progressUpdates,
      'openMs': openMs,
      'rssMb': rssMb,
      'rssBeforeImportBytes': rssBeforeImportBytes,
      'rssAfterImportBytes': rssAfterImportBytes,
      'rssAtFirstPageBytes': rssAtFirstPageBytes,
      'maxRssBytes': ProcessInfo.maxRss,
      'from': first,
      'to': second,
    };
  } finally {
    await tester.runAsync(app.dispose);
  }
}

/// Lets the page's images decode (they start when it is first drawn and
/// repaint it when ready) before a screenshot, which shows the frame
/// before the last on iOS.
Future<void> _settleImages(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 800)),
  );
  await tester.pumpAndSettle();
  await tester.pump();
}

BookFormat? _formatOf(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.fb2.zip') || lower.endsWith('.fbz')) {
    return BookFormat.fb2;
  }
  final dot = lower.lastIndexOf('.');
  return dot < 0 ? null : BookFormat.fromExtension(lower.substring(dot));
}
