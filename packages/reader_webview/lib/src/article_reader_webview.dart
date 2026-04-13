import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'reader_bridge.dart';

/// WebView-based article reader.
///
/// Loads the article reader shell (`reader.html` + `reader.js` + `reader.css`)
/// from the local server's `/assets/article/` route, then injects the article
/// HTML via JS `initArticle()`.
///
/// Communication:
///   JS → Flutter: `onReady`, `onRelocated`, `onSelectionEnd`,
///                  `onSelectionCleared`, `onHighlightTap`
///   Flutter → JS: `initArticle`, `scrollToFraction`, `changeStyle`,
///                  `renderHighlights`, `getScrollFraction`
class ArticleReaderWebView extends StatefulWidget {
  const ArticleReaderWebView({
    required this.serverPort,
    required this.articleId,
    this.articleHtml,
    this.initialScrollFraction,
    this.style,
    this.highlights = const [],
    this.onReady,
    this.onPositionChanged,
    this.onTextSelected,
    this.onTextDeselected,
    this.onHighlightTapped,
    super.key,
  });

  /// Port of the local reader server.
  final int serverPort;

  /// Article ID — used to fetch HTML from `/article/<id>` if
  /// [articleHtml] is not provided.
  final String articleId;

  /// Pre-loaded article HTML. When provided, injected directly via
  /// `initArticle()` instead of fetching from the server. Useful when
  /// the BLoC already has the content in memory.
  final String? articleHtml;

  /// Scroll position to restore on load, in [0, 1].
  final double? initialScrollFraction;

  /// Reader appearance (font, colors, spacing).
  final ReaderStyle? style;

  /// Highlights to render on load.
  final List<ReaderHighlight> highlights;

  /// Fires once when the WebView has loaded and is ready for interaction.
  final VoidCallback? onReady;

  /// Fires on scroll with the current fraction in [0, 1].
  final void Function(double fraction)? onPositionChanged;

  /// Fires when the user selects text.
  final void Function(ReaderSelection selection)? onTextSelected;

  /// Fires when the user clears the selection.
  final VoidCallback? onTextDeselected;

  /// Fires when the user taps an existing highlight.
  final void Function(String highlightId)? onHighlightTapped;

  @override
  State<ArticleReaderWebView> createState() => _ArticleReaderWebViewState();
}

class _ArticleReaderWebViewState extends State<ArticleReaderWebView> {
  InAppWebViewController? _controller;

  String get _baseUrl =>
      'http://127.0.0.1:${widget.serverPort}/assets/article/reader.html';

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(_baseUrl)),
      initialSettings: InAppWebViewSettings(
        supportZoom: false,
        transparentBackground: true,
        isInspectable: kDebugMode,
        useHybridComposition: true,
        javaScriptEnabled: true,
        // Page is served from http://127.0.0.1 but article images are
        // https://. Android WebView blocks this by default.
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
      ),
      onWebViewCreated: _onWebViewCreated,
      onLoadStop: (controller, url) => _onLoadStop(),
    );
  }

  void _onWebViewCreated(InAppWebViewController controller) {
    _controller = controller;
    _registerHandlers(controller);
  }

  void _registerHandlers(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: 'onReady',
      callback: (_) {
        _applyInitialStyle();
        _renderHighlights();
        _restoreScrollPosition();
        widget.onReady?.call();
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onRelocated',
      callback: (args) {
        if (args.isEmpty) return;
        final data = args.first as Map<String, dynamic>;
        final position = ArticlePosition.fromMap(data);
        widget.onPositionChanged?.call(position.fraction);
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onSelectionEnd',
      callback: (args) {
        if (args.isEmpty) return;
        final data = args.first as Map<String, dynamic>;
        final selection = ReaderSelection.fromMap(data);
        widget.onTextSelected?.call(selection);
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onSelectionCleared',
      callback: (_) {
        widget.onTextDeselected?.call();
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onHighlightTap',
      callback: (args) {
        if (args.isEmpty) return;
        final data = args.first as Map<String, dynamic>;
        final id = data['id'] as String?;
        if (id != null) widget.onHighlightTapped?.call(id);
      },
    );
  }

  Future<void> _onLoadStop() async {
    // Set <base> so relative image paths (images/<hash>.<ext>) in the
    // article HTML resolve to the server's article image route.
    await _controller?.evaluateJavascript(
      source:
          "var b = document.createElement('base');"
          "b.href = 'http://127.0.0.1:${widget.serverPort}"
          "/article/${widget.articleId}/';"
          "document.head.prepend(b);",
    );

    final html = widget.articleHtml ?? await _fetchArticleHtml();
    if (html == null) return;

    final escaped = jsonEncode(html);
    await _controller?.evaluateJavascript(
      source: 'window.initArticle($escaped);',
    );
  }

  Future<String?> _fetchArticleHtml() async {
    final url = Uri.parse(
      'http://127.0.0.1:${widget.serverPort}/article/${widget.articleId}',
    );
    final client = HttpClient();
    try {
      final request = await client.getUrl(url);
      final response = await request.close();
      if (response.statusCode == HttpStatus.ok) {
        return await response.transform(const Utf8Decoder()).join();
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  void _applyInitialStyle() {
    final style = widget.style;
    if (style == null) return;
    final json = jsonEncode(style.toMap());
    _controller?.evaluateJavascript(source: 'window.changeStyle($json);');
  }

  void _renderHighlights() {
    if (widget.highlights.isEmpty) return;
    final json = jsonEncode(
      widget.highlights.map((h) => h.toMap()).toList(),
    );
    _controller?.evaluateJavascript(
      source: 'window.renderHighlights($json);',
    );
  }

  void _restoreScrollPosition() {
    final fraction = widget.initialScrollFraction;
    if (fraction == null || fraction <= 0) return;
    _controller?.evaluateJavascript(
      source: 'window.scrollToFraction($fraction);',
    );
  }

  /// Update style from Flutter (e.g. when user changes reader theme).
  void changeStyle(ReaderStyle style) {
    final json = jsonEncode(style.toMap());
    _controller?.evaluateJavascript(source: 'window.changeStyle($json);');
  }

  /// Re-render highlights (e.g. after creating a new one).
  void updateHighlights(List<ReaderHighlight> highlights) {
    final json = jsonEncode(highlights.map((h) => h.toMap()).toList());
    _controller?.evaluateJavascript(
      source: 'window.renderHighlights($json);',
    );
  }
}
