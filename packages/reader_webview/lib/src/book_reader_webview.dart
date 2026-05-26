import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'reader_bridge.dart';
import 'reader_common_handlers.dart';

/// Exact CFI is the preferred restore path. When it is missing — or when the
/// WebView is retrying after the known iOS deep-CFI crash — fall back to the
/// persisted progress fraction so the reader reopens near the last spot
/// instead of at the cover.
@visibleForTesting
ReaderInitialLocation resolveInitialReaderLocation({
  required String? initialCfi,
  required double? initialProgress,
  required bool recoveringFromCrash,
}) {
  final cfi = switch (initialCfi) {
    final String value when value.isNotEmpty => value,
    _ => null,
  };
  final progress = switch (initialProgress) {
    final double value when value > 0 && value <= 1 => value,
    _ => null,
  };

  if (recoveringFromCrash) {
    return ReaderInitialLocation(cfi: null, progress: progress);
  }
  if (cfi != null) {
    return ReaderInitialLocation(cfi: cfi, progress: null);
  }
  return ReaderInitialLocation(cfi: null, progress: progress);
}

@visibleForTesting
final class ReaderInitialLocation {
  const ReaderInitialLocation({required this.cfi, required this.progress});

  final String? cfi;
  final double? progress;
}

@visibleForTesting
bool isGeneratedArticleReaderPath(String path) =>
    path.endsWith('/article.epub') && path.contains('/articles/');

@visibleForTesting
String buildReaderSearchStartScript({
  required int requestId,
  required String query,
}) {
  final escapedQuery = jsonEncode(query);
  return '''
(() => {
  const requestId = $requestId;
  const query = $escapedQuery;
  const defaultOptions = {
    scope: 'book',
    matchCase: false,
    matchDiacritics: false,
    matchWholeWords: false,
  };

  const sendSearchError = (message) => {
    try {
      const bridge = window.flutter_inappwebview;
      if (bridge && bridge.callHandler) {
        bridge.callHandler('onSearch', {
          requestId,
          type: 'error',
          message: String(message || 'Book search failed'),
        });
      }
    } catch (_) {}
  };

  try {
    if (typeof window.startSearch !== 'function') {
      sendSearchError('Book search bridge is missing');
      return;
    }
    Promise.resolve(window.startSearch(requestId, query, defaultOptions))
      .catch((error) => {
        sendSearchError(error && error.message ? error.message : error);
      });
  } catch (error) {
    sendSearchError(error && error.message ? error.message : error);
  }
})();
''';
}

@visibleForTesting
bool shouldLogReaderConsoleMessage({
  required bool debugMode,
  required String level,
}) {
  if (debugMode) return true;
  return level.toLowerCase().contains('error');
}

@visibleForTesting
String buildReaderCommandScript({
  required String label,
  required String expression,
}) {
  final escapedLabel = jsonEncode(label);
  return '''
(() => {
  const label = $escapedLabel;
  const reportError = (error) => {
    const message = error && error.stack ? error.stack : error;
    console.error('[readflex-eval:' + label + ']', message);
  };

  try {
    const result = $expression;
    if (result && typeof result.then === 'function') {
      result.catch(reportError);
    }
  } catch (error) {
    reportError(error);
  }
  return null;
})();
''';
}

