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
    this.sizeTotal,
    this.relocationReason,
    this.atEnd = false,
    this.atStart = false,
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

  /// Total byte size of all linear sections — the same quantity foliate-js
  /// uses internally when computing [bookCurrentPage] and [bookTotalPages].
  /// The Dart side keeps a copy so the slider can reproduce
  /// `floor(fraction × sizeTotal / 1500)` exactly while the user drags.
  /// Constant per book; reported on every relocate for simplicity.
  final int? sizeTotal;

  /// foliate-js relocation reason. User-driven navigation is reported as
  /// `page`, `scroll`, or `snap`; programmatic jumps may omit it.
  final String? relocationReason;

  /// `true` when the paginator reports we are on its trailing "blank
  /// buffer" pages past the actual content. foliate-js still emits
  /// onRelocated with `fraction=0` / `bookCurrentPage=0` on those
  /// pages, so consumers should pin progress to 100% when this is set
  /// instead of trusting the bogus numbers.
  final bool atEnd;

  /// `true` when the paginator reports we are at (or before) the very
  /// first readable page. The complement of [atEnd]; surfaced for
  /// symmetry, currently unused.
  final bool atStart;

  factory BookPosition.fromMap(Map<String, dynamic> map) {
    return BookPosition(
      cfi: map['cfi'] as String,
      fraction: (map['percentage'] as num?)?.toDouble() ?? 0,
      chapterTitle: map['chapterTitle'] as String?,
      chapterCurrentPage: (map['chapterCurrentPage'] as num?)?.toInt(),
      chapterTotalPages: (map['chapterTotalPages'] as num?)?.toInt(),
      bookCurrentPage: (map['bookCurrentPage'] as num?)?.toInt(),
      bookTotalPages: (map['bookTotalPages'] as num?)?.toInt(),
      sizeTotal: (map['sizeTotal'] as num?)?.toInt(),
      relocationReason: map['reason'] as String?,
      atEnd: map['atEnd'] as bool? ?? false,
      atStart: map['atStart'] as bool? ?? false,
    );
  }
}

/// Table-of-contents item emitted by foliate-js.
///
/// [href] is the navigation target accepted by `goToHref(...)`; [level]
/// preserves nesting depth so Flutter can render chapter hierarchy without
/// walking a recursive tree.
class ReaderTocItem {
  const ReaderTocItem({
    required this.label,
    required this.href,
    required this.level,
    this.id,
    this.startPercentage,
    this.startPage,
  });

  final String label;
  final String href;
  final String? id;
  final int level;
  final double? startPercentage;
  final int? startPage;

  factory ReaderTocItem.fromMap(Map<String, dynamic> map) {
    return ReaderTocItem(
      label: map['label'] as String? ?? '',
      href: map['href'] as String? ?? '',
      id: map['id']?.toString(),
      level: (map['level'] as num?)?.toInt() ?? 1,
      startPercentage: (map['startPercentage'] as num?)?.toDouble(),
      startPage: (map['startPage'] as num?)?.toInt(),
    );
  }
}

/// Search result emitted by foliate-js.
///
/// [cfi] is the exact target accepted by `goToCfi(...)`; [chapterTitle]
/// is best-effort context from the TOC progress map.
class ReaderSearchResult {
  const ReaderSearchResult({
    required this.cfi,
    required this.excerpt,
    this.chapterTitle,
  });

  final String cfi;
  final ReaderSearchExcerpt excerpt;
  final String? chapterTitle;

  factory ReaderSearchResult.fromMap(Map<String, dynamic> map) {
    return ReaderSearchResult(
      cfi: map['cfi'] as String? ?? '',
      excerpt: ReaderSearchExcerpt.fromMap(
        Map<String, dynamic>.from(map['excerpt'] as Map? ?? const {}),
      ),
      chapterTitle: map['chapterTitle'] as String?,
    );
  }
}

/// Streaming search event emitted by the WebView.
///
/// The reader sends progress and result batches as foliate-js scans sections,
/// so Flutter can render partial results instead of waiting for a full-book
/// search to finish.
sealed class ReaderSearchEvent {
  const ReaderSearchEvent({required this.requestId});

  final int requestId;

  factory ReaderSearchEvent.fromMap(Map<String, dynamic> map) {
    final requestId = (map['requestId'] as num?)?.toInt() ?? -1;
    final type =
        map['type'] as String? ??
        (map.containsKey('process') || map.containsKey('progress')
            ? 'progress'
            : 'results');

    return switch (type) {
      'progress' => ReaderSearchProgress(
        requestId: requestId,
        progress: _progressFromMap(map),
      ),
      'done' => ReaderSearchDone(requestId: requestId),
      'error' => ReaderSearchError(
        requestId: requestId,
        message: map['message'] as String? ?? 'Book search failed',
      ),
      _ => ReaderSearchResults(
        requestId: requestId,
        results: _searchResultsFromMap(map),
      ),
    };
  }
}

