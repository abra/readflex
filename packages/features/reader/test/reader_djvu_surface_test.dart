import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagecraft/djvu.dart';
import 'package:reader/src/reader_djvu_surface.dart';
import 'package:reader/src/reader_search_event.dart';
import 'package:reader/src/reader_selection.dart';

import '../../../pagecraft/test/formats/djvu/djvu_fixture.dart';

void main() {
  late Directory directory;
  late DjvuBook book;
  late FixedPagesController controller;
  late DjvuTextLayerCache layers;
  late DjvuTextSelection selection;
  late ComicImageAreaDraft draft;
  late ReaderDjvuSession session;
  late ReaderDjvuSurface surface;
  var bookmarkToggles = 0;
  final marks = <(int, DjvuTextRange?)>[];

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('reader-djvu-surface-');
    final path = '${directory.path}/original.djvu';
    await File(path).writeAsBytes(djvuFixtureBytes());
    book = await DjvuBook.open(path);
    controller = FixedPagesController(pageCount: book.pageCount, rtl: false);
    layers = DjvuTextLayerCache(book, capacity: 2);
    selection = DjvuTextSelection();
    draft = ComicImageAreaDraft();
    bookmarkToggles = 0;
    marks.clear();
    session = ReaderDjvuSession(
      controller: controller,
      book: book,
      layers: layers,
      selection: selection,
      draft: draft,
      onToggleBookmark: () => bookmarkToggles++,
      onSearchMark: (page, range) => marks.add((page, range)),
    );
    surface = ReaderDjvuSurface()..attach(session);
  });

  tearDown(() async {
    surface.detach(session);
    controller.dispose();
    layers.dispose();
    selection.dispose();
    draft.dispose();
    await book.close();
    await directory.delete(recursive: true);
  });

  test('navigation follows outline, page anchors and fixed-page progress', () {
    surface.goToHref(book.toc!.first.subitems!.single.href!);
    expect(controller.page, 1);
    surface.goToHref('https://example.org/');
    expect(controller.page, 1);
    surface.pageRight();
    expect(controller.page, 2);
    surface.pageLeft();
    expect(controller.page, 1);
    surface.goToBookmark(cfi: '', progress: 0, anchorSectionIndex: 2);
    expect(controller.page, 2);
    surface.goToBookmark(cfi: fakeCfiFromIndex(0), progress: 1);
    expect(controller.page, 0);
    surface.goToBookmark(cfi: 'missing', progress: 1);
    expect(controller.page, 2);
    surface.toggleBookmark();
    expect(bookmarkToggles, 1);
  });

  test(
    'hidden-text search streams hits without evicting visible text',
    () async {
      await layers.load(0);
      final events = await surface.searchBookStream('quiet')!.toList();
      final results = events
          .whereType<ReaderSearchResults>()
          .expand((batch) => batch.results)
          .toList();
      expect(results, hasLength(2));
      expect(events.last, isA<ReaderSearchDone>());
      expect(results.map((result) => result.excerpt.match), ['Quiet', 'quiet']);
      expect(
        results.map((result) => djvuTextAnchorFromCfi(result.cfi)!.pageIndex),
        [0, 1],
      );
      expect(layers.peek(0), isNotNull);
      expect(layers.loadedLayers, hasLength(1));
    },
  );

  test('search navigation marks exactly its page and range', () {
    const range = DjvuTextRange(0, 6);
    surface.goToSearchResult(djvuTextCfi(1, range));
    expect(controller.page, 1);
    expect(marks, [(1, range)]);
    surface.clearSearch();
    expect(marks.last, (1, null));
    surface.goToSearchResult(fakeCfiFromIndex(2));
    expect(controller.page, 1, reason: 'a page bookmark is not a search hit');
  });

  test(
    'selection exposes saved-word context and clears retained state',
    () async {
      final layer = await layers.load(0);
      final range = layer.rangeOfText('Quiet')!;
      selection.start(0, range);
      controller.lockInput(true);
      final selected = (await surface.currentTextSelection())!;
      expect(selected.text, 'Quiet');
      expect(selected.cfiRange, djvuTextCfi(0, range));
      expect(
        selected.markedContextText,
        contains('[[Quiet]] café Привет reader'),
      );
      surface.showSelectionHighlightPreview(
        cfiRange: selected.cfiRange!,
        color: const Color(0xFFFFCC00),
        opacity: 0.5,
      );
      expect(selection.color, const Color(0xFFFFCC00).withValues(alpha: 0.5));
      surface.clearSelectionHighlightPreview();
      expect(selection.color, DjvuTextSelection.defaultColor);
      surface.clearSelectionAfterTextAction();
      expect(selection.isActive, isFalse);
      expect(controller.inputLocked, isFalse);
    },
  );

  test(
    'scan-only pages retain image-area previews and native thumbnails',
    () async {
      expect((await book.pageText(2)).isEmpty, isTrue);
      draft.start(2, const Rect.fromLTWH(0.1, 0.1, 0.3, 0.2));
      controller.lockInput(true);
      surface.showImageAreaSelectionPreview(
        pageIndex: 2,
        rect: const ReaderImageAreaRect(
          x: 0.1,
          y: 0.1,
          width: 0.3,
          height: 0.2,
        ),
        color: const Color(0xFFAA4400),
        opacity: 0.4,
      );
      surface.setImageAreaSelectionPreviewRetained(true);
      expect(draft.retained, isTrue);
      expect(draft.color, const Color(0xFFAA4400));
      expect(await surface.pageThumbnail(1), DjvuPages(book).pageThumbnail(1));
      expect(await surface.pageThumbnail(3), isNull);
      surface.clearImageAreaSelectionPreview();
      expect(draft.isActive, isFalse);
      expect(controller.inputLocked, isFalse);
    },
  );

  test(
    'detached session drops commands and never detaches a newer one',
    () async {
      final detached = ReaderDjvuSurface()..attach(session);
      detached.detach(session);
      detached
        ..goToSectionIndex(2)
        ..toggleBookmark()
        ..clearSelection();
      expect(controller.page, 0);
      expect(bookmarkToggles, 0);
      expect(detached.searchBookStream('quiet'), isNull);
      expect(await detached.currentTextSelection(), isNull);
      expect(await detached.pageThumbnail(0), isNull);
      final other = ReaderDjvuSession(
        controller: controller,
        book: book,
        layers: layers,
        selection: selection,
        draft: draft,
        onToggleBookmark: () {},
        onSearchMark: (_, _) {},
      );
      surface.detach(other);
      expect(surface.isAttached, isTrue);
    },
  );
}
