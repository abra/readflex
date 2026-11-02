import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:import_flow/import_flow.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pagecraft/all_formats.dart';
import 'package:pagecraft/testing.dart';
import 'package:practice/practice.dart';

import '../test/support/device_screenshots.dart';
import '../test/support/reading_fixture.dart';
import '../test/support/ui_test_app.dart';
import '../test/support/ui_test_driver.dart';

/// Tablet-only reader direction and Practice checks on the native viewport.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDownAll(() {
    binding.reportData = {
      ...?binding.reportData,
      'platform': Platform.operatingSystem,
      'completedAt': DateTime.now().toUtc().toIso8601String(),
      'tests': binding.results.map(
        (name, result) => MapEntry(name, result.toString()),
      ),
    };
  });

  testWidgets('Arabic EPUB turns right to left on a native tablet', (
    tester,
  ) async {
    _expectNativeTablet(tester);
    final app = await UiTestApp.create(withBook: false);
    addTearDown(() async {
      await unmountUi(tester);
      await app.dispose();
    });
    await app.preferencesService.update(
      (preferences) => preferences.copyWith(locale: const Locale('ar')),
    );
    final book = await tester.runAsync(() async {
      final source = File('${app.directory.path}/tablet-arabic.epub');
      await source.writeAsBytes(_arabicEpub());
      return importBookFile(
        sourceFile: source,
        bookRepository: app.bookRepository,
        logger: app.logger,
      );
    });
    expect(book, isNotNull);
    tester.platformDispatcher.defaultRouteNameTestValue = '/';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(app.widget);
    await tapUi(tester, find.byKey(ValueKey('library-grid-${book!.id}')));

    final pages = find.byType(TextPagesView);
    TextPagesController controller() =>
        tester.widget<TextPagesView>(pages).controller;
    await waitForUi(
      tester,
      () =>
          pages.evaluate().isNotEmpty &&
          (controller().position?.spreadCount ?? 0) > 1 &&
          find.byType(TextColumnPage).evaluate().isNotEmpty,
      description: 'Arabic EPUB laid out across several spreads',
      timeout: const Duration(seconds: 45),
    );
    await tester.pumpAndSettle();
    expect(controller().rtl, isTrue);
    expect(Directionality.of(tester.element(pages)), TextDirection.rtl);
    final initial = controller().position!;
    await takeDeviceScreenshot(binding, 'tablet-rtl-epub');

    final bounds = tester.getRect(pages);
    await tester.tapAt(bounds.centerLeft + Offset(bounds.width * .08, 0));
    await waitForUi(
      tester,
      () => controller().position!.spread == initial.spread + 1,
      description: 'left edge advances the Arabic EPUB',
    );
    await tester.pumpAndSettle();
    expect(controller().position!.section, initial.section);
    final advanced = controller().position!;
    expect(advanced.cfi, isNot(initial.cfi));
    await takeDeviceScreenshot(binding, 'tablet-rtl-epub-next');

    await tester.tapAt(bounds.centerRight - Offset(bounds.width * .08, 0));
    await waitForUi(
      tester,
      () => controller().position!.spread == initial.spread,
      description: 'right edge returns to the previous Arabic spread',
    );
    await tester.pumpAndSettle();
    expect(controller().position!.section, initial.section);
    binding.reportData = {
      ...?binding.reportData,
      'tabletArabicEpub': {
        'rtl': controller().rtl,
        'initialSpread': initial.spread,
        'advancedSpread': advanced.spread,
        'returnedSpread': controller().position!.spread,
        'spreadCount': controller().position!.spreadCount,
      },
    };
    expect(tester.takeException(), isNull);
    await unmountUi(tester);
  });

  testWidgets('Practice completes a word and highlight session on a tablet', (
    tester,
  ) async {
    _expectNativeTablet(tester);
    final app = await UiTestApp.create();
    addTearDown(() async {
      await unmountUi(tester);
      await app.dispose();
    });
    tester.platformDispatcher.defaultRouteNameTestValue = '/';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(app.widget);
    await waitForUi(
      tester,
      () => find.text(ReadingFixture.bookTitle).evaluate().isNotEmpty,
      description: 'Library before saving vocabulary',
    );
    await tester.runAsync(() async {
      await app.dictionaryRepository.addEntry(
        word: 'power',
        translation: 'Strom',
        sourceId: app.book!.id,
        sourceType: SourceType.book,
        anchorText: 'power',
        anchorCfiRange: 'epubcfi(/6/2!/4/2,/1:0,/1:5)',
      );
      await app.highlightRepository.addHighlight(
        sourceId: app.book!.id,
        sourceType: SourceType.book,
        text: ReadingFixture.sentence,
        cfiRange: 'epubcfi(/6/2!/4/4,/1:0,/1:40)',
      );
    });

    final hub = find.byKey(const ValueKey('practiceTodayCard'));
    await tapUi(tester, find.byKey(const ValueKey('libraryPracticeButton')));
    await waitForUi(
      tester,
      () => hub.evaluate().isNotEmpty,
      description: 'Practice with two due items',
    );
    await tapUi(tester, find.byKey(const ValueKey('practiceStartReview')));
    await waitForUi(
      tester,
      () => find.byKey(const ValueKey('reviewWord')).evaluate().isNotEmpty,
      description: 'word review card',
    );
    await takeDeviceScreenshot(binding, 'tablet-practice-word');
    await tapUi(tester, find.byKey(const ValueKey('reviewShowAnswer')));
    await tapUi(tester, find.byKey(const ValueKey('reviewRate-good')));
    await waitForUi(
      tester,
      () => find.byKey(const ValueKey('reviewQuote')).evaluate().isNotEmpty,
      description: 'highlight review card',
    );
    await tapUi(tester, find.byKey(const ValueKey('reviewShowAnswer')));
    await tapUi(tester, find.byKey(const ValueKey('reviewRate-keep')));
    final summary = find.byKey(const ValueKey('reviewSummaryTitle'));
    await waitForUi(
      tester,
      () => summary.evaluate().isNotEmpty,
      description: 'Session complete',
    );
    await takeDeviceScreenshot(binding, 'tablet-practice-summary');
    await tapUi(tester, find.byKey(const ValueKey('reviewDone')));
    await waitForUi(
      tester,
      () =>
          find.text('Review ahead').hitTestable().evaluate().isNotEmpty &&
          find.byType(ReviewSessionScreen).evaluate().isEmpty,
      description: 'completed review returns to Practice',
    );
    await tester.pumpAndSettle();
    final resting = tester.getRect(hub);
    for (var frame = 0; frame < 6; frame++) {
      await tester.pump(const Duration(milliseconds: 32));
      expect(tester.getRect(hub), resting);
      expect(summary, findsNothing);
      expect(tester.takeException(), isNull);
    }
    final stats = (await tester.runAsync(app.fsrsRepository.getStats))!;
    expect(stats.due, 0);
    await takeDeviceScreenshot(binding, 'tablet-practice-returned');
    await tapUi(tester, find.byType(AppBackButton));
    await waitForUi(
      tester,
      () => find
          .byKey(const ValueKey('libraryPracticeRow'))
          .evaluate()
          .isNotEmpty,
      description: 'Library refreshes completed Practice counts',
    );
    expect(find.byKey(const ValueKey('libraryPracticeBadge')), findsNothing);
    binding.reportData = {
      ...?binding.reportData,
      'tabletPractice': {'reviewedItems': 2, 'dueAfterSession': stats.due},
    };
    await unmountUi(tester);
  });
}