@visibleForTesting
String buildArticleTextDirectionPatchScript({
  required String textAlign,
  required bool justify,
}) {
  final escapedTextAlign = jsonEncode(textAlign);
  final escapedJustify = justify ? 'true' : 'false';
  return '''
(() => {
  const requestedTextAlign = $escapedTextAlign;
  const requestedJustify = $escapedJustify;
  const rtlSampleRegex = /[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]/g;
  const ltrSampleRegex = /[A-Za-z\u00C0-\u024F\u1E00-\u1EFF]/g;

  const inferDirection = (doc) => {
    const sample = (doc.body?.textContent || '').replace(/\\s+/g, ' ').slice(0, 5000);
    if (!sample) return '';
    const rtlCount = (sample.match(rtlSampleRegex) || []).length;
    const ltrCount = (sample.match(ltrSampleRegex) || []).length;
    return rtlCount > ltrCount ? 'rtl' : '';
  };

  const resolveTextAlign = () => {
    const resolved = !requestedTextAlign || requestedTextAlign === 'auto'
      ? (requestedJustify ? 'justify' : 'start')
      : requestedTextAlign;
    if (resolved === 'start') return 'right';
    if (resolved === 'end') return 'left';
    return resolved;
  };

  const apply = () => {
    const view = document.querySelector('foliate-view');
    const renderer = view?.shadowRoot?.querySelector('foliate-paginator, foliate-fxl');
    const iframe = renderer?.shadowRoot?.querySelector('iframe');
    const doc = iframe?.contentDocument;
    if (!doc?.body) return false;

    const direction = doc.documentElement.dataset.readflexTextDirection
      || doc.documentElement.getAttribute('dir')
      || doc.body.getAttribute('dir')
      || inferDirection(doc);
    if (direction !== 'rtl') return false;

    doc.documentElement.dir = 'ltr';
    doc.documentElement.dataset.readflexTextDirection = 'rtl';
    doc.body.dir = 'ltr';

    let style = doc.getElementById('readflex-article-text-direction-runtime');
    if (!style) {
      style = doc.createElement('style');
      style.id = 'readflex-article-text-direction-runtime';
      doc.head?.append(style);
    }

    const align = resolveTextAlign();
    const selector = [
      'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
      'p', 'li', 'blockquote', 'dd', 'dt', 'figcaption', 'caption',
      'section', 'article', 'main', 'div:not(.readflex-wide-table)',
      'th', 'td',
    ].join(',');
    const nodes = Array.from(doc.body.querySelectorAll(selector));
    if (nodes.length === 0) nodes.push(doc.body);
    for (const node of nodes) {
      node.style.setProperty('direction', 'rtl', 'important');
      node.style.setProperty('unicode-bidi', 'plaintext');
      node.style.setProperty('text-align', align, 'important');
    }

    style.textContent = [
      'html[data-readflex-text-direction="rtl"] body h1,',
      'html[data-readflex-text-direction="rtl"] body h2,',
      'html[data-readflex-text-direction="rtl"] body h3,',
      'html[data-readflex-text-direction="rtl"] body h4,',
      'html[data-readflex-text-direction="rtl"] body h5,',
      'html[data-readflex-text-direction="rtl"] body h6,',
      'html[data-readflex-text-direction="rtl"] body p,',
      'html[data-readflex-text-direction="rtl"] body li,',
      'html[data-readflex-text-direction="rtl"] body blockquote,',
      'html[data-readflex-text-direction="rtl"] body dd,',
      'html[data-readflex-text-direction="rtl"] body dt,',
      'html[data-readflex-text-direction="rtl"] body figcaption,',
      'html[data-readflex-text-direction="rtl"] body caption,',
      'html[data-readflex-text-direction="rtl"] body section,',
      'html[data-readflex-text-direction="rtl"] body article,',
      'html[data-readflex-text-direction="rtl"] body main,',
      'html[data-readflex-text-direction="rtl"] body div:not(.readflex-wide-table),',
      'html[data-readflex-text-direction="rtl"] body th,',
      'html[data-readflex-text-direction="rtl"] body td {',
      '  direction: rtl !important;',
      '  unicode-bidi: plaintext;',
      '  text-align: ' + align + ' !important;',
      '}',
    ].join('\\n');
    if (!doc.documentElement.dataset.readflexRtlPatchLogged) {
      doc.documentElement.dataset.readflexRtlPatchLogged = 'true';
      console.log('[readflex-article-rtl] applied nodes=' + nodes.length + ' align=' + align);
    }
    return true;
  };

  apply();
  setTimeout(apply, 0);
  setTimeout(apply, 100);
  return null;
})()
''';
}

