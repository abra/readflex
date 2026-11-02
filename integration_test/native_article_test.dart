import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:library_feature/src/library_continue_reading_card.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_search_cubit.dart';
import 'package:reader/src/reader_search_occlusion.dart';
import 'package:reader/src/reader_search_result_tile.dart';
import 'package:reader/src/reader_selection_cubit.dart';
import 'package:pagecraft/all_formats.dart';

import '../test/support/device_screenshots.dart';
import '../test/support/reading_fixture.dart';
import '../test/support/ui_test_app.dart';
import '../test/support/ui_test_driver.dart';

/// A saved article in the real app on the native text engine (`pagecraft`):
/// every kind of block the import writes, a picture among them. It opens
/// from the library and scrolls; search opens a hit near the end and
/// returns to where the reader was; a long press selects a word with its
/// sentence, which translates and saves as a highlight; the article
/// reopens at the sentence it was left on.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('an article reads on the native text engine in the app', (
    tester,
  ) async {
    final app = await UiTestApp.create(withBook: false);
    addTearDown(app.dispose);
    // The reader route still hands out the book server's address (plan R6).
    final article = (await tester.runAsync(() => _addArticle(app)))!;
    tester.platformDispatcher.defaultRouteNameTestValue = '/';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(app.widget);

    await waitForUi(
      tester,
      () => find.text(article.title).hitTestable().evaluate().isNotEmpty,
      description: 'the article in the library',
    );
    final openWatch = Stopwatch()..start();
    await tapUi(tester, find.text(article.title));
    final tapMs = openWatch.elapsedMilliseconds;
    final view = find.byType(TextScrollView);
    TextScrollController controller() =>
        tester.widget<TextScrollView>(view).controller;
    await waitForUi(
      tester,
      () => view.evaluate().isNotEmpty,
      description: 'article source read',
      timeout: const Duration(seconds: 30),
    );
    final sourceMs = openWatch.elapsedMilliseconds;
    await waitForUi(
      tester,
      () => view.evaluate().isNotEmpty && controller().position != null,
      description: 'article on pagecraft',
      timeout: const Duration(seconds: 30),
    );
    final openMs = openWatch.elapsedMilliseconds;
    expect(
      find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString().contains('WebView'),
      ),
      findsNothing,
    );
    await _settleImages(tester);
    await takeDeviceScreenshot(binding, 'native-article-open');
    final bloc = tester.element(view).read<ReaderBloc>();
    final l10n = tester.element(view).l10n;
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;

    // Scrolling: a fling moves the sentence read and the progress.
    final firstCfi = bloc.state.document!.currentCfi;
    await tester.fling(view, const Offset(0, -900), 2500);
    await tester.pumpAndSettle();
    await waitForUi(
      tester,
      () => bloc.state.document!.currentCfi != firstCfi,
      description: 'scrolled position',
    );
    await _settleImages(tester);
    await takeDeviceScreenshot(binding, 'native-article-scrolled');
    final scrolled = {
      'progress': bloc.state.document!.readingProgress,
      'chapter': bloc.state.chapterTitle,
      'minutesLeft': bloc.state.minutesLeft,
    };

    // Search: a hit near the end, then back to reading.
    final before = bloc.state.document!.readingProgress;
    await tester.tapAt(size.center(Offset.zero));
    await tester.pumpAndSettle();
    await tapUi(tester, find.byTooltip(l10n.readerSearchAction).first);
    await tester.pumpAndSettle();
    final searchWatch = Stopwatch()..start();
    await tester.enterText(
      find.byType(TextField).hitTestable(),
      'Section 22',
    );
    final search = tester
        .element(find.byType(TextField).hitTestable())
        .read<ReaderSearchCubit>();
    await waitForUi(
      tester,
      () => !search.state.isLoading && search.state.results.isNotEmpty,
      description: 'article search results',
    );
    final searchMs = searchWatch.elapsedMilliseconds;
    final results = search.state.results.length;
    await tapUi(
      tester,
      find.byType(ReaderSearchResultTile).hitTestable().first,
    );
    await waitForUi(
      tester,
      () => bloc.state.document!.readingProgress > 0.5,
      description: 'search hit near the end',
    );
    await tester.pumpAndSettle();
    await takeDeviceScreenshot(binding, 'native-article-search');

    // Pulled under the search bar, the hit is marked on the bar's edge.
    final marker = tester.widget<ReaderSearchOcclusionMarker>(
      find.byType(ReaderSearchOcclusionMarker),
    );
    expect(marker.bottomInset, greaterThan(0));
    final hit = marker.rects.value.first;
    final edge = size.height * (1 - marker.bottomInset);
    await tester.drag(view, Offset(0, edge - hit.top + 12));
    await tester.pumpAndSettle();
    final covered = occludedSearchSpans(
      marker.rects.value,
      size,
      marker.bottomInset,
    );
    await takeDeviceScreenshot(binding, 'native-article-search-covered');
    expect(covered, isNotEmpty, reason: '${marker.rects.value} under $edge');
    expect(search.state.returnLocation!.fraction, closeTo(before, 0.01));
    await tapUi(tester, find.byKey(const ValueKey('reader-search-return')));
    await waitForUi(
      tester,
      () =>
          !search.state.isNavigating &&
          (bloc.state.document!.readingProgress - before).abs() < 0.01,
      description: 'back where the reader was',
    );

    // A long press selects a word with its sentence as context.
    final (where, word) = _wordOnScreen(tester, view);
    await tester.longPressAt(where);
    await tester.pumpAndSettle();
    await takeDeviceScreenshot(binding, 'native-article-selection');
    final selection = tester.element(view).read<ReaderSelectionCubit>().state;
    expect(selection.selectedText, word);
    expect(ArticleAnchor.decode(selection.cfiRange)?.matchText, word);
    await tapUi(tester, find.text('Translate'));
    await waitForUi(
      tester,
      () => app.contextualTranslationService.requests.isNotEmpty,
      description: 'translation requested',
    );
    await tester.pumpAndSettle();
    await takeDeviceScreenshot(binding, 'native-article-translation');
    expect(
      app.contextualTranslationService.requests.single.selection.text,
      word,
    );
    await tester.tapAt(Offset(size.width / 2, 60));
    await tester.pumpAndSettle();

    // Saved as a highlight, tinted on the page.
    await tester.longPressAt(where);
    await tester.pumpAndSettle();
    await tapUi(tester, find.byTooltip('Highlight'));
    await waitForUi(
      tester,
      () => bloc.state.highlights.isNotEmpty,
      description: 'highlight saved',
    );
    await waitForUi(
      tester,
      () => tester.widget<TextScrollView>(view).highlights.isNotEmpty,
      description: 'highlight drawn',
    );
    await tester.pumpAndSettle();
    await takeDeviceScreenshot(binding, 'native-article-highlight');

    // Back in the library and in again, it opens at the sentence it was
    // left on.
    final left = bloc.state.document!.currentCfi;
    await tester.pump(const Duration(seconds: 2));
    await tester.tapAt(size.center(Offset.zero));
    await tester.pumpAndSettle();
    await tapUi(tester, find.byTooltip(l10n.readerBack));
    await tester.pumpAndSettle();
    await takeDeviceScreenshot(binding, 'native-article-library');
    // The library item itself: a cover in the grid, a row in the list, or
    // the Continue reading card that takes the row's place.
    await tapUi(
      tester,
      find.byWidgetPredicate(
        (widget) =>
            widget is LibraryContinueReadingCard ||
            widget.key == ValueKey('library-grid-${article.id}') ||
            widget.key == ValueKey('library-row-${article.id}'),
      ),
    );
    await waitForUi(
      tester,
      () => view.evaluate().isNotEmpty && controller().position != null,
      description: 'article reopened',
    );
    await tester.pumpAndSettle();
    final reopened = tester.element(view).read<ReaderBloc>();
    await takeDeviceScreenshot(binding, 'native-article-reopened');

    final report = {
      'openMs': openMs,
      'tapMs': tapMs,
      'sourceMs': sourceMs,
      'scrolled': scrolled,
      'searchMs': searchMs,
      'results': results,
      'selection': selection.markedContextText,
      'left': ArticleAnchor.decode(left)?.sentenceText,
      'reopened': ArticleAnchor.decode(
        reopened.state.document!.currentCfi,
      )?.sentenceText,
      'rssMb': ProcessInfo.currentRss >> 20,
    };
    debugPrint('NATIVE ARTICLE ${jsonEncode(report)}');
    binding.reportData = {...?binding.reportData, 'nativeArticle': report};
    expect(report['reopened'], report['left']);
    await tester.pump(const Duration(seconds: 2));
    await unmountUi(tester);
  });
}

