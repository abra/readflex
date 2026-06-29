import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as p;

import 'reader_bridge.dart';
import 'reader_common_handlers.dart';

/// Vertical WebView reader for saved article HTML fragments.
///
/// Unlike [BookReaderWebView], this surface does not paginate. It loads the
/// cleaned article `content.html` fragment through the local reader server,
/// applies the shared reader appearance CSS, and reports scroll progress plus
/// a sentence anchor through the same [BookPosition] model used by the reader
/// bloc.
class ArticleHtmlReaderWebView extends StatefulWidget {
  const ArticleHtmlReaderWebView({
    required this.serverPort,
    required this.articleFilePath,
    this.initialPosition,
    this.initialProgress,
    this.foliateStyle = const FoliateStyle(),
    this.bookmarks = const [],
    this.onReady,
    this.onPositionChanged,
    this.onTocChanged,
    this.onDocumentFeaturesChanged,
    this.onBookmarkChanged,
    this.onTapped,
    super.key,
  });

  final int serverPort;

  /// Absolute path to either `article.epub` or `content.html` in the article
  /// directory. The HTML reader derives `content.html` from the directory.
  final String articleFilePath;
  final String? initialPosition;
  final double? initialProgress;
  final FoliateStyle foliateStyle;
  final List<ReaderBookmark> bookmarks;
  final VoidCallback? onReady;
  final void Function(BookPosition position)? onPositionChanged;
  final void Function(List<ReaderTocItem> items)? onTocChanged;
  final void Function(ReaderDocumentFeatures features)?
  onDocumentFeaturesChanged;
  final void Function(ReaderBookmarkChange change)? onBookmarkChanged;
  final void Function(double x, double y)? onTapped;

  @override
  State<ArticleHtmlReaderWebView> createState() =>
      ArticleHtmlReaderWebViewState();
}

class ArticleHtmlReaderWebViewState extends State<ArticleHtmlReaderWebView> {
  InAppWebViewController? _controller;
  bool _isReady = false;
  StreamController<ReaderSearchEvent>? _searchEvents;
  int _searchRequestSerial = 0;
  int? _activeSearchRequestId;
  Timer? _searchWatchdogTimer;
  static const _searchSilenceTimeout = Duration(seconds: 15);

  String get _articleDirectoryPath => p.dirname(widget.articleFilePath);

  String get _articleDirectoryUrl {
    final encodedDir = Uri.encodeComponent(_articleDirectoryPath);
    return 'http://127.0.0.1:${widget.serverPort}/article/$encodedDir/';
  }

  String get _contentUrl => '${_articleDirectoryUrl}content.html';

