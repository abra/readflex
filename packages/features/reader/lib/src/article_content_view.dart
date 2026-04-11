import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Renders a cleaned-up article HTML body as a scrollable widget tree.
///
/// This is intentionally a small, hand-rolled HTML renderer rather than a
/// full HTML widget library: readability_dart emits a tightly constrained
/// subset of block tags (p, headings, lists, blockquotes, figures) so a
/// custom walker keeps us free of heavy native deps (flutter_html,
/// flutter_inappwebview) until the book track needs them. Unknown tags are
/// rendered as plain text to stay readable even when a site's markup drifts
/// outside the expected set.
class ArticleContentView extends StatefulWidget {
  const ArticleContentView({
    required this.html,
    required this.textStyle,
    required this.accentColor,
    required this.secondaryTextColor,
    required this.dividerColor,
    this.articleUrl,
    this.onSelectionChanged,
    this.initialScrollFraction,
    this.onScrollFractionChanged,
    super.key,
  });

  final String html;
  final TextStyle textStyle;
  final Color accentColor;
  final Color secondaryTextColor;
  final Color dividerColor;

  /// Source URL of the article, used as the base for resolving relative
  /// image URLs inside the body. Readability tries to absolve URLs on its
  /// side, but protocol-relative (`//host/...`) and plain relative paths
  /// sometimes slip through.
  final String? articleUrl;

  /// Fires whenever the user's selection inside the article changes.
  ///
  /// Receives the plain text of the current selection, or `null` when the
  /// selection has been cleared (tap outside, collapsed selection). The
  /// reader screen forwards this to [ReaderBloc] so the context panel
  /// with TextAction buttons can light up for articles.
  final ValueChanged<String?>? onSelectionChanged;

  /// Scroll progress to restore on first layout, in [0, 1] where 1 is the
  /// bottom of the article. Stored per-article in [Article.currentScrollOffset]
  /// so reopening the same article drops the user back where they stopped.
  final double? initialScrollFraction;

  /// Fires (debounced) with the current scroll progress as a [0, 1] fraction
  /// so the reader bloc can persist it. A fraction keeps the saved position
  /// portable across font size / text scale / device width changes that
  /// would invalidate a raw pixel offset.
  final ValueChanged<double>? onScrollFractionChanged;

  @override
  State<ArticleContentView> createState() => _ArticleContentViewState();
}

class _ArticleContentViewState extends State<ArticleContentView> {
  // 500ms balances responsiveness (saved state doesn't feel stale after
  // a pause) against DB write pressure from a continuous fling.
  static const _saveDebounce = Duration(milliseconds: 500);

