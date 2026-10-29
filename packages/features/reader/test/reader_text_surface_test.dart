import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_search_event.dart';
import 'package:reader/src/reader_text_surface.dart';
import 'package:vellum/all_formats.dart';

/// The surface's commands on a real FB2 laid out by vellum.
String fb2() =>
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" '
    'xmlns:l="http://www.w3.org/1999/xlink">'
    '<description><title-info><book-title>T</book-title></title-info></description>'
    '<body>'
    '<section><title><p>One</p></title>'
    '${List.generate(20, (i) => '<p>Alpha paragraph $i with words to wrap.</p>').join()}'
    '</section>'
    '<section><title><p>Two</p></title>'
    '${List.generate(20, (i) => '<p>Beta paragraph $i with words to wrap.</p>').join()}'
    '</section>'
    '</body></FictionBook>';

void main() {
  late Directory dir;
  late TextBookSource source;
  late BookImageCache images;
  late TextPagesController controller;
  late ReaderTextSurface surface;
  late List<String?> marks;
  late List<(String?, Color?)> previews;
  var toggles = 0;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('reader_text_surface_');
    final path = '${dir.path}/b.fb2';
    File(path).writeAsStringSync(fb2());
    source = textBookSourceOf(await Fb2Book.open(path));
    images = BookImageCache(read: source.readImage);
    controller = TextPagesController(
      source: source,
      style: const BookStyle(fontScale: 10 / 16),
      fonts: const BookFonts(),
      images: images,
      settings: const TextPageSettings(topMargin: 10, bottomMargin: 10),
    )..setViewport(const Size(220, 160));
    marks = [];
    previews = [];
    toggles = 0;
    surface = ReaderTextSurface()
      ..attach(
        ReaderTextSession(
          controller: controller,
          source: source,
          onToggleBookmark: () => toggles++,
          onSearchMark: marks.add,
          onSelectionPreview: (cfi, color) => previews.add((cfi, color)),
          currentSelection: () => null,
          chapterTitleOf: (section) => controller.tocItemOf(section)?.label,
        ),
      );
    for (var i = 0; i < 400 && controller.position == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  });

  tearDown(() async {
    controller.dispose();
    images.dispose();
    await source.close();
    dir.deleteSync(recursive: true);
  });

  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 400 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(done(), isTrue);
  }

  test('navigation commands drive the controller', () async {
    surface.nextPage();
    await until(() => controller.position!.spread == 1);
    surface.prevPage();
    await until(() => controller.position!.spread == 0);
    surface.pageRight();
    await until(() => controller.position!.spread == 1);
    surface.pageLeft();
    await until(() => controller.position!.spread == 0);
    surface.goToSectionIndex(1);
    await until(() => controller.position!.section == 1);
    surface.goToFraction(0);
    await until(() => controller.position!.section == 0);
    surface.toggleBookmark();
    expect(toggles, 1);
  });

  test('search streams hits with chapter titles, then done', () async {
    await until(() => controller.tocItemOf(1) != null);
    final events = await surface.searchBookStream('paragraph 19')!.toList();
    final hits = events.whereType<ReaderSearchResults>().expand(
      (e) => e.results,
    );
    expect([for (final h in hits) h.chapterTitle], ['One', 'Two']);
    expect(hits.first.excerpt.match, 'paragraph 19');
    expect(events.whereType<ReaderSearchProgress>(), isNotEmpty);
    expect(events.last, isA<ReaderSearchDone>());

    surface.goToSearchResult(hits.last.cfi);
    await until(() => controller.position!.section == 1);
    expect(marks, [hits.last.cfi]);
    surface.clearSearch();
    expect(marks.last, isNull);
  });

  test('bookmarks open at their CFI, or at their progress', () async {
    await controller.goToSection(1);
    final cfi = controller.position!.cfi;
    await controller.goToSection(0);
    surface.goToBookmark(cfi: cfi, progress: 0);
    await until(() => controller.position!.section == 1);
    surface.goToBookmark(cfi: 'not a cfi', progress: 0);
    await until(() => controller.position!.section == 0);
  });

  test('previews take the colour and its opacity', () {
    surface.showSelectionHighlightPreview(
      cfiRange: 'epubcfi(/6/2!/4/2,/1:0,/1:3)',
      color: const Color(0xFFFFE600),
      opacity: 0.5,
    );
    expect(previews.single.$1, 'epubcfi(/6/2!/4/2,/1:0,/1:3)');
    expect(previews.single.$2!.a, closeTo(0.5, 0.01));
    surface.clearSelectionHighlightPreview();
    expect(previews.last, (null, null));
  });

  test('a detached surface drops commands and answers null', () async {
    final session = ReaderTextSession(
      controller: controller,
      source: source,
      onToggleBookmark: () {},
      onSearchMark: (_) {},
      onSelectionPreview: (_, _) {},
      currentSelection: () => null,
      chapterTitleOf: (_) => null,
    );
    final other = ReaderTextSurface()..attach(session);
    other.detach(session);
    expect(other.isAttached, isFalse);
    expect(other.searchBookStream('x'), isNull);
    expect(await other.currentTextSelection(), isNull);
    expect(await other.pageThumbnail(0), isNull);
    other.nextPage();
  });
}