/// WebView-based book reader backed by foliate-js.
///
/// Loads foliate-js `index.html` from the local server's `/assets/foliate-js/`
/// route. foliate-js fetches the book file from `/book/<encoded-path>` and
/// renders it.
///
/// Communication:
///   JS → Flutter: `onReady`, `onRelocated`, `onSelectionEnd`,
///                  `onSelectionCleared`, `onAnnotationClick`, `onSetToc`,
///                  `onSearch`, `handleBookmark`
///   Flutter → JS: `goToCfi`, `goToHref`, `startSearch`, `cancelSearch`,
///                  `searchBook`, `clearSearch`, `nextPage`, `prevPage`,
///                  `changeStyle`, `addAnnotation`, `removeAnnotation`,
///                  `toggleBookmarkHere`
class BookReaderWebView extends StatefulWidget {
  const BookReaderWebView({
    required this.serverPort,
    required this.bookFilePath,
    this.initialCfi,
    this.initialProgress,
    this.isArticle = false,
    this.foliateStyle = const FoliateStyle(),
    this.highlights = const [],
    this.bookmarks = const [],
    this.onReady,
    this.onPositionChanged,
    this.onTextSelected,
    this.onTextDeselected,
    this.onHighlightTapped,
    this.onTocChanged,
    this.onBookmarkChanged,
    this.onTapped,
    super.key,
  });

  /// Port of the local reader server.
  final int serverPort;

  /// Absolute path to the book file on disk.
  final String bookFilePath;

  /// CFI position to restore on load.
  final String? initialCfi;

  /// Fractional fallback used when exact CFI restore is unavailable or when
  /// the iOS crash-recovery path intentionally drops the saved CFI.
  final double? initialProgress;

  /// Whether the opened EPUB was generated from a saved web article.
  ///
  /// Web articles use the document language for text direction, but keep
  /// foliate-js page progression stable instead of treating text direction as
  /// book page-progression direction.
  final bool isArticle;

  /// Book reader appearance passed to foliate-js via URL params.
  final FoliateStyle foliateStyle;

  /// Highlights to render as annotations on load.
  final List<ReaderHighlight> highlights;

  /// Bookmarks to render as foliate-js bookmark annotations on load.
  final List<ReaderBookmark> bookmarks;

  /// Fires once when foliate-js has loaded the book and is ready.
  final VoidCallback? onReady;

  /// Fires on page turn with the new position.
  final void Function(BookPosition position)? onPositionChanged;

  /// Fires when the user selects text.
  final void Function(ReaderSelection selection)? onTextSelected;

  /// Fires when the user clears the selection.
  final VoidCallback? onTextDeselected;

  /// Fires when the user taps an existing highlight annotation.
  final void Function(String highlightId)? onHighlightTapped;

  /// Fires when foliate-js has parsed the book's table of contents.
  final void Function(List<ReaderTocItem> items)? onTocChanged;

  /// Fires when foliate-js requests adding/removing a bookmark.
  final void Function(ReaderBookmarkChange change)? onBookmarkChanged;

  /// Fires when the user taps empty reader space (no selection, no link).
  /// Coordinates are normalized to [0, 1] over the viewport.
  final void Function(double x, double y)? onTapped;

  @override
  State<BookReaderWebView> createState() => BookReaderWebViewState();
}

class BookReaderWebViewState extends State<BookReaderWebView> {
  InAppWebViewController? _controller;
  bool _isReady = false;
  StreamController<ReaderSearchEvent>? _searchEvents;
  int _searchRequestSerial = 0;
  int? _activeSearchRequestId;
  Timer? _searchWatchdogTimer;
  static const _searchSilenceTimeout = Duration(seconds: 15);

  // TEMP WORKAROUND — remove once the WKWebView deep-CFI restore crash is
  // fixed properly (see memory: project_wkwebview_cfi_crash_root_cause.md).
  // When the WebKit WebContent process dies during initial pagination
  // (TextOnlySimpleLineBuilder RELEASE_ASSERT triggered by goTo on a
  // saved deep CFI), we self-recover by reloading the index with no CFI
  // so the book at least opens from chapter 1 instead of staying blank.
  // This flag overrides the URL-built initialCfi during the recovery
  // reload, then clears itself once the reload signals onLoadEnd.
  bool _recoveringFromCrash = false;

  bool get _effectiveArticle =>
      widget.isArticle || isGeneratedArticleReaderPath(widget.bookFilePath);