/// The reading fixture with every block the import writes, and a picture
/// saved beside it as the import saves pictures.
Future<Article> _addArticle(UiTestApp app) async {
  final base = ReadingFixture.article;
  final blocks = <ArticleBlock>[
    const ArticleHeadingBlock(level: 2, text: 'Portable energy'),
    const ArticleParagraphBlock(
      text:
          'Batteries store chemical energy. They release it as current '
          'when a circuit closes, and a good pack does so evenly.',
    ),
    const ArticleImageBlock(
      src: 'https://example.com/pack.png',
      alt: 'A battery pack',
      title: 'A pack with four cells.',
    ),
    const ArticleListBlock(
      items: [
        'Keep packs away from heat.',
        'Charge them before a long trip.',
        'Recycle a swollen pack at once.',
      ],
    ),
    const ArticleQuoteBlock(
      text: 'The best battery is the one you remembered to charge.',
    ),
    const ArticleCodeBlock(
      text: 'capacity_wh = voltage * capacity_ah\nprint(capacity_wh)',
    ),
    const ArticleTableBlock(
      rows: [
        ['Pack', 'Capacity', 'Weight'],
        ['Small', '10 Wh', '180 g'],
        ['Large', '74 Wh', '520 g'],
      ],
    ),
    ...base.blocks.skip(1),
  ];
  final saved = await app.articleRepository.addExtractedArticle(
    ExtractedArticle(
      requestedUrl: base.requestedUrl,
      title: base.title,
      author: base.author,
      language: base.language,
      blocks: blocks,
      plainText: blocks.map((block) => block.fallbackText).join('\n'),
      rawJson: base.rawJson,
    ),
  );
  // The picture as the import keeps it: a file under images/.
  final html = File(saved.contentHtmlPath);
  final images = Directory('${html.parent.path}/images')
    ..createSync(recursive: true);
  File('${images.path}/pack.png').writeAsBytesSync(await _picture());
  html.writeAsStringSync(
    html.readAsStringSync().replaceFirst(
      '<img alt=',
      '<img src="images/pack.png" alt=',
    ),
  );
  return saved;
}

