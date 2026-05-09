import 'dart:convert';

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

/// WebView-based book reader backed by foliate-js.
///
/// Loads foliate-js `index.html` from the local server's `/assets/foliate-js/`
/// route. foliate-js fetches the book file from `/book/<encoded-path>` and
/// renders it.
///
/// Communication:
///   JS → Flutter: `onReady`, `onRelocated`, `onSelectionEnd`,
///                  `onSelectionCleared`, `onAnnotationClick`
///   Flutter → JS: `goToCfi`, `nextPage`, `prevPage`, `changeStyle`,
///                  `addAnnotation`, `removeAnnotation`
class BookReaderWebView extends StatefulWidget {
  const BookReaderWebView({
    required this.serverPort,
    required this.bookFilePath,
    this.initialCfi,
    this.initialProgress,
    this.foliateStyle = const FoliateStyle(),
    this.highlights = const [],
    this.onReady,
    this.onPositionChanged,
    this.onTextSelected,
    this.onTextDeselected,
    this.onHighlightTapped,
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

  /// Book reader appearance passed to foliate-js via URL params.
  final FoliateStyle foliateStyle;

  /// Highlights to render as annotations on load.
  final List<ReaderHighlight> highlights;

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

  /// Fires when the user taps empty reader space (no selection, no link).
  /// Coordinates are normalized to [0, 1] over the viewport.
  final void Function(double x, double y)? onTapped;

  @override
  State<BookReaderWebView> createState() => BookReaderWebViewState();
}

class BookReaderWebViewState extends State<BookReaderWebView> {
  InAppWebViewController? _controller;
  bool _isReady = false;

  // TEMP WORKAROUND — remove once the WKWebView deep-CFI restore crash is
  // fixed properly (see memory: project_wkwebview_cfi_crash_root_cause.md).
  // When the WebKit WebContent process dies during initial pagination
  // (TextOnlySimpleLineBuilder RELEASE_ASSERT triggered by goTo on a
  // saved deep CFI), we self-recover by reloading the index with no CFI
  // so the book at least opens from chapter 1 instead of staying blank.
  // This flag overrides the URL-built initialCfi during the recovery
  // reload, then clears itself once the reload signals onLoadEnd.
  bool _recoveringFromCrash = false;

  @override
  void didUpdateWidget(covariant BookReaderWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isReady) return;

    // Value-compare via FoliateStyle's `==` instead of double-encoding
    // both sides through jsonEncode on every parent rebuild.
    if (oldWidget.foliateStyle != widget.foliateStyle) {
      changeStyle(widget.foliateStyle);
    }

    _syncAnnotations(oldWidget.highlights, widget.highlights);
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

  void _evalAddAnnotation(ReaderHighlight h) {
    if (h.cfiRange == null) return;
    final annotation = jsonEncode({
      'id': h.id,
      'type': 'highlight',
      'value': h.cfiRange,
      'color': h.color ?? '#FFE600',
    });
    _controller?.evaluateJavascript(source: 'addAnnotation($annotation);');
  }

  void _evalRemoveAnnotation(String cfiRange) {
    final escaped = jsonEncode(cfiRange);
    _controller?.evaluateJavascript(source: 'removeAnnotation($escaped);');
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
      // TEMP — see _recoveringFromCrash field doc for context.
      onWebContentProcessDidTerminate: _onContentProcessTerminated,
    );
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
      callback: (_) {
        _isReady = true;
        // TEMP — clear the crash-recovery flag once the post-crash
        // reload finishes. Remove with the rest of the workaround.
        if (_recoveringFromCrash) {
          final progress = widget.initialProgress;
          final recoveredAt = progress != null && progress > 0
              ? ' at progress=${progress.toStringAsFixed(4)}'
              : ' at chapter 1';
          debugPrint(
            '[reader-recovery] post-crash reload completed; book is open'
            '$recoveredAt (saved deep CFI was discarded)',
          );
          _recoveringFromCrash = false;
        }
        _renderAnnotations();
        widget.onReady?.call();
      },
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
        final data = args.first as Map<String, dynamic>;
        final position = BookPosition.fromMap(data);
        widget.onPositionChanged?.call(position);
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onAnnotationClick',
      callback: (args) {
        if (args.isEmpty) return;
        final data = args.first as Map<String, dynamic>;
        final annotation = data['annotation'] as Map<String, dynamic>?;
        final id = annotation?['id'] as String?;
        if (id != null) widget.onHighlightTapped?.call(id);
      },
    );

    registerSharedReaderHandlers(
      controller,
      onTextSelected: widget.onTextSelected,
      onTextDeselected: widget.onTextDeselected,
      onTapped: widget.onTapped,
    );
  }

  void _renderAnnotations() {
    for (final h in widget.highlights) {
      _evalAddAnnotation(h);
    }
  }

  /// Navigate to a specific CFI position.
  void goToCfi(String cfi) {
    final escaped = jsonEncode(cfi);
    _controller?.evaluateJavascript(source: 'goToCfi($escaped);');
  }

  /// Navigate to a fraction `[0, 1]` of the whole book. Used by the
  /// bottom-chrome slider's drag-to-seek; foliate-js's
  /// `window.goToPercent` does the actual chapter+offset resolution.
  void goToFraction(double fraction) {
    final clamped = fraction.clamp(0.0, 1.0);
    _controller?.evaluateJavascript(source: 'goToPercent($clamped);');
  }

  /// Go to the next page.
  void nextPage() {
    _controller?.evaluateJavascript(source: 'nextPage();');
  }

  /// Go to the previous page.
  void prevPage() {
    _controller?.evaluateJavascript(source: 'prevPage();');
  }

  /// Update style from Flutter.
  void changeStyle(FoliateStyle style) {
    final json = jsonEncode(style.toMap());
    _controller?.evaluateJavascript(source: 'changeStyle($json);');
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
    _controller?.evaluateJavascript(
      source: 'addAnnotation($annotation);',
    );
  }

  /// Remove a highlight annotation by CFI.
  void removeAnnotation(String cfiRange) {
    final escaped = jsonEncode(cfiRange);
    _controller?.evaluateJavascript(
      source: 'removeAnnotation($escaped);',
    );
  }
}
