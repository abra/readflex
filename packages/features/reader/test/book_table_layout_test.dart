import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/book_custom_css.dart';
import 'package:pagecraft/all_formats.dart';

/// Tables under the reader's style sheet, laid out by pagecraft with the test
/// font (every glyph a square as wide as the font size): as the WebView
/// reader showed them, a table keeps its words whole and its content's
/// width up to 40em, and scrolls sideways when that is wider than the
/// column.
void main() {
  const theme = ReaderThemeData(
    backgroundColor: Color(0xFFF7F1E6),
    surfaceColor: Color(0xFFFCF7EF),
    panelColor: Color(0xFFF0E7D8),
    primaryTextColor: Color(0xFF2A221B),
    secondaryTextColor: Color(0xFF76685B),
    dividerColor: Color(0xFFD9CAB4),
    accentColor: Color(0xFFB86A2D),
    highlightYellow: Color(0xFFF6E7AC),
    highlightGreen: Color(0xFFBCE6D1),
    highlightBlue: Color(0xFFC2D9F0),
    highlightPink: Color(0xFFEAB8C9),
    highlightPurple: Color(0xFFD1BAE8),
  );
  // A 10px root: 40em of the tables' 0.95em is 380px.
  final book = BookStyle(
    fontScale: 10 / 16,
    readerStyleSheet: buildBookCustomCSS(
      theme: theme,
      sizes: const BookCustomCssSizes(
        rootFontSize: 10,
        textScale: 1,
        lineHeight: 1.5,
      ),
    ),
  );

  ColumnLayout layOut(String body, {double width = 200}) {
    final doc = ContentDocument.parseXml(
      '<html xmlns="http://www.w3.org/1999/xhtml"><body>$body</body></html>',
    );
    final styles =
        StyleResolver([
          CssSheetSource(
            CssStyleSheet.parse(cssUserAgentStyleSheet),
            CssOrigin.userAgent,
          ),
          ...readerSheetSources(book),
        ]).resolve(
          doc,
          options: StyleResolverOptions(rootFontSize: book.rootFontSize),
        );
    final column = ColumnLayout.layout(
      buildSectionBoxes(doc, styles),
      width: width,
      pageHeight: 1000,
      bookStyle: book,
      text: TextLayoutEnvironment(
        styler: InlineStyler(bookStyle: book, fonts: const BookFonts()),
        imageSize: (_) => null,
        maxImageHeight: 1000,
      ),
    );
    addTearDown(column.dispose);
    return column;
  }

  test('a table of long words scrolls, every word whole', () {
    const labels = [
      'Configuration',
      'Coordination',
      'Distribution',
      'Concurrency',
      'Communication',
      'Observability',
    ];
    final column = layOut(
      '<table><tr>${labels.map((l) => '<td>$l</td>').join()}</tr></table>'
      '<p>After the table.</p>',
    );
    final scroller = column.scrollers.single;
    expect(scroller.viewport.width, lessThanOrEqualTo(200));
    expect(scroller.contentWidth, greaterThan(200));
    for (final label in labels) {
      final cell = column.paragraphs.firstWhere(
        (t) => t.paragraph.box.text == label,
      );
      expect(cell.paragraph.lines, hasLength(1), reason: '$label is whole');
      expect(cell.scroller, same(scroller));
    }
    final after = column.paragraphs.last;
    expect(after.scroller, isNull);
    expect(after.rect.right, lessThanOrEqualTo(200));
  });

  test('a table of prose is as wide as 40em and wraps there', () {
    final prose = List.filled(30, 'word').join(' ');
    final column = layOut('<table><tr><td>$prose</td><td>x</td></tr></table>');
    final scroller = column.scrollers.single;
    // 40em at 0.95 of 10px, with the cells' padding inside it.
    expect(scroller.contentWidth, closeTo(380, 1));
    final cell = column.paragraphs.first;
    expect(cell.paragraph.lines.length, greaterThan(1));
  });

  test('a table that fits does not scroll', () {
    final column = layOut('<table><tr><td>a</td><td>b</td></tr></table>');
    expect(column.scrollers, isEmpty);
  });
}
