/// The stylesheets a content document asks for, in cascade order:
/// `<link rel="stylesheet">` and `<style>` elements as they appear, each
/// external sheet's `@import`s inlined before its own rules, as the
/// browser orders them. Loading goes through a callback, so the EPUB
/// container, a MOBI flow or a test map can serve the text.
library;

import '../document/content_document.dart';
import '../formats/epub/epub_url.dart';
import 'css_syntax.dart';
import 'css_tokenizer.dart';
import 'css_values.dart';

/// Reads the text at a resolved [href], or null when there is none.
typedef StyleSheetReader = Future<String?> Function(String href);

/// Parsed external sheets by resolved href, shared across the sections
/// of a book: a chapter's `<link>`s point at the same few files.
class StyleSheetCache {
  final _sheets = <String, CssStyleSheet?>{};

  int get length => _sheets.length;

  Future<CssStyleSheet?> _load(String href, StyleSheetReader read) async {
    if (_sheets.containsKey(href)) return _sheets[href];
    final text = await read(href);
    final sheet = text == null ? null : CssStyleSheet.parse(text);
    _sheets[href] = sheet;
    return sheet;
  }
}

/// Loads the sheets [document] links to and embeds, relative to
/// [documentHref]. Imports nest up to [maxImportDepth]; a sheet already
/// seen on the way down is not loaded twice. With a [cache], external
/// sheets are parsed once per book.
Future<List<CssStyleSheet>> loadDocumentStyleSheets(
  ContentDocument document, {
  required String documentHref,
  required StyleSheetReader read,
  StyleSheetCache? cache,
  int maxImportDepth = 8,
}) async {
  final out = <CssStyleSheet>[];
  final seen = <String>{};
  final sheets = cache ?? StyleSheetCache();
  for (final node in document.descendantsOf(ContentDocument.rootIndex)) {
    if (!document.isElement(node)) continue;
    switch (document.localNameOf(node).toLowerCase()) {
      case 'link':
        final rel = document.attributeOf(node, 'rel')?.toLowerCase() ?? '';
        final href = document.attributeOf(node, 'href');
        if (href == null || !rel.split(RegExp(r'\s+')).contains('stylesheet')) {
          continue;
        }
        if (!_isScreenMedia(document.attributeOf(node, 'media'))) continue;
        final type = document.attributeOf(node, 'type')?.toLowerCase();
        if (type != null && type.isNotEmpty && type != 'text/css') continue;
        final resolved = resolveEpubUrl(href, documentHref);
        await _loadInto(out, resolved, read, sheets, seen, maxImportDepth);
      case 'style':
        final type = document.attributeOf(node, 'type')?.toLowerCase();
        if (type != null && type.isNotEmpty && type != 'text/css') continue;
        if (!_isScreenMedia(document.attributeOf(node, 'media'))) continue;
        final sheet = CssStyleSheet.parse(document.textContentOf(node));
        await _inlineImports(
          out,
          sheet,
          documentHref,
          read,
          sheets,
          seen,
          maxImportDepth,
        );
        out.add(sheet);
    }
  }
  return out;
}

Future<void> _loadInto(
  List<CssStyleSheet> out,
  String href,
  StyleSheetReader read,
  StyleSheetCache sheets,
  Set<String> seen,
  int depth,
) async {
  if (depth < 0 || !seen.add(href)) return;
  final sheet = await sheets._load(href, read);
  if (sheet == null) return;
  await _inlineImports(out, sheet, href, read, sheets, seen, depth);
  out.add(sheet);
}

Future<void> _inlineImports(
  List<CssStyleSheet> out,
  CssStyleSheet sheet,
  String baseHref,
  StyleSheetReader read,
  StyleSheetCache sheets,
  Set<String> seen,
  int depth,
) async {
  for (final import in cssImportsOf(sheet)) {
    await _loadInto(
      out,
      resolveEpubUrl(import, baseHref),
      read,
      sheets,
      seen,
      depth - 1,
    );
  }
}

/// The URLs of a sheet's leading `@import` rules whose media is not
/// print only, as written.
List<String> cssImportsOf(CssStyleSheet sheet) {
  final out = <String>[];
  for (final rule in sheet.rules) {
    // Imports are only valid before other rules; `@charset` and
    // `@layer` may precede them.
    if (rule is! CssAtRule) break;
    if (rule.name == 'charset' || rule.name == 'layer') continue;
    if (rule.name != 'import') break;
    final values = cssWithoutWhitespace(rule.prelude);
    if (values.isEmpty) continue;
    final first = values.first;
    final url = switch (first) {
      CssTokenValue(:final token)
          when token.type == CssTokenType.string ||
              token.type == CssTokenType.url =>
        token.value,
      CssFunctionValue(name: 'url' || 'URL' || 'Url', :final arguments) =>
        switch (cssWithoutWhitespace(arguments)) {
          [CssTokenValue(:final token)]
              when token.type == CssTokenType.string =>
            token.value,
          _ => null,
        },
      _ => null,
    };
    if (url == null) continue;
    final media = [
      for (final v in values.skip(1))
        if (v is CssTokenValue && v.token.type == CssTokenType.ident)
          v.token.value.toLowerCase(),
    ];
    if (media.contains('print') &&
        !media.contains('not') &&
        !media.contains('screen') &&
        !media.contains('all')) {
      continue;
    }
    out.add(url);
  }
  return out;
}

/// `@font-face` rules: the family, its sources as written, weight and
/// style, for the font loader.
class CssFontFace {
  const CssFontFace({
    required this.family,
    required this.sources,
    this.weight,
    this.style,
  });

  final String family;

  /// `url(...)` sources in order; `local()` ones are left out.
  final List<String> sources;
  final String? weight;
  final String? style;

  @override
  String toString() => '@font-face $family ${sources.join(', ')}';
}

List<CssFontFace> cssFontFacesOf(CssStyleSheet sheet) {
  final out = <CssFontFace>[];
  void visit(List<CssRule> rules) {
    for (final rule in rules) {
      if (rule is! CssAtRule) continue;
      if (rule.name == 'media' && rule.rules != null) {
        visit(rule.rules!);
        continue;
      }
      if (rule.name != 'font-face' || rule.declarations == null) continue;
      String? family;
      String? weight;
      String? style;
      final sources = <String>[];
      for (final d in rule.declarations!) {
        final values = cssWithoutWhitespace(d.value);
        switch (d.name) {
          case 'font-family':
            family = cssParseFontFamilies(values)?.firstOrNull;
          case 'font-weight':
            weight = values.join(' ');
          case 'font-style':
            style = cssIdentOf(values);
          case 'src':
            for (final source in cssSplitOnCommas(values)) {
              for (final v in source) {
                if (v is CssTokenValue && v.token.type == CssTokenType.url) {
                  sources.add(v.token.value);
                } else if (v is CssFunctionValue &&
                    v.name.toLowerCase() == 'url') {
                  final inner = cssWithoutWhitespace(v.arguments);
                  if (inner case [CssTokenValue(:final token)]) {
                    sources.add(token.value);
                  }
                }
              }
            }
        }
      }
      if (family != null) {
        out.add(
          CssFontFace(
            family: family,
            sources: sources,
            weight: weight,
            style: style,
          ),
        );
      }
    }
  }

  visit(sheet.rules);
  return out;
}

bool _isScreenMedia(String? media) {
  if (media == null || media.trim().isEmpty) return true;
  final words = media.toLowerCase().split(RegExp(r'[\s,()]+'));
  if (!words.contains('print')) return true;
  return words.contains('not') ||
      words.contains('screen') ||
      words.contains('all');
}
