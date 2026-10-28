import 'package:flutter_test/flutter_test.dart';
import 'package:vellum/vellum.dart';

/// The cascade, as a table: a stylesheet and a document, and what each
/// element must compute to.
void main() {
  final ua = CssSheetSource(
    CssStyleSheet.parse(cssUserAgentStyleSheet),
    CssOrigin.userAgent,
  );

  /// Resolves [body] inside an XHTML document with [author] CSS and an
  /// optional [user] sheet; returns the style of the element with [id].
  ComputedStyle style(
    String body,
    String id, {
    String author = '',
    String user = '',
    StyleResolverOptions options = const StyleResolverOptions(),
  }) {
    final doc = ContentDocument.parseXml(
      '<html xmlns="http://www.w3.org/1999/xhtml"><body>$body</body></html>',
    );
    final resolver = StyleResolver([
      ua,
      if (user.isNotEmpty)
        CssSheetSource(CssStyleSheet.parse(user), CssOrigin.user),
      CssSheetSource(CssStyleSheet.parse(author), CssOrigin.author),
    ]);
    return resolver.resolve(doc, options: options)[doc.elementIndexById(id)];
  }

  group('user-agent defaults', () {
    test('block, inline, hidden and list elements', () {
      expect(style('<p id="x">a</p>', 'x').display, CssDisplay.block);
      expect(style('<em id="x">a</em>', 'x').display, CssDisplay.inline);
      expect(
        style('<ul><li id="x">a</li></ul>', 'x').display,
        CssDisplay.listItem,
      );
      expect(
        style('<p><script id="x">a</script></p>', 'x').display,
        CssDisplay.none,
      );
      expect(
        style('<p id="x" hidden="hidden">a</p>', 'x').display,
        CssDisplay.none,
      );
    });

    test('headings, emphasis and code', () {
      final h1 = style('<h1 id="x">a</h1>', 'x');
      expect(h1.fontSize, 32);
      expect(h1.fontWeight, 700);
      expect(h1.margin.top, const CssLength.px(32 * 0.67));
      expect(style('<section><h1 id="x">a</h1></section>', 'x').fontSize, 24);
      final em = style('<p><em id="x">a</em></p>', 'x');
      expect(em.fontStyle, CssFontStyle.italic);
      expect(em.fontWeight, 400);
      expect(style('<p><strong id="x">a</strong></p>', 'x').isBold, isTrue);
      final code = style('<pre id="x">a</pre>', 'x');
      expect(code.fontFamily, ['monospace']);
      expect(code.whiteSpace, CssWhiteSpace.pre);
      expect(
        style('<p><sup id="x">a</sup></p>', 'x').verticalAlign,
        CssVerticalAlign.sup,
      );
      expect(
        style('<p><sup id="x">a</sup></p>', 'x').fontSize,
        closeTo(16 / 1.2, 1e-9),
      );
      expect(style('<p><a id="x" href="#">a</a></p>', 'x').underline, isTrue);
      expect(
        style('<p><a id="x">a</a></p>', 'x').underline,
        isFalse,
        reason: 'no href',
      );
      expect(style('<p><s id="x">a</s></p>', 'x').lineThrough, isTrue);
    });

    test('lists and quotes', () {
      final ul = style('<ul id="x"><li>a</li></ul>', 'x');
      expect(ul.padding.left, const CssLength.px(40));
      expect(ul.listStyleType, 'disc');
      expect(style('<ol><li id="x">a</li></ol>', 'x').listStyleType, 'decimal');
      expect(
        style(
          '<ul><li><ul><li id="x">a</li></ul></li></ul>',
          'x',
        ).listStyleType,
        'circle',
      );
      expect(
        style('<blockquote id="x">a</blockquote>', 'x').margin.left,
        const CssLength.px(40),
      );
      expect(
        style('<blockquote id="x">a</blockquote>', 'x').margin.top,
        const CssLength.px(16),
      );
    });
  });

  group('cascade', () {
    test('specificity and order decide between author rules', () {
      const css =
          'p { color: red } .a { color: green } #i { color: blue } p { font-size: 20px } p { font-size: 10px }';
      expect(
        style('<p id="i" class="a">a</p>', 'i', author: css).color,
        0xFF0000FF,
      );
      expect(style('<p id="i" class="a">a</p>', 'i', author: css).fontSize, 10);
      expect(
        style(
          '<p id="i" class="a">a</p>',
          'i',
          author: 'p { color: red } .a { color: green }',
        ).color,
        0xFF008000,
      );
    });

    test('origins and importance', () {
      expect(
        style(
          '<p id="i">a</p>',
          'i',
          author: 'p { color: red }',
          user: 'p { color: blue }',
        ).color,
        0xFFFF0000,
        reason: 'author beats user',
      );
      expect(
        style(
          '<p id="i">a</p>',
          'i',
          author: 'p { color: red }',
          user: 'p { color: blue !important }',
        ).color,
        0xFF0000FF,
        reason: 'user important beats author',
      );
      expect(
        style(
          '<p id="i">a</p>',
          'i',
          author: 'p { color: red !important }',
          user: 'p { color: blue !important }',
        ).color,
        0xFF0000FF,
        reason: 'user important beats author important',
      );
      expect(
        style(
          '<p id="i">a</p>',
          'i',
          author: '#i { color: red } p { color: green !important }',
        ).color,
        0xFF008000,
        reason: 'important beats specificity',
      );
      expect(
        style(
          '<em id="i">a</em>',
          'i',
          user: 'em { font-style: normal }',
        ).fontStyle,
        CssFontStyle.normal,
        reason: 'user beats the user-agent sheet',
      );
    });

    test('inline style beats every author rule, not user important', () {
      expect(
        style(
          '<p id="i" style="color: red">a</p>',
          'i',
          author: '#i { color: green }',
        ).color,
        0xFFFF0000,
      );
      expect(
        style(
          '<p id="i" style="color: red">a</p>',
          'i',
          author: '#i { color: green !important }',
        ).color,
        0xFF008000,
      );
      expect(
        style(
          '<p id="i" style="color: red !important">a</p>',
          'i',
          author: '#i { color: green !important }',
        ).color,
        0xFFFF0000,
      );
      expect(
        style(
          '<p id="i" style="color: red !important">a</p>',
          'i',
          user: 'p { color: blue !important }',
        ).color,
        0xFF0000FF,
      );
    });

    test('presentational attributes sit below author rules', () {
      expect(
        style('<p id="i" align="center">a</p>', 'i').textAlign,
        CssTextAlign.center,
      );
      expect(
        style(
          '<p id="i" align="center">a</p>',
          'i',
          author: 'p { text-align: left }',
        ).textAlign,
        CssTextAlign.left,
      );
      expect(
        style(
          '<p><img id="i" width="200" height="50%" align="left"/></p>',
          'i',
        ).width,
        const CssLength.px(200),
      );
      expect(
        style(
          '<p><img id="i" width="200" height="50%" align="left"/></p>',
          'i',
        ).height,
        const CssLength.percent(50),
      );
      expect(
        style('<p><img id="i" align="left"/></p>', 'i').float,
        CssFloat.left,
      );
      expect(
        style('<p id="i" height="2em" width="1em">a</p>', 'i').margin.top,
        const CssLength.px(32),
      );
      expect(
        style('<p id="i" height="2em" width="1em">a</p>', 'i').textIndent,
        const CssLength.px(16),
      );
      expect(
        style(
          '<p><font id="i" size="5" color="ff0000" face="Arial">a</font></p>',
          'i',
        ).fontSize,
        24,
      );
      expect(
        style(
          '<p><font id="i" size="+1" color="ff0000" face="Arial">a</font></p>',
          'i',
        ).fontSize,
        18,
      );
      expect(
        style(
          '<p><font id="i" size="5" color="ff0000" face="Arial">a</font></p>',
          'i',
        ).color,
        0xFFFF0000,
      );
      expect(
        style(
          '<p><font id="i" size="5" color="ff0000" face="Arial">a</font></p>',
          'i',
        ).fontFamily,
        ['Arial'],
      );
      expect(
        style(
          '<table id="i" bgcolor="yellow"><tr><td>a</td></tr></table>',
          'i',
        ).backgroundColor,
        0xFFFFFF00,
      );
      expect(
        style('<p id="i" dir="rtl">a</p>', 'i').direction,
        CssDirection.rtl,
      );
    });

    test('media blocks for print are skipped, others apply', () {
      expect(
        style(
          '<p id="i">a</p>',
          'i',
          author: '@media print { p { color: red } }',
        ).color,
        0xFF000000,
      );
      expect(
        style(
          '<p id="i">a</p>',
          'i',
          author: '@media screen { p { color: red } }',
        ).color,
        0xFFFF0000,
      );
      expect(
        style(
          '<p id="i">a</p>',
          'i',
          author: '@media all and (min-width: 1px) { p { color: red } }',
        ).color,
        0xFFFF0000,
      );
      expect(
        style(
          '<p id="i">a</p>',
          'i',
          author: '@media not print { p { color: red } }',
        ).color,
        0xFFFF0000,
      );
      expect(
        style(
          '<p id="i">a</p>',
          'i',
          author: '@media print, screen { p { color: red } }',
        ).color,
        0xFFFF0000,
      );
      expect(
        style(
          '<p id="i">a</p>',
          'i',
          author: '@media only print { p { color: red } }',
        ).color,
        0xFF000000,
      );
    });

    test('an invalid declaration leaves the earlier valid one', () {
      expect(
        style(
          '<p id="i">a</p>',
          'i',
          author: 'p { color: red; color: nope }',
        ).color,
        0xFFFF0000,
      );
      expect(
        style(
          '<p id="i">a</p>',
          'i',
          author: 'p { color: red } p:unknown { color: blue }',
        ).color,
        0xFFFF0000,
      );
    });
  });

  group('inheritance and computation', () {
    test('inherited properties flow down, others reset', () {
      const body =
          '<div id="d" style="color: red; margin: 10px; text-align: center; font-weight: bold"><p id="p">a<em id="e">b</em></p></div>';
      final p = style(body, 'p');
      expect(p.color, 0xFFFF0000);
      expect(p.textAlign, CssTextAlign.center);
      expect(p.fontWeight, 700);
      expect(
        p.margin.top,
        const CssLength.px(16),
        reason: 'the UA margin, not the parent\'s',
      );
      final e = style(body, 'e');
      expect(e.fontStyle, CssFontStyle.italic);
      expect(e.margin.top, CssLength.zero);
    });

    test('inherit, initial and unset', () {
      const body =
          '<div style="color: red; margin-top: 10px"><p id="a" style="margin-top: inherit">a</p><p id="b" style="color: initial">b</p><p id="c" style="color: unset; margin-top: unset">c</p></div>';
      expect(style(body, 'a').margin.top, const CssLength.px(10));
      expect(style(body, 'b').color, 0xFF000000);
      expect(style(body, 'c').color, 0xFFFF0000);
      expect(style(body, 'c').margin.top, CssLength.zero);
    });

    test('font sizes: keywords, em chains, rem, percent, larger', () {
      expect(style('<p id="i">a</p>', 'i').fontSize, 16);
      expect(
        style(
          '<p id="i">a</p>',
          'i',
          options: const StyleResolverOptions(rootFontSize: 20),
        ).fontSize,
        20,
      );
      expect(
        style('<p id="i" style="font-size: large">a</p>', 'i').fontSize,
        18,
      );
      expect(
        style(
          '<div style="font-size: 20px"><p id="i" style="font-size: 1.5em">a</p></div>',
          'i',
        ).fontSize,
        30,
      );
      expect(
        style(
          '<div style="font-size: 20px"><p id="i" style="font-size: 150%">a</p></div>',
          'i',
        ).fontSize,
        30,
      );
      expect(
        style(
          '<div style="font-size: 20px"><p id="i" style="font-size: 2rem">a</p></div>',
          'i',
        ).fontSize,
        32,
      );
      expect(
        style(
          '<div style="font-size: 2em"><p id="i" style="font-size: 2em">a</p></div>',
          'i',
        ).fontSize,
        64,
      );
      expect(
        style(
          '<div style="font-size: 20px"><p id="i" style="font-size: larger">a</p></div>',
          'i',
        ).fontSize,
        24,
      );
      expect(
        style(
          '<p id="i" style="font-size: 10vw">a</p>',
          'i',
          options: const StyleResolverOptions(viewportWidth: 300),
        ).fontSize,
        30,
      );
    });

    test('lengths resolve em against the element\'s own size', () {
      final p = style(
        '<p id="i" style="font-size: 20px; margin: 1em 5%; text-indent: 2em; padding-left: 1rem">a</p>',
        'i',
      );
      expect(p.margin.top, const CssLength.px(20));
      expect(p.margin.right, const CssLength.percent(5));
      expect(p.textIndent, const CssLength.px(40));
      expect(p.padding.left, const CssLength.px(16));
    });

    test('line height: normal, number, length and percent', () {
      expect(style('<p id="i">a</p>', 'i').lineHeight, CssLineHeight.normal);
      expect(
        style('<p id="i" style="line-height: 1.5">a</p>', 'i').lineHeight,
        const CssLineHeight.factor(1.5),
      );
      expect(
        style('<p id="i" style="line-height: 24px">a</p>', 'i').lineHeight,
        const CssLineHeight.px(24),
      );
      expect(
        style('<p id="i" style="line-height: 150%">a</p>', 'i').lineHeight,
        const CssLineHeight.px(24),
      );
      expect(
        style('<p id="i" style="line-height: 1.5em">a</p>', 'i').lineHeight,
        const CssLineHeight.px(24),
      );
      // A number inherits as a factor, a percentage as the computed px.
      expect(
        style(
          '<div style="line-height: 150%"><p id="i" style="font-size: 32px">a</p></div>',
          'i',
        ).lineHeight,
        const CssLineHeight.px(24),
      );
      expect(
        style(
          '<div style="line-height: 1.5"><p id="i" style="font-size: 32px">a</p></div>',
          'i',
        ).lineHeight.resolve(32),
        48,
      );
    });

    test('font weight: bold, bolder, lighter, numbers', () {
      expect(
        style('<p id="i" style="font-weight: bold">a</p>', 'i').fontWeight,
        700,
      );
      expect(
        style('<p id="i" style="font-weight: 350">a</p>', 'i').fontWeight,
        350,
      );
      expect(
        style(
          '<b><em id="i" style="font-weight: bolder">a</em></b>',
          'i',
        ).fontWeight,
        900,
      );
      expect(
        style('<p id="i" style="font-weight: bolder">a</p>', 'i').fontWeight,
        700,
      );
      expect(
        style(
          '<b><em id="i" style="font-weight: lighter">a</em></b>',
          'i',
        ).fontWeight,
        400,
      );
    });

    test('colors: currentcolor and transparent', () {
      final p = style(
        '<p id="i" style="color: red; border: 1px solid; background: transparent">a</p>',
        'i',
      );
      expect(p.borderColor.top, 0xFFFF0000);
      expect(p.borderWidth.top, 1);
      expect(p.borderStyle.top, CssBorderStyle.solid);
      expect(p.backgroundColor, 0);
      final q = style(
        '<p id="i" style="border: 2px dashed blue; border-left-style: none">a</p>',
        'i',
      );
      expect(q.borderWidth.left, 0, reason: 'none zeroes the width');
      expect(q.borderWidth.right, 2);
      expect(q.borderColor.right, 0xFF0000FF);
      expect(
        style(
          '<p id="i" style="background-color: currentcolor; color: green">a</p>',
          'i',
        ).backgroundColor,
        0xFF008000,
      );
    });

    test('page breaks, floats, decoration, spacing, white-space', () {
      final p = style(
        '<p id="i" style="page-break-before: always; break-after: avoid-page; page-break-inside: avoid; float: right; text-decoration: underline overline; letter-spacing: 0.1em; word-spacing: 2px; white-space: pre-wrap; text-transform: uppercase; hyphens: auto; vertical-align: 20%">a</p>',
        'i',
      );
      expect(p.pageBreakBefore, CssPageBreak.always);
      expect(p.pageBreakAfter, CssPageBreak.avoid);
      expect(p.avoidPageBreakInside, isTrue);
      expect(p.float, CssFloat.right);
      expect(p.underline, isTrue);
      expect(p.overline, isTrue);
      expect(p.lineThrough, isFalse);
      expect(p.letterSpacing, closeTo(1.6, 1e-9));
      expect(p.wordSpacing, 2);
      expect(p.whiteSpace, CssWhiteSpace.preWrap);
      expect(p.textTransform, CssTextTransform.uppercase);
      expect(p.hyphens, CssHyphens.auto);
      expect(p.verticalAlign, CssVerticalAlign.length);
      expect(p.verticalAlignLength, const CssLength.percent(20));
    });

    test('widths and heights keep auto, none and percentages', () {
      final p = style(
        '<p id="i" style="width: 50%; max-width: 30em; min-height: 10px">a</p>',
        'i',
      );
      expect(p.width, const CssLength.percent(50));
      expect(p.height, isNull);
      expect(p.maxWidth, const CssLength.px(480));
      expect(p.maxHeight, isNull);
      expect(p.minHeight, const CssLength.px(10));
      expect(p.minWidth, CssLength.zero);
    });
  });

  group('ComputedStyles', () {
    test('text nodes take the parent style and identical styles are shared', () {
      final doc = ContentDocument.parseXml(
        '<html xmlns="http://www.w3.org/1999/xhtml"><body><p>one</p><p>two</p><p class="x">three</p></body></html>',
      );
      final styles = StyleResolver([
        ua,
        CssSheetSource(
          CssStyleSheet.parse('.x { color: red }'),
          CssOrigin.author,
        ),
      ]).resolve(doc);
      final body = doc.firstChildOf(0);
      final p1 = doc.childAt(body, 0);
      final p2 = doc.childAt(body, 1);
      final p3 = doc.childAt(body, 2);
      expect(styles[doc.firstChildOf(p1)], same(styles[p1]));
      expect(styles[p1], same(styles[p2]));
      expect(styles[p3], isNot(same(styles[p1])));
      expect(styles.distinctStyleCount, 4, reason: 'html, body, p, p.x');
      expect(styles.rootFontSize, 16);
    });
  });
}