/// A word of the paragraph nearest the middle of the view, and where it
/// is on screen.
(Offset, String) _wordOnScreen(WidgetTester tester, Finder view) {
  final size = tester.getSize(view);
  for (final element in find.byType(TextColumnPage).evaluate()) {
    final page = element.widget as TextColumnPage;
    final box = element.renderObject! as RenderBox;
    for (final item in page.column.items.whereType<ColumnText>()) {
      final text = item.paragraph.box.text;
      final at = text.indexOf(' device ') + 1;
      if (at < 1) continue;
      final glyph = item.paragraph.boxesFor(at + 1, at + 2).first.toRect();
      final local =
          page.padding.topLeft +
          item.rect.topLeft -
          Offset(0, page.page.top) +
          glyph.center;
      final global = box.localToGlobal(local);
      if (global.dy < size.height * 0.25 || global.dy > size.height * 0.75) {
        continue;
      }
      return (global, 'device');
    }
  }
  throw StateError('no word in the middle of the view');
}

/// Pictures decode after the first paint: let them land before a
/// screenshot.
Future<void> _settleImages(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 600)),
  );
  await tester.pumpAndSettle();
  await tester.pump();
}

/// A wide picture: a blue sky over an amber band.
Future<List<int>> _picture() async {
  const width = 600, height = 300;
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder)
    ..drawRect(
      const Rect.fromLTWH(0, 0, width + 0.0, height + 0.0),
      Paint()..color = const Color(0xFF3B6EA8),
    )
    ..drawRect(
      const Rect.fromLTWH(0, height * 0.6, width + 0.0, height * 0.4),
      Paint()..color = const Color(0xFFFFB300),
    );
  final image = await recorder.endRecording().toImage(width, height);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return png!.buffer.asUint8List();
}
