part of 'book_reader_webview.dart';

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
  int _webContentRecoveryAttempts = 0;

  static const _maxWebContentRecoveryAttempts = 1;

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
    if (oldWidget.bookFilePath != widget.bookFilePath ||
        oldWidget.initialCfi != widget.initialCfi) {
      _recoveringFromCrash = false;
      _webContentRecoveryAttempts = 0;
    }
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
      if (next == null) {
        _evalRemoveReaderHighlight(h);
      }
    }
    for (final h in newList) {
      final prev = oldById[h.id];
      if (prev == null) {
        _evalAddAnnotation(h);
      } else if (prev.cfiRange != h.cfiRange ||
          prev.imagePageIndex != h.imagePageIndex ||
          prev.imageArea != h.imageArea ||
          prev.color != h.color ||
          prev.opacity != h.opacity ||
          prev.mixBlendMode != h.mixBlendMode ||
          prev.verticalOffset != h.verticalOffset) {
        _evalRemoveReaderHighlight(prev);
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
    final annotation = h.isImageArea
        ? jsonEncode({
            'id': h.id,
            'type': 'image-area-highlight',
            'value': 'image-area:${h.id}',
            'pageIndex': h.imagePageIndex,
            'rect': h.imageArea!.toMap(),
            'color': h.color ?? '#FFE600',
            if (h.opacity != null) 'opacity': h.opacity,
          })
        : jsonEncode({
            'id': h.id,
            'type': 'highlight',
            'value': h.cfiRange,
            'color': h.color ?? '#FFE600',
            if (h.opacity != null) 'opacity': h.opacity,
            if (h.mixBlendMode != null) 'mixBlendMode': h.mixBlendMode,
            if (h.verticalOffset != null) 'verticalOffset': h.verticalOffset,
          });
    if (!h.isImageArea && h.cfiRange == null) return;
    _evaluateReaderCommand(
      label: 'addAnnotation',
      expression: 'addAnnotation($annotation)',
    );
  }

  void _evalRemoveReaderHighlight(ReaderHighlight highlight) {
    if (highlight.cfiRange != null) {
      _evalRemoveAnnotation(highlight.cfiRange!);
      return;
    }
    if (highlight.isImageArea) {
      _evalRemoveAnnotationById(highlight.id);
    }
  }

  void _evalRemoveAnnotation(String cfiRange) {
    final escaped = jsonEncode(cfiRange);
    _evaluateReaderCommand(
      label: 'removeAnnotation',
      expression: 'removeAnnotation($escaped)',
    );
  }

  void _evalRemoveAnnotationById(String id) {
    final escapedId = jsonEncode(id);
    _evaluateReaderCommand(
      label: 'removeAnnotationById',
      expression: 'removeAnnotation(null, false, $escapedId)',
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
      isArticle: _effectiveArticle,
    );
    final params = {
      'url': jsonEncode(_bookUrl),
      'initialCfi': jsonEncode(initialLocation.cfi),
      'initialProgress': jsonEncode(initialLocation.progress),
      'sourceType': jsonEncode(_effectiveArticle ? 'article' : 'book'),
      'pageProgressionDirection': jsonEncode(
        widget.pageProgressionRtl ? 'rtl' : null,
      ),
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
      contextMenu: readerContextMenu(),
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

  /// TEMP WORKAROUND for WKWebView content-process crashes while opening.
  /// Remove this handler (and the [_recoveringFromCrash] state field plus
  /// its branch in [_indexUrl]) once foliate-js / our integration handles
  /// CFI/progress restoration and article pagination without crashing the
  /// WebContent process.
  void _onContentProcessTerminated(InAppWebViewController controller) {
    final initialCfi = widget.initialCfi?.trim();

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

    if (_webContentRecoveryAttempts >= _maxWebContentRecoveryAttempts) {
      debugPrint(
        '[reader-recovery] WebContent process died after recovery attempt; '
        'skipping reload to avoid a recovery loop',
      );
      return;
    }

    if (!shouldAttemptWebContentRecovery(
      initialCfi: initialCfi,
      isArticle: _effectiveArticle,
      recoveryAttempts: _webContentRecoveryAttempts,
      maxRecoveryAttempts: _maxWebContentRecoveryAttempts,
      recoveryInProgress: _recoveringFromCrash,
    )) {
      debugPrint(
        '[reader-recovery] WebContent process died without an initial CFI '
        'or article fallback; skipping reload to avoid a recovery loop',
      );
      return;
    }

    final recoveryTarget = initialCfi == null || initialCfi.isEmpty
        ? 'article without initial CFI'
        : 'cfi=${widget.initialCfi}';
    debugPrint(
      '[reader-recovery] WebContent process died ($recoveryTarget), '
      'reloading with cfi=null',
    );
    _webContentRecoveryAttempts += 1;
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
        final tap = ReaderHighlightTap.fromMap(data);
        if (tap != null) widget.onHighlightTapped?.call(tap);
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onImageAreaSelected',
      callback: (args) {
        if (args.isEmpty) return;
        final data = readerBridgeMap(args.first);
        if (data == null) return;
        final selection = ReaderImageAreaSelection.fromMap(data);
        if (selection != null) widget.onImageAreaSelected?.call(selection);
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
      onTextSelected: (selection) => widget.onTextSelected?.call(selection),
      onTextDeselected: () => widget.onTextDeselected?.call(),
      onTapped: (x, y) => widget.onTapped?.call(x, y),
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

  /// Navigate to a search result and force its foliate annotation to render
  /// after the target section is active.
  void goToSearchResult(String cfi) {
    final escaped = jsonEncode(cfi);
    _evaluateReaderCommand(
      label: 'goToSearchResult',
      expression:
          "typeof goToSearchResult === 'function' ? goToSearchResult($escaped) : goToCfi($escaped)",
    );
  }

  /// Navigate to a zero-based book section index. Used by image-page
  /// highlights where there is no text CFI.
  void goToSectionIndex(int index) {
    if (index < 0) return;
    _evaluateReaderCommand(
      label: 'goToSectionIndex',
      expression: 'goToSectionIndex($index)',
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

  /// Turn toward the physical left side of the page.
  void pageLeft() {
    _evaluateReaderCommand(
      label: 'pageLeft',
      expression: 'pageLeft()',
    );
  }

  /// Turn toward the physical right side of the page.
  void pageRight() {
    _evaluateReaderCommand(
      label: 'pageRight',
      expression: 'pageRight()',
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

  /// Clear the active WebView text selection, if any.
  void clearSelection() {
    _evaluateReaderCommand(
      label: 'clearSelection',
      expression:
          "typeof window.clearSelection === 'function' ? window.clearSelection() : null",
    );
  }

  /// Clear selection after a completed reader text action without consuming
  /// the next page-turn click.
  void clearSelectionAfterTextAction() {
    _evaluateReaderCommand(
      label: 'clearSelectionAfterTextAction',
      expression:
          "typeof window.clearSelectionAfterTextAction === 'function' ? window.clearSelectionAfterTextAction() : "
          "typeof window.clearSelection === 'function' ? window.clearSelection() : null",
    );
  }

  /// Render a temporary highlight over the active selection after the native
  /// WebView selection is cleared to suppress iOS edit menus.
  void showSelectionHighlightPreview({
    required String cfiRange,
    required String color,
    double? opacity,
    String? mixBlendMode,
    double? verticalOffset,
  }) {
    final preview = jsonEncode({
      'cfi': cfiRange,
      'color': color,
      'opacity': ?opacity,
      'mixBlendMode': ?mixBlendMode,
      'verticalOffset': ?verticalOffset,
    });
    _evaluateReaderCommand(
      label: 'showSelectionHighlightPreview',
      expression:
          "typeof window.showSelectionHighlightPreview === 'function' ? "
          "window.showSelectionHighlightPreview($preview) : null",
    );
  }

  /// Remove the temporary selection highlight preview, if one is visible.
  void clearSelectionHighlightPreview() {
    _evaluateReaderCommand(
      label: 'clearSelectionHighlightPreview',
      expression:
          "typeof window.clearSelectionHighlightPreview === 'function' ? "
          "window.clearSelectionHighlightPreview() : null",
    );
  }

  /// Render or update the temporary image-area highlight preview.
  void showImageAreaSelectionPreview({
    required int pageIndex,
    required ReaderImageAreaRect rect,
    required String color,
    double? opacity,
  }) {
    final preview = jsonEncode({
      'pageIndex': pageIndex,
      'rect': rect.toMap(),
      'color': color,
      'opacity': ?opacity,
    });
    _evaluateReaderCommand(
      label: 'showImageAreaSelectionPreview',
      expression:
          "typeof window.showImageAreaSelectionPreview === 'function' ? "
          "window.showImageAreaSelectionPreview($preview) : null",
    );
  }

  /// Remove the temporary image-area highlight preview, if one is visible.
  void clearImageAreaSelectionPreview({bool allowNextTap = false}) {
    final payload = jsonEncode({'allowNextTap': allowNextTap});
    _evaluateReaderCommand(
      label: 'clearImageAreaSelectionPreview',
      expression:
          "typeof window.clearImageAreaSelectionPreview === 'function' ? "
          "window.clearImageAreaSelectionPreview($payload) : null",
    );
  }

  /// Tell WebView which viewport area is occupied by Flutter image controls.
  void setImageAreaSelectionControlsBounds(ReaderSelectionPosition bounds) {
    final payload = jsonEncode({
      'left': bounds.left,
      'top': bounds.top,
      'right': bounds.right,
      'bottom': bounds.bottom,
    });
    _evaluateReaderCommand(
      label: 'setImageAreaSelectionControlsBounds',
      expression:
          "typeof window.setImageAreaSelectionControlsBounds === 'function' ? "
          "window.setImageAreaSelectionControlsBounds($payload) : null",
    );
  }

  /// Clear the Flutter image-controls hit-test exclusion area inside WebView.
  void clearImageAreaSelectionControlsBounds() {
    _evaluateReaderCommand(
      label: 'clearImageAreaSelectionControlsBounds',
      expression:
          "typeof window.clearImageAreaSelectionControlsBounds === 'function' ? "
          "window.clearImageAreaSelectionControlsBounds() : null",
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
    if (!highlight.isImageArea && highlight.cfiRange == null) return;
    final annotation = jsonEncode(
      highlight.isImageArea
          ? {
              'id': highlight.id,
              'type': 'image-area-highlight',
              'value': 'image-area:${highlight.id}',
              'pageIndex': highlight.imagePageIndex,
              'rect': highlight.imageArea!.toMap(),
              'color': highlight.color ?? '#FFE600',
              'opacity': ?highlight.opacity,
            }
          : {
              'id': highlight.id,
              'type': 'highlight',
              'value': highlight.cfiRange,
              'color': highlight.color ?? '#FFE600',
              'opacity': ?highlight.opacity,
              'mixBlendMode': ?highlight.mixBlendMode,
              'verticalOffset': ?highlight.verticalOffset,
            },
    );
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
