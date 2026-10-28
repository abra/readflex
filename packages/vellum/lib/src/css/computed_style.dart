/// The computed style of an element: every supported property resolved
/// to the value layout uses. Relative font sizes and `em` lengths are in
/// px, percentages stay percentages (layout knows what they refer to),
/// keywords are enums. Immutable, with value equality so the resolver
/// can share one instance between elements that compute the same.
library;

import 'css_values.dart';

enum CssDisplay {
  block,
  inline,
  inlineBlock,
  none,
  listItem,
  table,
  inlineTable,
  tableRowGroup,
  tableHeaderGroup,
  tableFooterGroup,
  tableRow,
  tableCell,
  tableCaption,
  tableColumn,
  tableColumnGroup,
  ruby,
  rubyBase,
  rubyText,
  contents;

  /// Whether the element starts a block of its own in the flow.
  bool get isBlockLevel => switch (this) {
    block || listItem || table || tableCaption => true,
    _ => false,
  };

  static CssDisplay fromKeyword(String keyword) => switch (keyword) {
    'block' => block,
    'inline' => inline,
    'inline-block' => inlineBlock,
    'none' => none,
    'list-item' => listItem,
    'table' => table,
    'inline-table' => inlineTable,
    'table-row-group' => tableRowGroup,
    'table-header-group' => tableHeaderGroup,
    'table-footer-group' => tableFooterGroup,
    'table-row' => tableRow,
    'table-cell' => tableCell,
    'table-caption' => tableCaption,
    'table-column' => tableColumn,
    'table-column-group' => tableColumnGroup,
    'ruby' => ruby,
    'ruby-base' => rubyBase,
    'ruby-text' => rubyText,
    'contents' => contents,
    _ => inline,
  };
}

enum CssTextAlign { start, end, left, right, center, justify }

enum CssFontStyle { normal, italic, oblique }

enum CssPageBreak { auto, always, avoid, left, right }

enum CssFloat { none, left, right }

enum CssClear { none, left, right, both }

enum CssWhiteSpace {
  normal,
  nowrap,
  pre,
  preWrap,
  preLine;

  /// Whether runs of whitespace collapse to one space.
  bool get collapses => this == normal || this == nowrap || this == preLine;

  /// Whether line breaks in the source are honored.
  bool get preservesNewlines =>
      this == pre || this == preWrap || this == preLine;

  bool get wraps => this != nowrap && this != pre;
}

enum CssTextTransform { none, capitalize, uppercase, lowercase }

enum CssHyphens { none, manual, auto }

enum CssDirection { ltr, rtl }

enum CssUnicodeBidi {
  normal,
  embed,
  isolate,
  bidiOverride,
  isolateOverride,
  plaintext,
}

enum CssVerticalAlign {
  baseline,
  sub,
  sup,
  textTop,
  textBottom,
  middle,
  top,
  bottom,
  length,
}

enum CssBorderStyle { none, hidden, solid, dashed, dotted, double }

/// One value per edge.
class CssEdges<T> {
  const CssEdges(this.top, this.right, this.bottom, this.left);

  const CssEdges.all(T value) : this(value, value, value, value);

  final T top;
  final T right;
  final T bottom;
  final T left;

  @override
  bool operator ==(Object other) =>
      other is CssEdges<T> &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom &&
      other.left == left;

  @override
  int get hashCode => Object.hash(top, right, bottom, left);

  @override
  String toString() => '($top $right $bottom $left)';
}

/// `line-height`: a factor of the font size (`normal` and numbers) or a
/// length in px.
class CssLineHeight {
  const CssLineHeight.factor(this.factor) : px = null;

  const CssLineHeight.px(this.px) : factor = null;

  /// `normal`: the font's own line gap. Layout substitutes the font
  /// metrics; 1.2 is the usual stand-in.
  static const normal = CssLineHeight.factor(null);

  final double? factor;
  final double? px;

  bool get isNormal => factor == null && px == null;

  /// The line height in px for [fontSize], taking [normalFactor] for
  /// `normal`.
  double resolve(double fontSize, {double normalFactor = 1.2}) =>
      px ?? (factor ?? normalFactor) * fontSize;

  @override
  bool operator ==(Object other) =>
      other is CssLineHeight && other.factor == factor && other.px == px;

  @override
  int get hashCode => Object.hash(factor, px);

  @override
  String toString() => px != null
      ? '${px}px'
      : factor == null
      ? 'normal'
      : '$factor';
}

class ComputedStyle {
  const ComputedStyle({
    required this.fontFamily,
    required this.fontSize,
    required this.fontStyle,
    required this.fontWeight,
    required this.smallCaps,
    required this.color,
    required this.backgroundColor,
    required this.textAlign,
    required this.textIndent,
    required this.lineHeight,
    required this.margin,
    required this.padding,
    required this.borderWidth,
    required this.borderStyle,
    required this.borderColor,
    required this.display,
    required this.pageBreakBefore,
    required this.pageBreakAfter,
    required this.avoidPageBreakInside,
    required this.width,
    required this.height,
    required this.maxWidth,
    required this.maxHeight,
    required this.minWidth,
    required this.minHeight,
    required this.float,
    required this.clear,
    required this.underline,
    required this.overline,
    required this.lineThrough,
    required this.letterSpacing,
    required this.wordSpacing,
    required this.whiteSpace,
    required this.verticalAlign,
    required this.verticalAlignLength,
    required this.textTransform,
    required this.hyphens,
    required this.direction,
    required this.unicodeBidi,
    required this.listStyleType,
    required this.visible,
    required this.widows,
    required this.orphans,
  });

