// Data types for the JS ↔ Flutter bridge protocol.
//
// JS → Flutter handlers report events (position, selection).
// Flutter → JS calls control the WebView (navigate, style, highlights).

import 'dart:convert';

/// Safely coerces a WebView bridge value into a string-keyed map.
///
/// `flutter_inappwebview` can surface JavaScript payloads as generic maps, and
/// malformed publisher/reader scripts may occasionally send strings or wrong
/// shapes. Bridge parsing must treat that input as untrusted and avoid hard
/// casts inside handler callbacks.
Map<String, dynamic>? readerBridgeMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is String) result[key] = entry.value;
    }
    return result;
  }
  if (value is String) {
    try {
      final decoded = jsonDecode(value);
      return readerBridgeMap(decoded);
    } catch (_) {
      return null;
    }
  }
  return null;
}

List<dynamic>? readerBridgeList(Object? value) {
  if (value is List) return value;
  if (value is String) {
    try {
      final decoded = jsonDecode(value);
      return decoded is List ? decoded : null;
    } catch (_) {
      return null;
    }
  }
  return null;
}

String? _string(Object? value) => value is String ? value : null;

String? _nonEmptyString(Object? value) {
  final text = _string(value)?.trim();
  return text == null || text.isEmpty ? null : text;
}

int? _int(Object? value) => value is num ? value.toInt() : null;

double? _double(Object? value) => value is num ? value.toDouble() : null;

bool? _bool(Object? value) => value is bool ? value : null;

List<String> _stringList(Object? value) {
  final list = readerBridgeList(value) ?? const [];
  return [
    for (final item in list)
      if (item is String && item.trim().isNotEmpty) item,
  ];
}

/// Document-level capabilities reported by the reader runtime.
///
/// Some formats expose optional structures such as a table of contents.
/// Flutter treats null as "not detected yet".
class ReaderDocumentFeatures {
  const ReaderDocumentFeatures({
    required this.format,
    this.hasTableOfContents,
    this.hasSearchableText,
  });

  final String? format;
  final bool? hasTableOfContents;
  final bool? hasSearchableText;

  factory ReaderDocumentFeatures.fromMap(Map<String, dynamic> map) {
    return ReaderDocumentFeatures(
      format: _string(map['format']),
      hasTableOfContents: _bool(map['hasToc']),
      hasSearchableText:
          _bool(map['hasSearchableText']) ?? _bool(map['hasTextLayer']),
    );
  }
}

enum ReaderBookmarkChangeSource { unknown, pullDown, chrome }

ReaderBookmarkChangeSource _bookmarkChangeSource(Object? value) {
  return switch (_string(value)) {
    'pull-down' => ReaderBookmarkChangeSource.pullDown,
    'chrome' => ReaderBookmarkChangeSource.chrome,
    _ => ReaderBookmarkChangeSource.unknown,
  };
}

/// Bookmark add/remove event emitted by foliate-js.
class ReaderBookmarkChange {
  const ReaderBookmarkChange({
    required this.remove,
    required this.cfi,
    required this.content,
    required this.progress,
    required this.source,
    this.id,
    this.anchorExact,
    this.anchorPrefix,
    this.anchorSuffix,
    this.anchorSectionIndex,
    this.anchorSectionPage,
  });

  final bool remove;
  final String? id;
  final String cfi;
  final String content;
  final double progress;
  final ReaderBookmarkChangeSource source;
  final String? anchorExact;
  final String? anchorPrefix;
  final String? anchorSuffix;
  final int? anchorSectionIndex;
  final int? anchorSectionPage;

