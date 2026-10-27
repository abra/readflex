import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_pdf_surface.dart';
import 'package:reader_webview/reader_webview.dart';
import 'package:vellum/testing.dart';
import 'package:vellum/vellum.dart';

const fixtures = '../../vellum/test/fixtures/pdf';

void main() {
  late PdfBook book;
  late FixedPagesController controller;
  late PdfTextLayerCache layers;
  late PdfTextSelection selection;
  late ReaderPdfSurface surface;
  var bookmarkToggles = 0;
  final marks = <(int, PdfTextRange?)>[];

  setUpAll(() async {
    await preparePdfEngineForTests();
    expect(File('$fixtures/text_lines.pdf').existsSync(), isTrue);
  });

  setUp(() async {
    book = await PdfBook.open('$fixtures/many_pages.pdf');
    controller = FixedPagesController(pageCount: book.pageCount, rtl: false);
    layers = PdfTextLayerCache(book);
    selection = PdfTextSelection();
    bookmarkToggles = 0;
    marks.clear();
    surface = ReaderPdfSurface()
      ..attach(
        ReaderPdfSession(
          controller: controller,
          book: book,
          layers: layers,
          selection: selection,
          onToggleBookmark: () => bookmarkToggles++,
          onSearchMark: (page, range) => marks.add((page, range)),
        ),
      );
  });

  tearDown(() async {
    controller.dispose();
    layers.dispose();
    selection.dispose();
    await book.close();
  });

  test('navigation commands drive the controller', () {
    surface.goToCfi('epubcfi(/6/6)');
    expect(controller.page, 2);
    surface.goToFraction(1);
    expect(controller.page, 199);
    surface.goToHref(fakeCfiFromIndex(10));
    expect(controller.page, 10);
    surface.goToHref('');
    expect(controller.page, 10, reason: 'an entry without a page');
    surface.goToSectionIndex(4);
    expect(controller.page, 4);
    surface.goToSectionIndex(500);
    expect(controller.page, 4);
    surface.pageRight();
    expect(controller.page, 5);
    surface.pageLeft();
    expect(controller.page, 4);
    surface.nextPage();
    surface.prevPage();
    expect(controller.page, 4);
  });

  test('bookmarks open by page anchor, then CFI, then fraction', () {
    surface.goToBookmark(
      cfi: 'epubcfi(/6/2)',
      progress: 0.9,
      anchorSectionIndex: 3,
    );
    expect(controller.page, 3);
    surface.goToBookmark(cfi: 'epubcfi(/6/2)', progress: 0.9);
    expect(controller.page, 0);
    surface.goToBookmark(cfi: 'x', progress: 0.5);
    expect(controller.page, 100);
    surface.toggleBookmark();
    expect(bookmarkToggles, 1);
  });

  test('search streams hits as vellum CFIs with excerpts, then done', () async {
    final events = await surface.searchBookStream('page 17')!.toList();
    expect(events.last, isA<ReaderSearchDone>());
    final results = events.whereType<ReaderSearchResults>().toList();
    expect(results, hasLength(11));
    final first = results.first.results.single;
    expect(first.cfi, pdfTextCfi(16, const PdfTextRange(0, 7)));
    expect(first.excerpt.match, 'Page 17');
    expect(layers.peek(199), isNotNull, reason: 'the cache was used');
    expect(layers.loadedPages.length, layers.capacity);
  });

  test('a search result opens its page and marks the hit', () {
    surface.goToSearchResult(pdfTextCfi(16, const PdfTextRange(0, 7)));
    expect(controller.page, 16);
    expect(marks, [(16, const PdfTextRange(0, 7))]);
    surface.clearSearch();
    expect(marks.last, (16, null));
    surface.goToSearchResult('epubcfi(/6/4!/4/4,/1:0,/1:3)');
    expect(controller.page, 16, reason: 'a foreign CFI is not a hit');
  });

  test('selection commands style, clear and report', () async {
    expect(await surface.currentTextSelection(), isNull);
    await layers.load(0);
    selection.start(0, const PdfTextRange(0, 4));
    controller.lockInput(true);
    final current = (await surface.currentTextSelection())!;
    expect(current.text, 'Page');
    expect(current.cfiRange, pdfTextCfi(0, const PdfTextRange(0, 4)));
    expect(current.contextText, 'Page 1');
    expect(current.markedContextText, '[[Page]] 1');

    surface.showSelectionHighlightPreview(
      cfiRange: pdfTextCfi(0, const PdfTextRange(0, 4)),
      color: '#ffe600',
      opacity: 0.5,
    );
    expect(selection.color, const Color(0xFFFFE600).withValues(alpha: 0.5));
    surface.showSelectionHighlightPreview(
      cfiRange: pdfTextCfi(3, const PdfTextRange(0, 4)),
      color: '#00aaff',
    );
    expect(selection.color.g, closeTo(0xE6 / 255, 1e-6), reason: 'other page');
    surface.clearSelectionHighlightPreview();
    expect(selection.color, PdfTextSelection.defaultColor);

    surface.clearSelection();
    expect(selection.isActive, isFalse);
    expect(controller.inputLocked, isFalse);
    selection.start(0, const PdfTextRange(0, 4));
    surface.clearSelectionAfterTextAction();
    expect(selection.isActive, isFalse);
  });

  test('image-area commands are inert', () {
    surface.showImageAreaSelectionPreview(
      pageIndex: 0,
      rect: const ReaderImageAreaRect(x: 0, y: 0, width: 1, height: 1),
      color: '#ffffff',
    );
    surface.clearImageAreaSelectionPreview();
    surface.setImageAreaSelectionPreviewRetained(true);
    surface.setImageAreaSelectionControlsBounds(
      const ReaderSelectionPosition(left: 0, top: 0, right: 1, bottom: 1),
    );
    surface.clearImageAreaSelectionControlsBounds();
    expect(selection.isActive, isFalse);
  });

  test('thumbnails are the engine\'s providers at preview width', () async {
    expect(
      await surface.pageThumbnail(1),
      PdfPageImage(
        book: book,
        pageIndex: 1,
        targetWidth: PdfPageImage.thumbnailWidth,
      ),
    );
    expect(await surface.pageThumbnail(200), isNull);
  });

  test('a detached surface drops commands and answers null', () async {
    final session = ReaderPdfSession(
      controller: controller,
      book: book,
      layers: layers,
      selection: selection,
      onToggleBookmark: () => bookmarkToggles++,
      onSearchMark: (_, _) {},
    );
    final detached = ReaderPdfSurface()
      ..attach(session)
      ..detach(session);
    expect(detached.isAttached, isFalse);
    detached
      ..goToCfi('epubcfi(/6/6)')
      ..goToSectionIndex(3)
      ..toggleBookmark()
      ..clearSearch()
      ..clearSelection();
    expect(controller.page, 0);
    expect(bookmarkToggles, 0);
    expect(detached.searchBookStream('x'), isNull);
    expect(await detached.pageThumbnail(0), isNull);
    expect(await detached.currentTextSelection(), isNull);
    surface.detach(session);
    expect(surface.isAttached, isTrue);
  });
}
