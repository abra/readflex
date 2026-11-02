import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_article_surface.dart';
import 'package:reader/src/reader_search_event.dart';
import 'package:pagecraft/all_formats.dart';

/// An article as the import marks it: a heading per part, a sentence
/// per paragraph.
String article() => [
  '<h1 id="block-0" data-rf-block-id="block-0">'
      '<span id="block-0-s0" data-rf-sentence="0">Start</span></h1>',
  for (var i = 1; i < 60; i++)
    if (i == 30)
      '<h2 id="block-30" data-rf-block-id="block-30">'
          '<span id="block-30-s0" data-rf-sentence="0">Middle</span></h2>'
    else
      '<p id="block-$i" data-rf-block-id="block-$i">'
          '<span id="block-$i-s0" data-rf-sentence="0">Sentence $i has '
          'words enough to wrap in a narrow column.</span></p>',
].join();

void main() {
  late BookImageCache images;
  late TextScrollController controller;
  late ReaderArticleSurface surface;
  late ReaderArticleSession session;
  late List<List<ArticleSearchHit>?> hits;
  late List<String?> marks;
  late List<(String?, Color?)> previews;
  late int toggles;

  Future<void> settle(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(done(), isTrue, reason: 'timed out');
  }

  Future<void> show(WidgetTester tester) async {
    tester.view.physicalSize = const Size(240, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    images = BookImageCache(read: (_) async => null);
    addTearDown(images.dispose);
    controller = TextScrollController(
      source: ArticleTextSource.fromHtml(article()),
      style: const BookStyle(fontScale: 10 / 16, justify: false),
      fonts: const BookFonts(),
      images: images,
      settings: const TextPageSettings(topMargin: 20, bottomMargin: 20),
    );
    addTearDown(controller.dispose);
    hits = [];
    marks = [];
    previews = [];
    toggles = 0;
    ArticleIndex? index;
    session = ReaderArticleSession(
      controller: controller,
      index: () {
        final doc = controller.section?.prepared.document;
        if (doc == null) return null;
        if (index?.document != doc) index = ArticleIndex.of(doc);
        return index;
      },
      onToggleBookmark: () => toggles++,
      onSearchHits: hits.add,
      onSearchMark: marks.add,
      onSelectionPreview: (cfi, color) => previews.add((cfi, color)),
      currentSelection: () => null,
    );
    surface = ReaderArticleSurface()..attach(session);
    await tester.pumpWidget(
      MaterialApp(home: TextScrollView(controller: controller)),
    );
    await settle(tester, () => controller.position != null);
    await settle(tester, () => controller.section!.isComplete);
  }

  ContentDocument doc() => controller.section!.prepared.document;

  int? sentenceAtMiddle() {
    final point = controller.position?.point;
    return point == null ? null : ArticleIndex.of(doc()).sentenceAt(point);
  }

  String anchorOf(String id) =>
      ArticleAnchor.forSentence(doc(), doc().elementIndexById(id))!.encode();

  test('without a session commands are dropped and queries answer null', () {
    final surface = ReaderArticleSurface();
    expect(surface.isAttached, isFalse);
    surface
      ..goToCfi('readflex-html-position:x')
      ..goToFraction(0.5)
      ..goToHref('#x')
      ..toggleBookmark()
      ..clearSearch()
      ..clearSelection();
    expect(surface.searchBookStream('x'), isNull);
    expect(surface.currentTextSelection(), completion(isNull));
    expect(surface.pageThumbnail(0), completion(isNull));
  });

  testWidgets('a sentence anchor opens at the middle of the view', (
    tester,
  ) async {
    await show(tester);
    surface.goToCfi(anchorOf('block-45-s0'));
    await tester.pump();
    await settle(
      tester,
      () => sentenceAtMiddle() == doc().elementIndexById('block-45-s0'),
    );
    expect(marks.last, isNull, reason: 'navigation clears the active hit');
    // A bookmark whose sentence is gone opens at its progress.
    surface.goToBookmark(cfi: 'readflex-html-position:%7B%7D', progress: 1);
    await tester.pump();
    await settle(tester, () => controller.position!.atEnd);
  });

  testWidgets('an href opens its element at the top, a section index at '
      'the start', (tester) async {
    await show(tester);
    surface.goToHref('#block-30');
    await tester.pump();
    final top = controller.contentOffsetOf(
      TextPoint(doc().elementIndexById('block-30'), 0),
    )!;
    await settle(
      tester,
      () => (controller.scroll.offset - (top - controller.topInset)).abs() < 1,
    );
    surface.goToSectionIndex(0);
    await tester.pump();
    await settle(tester, () => controller.position!.atStart);
  });

  testWidgets('search tints hits as they come and marks the one opened', (
    tester,
  ) async {
    await show(tester);
    final events = await tester.runAsync(
      () => surface.searchBookStream('sentence 4')!.toList(),
    );
    final results = [
      for (final event in events!)
        if (event is ReaderSearchResults) ...event.results,
    ];
    // 4 and 40 to 49, under the second heading but 4.
    expect(results, hasLength(11));
    expect(results.first.chapterTitle, 'Start');
    expect(results.last.chapterTitle, 'Middle');
    expect(events.last, isA<ReaderSearchDone>());
    expect(hits.first, isEmpty, reason: 'a new search clears the old tints');
    expect(hits.last, hasLength(11));

    surface.goToSearchResult(results.last.cfi);
    expect(marks.last, results.last.cfi);
    await tester.pump();
    await settle(
      tester,
      () => sentenceAtMiddle() == doc().elementIndexById('block-49-s0'),
    );

    surface.clearSearch();
    expect(hits.last, isNull);
    expect(marks.last, isNull);
  });

  testWidgets('bookmarks, previews and selection reach the session', (
    tester,
  ) async {
    await show(tester);
    surface.toggleBookmark();
    expect(toggles, 1);
    surface.showSelectionHighlightPreview(
      cfiRange: 'readflex-html-position:x',
      color: const Color(0xFFFF0000),
      opacity: 0.5,
    );
    expect(previews.single.$1, 'readflex-html-position:x');
    expect(previews.single.$2!.a, closeTo(0.5, 0.01));
    surface.clearSelectionHighlightPreview();
    expect(previews.last, (null, null));
    final clears = controller.selectionClears;
    surface.clearSelectionAfterTextAction();
    expect(controller.selectionClears, clears + 1);
  });
}