void _expectNativeTablet(WidgetTester tester) {
  expect(Platform.isIOS || Platform.isAndroid, isTrue);
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  expect(size.shortestSide, greaterThanOrEqualTo(600));
}

Uint8List _arabicEpub() {
  const paragraph =
      'هذه فقرة عربية لاختبار القراءة على الجهاز اللوحي. '
      'نقرأ النص من اليمين إلى اليسار وننتقل إلى الصفحة التالية. '
      'يبقى موضع القراءة محفوظاً عند العودة إلى الصفحة السابقة.';
  final archive = ZipBuilder()
    ..add('mimetype', ascii.encode('application/epub+zip'), deflate: false)
    ..add(
      'META-INF/container.xml',
      utf8.encode(
        '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" '
        'version="1.0"><rootfiles><rootfile full-path="book.opf" '
        'media-type="application/oebps-package+xml"/></rootfiles></container>',
      ),
    )
    ..add(
      'book.opf',
      utf8.encode(
        '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" '
        'unique-identifier="id"><metadata '
        'xmlns:dc="http://purl.org/dc/elements/1.1/">'
        '<dc:identifier id="id">tablet-arabic</dc:identifier>'
        '<dc:title>كتاب عربي للاختبار</dc:title><dc:language>ar</dc:language>'
        '</metadata><manifest><item id="chapter" href="chapter.xhtml" '
        'media-type="application/xhtml+xml"/></manifest>'
        '<spine page-progression-direction="rtl"><itemref idref="chapter"/>'
        '</spine></package>',
      ),
    )
    ..add(
      'chapter.xhtml',
      utf8.encode(
        '<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="ar" '
        'lang="ar" dir="rtl"><head><title>قراءة عربية</title></head>'
        '<body dir="rtl"><h1>قراءة عربية</h1>'
        '${List.generate(100, (index) => '<p>$paragraph</p>').join()}'
        '</body></html>',
      ),
    );
  return archive.build();
}