  String get _indexUrl {
    final base =
        'http://127.0.0.1:${widget.serverPort}/assets/article-html/index.html';
    final params = {
      'contentUrl': jsonEncode(_contentUrl),
      'contentBaseUrl': jsonEncode(_articleDirectoryUrl),
      'initialPosition': jsonEncode(widget.initialPosition),
      'initialProgress': jsonEncode(widget.initialProgress),
      'style': jsonEncode(widget.foliateStyle.toMap()),
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return '$base?$query';
  }

  @override
  void dispose() {
    _cancelSearchWatchdog();
    _closeSearchEvents();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ArticleHtmlReaderWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.articleFilePath != widget.articleFilePath) {
      _isReady = false;
      _cancelActiveSearch();
    }
    if (!_isReady) return;
    if (oldWidget.foliateStyle != widget.foliateStyle) {
      changeStyle(widget.foliateStyle);
    }
    if (oldWidget.bookmarks != widget.bookmarks) {
      _syncBookmarks();
    }
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(_indexUrl)),
      initialSettings: baseReaderSettings(),
      contextMenu: readerContextMenu(),
      onWebViewCreated: _onWebViewCreated,
      onConsoleMessage: _onConsoleMessage,
    );
  }

  void _onWebViewCreated(InAppWebViewController controller) {
    _controller = controller;
    _registerHandlers(controller);
  }

  void _registerHandlers(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: 'onLoadEnd',
      callback: (_) => _markReady(),
    );
    controller.addJavaScriptHandler(
      handlerName: 'onArticlePositionChanged',
      callback: (args) {
        if (args.isEmpty) return;
        final data = readerBridgeMap(args.first);
        if (data == null) return;
        widget.onPositionChanged?.call(BookPosition.fromMap(data));
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'onSetToc',
      callback: (args) {
        if (args.isEmpty) return;
        widget.onTocChanged?.call(readerTocItemsFromBridge(args.first));
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'onDocumentFeatures',
      callback: (args) {
        if (args.isEmpty) return;
        final data = readerBridgeMap(args.first);
        if (data == null) return;
        widget.onDocumentFeaturesChanged?.call(
          ReaderDocumentFeatures.fromMap(data),
        );
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'onSearch',
      callback: (args) {
        if (args.isEmpty) return;
        final raw = readerBridgeMap(args.first);
        if (raw == null) return;
        _handleSearchEvent(ReaderSearchEvent.fromMap(raw));
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'handleBookmark',
      callback: (args) {
        if (args.isEmpty) return;
        final raw = readerBridgeMap(args.first);
        if (raw == null) return;
        widget.onBookmarkChanged?.call(ReaderBookmarkChange.fromMap(raw));
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'onJsError',
      callback: (args) {
        if (args.isEmpty) return;
        final data = readerBridgeMap(args.first);
        if (data == null) {
          debugPrint('[article-reader-js-error] ${args.first}');
          return;
        }
        debugPrint(
          '[article-reader-js-${data['kind'] ?? 'error'}] ${data['msg']}',
        );
        if (data['stack'] != null) {
          debugPrint('[article-reader-js-stack]\n${data['stack']}');
        }
      },
    );
    registerSharedReaderHandlers(
      controller,
      onTapped: (x, y) => widget.onTapped?.call(x, y),
    );
  }

  void _markReady() {
    if (_isReady) return;
    _isReady = true;
    _syncBookmarks();
    widget.onReady?.call();
  }

  void _onConsoleMessage(
    InAppWebViewController controller,
    ConsoleMessage message,
  ) {
    final level = message.messageLevel.toString();
    if (!shouldLogReaderWebViewConsoleMessage(
      debugMode: kDebugMode,
      level: level,
    )) {
      return;
    }
    debugPrint('[article-reader-console] $level: ${message.message}');
  }

  void _evaluateArticleCommand({
    required String label,
    required String expression,
  }) {
    final controller = _controller;
    if (controller == null) return;
    unawaited(
      controller
          .evaluateJavascript(
            source:
                '''
(() => {
  try {
    return $expression;
  } catch (error) {
    console.error('Readflex article command failed: $label', error);
    return null;
  }
})()
''',
          )
          .catchError((Object error) {
            debugPrint('[article-reader-eval] $label failed: $error');
          }),
    );
  }

  void goToFraction(double fraction) {
    final clamped = fraction.clamp(0.0, 1.0);
    _evaluateArticleCommand(
      label: 'goToPercent',
      expression: 'window.goToPercent($clamped)',
    );
  }

  void goToHref(String href) {
    final escaped = jsonEncode(href);
    _evaluateArticleCommand(
      label: 'goToHref',
      expression: 'window.goToHref($escaped)',
    );
  }

  void goToCfi(String cfi) {
    final escaped = jsonEncode(cfi);
    _evaluateArticleCommand(
      label: 'goToCfi',
      expression: 'window.goToCfi($escaped)',
    );
  }

  void goToSearchResult(String cfi) {
    goToCfi(cfi);
  }

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
    });
    _evaluateArticleCommand(
      label: 'goToBookmark',
      expression: 'window.goToBookmark($payload)',
    );
  }

  void changeStyle(FoliateStyle style) {
    final payload = jsonEncode(style.toMap());
    _evaluateArticleCommand(
      label: 'changeStyle',
      expression: 'window.changeStyle($payload)',
    );
  }

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
            message: 'Article search failed: reader is not ready',
          ),
        );
      });
      return events.stream;
    }

    final escapedQuery = jsonEncode(trimmed);
    unawaited(
      controller
          .evaluateJavascript(
            source:
                '''
(() => {
  if (typeof window.startSearch !== 'function') {
    window.flutter_inappwebview?.callHandler('onSearch', {
      requestId: $requestId,
      type: 'error',
      message: 'Article search bridge is missing',
    });
    return null;
  }
  return window.startSearch($requestId, $escapedQuery);
})()
''',
          )
          .catchError((Object error) {
            _handleSearchEvent(
              ReaderSearchError(
                requestId: requestId,
                message: 'Article search failed: $error',
              ),
            );
          }),
    );
    return events.stream;
  }

  void clearSearch() {
    _cancelActiveSearch();
    _evaluateArticleCommand(
      label: 'clearSearch',
      expression:
          "typeof window.clearSearch === 'function' ? window.clearSearch() : null",
    );
  }

  void toggleBookmark() {
    _evaluateArticleCommand(
      label: 'toggleBookmarkHere',
      expression:
          "typeof window.toggleBookmarkHere === 'function' ? window.toggleBookmarkHere() : null",
    );
  }

  void _syncBookmarks() {
    if (!_isReady) return;
    final payload = jsonEncode([
      for (final bookmark in widget.bookmarks)
        {
          'id': bookmark.id,
          'cfi': bookmark.cfi,
          'content': bookmark.content,
          'progress': bookmark.progress,
          'anchorExact': bookmark.anchorExact,
          'anchorPrefix': bookmark.anchorPrefix,
          'anchorSuffix': bookmark.anchorSuffix,
        },
    ]);
    _evaluateArticleCommand(
      label: 'setArticleBookmarks',
      expression:
          "typeof window.setArticleBookmarks === 'function' ? window.setArticleBookmarks($payload) : null",
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
      _evaluateArticleCommand(
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
      _evaluateArticleCommand(
        label: 'cancelSearchWatchdog',
        expression:
            "typeof window.cancelSearch === 'function' ? window.cancelSearch($requestId) : null",
      );
      _handleSearchEvent(
        ReaderSearchError(
          requestId: requestId,
          message: 'Article search timed out',
        ),
      );
    });
  }

  void _cancelSearchWatchdog() {
    _searchWatchdogTimer?.cancel();
    _searchWatchdogTimer = null;
  }
}