  @override
  void dispose() {
    _cancelSearchWatchdog();
    _closeSearchEvents();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BookReaderWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isReady) return;

    // Value-compare via FoliateStyle's `==` instead of double-encoding
    // both sides through jsonEncode on every parent rebuild.
    if (oldWidget.foliateStyle != widget.foliateStyle) {
      changeStyle(widget.foliateStyle);
      _applyArticleTextDirectionPatch();
    }

    _syncAnnotations(oldWidget.highlights, widget.highlights);
    _syncBookmarkAnnotations(oldWidget.bookmarks, widget.bookmarks);
  }

  /// Push a highlight diff into the WebView without rebuilding the
  /// widget tree. Caller computes the old/new lists; this method only
  /// fires `addAnnotation` / `removeAnnotation` evaluateJavascript
  /// calls for the differences. Used by reader callers that hold a
  /// [GlobalKey] on this state and react to bloc emits via
  /// `BlocListener` instead of `context.select` — that route avoids
  /// rebuilding the platform-view subtree mid-frame, which can race
  /// with `flushSemantics` and trip a `parentDataDirty` assertion.
  void syncAnnotations(
    List<ReaderHighlight> oldList,
    List<ReaderHighlight> newList,
  ) {
    if (!_isReady) return;
    _syncAnnotations(oldList, newList);
  }

  void _syncAnnotations(
    List<ReaderHighlight> oldList,
    List<ReaderHighlight> newList,
  ) {
    final oldById = {for (final h in oldList) h.id: h};
    final newById = {for (final h in newList) h.id: h};

    for (final h in oldList) {
      final next = newById[h.id];
      if (next == null && h.cfiRange != null) {
        _evalRemoveAnnotation(h.cfiRange!);
      }
    }
    for (final h in newList) {
      final prev = oldById[h.id];
      if (prev == null) {
        _evalAddAnnotation(h);
      } else if (prev.cfiRange != h.cfiRange || prev.color != h.color) {
        if (prev.cfiRange != null) _evalRemoveAnnotation(prev.cfiRange!);
        _evalAddAnnotation(h);
      }
    }
  }

  void _evaluateReaderCommand({
    required String label,
    required String expression,
  }) {
    final controller = _controller;
    if (controller == null) return;
    unawaited(
      controller
          .evaluateJavascript(
            source: buildReaderCommandScript(
              label: label,
              expression: expression,
            ),
          )
          .catchError((Object error) {
            debugPrint('[reader-eval] $label failed: $error');
          }),
    );
  }

  void _evalAddAnnotation(ReaderHighlight h) {
    if (h.cfiRange == null) return;
    final annotation = jsonEncode({
      'id': h.id,
      'type': 'highlight',
      'value': h.cfiRange,
      'color': h.color ?? '#FFE600',
    });
    _evaluateReaderCommand(
      label: 'addAnnotation',
      expression: 'addAnnotation($annotation)',
    );
  }

  void _evalRemoveAnnotation(String cfiRange) {
    final escaped = jsonEncode(cfiRange);
    _evaluateReaderCommand(
      label: 'removeAnnotation',
      expression: 'removeAnnotation($escaped)',
    );
  }

  void _syncBookmarkAnnotations(
    List<ReaderBookmark> oldList,
    List<ReaderBookmark> newList,
  ) {
    final oldById = {for (final h in oldList) h.id: h};
    final newById = {for (final h in newList) h.id: h};
    var changed = false;

    for (final bookmark in oldList) {
      final next = newById[bookmark.id];
      if (next == null) {
        _evalRemoveBookmarkAnnotation(bookmark.cfi, id: bookmark.id);
        changed = true;
      }
    }
    for (final bookmark in newList) {
      final prev = oldById[bookmark.id];
      if (prev == null) {
        _evalAddBookmarkAnnotation(bookmark);
        changed = true;
      } else if (prev.cfi != bookmark.cfi ||
          prev.anchorExact != bookmark.anchorExact ||
          prev.anchorPrefix != bookmark.anchorPrefix ||
          prev.anchorSuffix != bookmark.anchorSuffix ||
          prev.anchorSectionIndex != bookmark.anchorSectionIndex ||
          prev.anchorSectionPage != bookmark.anchorSectionPage) {
        _evalRemoveBookmarkAnnotation(prev.cfi, id: prev.id);
        _evalAddBookmarkAnnotation(bookmark);
        changed = true;
      }
    }
    if (changed) _refreshBookmarkState();
  }

  void _evalAddBookmarkAnnotation(ReaderBookmark bookmark) {
    if (bookmark.cfi.isEmpty) return;
    final annotation = jsonEncode({
      'id': bookmark.id,
      'type': 'bookmark',
      'value': bookmark.cfi,
      'content': bookmark.content,
      'progress': bookmark.progress,
      'anchorExact': bookmark.anchorExact,
      'anchorPrefix': bookmark.anchorPrefix,
      'anchorSuffix': bookmark.anchorSuffix,
      'anchorSectionIndex': bookmark.anchorSectionIndex,
      'anchorSectionPage': bookmark.anchorSectionPage,
    });
    _evaluateReaderCommand(
      label: 'addAnnotation',
      expression: 'addAnnotation($annotation)',
    );
  }

  void _evalRemoveBookmarkAnnotation(String cfiRange, {String? id}) {
    final escaped = jsonEncode(cfiRange);
    final escapedId = jsonEncode(id);
    _evaluateReaderCommand(
      label: 'removeBookmarkAnnotation',
      expression: 'removeAnnotation($escaped, false, $escapedId)',
    );
  }

  String get _bookUrl {
    final encoded = Uri.encodeComponent(widget.bookFilePath);
    return 'http://127.0.0.1:${widget.serverPort}/book/$encoded';
  }

  /// Default reading rules for foliate-js. No Chinese conversion, no
  /// bionic reading — matches the anx-reader defaults.
  static const _defaultReadingRules = {
    'convertChineseMode': 'none',
    'bionicReadingMode': false,
  };

  String get _indexUrl {
    final base =
        'http://127.0.0.1:${widget.serverPort}/assets/foliate-js/index.html';
    final initialLocation = resolveInitialReaderLocation(
      initialCfi: widget.initialCfi,
      initialProgress: widget.initialProgress,
      recoveringFromCrash: _recoveringFromCrash,
    );
    final params = {
      'url': jsonEncode(_bookUrl),
      'initialCfi': jsonEncode(initialLocation.cfi),
      'initialProgress': jsonEncode(initialLocation.progress),
      'sourceType': jsonEncode(_effectiveArticle ? 'article' : 'book'),
      'style': jsonEncode(widget.foliateStyle.toMap()),
      'readingRules': jsonEncode(_defaultReadingRules),
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return '$base?$query';
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(_indexUrl)),
      initialSettings: baseReaderSettings(),
      onWebViewCreated: _onWebViewCreated,
      onConsoleMessage: _onConsoleMessage,
      // TEMP — see _recoveringFromCrash field doc for context.
      onWebContentProcessDidTerminate: _onContentProcessTerminated,
    );
  }

  void _onConsoleMessage(
    InAppWebViewController controller,
    ConsoleMessage message,
  ) {
    final level = message.messageLevel.toString();
    if (!shouldLogReaderConsoleMessage(debugMode: kDebugMode, level: level)) {
      return;
    }
    debugPrint('[reader-console] $level: ${message.message}');
  }

  /// TEMP WORKAROUND for the WKWebView deep-CFI restore crash.
  /// Remove this handler (and the [_recoveringFromCrash] state field plus
  /// its branch in [_indexUrl]) once foliate-js / our integration handles
  /// deep-CFI restoration without crashing the WebContent process.
  void _onContentProcessTerminated(InAppWebViewController controller) {
    // Avoid re-entering recovery if a second crash arrives before the
    // first reload finishes. If we hit this twice, something else is
    // wrong and reloading again will only spin.
    if (_recoveringFromCrash) {
      debugPrint(
        '[reader-recovery] second WebContent crash before first reload '
        'finished — skipping to avoid loop',
      );
      return;
    }
    debugPrint(
      '[reader-recovery] WebContent process died (cfi=${widget.initialCfi}), '
      'reloading with cfi=null',
    );
    setState(() {
      _recoveringFromCrash = true;
      _isReady = false;
    });
    controller.loadUrl(urlRequest: URLRequest(url: WebUri(_indexUrl)));
  }

  void _onWebViewCreated(InAppWebViewController controller) {
    _controller = controller;
    _registerHandlers(controller);
  }

  void _registerHandlers(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: 'onLoadEnd',
      callback: (_) => _markReady('onLoadEnd'),
    );

    // Capture uncaught JS errors and unhandled promise rejections from
    // the reader iframe. The matching JS-side hook lives at the top of
    // index.html's bootstrap IIFE.
    controller.addJavaScriptHandler(
      handlerName: 'onJsError',
      callback: (args) {
        if (args.isEmpty) return;
        final raw = args.first;
        if (raw is! Map) {
          debugPrint('[reader-js-error] $raw');
          return;
        }
        final kind = raw['kind'] ?? 'error';
        final msg = raw['msg'] ?? '<no message>';
        final src = raw['src'];
        final line = raw['line'];
        final col = raw['col'];
        final stack = raw['stack'];
        final location = (src != null && line != null)
            ? ' at $src:$line${col != null ? ':$col' : ''}'
            : '';
        debugPrint('[reader-js-$kind] $msg$location');
        if (stack != null) debugPrint('[reader-js-stack]\n$stack');
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onRelocated',
      callback: (args) {
        if (args.isEmpty) return;
        final data = readerBridgeMap(args.first);
        if (data == null) return;
        final position = BookPosition.fromMap(data);
        widget.onPositionChanged?.call(position);
        _markReady('onRelocated');
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onAnnotationClick',
      callback: (args) {
        if (args.isEmpty) return;
        final data = readerBridgeMap(args.first);
        if (data == null) return;
        final annotation = readerBridgeMap(data['annotation']);
        final id = annotation?['id'] as String?;
        if (id != null) widget.onHighlightTapped?.call(id);
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onSetToc',
      callback: (args) {
        if (args.isEmpty) return;
        final rawItems = readerBridgeList(args.first) ?? const [];
        final items = [
          for (final raw in rawItems)
            if (readerBridgeMap(raw) case final data?)
              ReaderTocItem.fromMap(data),
        ];
        widget.onTocChanged?.call(items);
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onSearch',
      callback: (args) {
        if (args.isEmpty) return;
        final raw = readerBridgeMap(args.first);
        if (raw == null) return;
        final event = ReaderSearchEvent.fromMap(raw);
        _handleSearchEvent(event);
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'handleBookmark',
      callback: (args) {
        if (args.isEmpty) return;
        final raw = readerBridgeMap(args.first);
        if (raw == null) return;
        final change = ReaderBookmarkChange.fromMap(raw);
        widget.onBookmarkChanged?.call(change);
      },
    );

    registerSharedReaderHandlers(
      controller,
      onTextSelected: widget.onTextSelected,
      onTextDeselected: widget.onTextDeselected,
      onTapped: widget.onTapped,
    );
  }

  void _markReady(String source) {
    final wasReady = _isReady;
    _isReady = true;

    // TEMP — clear the crash-recovery flag once the post-crash reload produces
    // either the normal load callback or a first relocation event. Some heavy
    // formats can relocate before `onLoadEnd`; at that point the page is usable
    // and keeping the loading scrim would be worse than showing the content.
    if (_recoveringFromCrash) {
      final progress = widget.initialProgress;
      final recoveredAt = progress != null && progress > 0
          ? ' at progress=${progress.toStringAsFixed(4)}'
          : ' at chapter 1';
      debugPrint(
        '[reader-recovery] post-crash reload completed via $source; book is open'
        '$recoveredAt (saved deep CFI was discarded)',
      );
      _recoveringFromCrash = false;
    }

    if (wasReady) {
      _applyArticleTextDirectionPatch();
      return;
    }
    _renderAnnotations();
    _applyArticleTextDirectionPatch();
    widget.onReady?.call();
  }

  void _applyArticleTextDirectionPatch() {
    if (!_effectiveArticle) return;
    _evaluateReaderCommand(
      label: 'articleTextDirection',
      expression: buildArticleTextDirectionPatchScript(
        textAlign: widget.foliateStyle.textAlign,
        justify: widget.foliateStyle.justify,
      ),
    );
  }

  void _renderAnnotations() {
    for (final h in widget.highlights) {
      _evalAddAnnotation(h);
    }
    for (final bookmark in widget.bookmarks) {
      _evalAddBookmarkAnnotation(bookmark);
    }
    _refreshBookmarkState();
  }

  void _refreshBookmarkState() {
    _evaluateReaderCommand(
      label: 'refreshBookmarkState',
      expression:
          "typeof window.refreshBookmarkState === 'function' ? window.refreshBookmarkState() : null",
    );
  }

  /// Navigate to a specific CFI position.
  void goToCfi(String cfi) {
    final escaped = jsonEncode(cfi);
    _evaluateReaderCommand(
      label: 'goToCfi',
      expression: 'goToCfi($escaped)',
    );
  }

  /// Navigate to a stored bookmark, preferring its visual page anchor when
  /// available because some formats expose a coarse CFI for the whole section.
  void goToBookmark({
    required String cfi,
    required double progress,
    int? anchorSectionIndex,
    int? anchorSectionPage,
  }) {
    if (cfi.isEmpty && progress <= 0) return;
    final payload = jsonEncode({
      'cfi': cfi,
      'progress': progress,
      'anchorSectionIndex': anchorSectionIndex,
      'anchorSectionPage': anchorSectionPage,
    });
    _evaluateReaderCommand(
      label: 'goToBookmark',
      expression: 'goToBookmark($payload)',
    );
  }

  /// Navigate to a TOC/book href target.
  void goToHref(String href) {
    final escaped = jsonEncode(href);
    _evaluateReaderCommand(
      label: 'goToHref',
      expression: 'goToHref($escaped)',
    );
  }

  /// Search the whole book and keep foliate-js search highlights active.
  Future<List<ReaderSearchResult>> searchBook(String query) async {
    final results = <ReaderSearchResult>[];
    await for (final event in searchBookStream(query)) {
      switch (event) {
        case ReaderSearchResults(results: final batch):
          results.addAll(batch);
        case ReaderSearchError(:final message):
          throw StateError(message);
        case ReaderSearchProgress() || ReaderSearchDone():
          break;
      }
    }
    return results;
  }

  /// Start a streamed book search.
  ///
  /// A new search cancels the previous one. Results are emitted in batches
  /// as foliate-js finishes scanning sections; progress is reported in
  /// `[0, 1]`. Cancel the returned subscription to stop work early.
  Stream<ReaderSearchEvent> searchBookStream(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      clearSearch();
      final requestId = ++_searchRequestSerial;
      return Stream.value(ReaderSearchDone(requestId: requestId));
    }

    _cancelActiveSearch();

    final requestId = ++_searchRequestSerial;
    final events = StreamController<ReaderSearchEvent>();
    _searchEvents = events;
    _activeSearchRequestId = requestId;
    _startSearchWatchdog(requestId);
    events.onCancel = () {
      if (_activeSearchRequestId == requestId) _cancelActiveSearch();
    };

    final controller = _controller;
    if (controller == null || !_isReady) {
      scheduleMicrotask(() {
        _handleSearchEvent(
          ReaderSearchError(
            requestId: requestId,
            message: 'Book search failed: reader is not ready',
          ),
        );
      });
      return events.stream;
    }

    unawaited(
      controller
          .evaluateJavascript(
            source: buildReaderSearchStartScript(
              requestId: requestId,
              query: trimmed,
            ),
          )
          .catchError((Object error) {
            _handleSearchEvent(
              ReaderSearchError(
                requestId: requestId,
                message: 'Book search failed: $error',
              ),
            );
          }),
    );
    return events.stream;
  }

  /// Clear active search annotations inside foliate-js.
  void clearSearch() {
    _cancelActiveSearch();
    _evaluateReaderCommand(
      label: 'clearSearch',
      expression:
          "typeof window.clearSearch === 'function' ? window.clearSearch() : null",
    );
  }

  void _handleSearchEvent(ReaderSearchEvent event) {
    if (_activeSearchRequestId != event.requestId) return;
    final events = _searchEvents;
    if (events == null || events.isClosed) return;
    final isTerminal = event is ReaderSearchDone || event is ReaderSearchError;
    if (isTerminal) {
      _cancelSearchWatchdog();
    } else {
      _startSearchWatchdog(event.requestId);
    }
    events.add(event);
    if (isTerminal) {
      _activeSearchRequestId = null;
      _searchEvents = null;
      unawaited(events.close());
    }
  }

  void _cancelActiveSearch() {
    final requestId = _activeSearchRequestId;
    _activeSearchRequestId = null;
    _cancelSearchWatchdog();
    _closeSearchEvents();
    if (requestId != null) {
      _evaluateReaderCommand(
        label: 'cancelSearch',
        expression:
            "typeof window.cancelSearch === 'function' ? window.cancelSearch($requestId) : null",
      );
    }
  }

  void _closeSearchEvents() {
    _cancelSearchWatchdog();
    final events = _searchEvents;
    _searchEvents = null;
    if (events != null && !events.isClosed) unawaited(events.close());
  }

  void _startSearchWatchdog(int requestId) {
    _searchWatchdogTimer?.cancel();
    _searchWatchdogTimer = Timer(_searchSilenceTimeout, () {
      if (_activeSearchRequestId != requestId) return;
      _evaluateReaderCommand(
        label: 'cancelSearchWatchdog',
        expression:
            "typeof window.cancelSearch === 'function' ? window.cancelSearch($requestId) : null",
      );
      _handleSearchEvent(
        ReaderSearchError(
          requestId: requestId,
          message: 'Book search timed out',
        ),
      );
    });
  }

  void _cancelSearchWatchdog() {
    _searchWatchdogTimer?.cancel();
    _searchWatchdogTimer = null;
  }

  /// Navigate to a fraction `[0, 1]` of the whole book. Used by the
  /// bottom-chrome slider's drag-to-seek; foliate-js's
  /// `window.goToPercent` does the actual chapter+offset resolution.
  void goToFraction(double fraction) {
    final clamped = fraction.clamp(0.0, 1.0);
    _evaluateReaderCommand(
      label: 'goToPercent',
      expression: 'goToPercent($clamped)',
    );
  }

  /// Go to the next page.
  void nextPage() {
    _evaluateReaderCommand(
      label: 'nextPage',
      expression: 'nextPage()',
    );
  }

  /// Go to the previous page.
  void prevPage() {
    _evaluateReaderCommand(
      label: 'prevPage',
      expression: 'prevPage()',
    );
  }

  /// Toggle a bookmark at the current visible page.
  void toggleBookmark() {
    _evaluateReaderCommand(
      label: 'toggleBookmarkHere',
      expression:
          "typeof window.toggleBookmarkHere === 'function' ? window.toggleBookmarkHere() : null",
    );
  }

  /// Update style from Flutter.
  void changeStyle(FoliateStyle style) {
    final json = jsonEncode(style.toMap());
    _evaluateReaderCommand(
      label: 'changeStyle',
      expression: 'changeStyle($json)',
    );
  }

  /// Add a highlight annotation.
  void addAnnotation(ReaderHighlight highlight) {
    if (highlight.cfiRange == null) return;
    final annotation = jsonEncode({
      'id': highlight.id,
      'type': 'highlight',
      'value': highlight.cfiRange,
      'color': highlight.color ?? '#FFE600',
    });
    _evaluateReaderCommand(
      label: 'addAnnotation',
      expression: 'addAnnotation($annotation)',
    );
  }

  /// Remove a highlight annotation by CFI.
  void removeAnnotation(String cfiRange) {
    final escaped = jsonEncode(cfiRange);
    _evaluateReaderCommand(
      label: 'removeAnnotation',
      expression: 'removeAnnotation($escaped)',
    );
  }
}