  final ScrollController _scrollController = ScrollController();
  Timer? _saveTimer;
  bool _restoredInitial = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreInitial());
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _restoreInitial() {
    if (!mounted || _restoredInitial) return;
    _restoredInitial = true;
    final target = widget.initialScrollFraction;
    if (target == null || target <= 0) return;
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) return;
    _scrollController.jumpTo((target * max).clamp(0.0, max));
  }

  void _handleScroll() {
    final handler = widget.onScrollFractionChanged;
    if (handler == null) return;
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) return;
    final fraction = (_scrollController.offset / max).clamp(0.0, 1.0);
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDebounce, () {
      if (!mounted) return;
      handler(fraction);
    });
  }

  @override
  Widget build(BuildContext context) {
    final document = html_parser.parse(widget.html);
    final body = document.body ?? document.documentElement;
    final blocks = body == null ? const <dom.Node>[] : body.nodes;

    final widgets = <Widget>[];
    for (final node in blocks) {
      final w = _renderBlock(node);
      if (w != null) widgets.add(w);
    }

    return SelectionArea(
      onSelectionChanged: (selection) {
        final handler = widget.onSelectionChanged;
        if (handler == null) return;
        final text = selection?.plainText.trim() ?? '';
        handler(text.isEmpty ? null : text);
      },
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xl,
        ),
        itemCount: widgets.length,
        itemBuilder: (_, i) => widgets[i],
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      ),
    );
  }

  Widget? _renderBlock(dom.Node node) {
    if (node is dom.Text) {
      final text = node.text.trim();
      if (text.isEmpty) return null;
      return Text(text, style: widget.textStyle);
    }
    if (node is! dom.Element) return null;

    switch (node.localName) {
      case 'p':
        final span = _inlineSpan(node, widget.textStyle);
        if (span.toPlainText().trim().isEmpty) return null;
        return Text.rich(span, style: widget.textStyle);
      case 'h1':
        return _heading(node, 1.8);
      case 'h2':
        return _heading(node, 1.5);
      case 'h3':
        return _heading(node, 1.3);
      case 'h4':
      case 'h5':
      case 'h6':
        return _heading(node, 1.15);
      case 'blockquote':
        return _blockquote(node);
      case 'ul':
        return _list(node, ordered: false);
      case 'ol':
        return _list(node, ordered: true);
      case 'figure':
        return _figure(node);
      case 'img':
        return _inlineImage(
          src: node.attributes['src'],
          alt: node.attributes['alt'],
        );
      case 'hr':
        return Divider(color: widget.dividerColor, height: AppSpacing.lg * 2);
      case 'pre':
      case 'code':
        return _codeBlock(node);
      case 'table':
        return _table(node);
      default:
        // Fall back to inline rendering — readability sometimes emits
        // <section> / <div> wrappers around the real content.
        final children = <Widget>[];
        for (final child in node.nodes) {
          final widget = _renderBlock(child);
          if (widget != null) children.add(widget);
        }
        if (children.isEmpty) return null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final c in children) ...[
              c,
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        );
    }
  }

  Widget _heading(dom.Element node, double scale) {
    final style = widget.textStyle.copyWith(
      fontSize: (widget.textStyle.fontSize ?? 16) * scale,
      fontWeight: FontWeight.w700,
      height: 1.2,
    );
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Text.rich(_inlineSpan(node, style), style: style),
    );
  }

  Widget _blockquote(dom.Element node) {
    final style = widget.textStyle.copyWith(
      fontStyle: FontStyle.italic,
      color: widget.secondaryTextColor,
    );
    return Container(
      padding: const EdgeInsets.only(left: AppSpacing.md),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: widget.accentColor, width: 3),
        ),
      ),
      child: Text.rich(_inlineSpan(node, style), style: style),
    );
  }

  Widget _list(dom.Element node, {required bool ordered}) {
    final items = node.children.where((c) => c.localName == 'li').toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    ordered ? '${i + 1}.' : '•',
                    style: widget.textStyle,
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    _inlineSpan(items[i], widget.textStyle),
                    style: widget.textStyle,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _figure(dom.Element node) {
    final img = node.getElementsByTagName('img').firstOrNull;
    final caption = node.getElementsByTagName('figcaption').firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _inlineImage(
          src: img?.attributes['src'],
          alt: img?.attributes['alt'],
        ),
        if (caption != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            caption.text.trim(),
            style: widget.textStyle.copyWith(
              fontStyle: FontStyle.italic,
              color: widget.secondaryTextColor,
              fontSize: (widget.textStyle.fontSize ?? 16) * 0.9,
            ),
          ),
        ],
      ],
    );
  }

  /// Renders an inline `<img>`. Resolves the src against the article URL so
  /// relative / protocol-relative paths work, then shows the image via
  /// [Image.network] with the placeholder card as both loading and error
  /// fallback.
  ///
  /// TODO: images are fetched from the network at render time and only sit
  /// in the in-memory [ImageCache] for the session — articles aren't truly
  /// offline-safe until the import flow downloads inline assets to app
  /// documents and rewrites `src` to local paths (see the matching TODO in
  /// `lib/app/routing.dart` `_importArticle`).
  Widget _inlineImage({String? src, String? alt}) {
    final resolved = _resolveImageUrl(src);
    if (resolved == null) {
      return _imageFallback(alt: alt);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Image.network(
        resolved,
        width: double.infinity,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _imageFallback(alt: alt, isLoading: true);
        },
        errorBuilder: (_, _, _) => _imageFallback(alt: alt),
      ),
    );
  }

  /// Resolves an `<img src>` value against the article URL. Returns null
  /// when the input is unusable (empty, missing, data-URI, or a relative
  /// path with no base URL to anchor on).
  String? _resolveImageUrl(String? src) {
    if (src == null || src.isEmpty) return null;
    if (src.startsWith('data:')) return null;
    if (src.startsWith('//')) return 'https:$src';
    if (src.startsWith('http://') || src.startsWith('https://')) return src;

    final base = widget.articleUrl;
    if (base == null) return null;
    final baseUri = Uri.tryParse(base);
    if (baseUri == null || !baseUri.hasScheme) return null;
    try {
      return baseUri.resolve(src).toString();
    } catch (_) {
      return null;
    }
  }

  Widget _imageFallback({String? alt, bool isLoading = false}) {
    final label = (alt == null || alt.isEmpty)
        ? (isLoading ? 'Loading image…' : 'Image')
        : alt;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: widget.dividerColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          if (isLoading)
            SizedBox(
              width: AppIconSize.md,
              height: AppIconSize.md,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: widget.secondaryTextColor,
              ),
            )
          else
            Icon(Icons.image_outlined, color: widget.secondaryTextColor),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: widget.textStyle.copyWith(
                color: widget.secondaryTextColor,
                fontSize: (widget.textStyle.fontSize ?? 16) * 0.9,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _codeBlock(dom.Element node) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: widget.dividerColor.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        node.text,
        style: widget.textStyle.copyWith(
          fontFamily: 'monospace',
          fontSize: (widget.textStyle.fontSize ?? 16) * 0.9,
        ),
      ),
    );
  }

  /// Renders a `<table>` as a Flutter [Table] widget.
  ///
  /// Intentionally narrow in scope: flattens thead/tbody/tfoot wrappers,
  /// bolds `<th>` cells, pads short rows to the widest row so [Table]'s
  /// same-width constraint holds, and ignores colspan / rowspan / nested
  /// tables. Anything fancier falls back to a caption-less cell layout —
  /// the goal is that Wikipedia infoboxes and simple reference tables stop
  /// rendering as a vertical column of orphaned cells, not to re-implement
  /// HTML tables in Flutter.
  Widget? _table(dom.Element node) {
    final rows = <List<dom.Element>>[];
    void collectRows(dom.Element parent) {
      for (final child in parent.children) {
        switch (child.localName) {
          case 'tr':
            final cells = child.children
                .where(
                  (c) => c.localName == 'th' || c.localName == 'td',
                )
                .toList();
            if (cells.isNotEmpty) rows.add(cells);
          case 'thead':
          case 'tbody':
          case 'tfoot':
            collectRows(child);
        }
      }
    }

    collectRows(node);
    if (rows.isEmpty) return null;

    final columnCount = rows
        .map((r) => r.length)
        .reduce((a, b) => a > b ? a : b);

    TextStyle cellStyle(dom.Element cell) {
      if (cell.localName == 'th') {
        return widget.textStyle.copyWith(fontWeight: FontWeight.w700);
      }
      return widget.textStyle;
    }

    Widget buildCell(dom.Element? cell) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: cell == null
            ? const SizedBox.shrink()
            : Text.rich(
                _inlineSpan(cell, cellStyle(cell)),
                style: cellStyle(cell),
              ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: widget.dividerColor),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Table(
          border: TableBorder.symmetric(
            inside: BorderSide(color: widget.dividerColor),
          ),
          defaultVerticalAlignment: TableCellVerticalAlignment.top,
          // FlexColumnWidth keeps wide tables from blowing past the screen;
          // the tradeoff is long cell text wraps, which is fine for prose
          // readers (unlike scientific data tables we can't support yet).
          defaultColumnWidth: const FlexColumnWidth(),
          children: [
            for (final row in rows)
              TableRow(
                children: [
                  for (var i = 0; i < columnCount; i++)
                    buildCell(i < row.length ? row[i] : null),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Walks inline children of a block and collects them into a single
  /// [TextSpan] so inline formatting (bold, italic, links) flows inside
  /// one [Text.rich] rather than breaking into a column of widgets.
  TextSpan _inlineSpan(dom.Element element, TextStyle style) {
    final children = <InlineSpan>[];
    for (final node in element.nodes) {
      children.add(_inlineFromNode(node, style));
    }
    return TextSpan(style: style, children: children);
  }

  InlineSpan _inlineFromNode(dom.Node node, TextStyle style) {
    if (node is dom.Text) {
      return TextSpan(text: node.text);
    }
    if (node is! dom.Element) return const TextSpan(text: '');

    TextStyle childStyle = style;
    switch (node.localName) {
      case 'strong':
      case 'b':
        childStyle = style.copyWith(fontWeight: FontWeight.w700);
      case 'em':
      case 'i':
        childStyle = style.copyWith(fontStyle: FontStyle.italic);
      case 'a':
        childStyle = style.copyWith(
          color: widget.accentColor,
          decoration: TextDecoration.underline,
        );
      case 'code':
        childStyle = style.copyWith(fontFamily: 'monospace');
      case 'br':
        return const TextSpan(text: '\n');
      default:
        break;
    }

    final children = <InlineSpan>[
      for (final child in node.nodes) _inlineFromNode(child, childStyle),
    ];
    return TextSpan(style: childStyle, children: children);
  }
}