  final List<String> fontFamily;

  /// In px.
  final double fontSize;
  final CssFontStyle fontStyle;

  /// 1–1000.
  final int fontWeight;
  final bool smallCaps;

  /// `0xAARRGGBB`.
  final int color;
  final int backgroundColor;
  final CssTextAlign textAlign;

  /// px or a percentage of the containing block's width.
  final CssLength textIndent;
  final CssLineHeight lineHeight;

  /// px or a percentage; null is `auto`.
  final CssEdges<CssLength?> margin;
  final CssEdges<CssLength> padding;

  /// In px; 0 when the style is `none` or `hidden`.
  final CssEdges<double> borderWidth;
  final CssEdges<CssBorderStyle> borderStyle;
  final CssEdges<int> borderColor;
  final CssDisplay display;
  final CssPageBreak pageBreakBefore;
  final CssPageBreak pageBreakAfter;
  final bool avoidPageBreakInside;

  /// px or a percentage; null is `auto`.
  final CssLength? width;
  final CssLength? height;

  /// px or a percentage; null is `none`.
  final CssLength? maxWidth;
  final CssLength? maxHeight;
  final CssLength minWidth;
  final CssLength minHeight;
  final CssFloat float;
  final CssClear clear;
  final bool underline;
  final bool overline;
  final bool lineThrough;

  /// In px; 0 is `normal`.
  final double letterSpacing;
  final double wordSpacing;
  final CssWhiteSpace whiteSpace;
  final CssVerticalAlign verticalAlign;

  /// For [CssVerticalAlign.length]: px or a percentage of the line height.
  final CssLength? verticalAlignLength;
  final CssTextTransform textTransform;
  final CssHyphens hyphens;
  final CssDirection direction;
  final CssUnicodeBidi unicodeBidi;

  /// A keyword (`disc`, `decimal`, `none`) or a literal marker string.
  final String listStyleType;
  final bool visible;
  final int widows;
  final int orphans;

  bool get isBold => fontWeight >= 600;

  bool get isItalic => fontStyle != CssFontStyle.normal;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComputedStyle &&
          _sameFamilies(other.fontFamily, fontFamily) &&
          other.fontSize == fontSize &&
          other.fontStyle == fontStyle &&
          other.fontWeight == fontWeight &&
          other.smallCaps == smallCaps &&
          other.color == color &&
          other.backgroundColor == backgroundColor &&
          other.textAlign == textAlign &&
          other.textIndent == textIndent &&
          other.lineHeight == lineHeight &&
          other.margin == margin &&
          other.padding == padding &&
          other.borderWidth == borderWidth &&
          other.borderStyle == borderStyle &&
          other.borderColor == borderColor &&
          other.display == display &&
          other.pageBreakBefore == pageBreakBefore &&
          other.pageBreakAfter == pageBreakAfter &&
          other.avoidPageBreakInside == avoidPageBreakInside &&
          other.width == width &&
          other.height == height &&
          other.maxWidth == maxWidth &&
          other.maxHeight == maxHeight &&
          other.minWidth == minWidth &&
          other.minHeight == minHeight &&
          other.float == float &&
          other.clear == clear &&
          other.underline == underline &&
          other.overline == overline &&
          other.lineThrough == lineThrough &&
          other.letterSpacing == letterSpacing &&
          other.wordSpacing == wordSpacing &&
          other.whiteSpace == whiteSpace &&
          other.verticalAlign == verticalAlign &&
          other.verticalAlignLength == verticalAlignLength &&
          other.textTransform == textTransform &&
          other.hyphens == hyphens &&
          other.direction == direction &&
          other.unicodeBidi == unicodeBidi &&
          other.listStyleType == listStyleType &&
          other.visible == visible &&
          other.widows == widows &&
          other.orphans == orphans;

  static bool _sameFamilies(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll([
    Object.hashAll(fontFamily),
    fontSize,
    fontStyle,
    fontWeight,
    smallCaps,
    color,
    backgroundColor,
    textAlign,
    textIndent,
    lineHeight,
    margin,
    padding,
    borderWidth,
    borderStyle,
    borderColor,
    display,
    pageBreakBefore,
    pageBreakAfter,
    avoidPageBreakInside,
    width,
    height,
    maxWidth,
    maxHeight,
    minWidth,
    minHeight,
    float,
    clear,
    underline,
    overline,
    lineThrough,
    letterSpacing,
    wordSpacing,
    whiteSpace,
    verticalAlign,
    verticalAlignLength,
    textTransform,
    hyphens,
    direction,
    unicodeBidi,
    listStyleType,
    visible,
    widows,
    orphans,
  ]);

  @override
  String toString() =>
      'ComputedStyle(${fontFamily.join(', ')} ${fontSize}px $fontWeight '
      '$fontStyle color #${color.toRadixString(16)} $display)';
}
