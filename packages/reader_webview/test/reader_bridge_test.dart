import 'package:flutter_test/flutter_test.dart';
import 'package:reader_webview/reader_webview.dart';

void main() {
  group('ReaderBookmarkChange', () {
    test('fromMap parses add event', () {
      final change = ReaderBookmarkChange.fromMap({
        'remove': false,
        'detail': {
          'cfi': 'epubcfi(/6/34!/4/2)',
          'content': 'Bookmark context',
          'percentage': 0.56,
          'anchorExact': 'Bookmark exact text',
          'anchorPrefix': 'Before text',
          'anchorSuffix': 'After text',
          'anchorSectionIndex': 12,
          'anchorSectionPage': 3,
        },
        'source': 'pull-down',
      });

      expect(change.remove, isFalse);
      expect(change.id, isNull);
      expect(change.cfi, 'epubcfi(/6/34!/4/2)');
      expect(change.content, 'Bookmark context');
      expect(change.progress, 0.56);
      expect(change.source, ReaderBookmarkChangeSource.pullDown);
      expect(change.anchorExact, 'Bookmark exact text');
      expect(change.anchorPrefix, 'Before text');
      expect(change.anchorSuffix, 'After text');
      expect(change.anchorSectionIndex, 12);
      expect(change.anchorSectionPage, 3);
    });

    test('fromMap parses remove event id', () {
      final change = ReaderBookmarkChange.fromMap({
        'remove': true,
        'detail': {
          'id': 'bookmark-1',
          'cfi': 'epubcfi(/6/34!/4/2)',
          'percentage': 0.56,
        },
        'source': 'chrome',
      });

      expect(change.remove, isTrue);
      expect(change.id, 'bookmark-1');
      expect(change.cfi, 'epubcfi(/6/34!/4/2)');
      expect(change.source, ReaderBookmarkChangeSource.chrome);
    });

    test('fromMap tolerates malformed bridge values', () {
      final change = ReaderBookmarkChange.fromMap({
        'remove': 'yes',
        'detail': {
          'cfi': 42,
          'content': false,
          'percentage': 'half',
        },
      });

      expect(change.remove, isFalse);
      expect(change.cfi, '');
      expect(change.content, '');
      expect(change.progress, 0.0);
      expect(change.source, ReaderBookmarkChangeSource.unknown);
    });
  });

  group('BookPosition', () {
    test('fromMap parses all fields', () {
      final position = BookPosition.fromMap({
        'cfi': 'epubcfi(/6/4!/4/2)',
        'percentage': 0.35,
        'chapterTitle': 'Chapter 1',
        'chapterCurrentPage': 5,
        'chapterTotalPages': 20,
        'bookCurrentPage': 84,
        'bookTotalPages': 200,
        'sizeTotal': 480000,
        'reason': 'page',
        'pageProgressionDirection': 'rtl',
        'atEnd': false,
        'atStart': false,
        'bookmark': {
          'exists': true,
          'cfi': 'epubcfi(/6/4)',
          'id': 'bookmark-1',
        },
      });

      expect(position.cfi, 'epubcfi(/6/4!/4/2)');
      expect(position.fraction, 0.35);
      expect(position.chapterTitle, 'Chapter 1');
      expect(position.chapterCurrentPage, 5);
      expect(position.chapterTotalPages, 20);
      expect(position.bookCurrentPage, 84);
      expect(position.bookTotalPages, 200);
      expect(position.sizeTotal, 480000);
      expect(position.relocationReason, 'page');
      expect(position.pageProgressionRtl, isTrue);
      expect(position.atEnd, isFalse);
      expect(position.atStart, isFalse);
      expect(position.bookmarkExists, isTrue);
      expect(position.bookmarkCfi, 'epubcfi(/6/4)');
      expect(position.bookmarkId, 'bookmark-1');
    });

    test('fromMap handles missing optional fields', () {
      final position = BookPosition.fromMap({
        'cfi': 'epubcfi(/6/4)',
        'percentage': 0.0,
      });

      expect(position.cfi, 'epubcfi(/6/4)');
      expect(position.fraction, 0.0);
      expect(position.chapterTitle, isNull);
      expect(position.chapterCurrentPage, isNull);
      expect(position.chapterTotalPages, isNull);
      expect(position.bookCurrentPage, isNull);
      expect(position.bookTotalPages, isNull);
      expect(position.sizeTotal, isNull);
      expect(position.pageProgressionRtl, isNull);
      // atEnd / atStart default to false so old payloads (or fixtures
      // that haven't added the field) keep working without coercion.
      expect(position.atEnd, isFalse);
      expect(position.atStart, isFalse);
      expect(position.bookmarkExists, isFalse);
      expect(position.bookmarkCfi, isNull);
    });

    test('fromMap coerces sizeTotal from num to int', () {
      // foliate-js's sizeTotal is typed as number — large books may
      // surface it as a JSON double (e.g. 1.5e6) rather than int. The
      // bridge must coerce so callers always see int.
      final position = BookPosition.fromMap({
        'cfi': 'epubcfi(/6/4)',
        'percentage': 0.5,
        'sizeTotal': 1500000.0,
      });
      expect(position.sizeTotal, 1500000);
      expect(position.sizeTotal, isA<int>());
    });

    test('fromMap parses atEnd=true', () {
      final position = BookPosition.fromMap({
        'cfi': 'epubcfi(/6/4)',
        'percentage': 0.0,
        'bookCurrentPage': 0,
        'bookTotalPages': 200,
        'atEnd': true,
      });

      // Note: foliate-js reports fraction=0 / current=0 when atEnd is
      // true (we are on the trailing blank buffer past content). The
      // bridge is a passive transport — the bloc is what overrides
      // these to "100% / last page".
      expect(position.atEnd, isTrue);
      expect(position.fraction, 0.0);
      expect(position.bookCurrentPage, 0);
    });

    test('fromMap handles integer percentage', () {
      final position = BookPosition.fromMap({
        'cfi': 'epubcfi(/6/4)',
        'percentage': 0,
      });
      expect(position.fraction, 0.0);
    });

    test('fromMap tolerates malformed bridge values', () {
      final position = BookPosition.fromMap({
        'cfi': 42,
        'percentage': 'invalid',
        'chapterTitle': 10,
        'chapterCurrentPage': 'page',
        'bookTotalPages': '200',
        'sizeTotal': false,
        'atEnd': 'yes',
      });

      expect(position.cfi, '');
      expect(position.fraction, 0.0);
      expect(position.chapterTitle, isNull);
      expect(position.chapterCurrentPage, isNull);
      expect(position.bookTotalPages, isNull);
      expect(position.sizeTotal, isNull);
      expect(position.atEnd, isFalse);
    });
  });

  group('ReaderTocItem', () {
    test('readerTocItemsFromBridge flattens nested foliate toc items', () {
      final items = readerTocItemsFromBridge([
        {
          'label': 'Part One',
          'href': 'part.xhtml',
          'subitems': [
            {
              'label': 'Chapter One',
              'href': 'part.xhtml#chapter-one',
              'subitems': [
                {
                  'label': 'Scene',
                  'href': 'part.xhtml#scene',
                },
              ],
            },
          ],
        },
        {
          'label': 'Appendix',
          'href': 'appendix.xhtml',
          'level': 1,
        },
      ]);

      expect(items.map((item) => item.label), [
        'Part One',
        'Chapter One',
        'Scene',
        'Appendix',
      ]);
      expect(items.map((item) => item.href), [
        'part.xhtml',
        'part.xhtml#chapter-one',
        'part.xhtml#scene',
        'appendix.xhtml',
      ]);
      expect(items.map((item) => item.level), [1, 2, 3, 1]);
    });

    test('fromMap parses foliate toc item', () {
      final item = ReaderTocItem.fromMap({
        'label': 'Chapter 7',
        'href': 'chapter_07.xhtml',
        'id': 12,
        'level': 2,
        'startPercentage': 0.42,
        'startPage': 128,
      });

      expect(item.label, 'Chapter 7');
      expect(item.href, 'chapter_07.xhtml');
      expect(item.id, '12');
      expect(item.level, 2);
      expect(item.startPercentage, 0.42);
      expect(item.startPage, 128);
    });

    test('fromMap tolerates missing optional fields', () {
      final item = ReaderTocItem.fromMap({
        'label': 'Cover',
        'href': 'cover.xhtml',
      });

      expect(item.label, 'Cover');
      expect(item.href, 'cover.xhtml');
      expect(item.id, isNull);
      expect(item.level, 1);
      expect(item.startPercentage, isNull);
      expect(item.startPage, isNull);
    });

    test('fromMap tolerates malformed bridge values', () {
      final item = ReaderTocItem.fromMap({
        'label': 42,
        'href': false,
        'level': 'two',
        'startPercentage': 'half',
        'startPage': 'ten',
      });

      expect(item.label, '');
      expect(item.href, '');
      expect(item.level, 1);
      expect(item.startPercentage, isNull);
      expect(item.startPage, isNull);
    });
  });

  group('ReaderSearchResult', () {
    test('fromMap parses foliate search result', () {
      final result = ReaderSearchResult.fromMap({
        'cfi': 'epubcfi(/6/34!/4/2)',
        'chapterTitle': 'Chapter 9',
        'excerpt': {
          'pre': 'before ',
          'match': 'needle',
          'post': ' after',
        },
      });

      expect(result.cfi, 'epubcfi(/6/34!/4/2)');
      expect(result.chapterTitle, 'Chapter 9');
      expect(result.excerpt.pre, 'before ');
      expect(result.excerpt.match, 'needle');
      expect(result.excerpt.post, ' after');
    });

    test('fromMap tolerates missing optional fields', () {
      final result = ReaderSearchResult.fromMap({
        'cfi': 'epubcfi(/6/34)',
      });

      expect(result.cfi, 'epubcfi(/6/34)');
      expect(result.chapterTitle, isNull);
      expect(result.excerpt.pre, '');
      expect(result.excerpt.match, '');
      expect(result.excerpt.post, '');
    });

    test('fromMap tolerates malformed bridge values', () {
      final result = ReaderSearchResult.fromMap({
        'cfi': 10,
        'chapterTitle': false,
        'excerpt': 'needle',
      });

      expect(result.cfi, '');
      expect(result.chapterTitle, isNull);
      expect(result.excerpt.match, '');
    });
  });

  group('ReaderSearchEvent', () {
    test('fromMap parses progress event', () {
      final event = ReaderSearchEvent.fromMap({
        'requestId': 3,
        'type': 'progress',
        'progress': 0.42,
      });

      expect(event, isA<ReaderSearchProgress>());
      final progress = event as ReaderSearchProgress;
      expect(progress.requestId, 3);
      expect(progress.progress, 0.42);
    });

    test('fromMap parses result batch event', () {
      final event = ReaderSearchEvent.fromMap({
        'requestId': 7,
        'type': 'results',
        'items': [
          {
            'cfi': 'epubcfi(/6/34!/4/2)',
            'chapterTitle': 'Chapter 9',
            'excerpt': {
              'pre': 'before ',
              'match': 'needle',
              'post': ' after',
            },
          },
        ],
      });

      expect(event, isA<ReaderSearchResults>());
      final results = event as ReaderSearchResults;
      expect(results.requestId, 7);
      expect(results.results, hasLength(1));
      expect(results.results.single.cfi, 'epubcfi(/6/34!/4/2)');
      expect(results.results.single.chapterTitle, 'Chapter 9');
      expect(results.results.single.excerpt.match, 'needle');
    });

    test('fromMap parses foliate section-shaped result event', () {
      final event = ReaderSearchEvent.fromMap({
        'requestId': 8,
        'label': 'Chapter 10',
        'subitems': [
          {
            'cfi': 'epubcfi(/6/40!/4/2)',
            'excerpt': {'match': 'needle'},
          },
        ],
      });

      expect(event, isA<ReaderSearchResults>());
      final results = event as ReaderSearchResults;
      expect(results.results.single.chapterTitle, 'Chapter 10');
      expect(results.results.single.excerpt.match, 'needle');
    });

    test('fromMap parses terminal events', () {
      final done = ReaderSearchEvent.fromMap({
        'requestId': 9,
        'type': 'done',
      });
      final error = ReaderSearchEvent.fromMap({
        'requestId': 10,
        'type': 'error',
        'message': 'boom',
      });

      expect(done, isA<ReaderSearchDone>());
      expect(error, isA<ReaderSearchError>());
      expect((error as ReaderSearchError).message, 'boom');
    });

    test('fromMap tolerates malformed bridge values', () {
      final event = ReaderSearchEvent.fromMap({
        'requestId': 'bad',
        'type': false,
        'items': ['invalid'],
      });

      expect(event, isA<ReaderSearchResults>());
      final results = event as ReaderSearchResults;
      expect(results.requestId, -1);
      expect(results.results, isEmpty);
    });
  });

  group('ReaderSelection', () {
    test('fromMap parses scroll-offset-only selection', () {
      // Legacy article selections (pre-EPUB migration) carried only a
      // scroll fraction; the field is still on the bridge type because
      // the highlight flow forwards it to storage.
      final selection = ReaderSelection.fromMap({
        'text': 'Hello world',
        'scrollOffset': 0.5,
      });

      expect(selection.text, 'Hello world');
      expect(selection.scrollOffset, 0.5);
      expect(selection.cfiRange, isNull);
    });

    test('fromMap parses book selection with CFI', () {
      final selection = ReaderSelection.fromMap({
        'text': 'Some text',
        'cfi': 'epubcfi(/6/4!/4/2,/1:0,/1:10)',
      });

      expect(selection.text, 'Some text');
      expect(selection.cfiRange, 'epubcfi(/6/4!/4/2,/1:0,/1:10)');
      expect(selection.scrollOffset, isNull);
    });

    test('fromMap handles all fields present', () {
      final selection = ReaderSelection.fromMap({
        'text': 'Both fields',
        'cfi': 'epubcfi(/6/4)',
        'scrollOffset': 0.3,
      });

      expect(selection.text, 'Both fields');
      expect(selection.cfiRange, 'epubcfi(/6/4)');
      expect(selection.scrollOffset, 0.3);
    });

    test('fromMap tolerates malformed bridge values', () {
      final selection = ReaderSelection.fromMap({
        'text': 42,
        'cfi': false,
        'scrollOffset': 'half',
      });

      expect(selection.text, '');
      expect(selection.cfiRange, isNull);
      expect(selection.scrollOffset, isNull);
    });
  });

  group('FoliateStyle', () {
    test('toMap includes all properties with defaults', () {
      const style = FoliateStyle();
      final map = style.toMap();

      expect(map['fontSize'], 1.4);
      expect(map['textScale'], 1.0);
      expect(map['deviceFontScale'], 1.0);
      expect(map['fontName'], '');
      expect(map['fontPath'], '');
      expect(map['fontWeight'], 400);
      expect(map['letterSpacing'], 0);
      expect(map['spacing'], 1.8);
      expect(map['paragraphSpacing'], 1.0);
      expect(map['textIndent'], 0);
      expect(map['fontColor'], '#000000');
      expect(map['backgroundColor'], '#FFFFFF');
      expect(map['accentColor'], '#000000');
      expect(map['topMargin'], 90);
      expect(map['bottomMargin'], 50);
      expect(map['sideMargin'], 8);
      expect(map['justify'], true);
      expect(map['hyphenate'], false);
      expect(map['textAlign'], '');
      expect(map['pageTurnStyle'], 'slide');
      expect(map['maxColumnCount'], 0);
      expect(map['writingMode'], 'horizontal-tb');
      expect(map['backgroundImage'], '');
      expect(map['allowScript'], false);
      expect(map['customCSS'], '');
      expect(map['customCSSEnabled'], false);
      expect(map['overrideFont'], true);
      expect(map['overrideColor'], true);
      expect(map['useBookLayout'], true);
    });

    test('override flags can be disabled', () {
      const style = FoliateStyle(
        overrideFont: false,
        overrideColor: false,
        useBookLayout: false,
      );
      final map = style.toMap();

      expect(map['overrideFont'], false);
      expect(map['overrideColor'], false);
      expect(map['useBookLayout'], false);
    });

    test('toMap reflects custom values', () {
      const style = FoliateStyle(
        fontSize: 1.8,
        textScale: 1.15,
        deviceFontScale: 1.12,
        fontColor: '#FFFFFF',
        backgroundColor: '#1A1A1A',
        accentColor: '#9B1C31',
        pageTurnStyle: 'scroll',
        topMargin: 40,
        bottomMargin: 30,
        sideMargin: 8,
      );
      final map = style.toMap();

      expect(map['fontSize'], 1.8);
      expect(map['textScale'], 1.15);
      expect(map['deviceFontScale'], 1.12);
      expect(map['fontColor'], '#FFFFFF');
      expect(map['backgroundColor'], '#1A1A1A');
      expect(map['accentColor'], '#9B1C31');
      expect(map['pageTurnStyle'], 'scroll');
      expect(map['topMargin'], 40);
      expect(map['bottomMargin'], 30);
      expect(map['sideMargin'], 8);
      // Defaults are still present.
      expect(map['allowScript'], false);
      expect(map['writingMode'], 'horizontal-tb');
    });

    test('toMap has expected key count', () {
      const style = FoliateStyle();
      expect(style.toMap().length, 29);
    });
  });

  group('ReaderHighlight', () {
    test('toMap includes required fields', () {
      const highlight = ReaderHighlight(
        id: 'h-1',
        text: 'Highlighted text',
      );

      final map = highlight.toMap();
      expect(map['id'], 'h-1');
      expect(map['text'], 'Highlighted text');
      expect(map.containsKey('cfiRange'), isFalse);
      expect(map.containsKey('color'), isFalse);
    });

    test('toMap includes optional fields when set', () {
      const highlight = ReaderHighlight(
        id: 'h-2',
        text: 'Book highlight',
        cfiRange: 'epubcfi(/6/4!/4/2,/1:0,/1:15)',
        color: '#FFE600',
      );

      final map = highlight.toMap();
      expect(map['id'], 'h-2');
      expect(map['text'], 'Book highlight');
      expect(map['cfiRange'], 'epubcfi(/6/4!/4/2,/1:0,/1:15)');
      expect(map['color'], '#FFE600');
    });
  });
}
