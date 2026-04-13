import 'package:flutter_test/flutter_test.dart';
import 'package:reader_webview/reader_webview.dart';

void main() {
  group('ArticlePosition', () {
    test('fromMap parses fraction', () {
      final position = ArticlePosition.fromMap({'fraction': 0.42});
      expect(position.fraction, 0.42);
    });

    test('fromMap handles integer fraction', () {
      final position = ArticlePosition.fromMap({'fraction': 1});
      expect(position.fraction, 1.0);
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
      });

      expect(position.cfi, 'epubcfi(/6/4!/4/2)');
      expect(position.fraction, 0.35);
      expect(position.chapterTitle, 'Chapter 1');
      expect(position.chapterCurrentPage, 5);
      expect(position.chapterTotalPages, 20);
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
    test('fromMap parses article selection', () {
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

  group('ReaderStyle', () {
    test('toMap includes only non-null fields', () {
      const style = ReaderStyle(
        fontFamily: 'Geist',
        fontSize: '18px',
        bgColor: '#ffffff',
      );

      final map = style.toMap();
      expect(map, {
        'fontFamily': 'Geist',
        'fontSize': '18px',
        'bgColor': '#ffffff',
      });
    });

    test('toMap returns empty map when all fields null', () {
      const style = ReaderStyle();
      expect(style.toMap(), isEmpty);
    });

    test('toMap includes all fields when set', () {
      const style = ReaderStyle(
        fontFamily: 'serif',
        fontSize: '20px',
        lineHeight: '1.8',
        textColor: '#000',
        bgColor: '#fff',
        accentColor: '#0066cc',
        secondaryColor: '#666',
        dividerColor: '#e0e0e0',
        codeBgColor: '#f5f5f5',
        padding: '24px',
      );

      final map = style.toMap();
      expect(map.length, 10);
      expect(map['fontFamily'], 'serif');
      expect(map['padding'], '24px');
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
      expect(style.toMap().length, 23);
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
