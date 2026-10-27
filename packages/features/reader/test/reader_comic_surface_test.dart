import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_comic_surface.dart';
import 'package:reader_webview/reader_webview.dart';
import 'package:vellum/testing.dart';
import 'package:vellum/vellum.dart';

void main() {
  late Directory tempDir;
  late ComicBook book;
  late FixedPagesController controller;
  late ComicImageAreaDraft draft;
  late ReaderComicSurface surface;
  var bookmarkToggles = 0;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('reader_comic_surface_');
    final path = '${tempDir.path}/issue.cbz';
    await File(path).writeAsBytes(buildComicArchive(portraitPages(6)));
    book = await ComicBook.open(path, pageOrderVersion: 1);
    controller = FixedPagesController(pageCount: book.pageCount, rtl: false);
    draft = ComicImageAreaDraft();
    bookmarkToggles = 0;
    surface = ReaderComicSurface()
      ..attach(
        ReaderComicSession(
          controller: controller,
          book: book,
          draft: draft,
          onToggleBookmark: () => bookmarkToggles++,
        ),
      );
  });

  tearDown(() async {
    controller.dispose();
    draft.dispose();
    await book.close();
    await tempDir.delete(recursive: true);
  });

  test('navigation commands drive the controller', () {
    surface.goToCfi('epubcfi(/6/6)');
    expect(controller.page, 2);
    surface.goToFraction(1);
    expect(controller.page, 5);
    surface.goToHref('002.png');
    expect(controller.page, 1);
    surface.goToHref('missing.png');
    expect(controller.page, 1);
    surface.goToSectionIndex(4);
    expect(controller.page, 4);
    surface.goToSectionIndex(6);
    expect(controller.page, 4, reason: 'out of range is ignored');
    surface.goToSearchResult('epubcfi(/6/2)');
    expect(controller.page, 4, reason: 'comics have no search results');
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
    surface.goToBookmark(cfi: 'readflex-html-position:1', progress: 0.5);
    expect(controller.page, 3, reason: 'fraction 0.5 of 6 pages');
    surface.goToBookmark(cfi: '', progress: 0, anchorSectionIndex: 9);
    expect(controller.page, 0, reason: 'a page anchor past the end falls back');
  });

  test('physical and logical page turns respect reading direction', () {
    surface.goToSectionIndex(2);
    surface.pageRight();
    expect(controller.page, 3);
    surface.pageLeft();
    expect(controller.page, 2);
    surface.nextPage();
    expect(controller.page, 3);
    surface.prevPage();
    expect(controller.page, 2);

    final rtl = FixedPagesController(pageCount: 6, rtl: true, initialPage: 2);
    addTearDown(rtl.dispose);
    final rtlSurface = ReaderComicSurface()
      ..attach(
        ReaderComicSession(
          controller: rtl,
          book: book,
          draft: draft,
          onToggleBookmark: () {},
        ),
      );
    rtlSurface.pageRight();
    expect(rtl.page, 1, reason: 'right is backward in a right-to-left comic');
    rtlSurface.pageLeft();
    expect(rtl.page, 2);
  });

  test('bookmark toggles reach the body', () {
    surface.toggleBookmark();
    surface.toggleBookmark();
    expect(bookmarkToggles, 2);
  });

  test('text search and selection commands are inert', () async {
    expect(surface.searchBookStream('sea'), isNull);
    surface.clearSearch();
    expect(await surface.currentTextSelection(), isNull);
    surface.showSelectionHighlightPreview(cfiRange: 'x', color: '#ffffff');
    surface.clearSelectionHighlightPreview();
    surface.setImageAreaSelectionControlsBounds(
      const ReaderSelectionPosition(left: 0, top: 0, right: 1, bottom: 1),
    );
    surface.clearImageAreaSelectionControlsBounds();
  });

  test('image-area previews style, retain and clear the draft', () {
    draft.start(2, const Rect.fromLTWH(0.1, 0.1, 0.2, 0.2));
    controller.lockInput(true);
    surface.showImageAreaSelectionPreview(
      pageIndex: 3,
      rect: const ReaderImageAreaRect(x: 0, y: 0, width: 1, height: 1),
      color: '#00aaff',
      opacity: 0.5,
    );
    expect(draft.color, isNot(const Color(0xFF00AAFF)), reason: 'other page');
    surface.showImageAreaSelectionPreview(
      pageIndex: 2,
      rect: const ReaderImageAreaRect(x: 0, y: 0, width: 1, height: 1),
      color: '#00aaff',
      opacity: 0.5,
    );
    expect(draft.color, const Color(0xFF00AAFF));
    expect(draft.opacity, 0.5);
    surface.setImageAreaSelectionPreviewRetained(true);
    expect(draft.retained, isTrue);
    surface.clearImageAreaSelectionPreview(allowNextTap: true);
    expect(draft.isActive, isFalse);
    expect(controller.inputLocked, isFalse);

    draft.start(0, const Rect.fromLTWH(0, 0, 0.1, 0.1));
    surface.clearSelection();
    expect(draft.isActive, isFalse);
    draft.start(0, const Rect.fromLTWH(0, 0, 0.1, 0.1));
    surface.clearSelectionAfterTextAction();
    expect(draft.isActive, isFalse);
  });

  test('thumbnails are the engine\'s providers at preview width', () async {
    final image = await surface.pageThumbnail(1);
    expect(
      image,
      ComicPageImage(
        source: book,
        pageIndex: 1,
        targetWidth: ComicPageImage.thumbnailWidth,
        maxBytes: ComicPageImage.thumbnailMaxBytes,
      ),
    );
    expect(await surface.pageThumbnail(6), isNull);
    expect(await surface.pageThumbnail(-1), isNull);
  });

  test('a detached surface drops commands and answers null', () async {
    final session = ReaderComicSession(
      controller: controller,
      book: book,
      draft: draft,
      onToggleBookmark: () => bookmarkToggles++,
    );
    final detached = ReaderComicSurface()
      ..attach(session)
      ..detach(session);
    expect(detached.isAttached, isFalse);
    detached
      ..goToCfi('epubcfi(/6/6)')
      ..goToFraction(1)
      ..goToHref('002.png')
      ..goToSectionIndex(3)
      ..goToBookmark(cfi: 'epubcfi(/6/6)', progress: 1)
      ..pageLeft()
      ..pageRight()
      ..prevPage()
      ..nextPage()
      ..toggleBookmark()
      ..clearSelection()
      ..setImageAreaSelectionPreviewRetained(true);
    expect(controller.page, 0);
    expect(bookmarkToggles, 0);
    expect(draft.retained, isFalse);
    expect(await detached.pageThumbnail(0), isNull);

    // Detaching another session leaves the current one in place.
    surface.detach(session);
    expect(surface.isAttached, isTrue);
  });

  group('parseCssHexColor', () {
    test('reads the forms the reader writes', () {
      expect(parseCssHexColor('#ffe600'), const Color(0xFFFFE600));
      expect(parseCssHexColor('#FFE600'), const Color(0xFFFFE600));
      expect(parseCssHexColor(' #abc '), const Color(0xFFAABBCC));
      expect(parseCssHexColor('#ffe60080'), const Color(0x80FFE600));
    });

    test('rejects anything else', () {
      expect(parseCssHexColor('ffe600'), isNull);
      expect(parseCssHexColor('#ffe6'), isNull);
      expect(parseCssHexColor('#gggggg'), isNull);
      expect(parseCssHexColor('rgb(1, 2, 3)'), isNull);
    });
  });
}