final class ReaderSearchProgress extends ReaderSearchEvent {
  const ReaderSearchProgress({
    required super.requestId,
    required this.progress,
  });

  final double progress;
}

final class ReaderSearchResults extends ReaderSearchEvent {
  const ReaderSearchResults({
    required super.requestId,
    required this.results,
  });

  final List<ReaderSearchResult> results;
}

final class ReaderSearchDone extends ReaderSearchEvent {
  const ReaderSearchDone({required super.requestId});
}

final class ReaderSearchError extends ReaderSearchEvent {
  const ReaderSearchError({
    required super.requestId,
    required this.message,
  });

  final String message;
}

double _progressFromMap(Map<String, dynamic> map) {
  final value = (map['progress'] ?? map['process']) as num?;
  return (value?.toDouble() ?? 0).clamp(0.0, 1.0).toDouble();
}

List<ReaderSearchResult> _searchResultsFromMap(Map<String, dynamic> map) {
  final items = map['items'];
  if (items is List) {
    return [
      for (final item in items)
        if (item is Map)
          ReaderSearchResult.fromMap(Map<String, dynamic>.from(item)),
    ];
  }

  final chapterTitle = (map['chapterTitle'] ?? map['label']) as String?;
  final subitems = map['subitems'];
  if (subitems is List) {
    return [
      for (final item in subitems)
        if (item is Map)
          ReaderSearchResult.fromMap({
            ...Map<String, dynamic>.from(item),
            'chapterTitle': ?chapterTitle,
          }),
    ];
  }

  if (map['cfi'] != null) {
    return [
      ReaderSearchResult.fromMap({
        ...map,
        'chapterTitle': ?chapterTitle,
      }),
    ];
  }

  return const [];
}

/// Split text around a search match. foliate-js returns excerpts this way so
/// Flutter can emphasize only the matched fragment.
class ReaderSearchExcerpt {
  const ReaderSearchExcerpt({
    this.pre = '',
    this.match = '',
    this.post = '',
  });

  final String pre;
  final String match;
  final String post;

  factory ReaderSearchExcerpt.fromMap(Map<String, dynamic> map) {
    return ReaderSearchExcerpt(
      pre: map['pre'] as String? ?? '',
      match: map['match'] as String? ?? '',
      post: map['post'] as String? ?? '',
    );
  }
}

/// User text selection surfaced from the reader WebView. The CFI range is
/// the anchor used to restore highlights later. [scrollOffset] is
/// vestigial from the removed article reader.
class ReaderSelection {
  const ReaderSelection({
    required this.text,
    this.cfiRange,
    this.scrollOffset,
  });

  final String text;

  /// CFI range of the selection.
  final String? cfiRange;

  /// Vestigial — was emitted by the removed article reader.
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

  // Value equality so `BookReaderWebView.didUpdateWidget` can decide
  // whether to push a `changeStyle(...)` JS call by comparing
  // `oldWidget.foliateStyle != widget.foliateStyle` directly. Earlier
  // it was diffing through `jsonEncode(toMap())` on both sides — two
  // heavy encodes on every parent rebuild (highlight add/remove,
  // PreferencesScope notify, etc.).
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoliateStyle &&
          fontSize == other.fontSize &&
          fontName == other.fontName &&
          fontPath == other.fontPath &&
          fontWeight == other.fontWeight &&
          letterSpacing == other.letterSpacing &&
          spacing == other.spacing &&
          paragraphSpacing == other.paragraphSpacing &&
          textIndent == other.textIndent &&
          fontColor == other.fontColor &&
          backgroundColor == other.backgroundColor &&
          topMargin == other.topMargin &&
          bottomMargin == other.bottomMargin &&
          sideMargin == other.sideMargin &&
          justify == other.justify &&
          hyphenate == other.hyphenate &&
          textAlign == other.textAlign &&
          pageTurnStyle == other.pageTurnStyle &&
          maxColumnCount == other.maxColumnCount &&
          writingMode == other.writingMode &&
          backgroundImage == other.backgroundImage &&
          allowScript == other.allowScript &&
          customCSS == other.customCSS &&
          customCSSEnabled == other.customCSSEnabled &&
          overrideFont == other.overrideFont &&
          overrideColor == other.overrideColor &&
          useBookLayout == other.useBookLayout;

  @override
  int get hashCode => Object.hashAll([
    fontSize,
    fontName,
    fontPath,
    fontWeight,
    letterSpacing,
    spacing,
    paragraphSpacing,
    textIndent,
    fontColor,
    backgroundColor,
    topMargin,
    bottomMargin,
    sideMargin,
    justify,
    hyphenate,
    textAlign,
    pageTurnStyle,
    maxColumnCount,
    writingMode,
    backgroundImage,
    allowScript,
    customCSS,
    customCSSEnabled,
    overrideFont,
    overrideColor,
    useBookLayout,
  ]);
}

/// A highlight annotation the WebView should render. The [cfiRange] pins
/// the annotation to exact text in the EPUB. [color] overrides the
/// default yellow when set.
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
