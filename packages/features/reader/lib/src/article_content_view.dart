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
class ArticleContentView extends StatelessWidget {
  const ArticleContentView({
    required this.html,
    required this.textStyle,
    required this.accentColor,
    required this.secondaryTextColor,
    required this.dividerColor,
    super.key,
  });

  final String html;
  final TextStyle textStyle;
  final Color accentColor;
  final Color secondaryTextColor;
  final Color dividerColor;

  @override
  Widget build(BuildContext context) {
    final document = html_parser.parse(html);
    final body = document.body ?? document.documentElement;
    final blocks = body == null ? const <dom.Node>[] : body.nodes;

    final widgets = <Widget>[];
    for (final node in blocks) {
      final widget = _renderBlock(node);
      if (widget != null) widgets.add(widget);
    }

    // SelectionArea lets the user drag-select text. Wiring selection
    // events into ReaderBloc (for TextAction context panel) is left to a
    // later vertical — reading the article end-to-end already adds value
    // on its own.
    return SelectionArea(
      child: ListView.separated(
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
      return Text(text, style: textStyle);
    }
    if (node is! dom.Element) return null;

    switch (node.localName) {
      case 'p':
        final span = _inlineSpan(node, textStyle);
        if (span.toPlainText().trim().isEmpty) return null;
        return Text.rich(span, style: textStyle);
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
        return _imagePlaceholder(
          node.attributes['alt'] ?? node.attributes['src'] ?? '',
        );
      case 'hr':
        return Divider(color: dividerColor, height: AppSpacing.lg * 2);
      case 'pre':
      case 'code':
        return _codeBlock(node);
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
    final style = textStyle.copyWith(
      fontSize: (textStyle.fontSize ?? 16) * scale,
      fontWeight: FontWeight.w700,
      height: 1.2,
    );
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Text.rich(_inlineSpan(node, style), style: style),
    );
  }

  Widget _blockquote(dom.Element node) {
    final style = textStyle.copyWith(
      fontStyle: FontStyle.italic,
      color: secondaryTextColor,
    );
    return Container(
      padding: const EdgeInsets.only(left: AppSpacing.md),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: accentColor, width: 3),
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
                    style: textStyle,
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    _inlineSpan(items[i], textStyle),
                    style: textStyle,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _figure(dom.Element node) {
    // Render the figure's caption if present; image itself is a
    // placeholder because we don't yet cache inline images locally.
    final img = node.getElementsByTagName('img').firstOrNull;
    final caption = node.getElementsByTagName('figcaption').firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _imagePlaceholder(
          img?.attributes['alt'] ?? img?.attributes['src'] ?? 'Image',
        ),
        if (caption != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            caption.text.trim(),
            style: textStyle.copyWith(
              fontStyle: FontStyle.italic,
              color: secondaryTextColor,
              fontSize: (textStyle.fontSize ?? 16) * 0.9,
            ),
          ),
        ],
      ],
    );
  }

  Widget _imagePlaceholder(String alt) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: dividerColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(Icons.image_outlined, color: secondaryTextColor),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              alt.isEmpty ? 'Image' : alt,
              style: textStyle.copyWith(
                color: secondaryTextColor,
                fontSize: (textStyle.fontSize ?? 16) * 0.9,
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
        color: dividerColor.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        node.text,
        style: textStyle.copyWith(
          fontFamily: 'monospace',
          fontSize: (textStyle.fontSize ?? 16) * 0.9,
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
          color: accentColor,
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
