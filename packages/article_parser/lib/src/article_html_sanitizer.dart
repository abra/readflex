import 'package:sanitize_html/sanitize_html.dart';

/// Removes dangerous markup from article HTML before it's stored on disk
/// and loaded back into the reader's WebView.
///
/// readability_dart strips most navigation/chrome but doesn't claim to be
/// a security boundary — its output can still carry `<script>` tags,
/// inline `onclick` handlers, `javascript:` URLs, and external iframes
/// from the source page. The reader serves articles from `127.0.0.1`, so
/// any script that survives this stage runs same-origin with our reader
/// shell — close enough to a content-injection vector to take seriously.
///
/// Backed by the `sanitize_html` package, which ships a conservative
/// allow-list (text formatting, headings, lists, tables, links, images)
/// and drops every event-handler attribute, inline style, and unsafe
/// URL scheme. Customisations on top of its defaults:
///
///   * `<a>` tags get `rel="noopener noreferrer"` — defensive even though
///     the reader currently doesn't navigate.
///   * Class names are kept (`allowClassName: (_) => true`) so theme/CSS
///     hooks emitted by readability — e.g. `<p class="caption">` — still
///     work after sanitisation.
///
/// One quirk we work around: `sanitize_html` strips an unknown tag
/// **together with its children**. readability_dart wraps cleaned content
/// in semantic `<article>` / `<section>` / `<main>` / `<aside>` blocks
/// which aren't on the package's allow-list — handing its raw output
/// directly to `sanitize_html` would discard the entire body. We rewrite
/// those four containers to `<div>` first; navigation / footer chrome
/// (`<header>`, `<footer>`, `<nav>`) is still dropped because those tags
/// stay non-allow-listed.
class ArticleHtmlSanitizer {
  const ArticleHtmlSanitizer();

  static final _semanticContainerTag = RegExp(
    r'<(/?)(article|section|main|aside)(\s[^>]*)?>',
    caseSensitive: false,
  );

  /// Returns a sanitised copy of [html] safe to embed in the reader.
  /// Pass the raw output of `readability_dart` here before writing it to
  /// disk; consumers should treat the result as the article body.
  String sanitize(String html) {
    final preProcessed = html.replaceAllMapped(
      _semanticContainerTag,
      (match) => '<${match.group(1)!}div${match.group(3) ?? ''}>',
    );
    return sanitizeHtml(
      preProcessed,
      allowClassName: (_) => true,
      addLinkRel: (href) {
        if (href.isEmpty) return null;
        return const ['noopener', 'noreferrer'];
      },
    );
  }
}