  factory ReaderBookmarkChange.fromMap(Map<String, dynamic> map) {
    final detail = readerBridgeMap(map['detail']) ?? const {};
    return ReaderBookmarkChange(
      remove: _bool(map['remove']) ?? false,
      id: _nonEmptyString(detail['id']),
      cfi: _string(detail['cfi']) ?? '',
      content: _string(detail['content']) ?? '',
      progress: (_double(detail['percentage']) ?? 0).clamp(0.0, 1.0).toDouble(),
      source: _bookmarkChangeSource(map['source']),
      anchorExact: _nonEmptyString(detail['anchorExact']),
      anchorPrefix: _nonEmptyString(detail['anchorPrefix']),
      anchorSuffix: _nonEmptyString(detail['anchorSuffix']),
      anchorSectionIndex: _int(detail['anchorSectionIndex']),
      anchorSectionPage: _int(detail['anchorSectionPage']),
    );
  }
}

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
    this.pageProgressionRtl,
    this.atEnd = false,
    this.atStart = false,
    this.bookmarkExists = false,
    this.bookmarkCfi,
    this.bookmarkId,
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

  /// True when the publication progresses right-to-left. Text direction and
  /// page progression are separate: saved articles keep their iframe root LTR
  /// for stable pagination, but can still read forward from right to left.
  final bool? pageProgressionRtl;

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

  /// Current visible page has a bookmark annotation.
  final bool bookmarkExists;
  final String? bookmarkCfi;
  final String? bookmarkId;

  factory BookPosition.fromMap(Map<String, dynamic> map) {
    final bookmark = readerBridgeMap(map['bookmark']) ?? const {};
    final pageProgressionDirection = _string(map['pageProgressionDirection']);
    return BookPosition(
      cfi: _string(map['cfi']) ?? '',
      fraction: _double(map['percentage']) ?? 0,
      chapterTitle: _string(map['chapterTitle']),
      chapterCurrentPage: _int(map['chapterCurrentPage']),
      chapterTotalPages: _int(map['chapterTotalPages']),
      bookCurrentPage: _int(map['bookCurrentPage']),
      bookTotalPages: _int(map['bookTotalPages']),
      sizeTotal: _int(map['sizeTotal']),
      relocationReason: _string(map['reason']),
      pageProgressionRtl: pageProgressionDirection == null
          ? null
          : pageProgressionDirection == 'rtl',
      atEnd: _bool(map['atEnd']) ?? false,
      atStart: _bool(map['atStart']) ?? false,
      bookmarkExists: _bool(bookmark['exists']) ?? false,
      bookmarkCfi: _string(bookmark['cfi']),
      bookmarkId: _string(bookmark['id']),
    );
  }
}

/// Flattens a raw foliate-js TOC tree into drawer-ready items.
List<ReaderTocItem> readerTocItemsFromBridge(Object? value) {
  final rawItems = readerBridgeList(value) ?? const [];
  final items = <ReaderTocItem>[];

  void collect(Object? raw, int parentLevel) {
    final data = readerBridgeMap(raw);
    if (data == null) return;

    final level = _int(data['level']) ?? parentLevel + 1;
    items.add(ReaderTocItem.fromMap({...data, 'level': level}));

    final subitems = readerBridgeList(data['subitems']);
    if (subitems == null) return;
    for (final subitem in subitems) {
      collect(subitem, level);
    }
  }

  for (final rawItem in rawItems) {
    collect(rawItem, 0);
  }
  return items;
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
      label: _string(map['label']) ?? '',
      href: _string(map['href']) ?? '',
      id: map['id']?.toString(),
      level: _int(map['level']) ?? 1,
      startPercentage: _double(map['startPercentage']),
      startPage: _int(map['startPage']),
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
      cfi: _string(map['cfi']) ?? '',
      excerpt: ReaderSearchExcerpt.fromMap(
        readerBridgeMap(map['excerpt']) ?? const {},
      ),
      chapterTitle: _string(map['chapterTitle']),
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
    final requestId = _int(map['requestId']) ?? -1;
    final type =
        _string(map['type']) ??
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
        message: _string(map['message']) ?? 'Book search failed',
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
  final value = _double(map['progress']) ?? _double(map['process']);
  return (value ?? 0).clamp(0.0, 1.0).toDouble();
}

