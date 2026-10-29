import 'dart:io';

import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vellum/all_formats.dart';

import '../test/support/device_screenshots.dart';
import '../test/support/ui_test_app.dart';
import '../test/support/ui_test_driver.dart';

/// Every book format reads on vellum in the real app, never in the
/// WebView: each book of `--dart-define=VELLUM_BOOKS=a|b|…` (EPUB, FB2,
/// MOBI, AZW3, CBZ or PDF) is added to an empty library, opened from its
/// tile, shows its first page, turns one page and closes. Reports the
/// open time and the process RSS per book, and saves a screenshot of each
/// first page.
///
/// `--dart-define=VELLUM_AT=href|…` (in the books' order, empty to skip
/// one) then goes to that place of a book (a section href with an
/// optional `#id`) and saves a screenshot of it: what a layout change is
/// checked on.
///
/// The iOS simulator reads host paths; on Android pass paths pushed with
/// `adb push`. The tool splits `--dart-define` at commas: link files with
/// commas in their names under plain names first.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const books = String.fromEnvironment('VELLUM_BOOKS');
  const places = String.fromEnvironment('VELLUM_AT');

  testWidgets('every book opens and turns on vellum', (tester) async {
    final paths = books.split('|').where((p) => p.isNotEmpty).toList();
    if (paths.isEmpty) {
      markTestSkipped('pass VELLUM_BOOKS');
      return;
    }
    tester.platformDispatcher.defaultRouteNameTestValue = '/';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    final report = <Map<String, Object?>>[];
    final targets = places.split('|');
    for (final (index, path) in paths.indexed) {
      final format = _formatOf(path);
      expect(format, isNotNull, reason: 'a book format: $path');
      final at = index < targets.length ? targets[index] : '';
      report.add(
        await _openAndTurn(
          tester,
          binding,
          index,
          path,
          format!,
          at: at.isEmpty ? null : at,
        ),
      );
    }
    for (final entry in report) {
      debugPrint('NATIVE BOOK $entry');
    }
    binding.reportData = {...?binding.reportData, 'nativeBooks': report};
  });
}

/// Opens [path] in a fresh app, goes to [at] when given, turns a page
/// and closes it.
Future<Map<String, Object?>> _openAndTurn(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  int index,
  String path,
  BookFormat format, {
  String? at,
}) async {
  final app = await UiTestApp.create(withBook: false);
  try {
    final name = path.split('/').last;
    final book = await tester.runAsync(
      () => app.bookRepository.addBook(
        sourceFile: File(path),
        title: name,
        format: format,
      ),
    );
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

    final open = Stopwatch()..start();
    await tapUi(tester, find.byKey(ValueKey('library-grid-${book!.id}')));
    await waitForUi(
      tester,
      () => page.evaluate().isNotEmpty && place() != null,
      description: 'the first page of $name',
      timeout: const Duration(seconds: 60),
    );
    final openMs = open.elapsedMilliseconds;
    await _settleImages(tester);
    await takeDeviceScreenshot(
      binding,
      'native-book-${index.toString().padLeft(2, '0')}-${format.name}',
    );
    final rssMb = ProcessInfo.currentRss >> 20;
    final shot = 'native-book-${index.toString().padLeft(2, '0')}';
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
      await _settleImages(tester);
      await takeDeviceScreenshot(binding, '$shot-at');
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
      'openMs': openMs,
      'rssMb': rssMb,
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
