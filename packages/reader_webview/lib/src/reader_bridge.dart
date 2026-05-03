/// Data types for the JS ↔ Flutter bridge protocol.
///
/// JS → Flutter handlers report events (position, selection).
/// Flutter → JS calls control the WebView (navigate, style, highlights).
library;

/// Current reading position inside a book WebView, reported by foliate-js
/// on every page turn. Includes the EPUB CFI (for exact restore), an
/// overall progress fraction, and optional chapter context.
class BookPosition {
  const BookPosition({
    required this.cfi,
    required this.fraction,
    this.chapterTitle,
    this.chapterCurrentPage,
    this.chapterTotalPages,
    this.bookCurrentPage,
    this.bookTotalPages,
  });

  /// EPUB Canonical Fragment Identifier — exact position in the book.
  final String cfi;

  /// Overall reading progress in [0, 1].
  final double fraction;

  final String? chapterTitle;
  final int? chapterCurrentPage;
  final int? chapterTotalPages;

  /// Page number across the whole book (1-based). Surfaced by foliate-js
  /// alongside the chapter-scoped count for "page 84 of 200" UIs.
  final int? bookCurrentPage;
  final int? bookTotalPages;

  factory BookPosition.fromMap(Map<String, dynamic> map) {
    return BookPosition(
      cfi: map['cfi'] as String,
      fraction: (map['percentage'] as num?)?.toDouble() ?? 0,
      chapterTitle: map['chapterTitle'] as String?,
      chapterCurrentPage: (map['chapterCurrentPage'] as num?)?.toInt(),
      chapterTotalPages: (map['chapterTotalPages'] as num?)?.toInt(),
      bookCurrentPage: (map['bookCurrentPage'] as num?)?.toInt(),
      bookTotalPages: (map['bookTotalPages'] as num?)?.toInt(),
    );
  }
}

/// User text selection surfaced from the reader WebView. Books carry a
/// CFI range, articles carry a scroll fraction — either is enough to
/// restore the anchor later (e.g. for a highlight).
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

/// Appearance bundle for the foliate-js book reader. Passed as the
/// `style` query param on the initial `index.html` load and via
/// `changeStyle()` thereafter. Field names mirror the JS object keys that
/// foliate-js's `book.js` reads — do not rename without updating the
/// bundled JS.
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

/// A highlight annotation the WebView should render. For books the
/// [cfiRange] pins the annotation to exact text; articles match by
/// [text]. [color] overrides the default yellow when set.
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