List<ReaderSearchResult> _searchResultsFromMap(Map<String, dynamic> map) {
  final items = readerBridgeList(map['items']);
  if (items != null) {
    return [
      for (final item in items)
        if (readerBridgeMap(item) case final data?)
          ReaderSearchResult.fromMap(data),
    ];
  }

  final chapterTitle = _string(map['chapterTitle']) ?? _string(map['label']);
  final subitems = readerBridgeList(map['subitems']);
  if (subitems != null) {
    return [
      for (final item in subitems)
        if (readerBridgeMap(item) case final data?)
          ReaderSearchResult.fromMap({
            ...data,
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
      pre: _string(map['pre']) ?? '',
      match: _string(map['match']) ?? '',
      post: _string(map['post']) ?? '',
    );
  }
}

/// User text selection surfaced from the reader WebView. The CFI range is
/// the anchor used to restore highlights later. [scrollOffset] is a legacy
/// optional position field kept for compatibility with existing contracts.
class ReaderSelection {
  const ReaderSelection({
    required this.text,
    this.normalizedText,
    this.selectionKind,
    this.contextText,
    this.markedContextText,
    this.normalizedMarkedContextText,
    this.cfiRange,
    this.normalizedCfiRange,
    this.position,
    this.scrollOffset,
    this.containedHighlightIds = const [],
  });

  final String text;

  /// Selection expanded to complete word boundaries for lexical actions.
  final String? normalizedText;

  /// Reader-side selection shape, e.g. exact, partial_word, partial_span.
  final String? selectionKind;

  /// Surrounding sentence/paragraph excerpt for lexical text actions.
  final String? contextText;

  /// Same excerpt with the exact selected range wrapped in [[...]].
  final String? markedContextText;

  /// Same excerpt with the normalized lexical range wrapped in [[...]].
  final String? normalizedMarkedContextText;

  /// CFI range of the selection.
  final String? cfiRange;

  /// CFI range of the normalized lexical selection.
  final String? normalizedCfiRange;

  /// Normalized viewport rectangle of the selected text.
  final ReaderSelectionPosition? position;

  /// Legacy optional scroll position.
  final double? scrollOffset;

  /// Existing highlights strictly contained inside this selection.
  final List<String> containedHighlightIds;

  factory ReaderSelection.fromMap(Map<String, dynamic> map) {
    return ReaderSelection(
      text: _string(map['text']) ?? '',
      normalizedText: _string(map['normalizedText']),
      selectionKind: _string(map['selectionKind']),
      contextText: _string(map['contextText']),
      markedContextText: _string(map['markedContextText']),
      normalizedMarkedContextText: _string(map['normalizedMarkedContextText']),
      cfiRange: _string(map['cfi']),
      normalizedCfiRange: _string(map['normalizedCfi']),
      position: ReaderSelectionPosition.fromValue(map['pos']),
      scrollOffset: _double(map['scrollOffset']),
      containedHighlightIds: _stringList(map['containedHighlightIds']),
    );
  }
}

/// Selection bounds reported by the WebView as normalized viewport fractions.
///
/// Values are clamped to 0..1 so malformed JavaScript payloads cannot place
/// Flutter overlays outside the reader surface.
class ReaderSelectionPosition {
  const ReaderSelectionPosition({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  static ReaderSelectionPosition? fromValue(Object? value) {
    final map = readerBridgeMap(value);
    if (map == null) return null;
    final left = _double(map['left']);
    final top = _double(map['top']);
    final right = _double(map['right']);
    final bottom = _double(map['bottom']);
    if (left == null || top == null || right == null || bottom == null) {
      return null;
    }

    return ReaderSelectionPosition(
      left: _clampFraction(left),
      top: _clampFraction(top),
      right: _clampFraction(right),
      bottom: _clampFraction(bottom),
    );
  }

  static double _clampFraction(double value) =>
      value.clamp(0.0, 1.0).toDouble();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ReaderSelectionPosition &&
            other.left == left &&
            other.top == top &&
            other.right == right &&
            other.bottom == bottom;
  }

  @override
  int get hashCode => Object.hash(left, top, right, bottom);
}

/// Tap event emitted when the user taps an existing highlight annotation.
class ReaderHighlightTap {
  const ReaderHighlightTap({
    required this.highlightId,
    this.position,
    this.contextText,
  });

  final String highlightId;
  final ReaderSelectionPosition? position;
  final String? contextText;

  static ReaderHighlightTap? fromMap(Map<String, dynamic> map) {
    final annotation = readerBridgeMap(map['annotation']) ?? map;
    final id = _nonEmptyString(annotation['id']);
    if (id == null) return null;

    return ReaderHighlightTap(
      highlightId: id,
      position: ReaderSelectionPosition.fromValue(map['pos']),
      contextText: _string(map['contextText']),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ReaderHighlightTap &&
            other.highlightId == highlightId &&
            other.position == position &&
            other.contextText == contextText;
  }

  @override
  int get hashCode => Object.hash(highlightId, position, contextText);
}

class ReaderImageAreaRect {
  const ReaderImageAreaRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  static ReaderImageAreaRect? fromValue(Object? value) {
    final map = readerBridgeMap(value);
    if (map == null) return null;
    final x = _double(map['x']);
    final y = _double(map['y']);
    final width = _double(map['width']);
    final height = _double(map['height']);
    if (x == null || y == null || width == null || height == null) {
      return null;
    }

    final left = _clampFraction(x);
    final top = _clampFraction(y);
    final right = _clampFraction(x + width);
    final bottom = _clampFraction(y + height);
    final normalizedWidth = right - left;
    final normalizedHeight = bottom - top;
    if (normalizedWidth <= 0 || normalizedHeight <= 0) return null;

    return ReaderImageAreaRect(
      x: left,
      y: top,
      width: normalizedWidth,
      height: normalizedHeight,
    );
  }

  Map<String, dynamic> toMap() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };

  static double _clampFraction(double value) =>
      value.clamp(0.0, 1.0).toDouble();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ReaderImageAreaRect &&
            other.x == x &&
            other.y == y &&
            other.width == width &&
            other.height == height;
  }

  @override
  int get hashCode => Object.hash(x, y, width, height);
}

/// Image-page area selection surfaced from comic/fixed-layout pages.
class ReaderImageAreaSelection {
  const ReaderImageAreaSelection({
    required this.pageIndex,
    required this.rect,
    this.position,
  });

  final int pageIndex;
  final ReaderImageAreaRect rect;
  final ReaderSelectionPosition? position;

  static ReaderImageAreaSelection? fromMap(Map<String, dynamic> map) {
    final pageIndex = _int(map['pageIndex']);
    final rect = ReaderImageAreaRect.fromValue(map['rect']);
    if (pageIndex == null || pageIndex < 0 || rect == null) return null;
    return ReaderImageAreaSelection(
      pageIndex: pageIndex,
      rect: rect,
      position: ReaderSelectionPosition.fromValue(map['pos']),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ReaderImageAreaSelection &&
            other.pageIndex == pageIndex &&
            other.rect == rect &&
            other.position == position;
  }

  @override
  int get hashCode => Object.hash(pageIndex, rect, position);
}

/// Appearance bundle for the foliate-js book reader. Passed as the
/// `style` query param on the initial `index.html` load and via
/// `changeStyle()` thereafter. Field names mirror the JS object keys that
/// foliate-js's `book.js` reads — do not rename without updating the
/// bundled JS.
class FoliateStyle {
  const FoliateStyle({
    this.fontSize = 1.4,
    this.textScale = 1.0,
    this.deviceFontScale = 1.0,
    this.fontName = '',
    this.fontPath = '',
    this.fontWeight = 400,
    this.letterSpacing = 0,
    this.spacing = 1.8,
    this.paragraphSpacing = 1.0,
    this.textIndent = 0,
    this.fontColor = '#000000',
    this.backgroundColor = '#FFFFFF',
    this.accentColor = '#000000',
    this.topMargin = 90,
    this.bottomMargin = 50,
    this.safeAreaTop = 0,
    this.safeAreaBottom = 0,
    this.sideMargin = 8,
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
  final double textScale;
  final double deviceFontScale;
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

  /// App primary/accent color used for reader gesture feedback.
  final String accentColor;

  final double topMargin;
  final double bottomMargin;
  final double safeAreaTop;
  final double safeAreaBottom;

  /// Side margin in percent.
  final double sideMargin;

  final bool justify;
  final bool hyphenate;
  final String textAlign;

  /// `'slide'` for horizontal turns or `'vertical'` for vertical turns.
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
    'textScale': textScale,
    'deviceFontScale': deviceFontScale,
    'fontName': fontName,
    'fontPath': fontPath,
    'fontWeight': fontWeight,
    'letterSpacing': letterSpacing,
    'spacing': spacing,
    'paragraphSpacing': paragraphSpacing,
    'textIndent': textIndent,
    'fontColor': fontColor,
    'backgroundColor': backgroundColor,
    'accentColor': accentColor,
    'topMargin': topMargin,
    'bottomMargin': bottomMargin,
    'safeAreaTop': safeAreaTop,
    'safeAreaBottom': safeAreaBottom,
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
          textScale == other.textScale &&
          deviceFontScale == other.deviceFontScale &&
          fontName == other.fontName &&
          fontPath == other.fontPath &&
          fontWeight == other.fontWeight &&
          letterSpacing == other.letterSpacing &&
          spacing == other.spacing &&
          paragraphSpacing == other.paragraphSpacing &&
          textIndent == other.textIndent &&
          fontColor == other.fontColor &&
          backgroundColor == other.backgroundColor &&
          accentColor == other.accentColor &&
          topMargin == other.topMargin &&
          bottomMargin == other.bottomMargin &&
          safeAreaTop == other.safeAreaTop &&
          safeAreaBottom == other.safeAreaBottom &&
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
    textScale,
    deviceFontScale,
    fontName,
    fontPath,
    fontWeight,
    letterSpacing,
    spacing,
    paragraphSpacing,
    textIndent,
    fontColor,
    backgroundColor,
    accentColor,
    topMargin,
    bottomMargin,
    safeAreaTop,
    safeAreaBottom,
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
/// default yellow when set. [opacity], [mixBlendMode], and [verticalOffset]
/// tune contrast and placement without changing the saved domain model.
class ReaderHighlight {
  const ReaderHighlight({
    required this.id,
    required this.text,
    this.cfiRange,
    this.imagePageIndex,
    this.imageArea,
    this.color,
    this.opacity,
    this.mixBlendMode,
    this.verticalOffset,
  });

  final String id;
  final String text;

  /// For books: CFI range for exact positioning.
  final String? cfiRange;

  /// For image-page sources: zero-based page index.
  final int? imagePageIndex;

  /// For image-page sources: normalized rectangle inside [imagePageIndex].
  final ReaderImageAreaRect? imageArea;

  /// Hex color override (e.g. '#FFE600').
  final String? color;

  /// CSS opacity for the SVG highlight overlay.
  final double? opacity;

  /// CSS mix-blend-mode for the SVG highlight overlay.
  final String? mixBlendMode;

  /// Positive Y offset, in CSS pixels, for the SVG highlight overlay.
  final double? verticalOffset;

  bool get isImageArea => imagePageIndex != null && imageArea != null;

  Map<String, dynamic> toMap() => {
    'id': id,
    'text': text,
    if (cfiRange != null) 'cfiRange': cfiRange,
    if (imagePageIndex != null) 'imagePageIndex': imagePageIndex,
    if (imageArea != null) 'imageArea': imageArea!.toMap(),
    if (color != null) 'color': color,
    if (opacity != null) 'opacity': opacity,
    if (mixBlendMode != null) 'mixBlendMode': mixBlendMode,
    if (verticalOffset != null) 'verticalOffset': verticalOffset,
  };
}

/// A bookmark annotation the WebView should render and track against the
/// current page.
class ReaderBookmark {
  const ReaderBookmark({
    required this.id,
    required this.cfi,
    required this.progress,
    this.content = '',
    this.anchorExact,
    this.anchorPrefix,
    this.anchorSuffix,
    this.anchorSectionIndex,
    this.anchorSectionPage,
  });

  final String id;
  final String cfi;
  final double progress;
  final String content;
  final String? anchorExact;
  final String? anchorPrefix;
  final String? anchorSuffix;
  final int? anchorSectionIndex;
  final int? anchorSectionPage;
}
