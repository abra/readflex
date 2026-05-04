import 'package:flutter_test/flutter_test.dart';
import 'package:reader_webview/reader_webview.dart';

void main() {
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
        'atEnd': false,
        'atStart': false,
      });

      expect(position.cfi, 'epubcfi(/6/4!/4/2)');
      expect(position.fraction, 0.35);
      expect(position.chapterTitle, 'Chapter 1');
      expect(position.chapterCurrentPage, 5);
      expect(position.chapterTotalPages, 20);
      expect(position.bookCurrentPage, 84);
      expect(position.bookTotalPages, 200);
      expect(position.sizeTotal, 480000);
      expect(position.atEnd, isFalse);
      expect(position.atStart, isFalse);
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
      // atEnd / atStart default to false so old payloads (or fixtures
      // that haven't added the field) keep working without coercion.
      expect(position.atEnd, isFalse);
      expect(position.atStart, isFalse);
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
  });

  group('FoliateStyle', () {
    test('toMap includes all properties with defaults', () {
      const style = FoliateStyle();
      final map = style.toMap();

      expect(map['fontSize'], 1.4);
      expect(map['fontName'], '');
      expect(map['fontPath'], '');
      expect(map['fontWeight'], 400);
      expect(map['letterSpacing'], 0);
      expect(map['spacing'], 1.8);
      expect(map['paragraphSpacing'], 1.0);
      expect(map['textIndent'], 0);
      expect(map['fontColor'], '#000000');
      expect(map['backgroundColor'], '#FFFFFF');
      expect(map['topMargin'], 90);
      expect(map['bottomMargin'], 50);
      expect(map['sideMargin'], 6);
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
        fontColor: '#FFFFFF',
        backgroundColor: '#1A1A1A',
        pageTurnStyle: 'scroll',
        topMargin: 40,
        bottomMargin: 30,
        sideMargin: 8,
      );
      final map = style.toMap();

      expect(map['fontSize'], 1.8);
      expect(map['fontColor'], '#FFFFFF');
      expect(map['backgroundColor'], '#1A1A1A');
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
      expect(style.toMap().length, 26);
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
