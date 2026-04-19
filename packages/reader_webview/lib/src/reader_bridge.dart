/// Data types for the JS ↔ Flutter bridge protocol.
///
/// JS → Flutter handlers report events (position, selection).
/// Flutter → JS calls control the WebView (navigate, style, highlights).
library;

/// Position report from the article reader (scroll fraction).
class ArticlePosition {
  const ArticlePosition({required this.fraction});

  final double fraction;

  factory ArticlePosition.fromMap(Map<String, dynamic> map) {
    return ArticlePosition(fraction: (map['fraction'] as num).toDouble());
  }
}

/// Position report from the book reader (CFI + progress fraction).
class BookPosition {
  const BookPosition({
    required this.cfi,
    required this.fraction,
    this.chapterTitle,
    this.chapterCurrentPage,
    this.chapterTotalPages,
  });

  /// EPUB Canonical Fragment Identifier — exact position in the book.
  final String cfi;

  /// Overall reading progress in [0, 1].
  final double fraction;

  final String? chapterTitle;
  final int? chapterCurrentPage;
  final int? chapterTotalPages;

  factory BookPosition.fromMap(Map<String, dynamic> map) {
    return BookPosition(
      cfi: map['cfi'] as String,
      fraction: (map['percentage'] as num?)?.toDouble() ?? 0,
      chapterTitle: map['chapterTitle'] as String?,
      chapterCurrentPage: (map['chapterCurrentPage'] as num?)?.toInt(),
      chapterTotalPages: (map['chapterTotalPages'] as num?)?.toInt(),
    );
  }
}

/// Text selection from the WebView.
class ReaderSelection {
  const ReaderSelection({
    required this.text,
    this.cfiRange,
    this.scrollOffset,
  });

  final String text;

  /// For books: CFI range of the selection.
  final String? cfiRange;

  /// For articles: scroll fraction at time of selection.
  final double? scrollOffset;

  factory ReaderSelection.fromMap(Map<String, dynamic> map) {
    return ReaderSelection(
      text: map['text'] as String,
      cfiRange: map['cfi'] as String?,
      scrollOffset: (map['scrollOffset'] as num?)?.toDouble(),
    );
  }
}

/// Style parameters passed to the WebView via `changeStyle()`.
class ReaderStyle {
  const ReaderStyle({
    this.fontFamily,
    this.fontSize,
    this.lineHeight,
    this.textColor,
    this.bgColor,
    this.accentColor,
    this.secondaryColor,
    this.dividerColor,
    this.codeBgColor,
    this.padding,
  });

  final String? fontFamily;
  final String? fontSize;
  final String? lineHeight;
  final String? textColor;
  final String? bgColor;
  final String? accentColor;
  final String? secondaryColor;
  final String? dividerColor;
  final String? codeBgColor;
  final String? padding;

  Map<String, String> toMap() {
    final map = <String, String>{};
    if (fontFamily != null) map['fontFamily'] = fontFamily!;
    if (fontSize != null) map['fontSize'] = fontSize!;
    if (lineHeight != null) map['lineHeight'] = lineHeight!;
    if (textColor != null) map['textColor'] = textColor!;
    if (bgColor != null) map['bgColor'] = bgColor!;
    if (accentColor != null) map['accentColor'] = accentColor!;
    if (secondaryColor != null) map['secondaryColor'] = secondaryColor!;
    if (dividerColor != null) map['dividerColor'] = dividerColor!;
    if (codeBgColor != null) map['codeBgColor'] = codeBgColor!;
    if (padding != null) map['padding'] = padding!;
    return map;
  }
}

/// Style parameters for the foliate-js book reader.
///
/// Passed as the `style` URL param when loading `index.html`.
/// Property names match the JS object keys that `book.js` reads.
class FoliateStyle {
  const FoliateStyle({
    this.fontSize = 1.4,
    this.fontName = '',
    this.fontPath = '',
    this.fontWeight = 400,
    this.letterSpacing = 0,
    this.spacing = 1.8,
    this.paragraphSpacing = 1.0,
    this.textIndent = 0,
    this.fontColor = '#000000',
    this.backgroundColor = '#FFFFFF',
    this.topMargin = 90,
    this.bottomMargin = 50,
    this.sideMargin = 6,
    this.justify = true,
    this.hyphenate = false,
    this.textAlign = '',
    this.pageTurnStyle = 'slide',
    this.maxColumnCount = 0,
    this.writingMode = 'horizontal-tb',
    this.backgroundImage = '',
    this.allowScript = false,
    this.customCSS = '',
    this.customCSSEnabled = false,
    this.overrideFont = true,
    this.overrideColor = true,
    this.useBookLayout = true,
  });

  final double fontSize;
  final String fontName;
  final String fontPath;
  final double fontWeight;
  final double letterSpacing;

  /// Line height multiplier.
  final double spacing;
  final double paragraphSpacing;
  final double textIndent;

  /// Hex color including `#`, e.g. `'#000000'`.
  final String fontColor;

  /// Hex color including `#`, e.g. `'#FFFFFF'`.
  final String backgroundColor;

  final double topMargin;
  final double bottomMargin;

  /// Side margin in percent.
  final double sideMargin;

  final bool justify;
  final bool hyphenate;
  final String textAlign;

  /// `'slide'`, `'scroll'`, or `'noAnimation'`.
  final String pageTurnStyle;
  final int maxColumnCount;

  /// `'horizontal-tb'` or `'vertical-rl'`.
  final String writingMode;
  final String backgroundImage;
  final bool allowScript;
  final String customCSS;
  final bool customCSSEnabled;

  /// When `false`, publisher font-family / font-weight win over reader prefs.
  final bool overrideFont;

  /// When `false`, publisher text color wins over reader prefs.
  final bool overrideColor;

  /// When `false`, publisher line-height / indent / hyphenation / margins win.
  final bool useBookLayout;

  Map<String, dynamic> toMap() => {
    'fontSize': fontSize,
    'fontName': fontName,
    'fontPath': fontPath,
    'fontWeight': fontWeight,
    'letterSpacing': letterSpacing,
    'spacing': spacing,
    'paragraphSpacing': paragraphSpacing,
    'textIndent': textIndent,
    'fontColor': fontColor,
    'backgroundColor': backgroundColor,
    'topMargin': topMargin,
    'bottomMargin': bottomMargin,
    'sideMargin': sideMargin,
    'justify': justify,
    'hyphenate': hyphenate,
    'textAlign': textAlign,
    'pageTurnStyle': pageTurnStyle,
    'maxColumnCount': maxColumnCount,
    'writingMode': writingMode,
    'backgroundImage': backgroundImage,
    'allowScript': allowScript,
    'customCSS': customCSS,
    'customCSSEnabled': customCSSEnabled,
    'overrideFont': overrideFont,
    'overrideColor': overrideColor,
    'useBookLayout': useBookLayout,
  };
}

/// A highlight to render in the WebView.
class ReaderHighlight {
  const ReaderHighlight({
    required this.id,
    required this.text,
    this.cfiRange,
    this.color,
  });

  final String id;
  final String text;

  /// For books: CFI range for exact positioning.
  final String? cfiRange;

  /// Hex color override (e.g. '#FFE600').
  final String? color;

  Map<String, dynamic> toMap() => {
    'id': id,
    'text': text,
    if (cfiRange != null) 'cfiRange': cfiRange,
    if (color != null) 'color': color,
  };
}
