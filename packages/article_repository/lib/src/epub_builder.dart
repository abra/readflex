import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// Wraps a single in-memory image entry that goes into the EPUB.
class EpubImage {
  const EpubImage({
    required this.filename,
    required this.bytes,
    required this.mimeType,
  });

  /// Filename **inside** `OEBPS/images/`. Must match the `src` attribute used
  /// in [EpubBuilder.htmlBody] (which uses relative paths like
  /// `images/abc.jpg`).
  final String filename;

  final Uint8List bytes;

  /// MIME type of the image, e.g. `image/jpeg`. Used both for the OPF
  /// manifest and for choosing the right zip media-type entry.
  final String mimeType;
}

/// Assembles a minimal EPUB 3.0 file from sanitised article HTML.
///
/// The output is a single-chapter zip with the layout the spec requires:
/// ```
/// mimetype                          ← stored uncompressed; first entry
/// META-INF/container.xml            ← points at the OPF
/// OEBPS/content.opf                 ← package metadata + manifest + spine
/// OEBPS/toc.xhtml                   ← EPUB3 navigation document
/// OEBPS/chapter1.xhtml              ← the article body, wrapped in XHTML
/// OEBPS/styles.css                  ← minimal stylesheet
/// OEBPS/images/<file>               ← inlined article images
/// ```
///
/// Why we build EPUBs from articles: foliate-js renders books from EPUB/MOBI/
/// FB2 — it doesn't have a "plain HTML" path. Converting articles to EPUB on
/// import lets the reader use the same paginated foliate-js view for both
/// books and articles, without a parallel custom-HTML reader.
///
/// The class is pure logic — no network or readability work happens here.
/// Callers (e.g. `ArticleRepository.addArticle`) prepare the sanitised HTML
/// and the image set, then ask the builder to write the file to disk.
class EpubBuilder {
  const EpubBuilder();

  /// Builds an EPUB file at [outputFile]. Returns the same `File` for
  /// convenience. Overwrites any existing file at the path.
  Future<File> build({
    required String id,
    required String title,
    required String htmlBody,
    required File outputFile,
    String? author,
    String? lang,
    List<EpubImage> images = const [],
  }) async {
    final archive = Archive()
      ..addFile(_rawFile('mimetype', 'application/epub+zip'))
      ..addFile(_textFile('META-INF/container.xml', _containerXml))
      ..addFile(_textFile('OEBPS/styles.css', _defaultStylesheet))
      ..addFile(
        _textFile(
          'OEBPS/content.opf',
          _buildContentOpf(
            id: id,
            title: title,
            author: author,
            lang: lang ?? 'en',
            images: images,
          ),
        ),
      )
      ..addFile(
        _textFile(
          'OEBPS/toc.xhtml',
          _buildTocXhtml(title: title),
        ),
      )
      ..addFile(
        _textFile(
          'OEBPS/chapter1.xhtml',
          _buildChapterXhtml(
            title: title,
            lang: lang ?? 'en',
            htmlBody: htmlBody,
          ),
        ),
      );

    for (final image in images) {
      archive.addFile(
        ArchiveFile(
          'OEBPS/images/${image.filename}',
          image.bytes.length,
          image.bytes,
        ),
      );
    }

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw StateError('EpubBuilder: ZipEncoder returned null');
    }
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsBytes(encoded, flush: true);
    return outputFile;
  }

  // ── helpers ─────────────────────────────────────────────────────────────

  /// `mimetype` must be the very first zip entry **and** stored without
  /// compression — it's how readers identify the file as EPUB without
  /// opening the zip central directory. `archive`'s default deflate is
  /// suppressed via [ArchiveFile.compress] = false.
  ArchiveFile _rawFile(String name, String content) {
    final bytes = utf8.encode(content);
    return ArchiveFile(name, bytes.length, bytes)..compress = false;
  }

  ArchiveFile _textFile(String name, String content) {
    final bytes = utf8.encode(content);
    return ArchiveFile(name, bytes.length, bytes);
  }

  static const _containerXml =
      '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<container version="1.0" '
      'xmlns="urn:oasis:names:tc:opendocument:xmlns:container">\n'
      '  <rootfiles>\n'
      '    <rootfile full-path="OEBPS/content.opf" '
      'media-type="application/oebps-package+xml"/>\n'
      '  </rootfiles>\n'
      '</container>\n';

  // foliate-js' paginator owns page-level layout (margins, columns, page
  // breaks). Adding a `body { margin: 1em }` here gets counted twice by
  // the paginator and frequently produces a trailing empty page when the
  // article happens to end near a column boundary. We keep stylesheet
  // rules strictly to inline content (typography, image fit, code
  // wrapping) and let the paginator handle page geometry.
  static const _defaultStylesheet =
      'body { font-family: serif; line-height: 1.5; margin: 0; padding: 0; }\n'
      // Zero out the first/last child margin to prevent foliate-js from
      // overflowing into a leading/trailing empty column. Default browser
      // margin on `<h1>` (chapter title we inject) and on the trailing
      // block (often a wrapped <table> with margin: 1em 0) otherwise spills
      // past the column boundary and the paginator allocates a blank page
      // for that overflow.
      'body > *:first-child { margin-top: 0 !important; '
      'padding-top: 0 !important; }\n'
      'body > *:last-child { margin-bottom: 0 !important; '
      'padding-bottom: 0 !important; }\n'
      // Defeat any `break-before: page|recto|always` a publisher might have
      // shipped for headings — articles are single-chapter so any forced
      // page break before the title creates a phantom leading page.
      'h1, h2, h3, h4, h5, h6 { break-before: auto !important; '
      'page-break-before: auto !important; }\n'
      'img { max-width: 100%; height: auto; }\n'
      'figure { margin: 1em 0; }\n'
      'figure img { display: block; margin: 0 auto; }\n'
      'pre, code { font-family: ui-monospace, monospace; }\n'
      'pre { white-space: pre-wrap; word-wrap: break-word; }\n'
      'blockquote { border-left: 3px solid #ccc; padding-left: 1em; '
      'margin-left: 0; font-style: italic; }\n'
      // Tables: foliate-js paginates inside CSS columns, and a publisher
      // stylesheet that flips `<table>` to `display: block` (or strips its
      // styling entirely) collapses every cell into the surrounding prose.
      // Pin the table to its native layout, give cells visible borders and
      // padding so rows are distinguishable, and let long cell content
      // wrap inside the column instead of overflowing it.
      // `!important` is intentional: foliate-js' book.js wraps the chapter
      // in its own !important-heavy stylesheet (paragraph spacing, line
      // height, font-size on `html`). Without it, those rules can override
      // ours via cascade order even though our selectors are more specific.
      //
      // Wide tables: `<table>` is wrapped in a `.rf-table-scroll` div by
      // [ArticleRepository] before EPUB packaging. The wrapper gives the
      // user a horizontal scroll affordance inside the page when the table
      // is wider than the foliate-js column. Without it, wide tables get
      // clipped at the column edge with no recovery.
      '.rf-table-scroll { overflow-x: auto !important; max-width: 100%; '
      'margin: 1em 0; -webkit-overflow-scrolling: touch; }\n'
      '.rf-table-scroll > table { margin: 0 !important; '
      'min-width: max-content; }\n'
      'table { display: table !important; border-collapse: collapse; '
      'width: 100%; margin: 1em 0; font-size: 0.65em !important; '
      'line-height: 1.3 !important; table-layout: auto; }\n'
      'thead { display: table-header-group; }\n'
      'tbody { display: table-row-group; }\n'
      'tfoot { display: table-footer-group; }\n'
      'tr { display: table-row; }\n'
      'th, td { display: table-cell; border: 1px solid #ccc; '
      'padding: 0.3em 0.45em !important; text-align: left; '
      'vertical-align: top; word-wrap: break-word; '
      'overflow-wrap: break-word; font-size: inherit !important; '
      'line-height: 1.3 !important; white-space: normal; }\n'
      'th { background-color: rgba(0, 0, 0, 0.04); font-weight: bold; }\n'
      'caption { caption-side: top; font-style: italic; '
      'font-size: 0.85em !important; margin-bottom: 0.4em; }\n';

  String _buildContentOpf({
    required String id,
    required String title,
    required String? author,
    required String lang,
    required List<EpubImage> images,
  }) {
    final modified = DateTime.now().toUtc().toIso8601String().split('.').first;
    final imageManifest = StringBuffer();
    for (var i = 0; i < images.length; i++) {
      final image = images[i];
      final imageId = 'img${i + 1}';
      imageManifest.writeln(
        '    <item id="$imageId" '
        'href="images/${_xmlAttr(image.filename)}" '
        'media-type="${_xmlAttr(image.mimeType)}"/>',
      );
    }

    final authorEntry = author != null && author.isNotEmpty
        ? '    <dc:creator>${_xmlText(author)}</dc:creator>\n'
        : '';

    return '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<package xmlns="http://www.idpf.org/2007/opf" '
        'version="3.0" unique-identifier="bookid">\n'
        '  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">\n'
        '    <dc:identifier id="bookid">urn:uuid:$id</dc:identifier>\n'
        '    <dc:title>${_xmlText(title)}</dc:title>\n'
        '    <dc:language>${_xmlAttr(lang)}</dc:language>\n'
        '$authorEntry'
        '    <meta property="dcterms:modified">${modified}Z</meta>\n'
        '  </metadata>\n'
        '  <manifest>\n'
        '    <item id="nav" href="toc.xhtml" '
        'media-type="application/xhtml+xml" properties="nav"/>\n'
        '    <item id="chapter1" href="chapter1.xhtml" '
        'media-type="application/xhtml+xml"/>\n'
        '    <item id="styles" href="styles.css" media-type="text/css"/>\n'
        '${imageManifest.toString()}'
        '  </manifest>\n'
        '  <spine>\n'
        '    <itemref idref="chapter1"/>\n'
        '  </spine>\n'
        '</package>\n';
  }

  String _buildTocXhtml({required String title}) {
    return '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<!DOCTYPE html>\n'
        '<html xmlns="http://www.w3.org/1999/xhtml" '
        'xmlns:epub="http://www.idpf.org/2007/ops">\n'
        '<head><title>Table of Contents</title></head>\n'
        '<body>\n'
        '<nav epub:type="toc">\n'
        '  <h1>Table of Contents</h1>\n'
        '  <ol>\n'
        '    <li><a href="chapter1.xhtml">${_xmlText(title)}</a></li>\n'
        '  </ol>\n'
        '</nav>\n'
        '</body>\n'
        '</html>\n';
  }

  String _buildChapterXhtml({
    required String title,
    required String lang,
    required String htmlBody,
  }) {
    return '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<!DOCTYPE html>\n'
        '<html xmlns="http://www.w3.org/1999/xhtml" '
        'xml:lang="${_xmlAttr(lang)}" lang="${_xmlAttr(lang)}">\n'
        '<head>\n'
        '  <meta charset="utf-8"/>\n'
        '  <title>${_xmlText(title)}</title>\n'
        '  <link rel="stylesheet" type="text/css" href="styles.css"/>\n'
        '</head>\n'
        '<body>\n'
        '<h1>${_xmlText(title)}</h1>\n'
        '$htmlBody\n'
        '</body>\n'
        '</html>\n';
  }

  /// Escapes XML special chars in element text content. `<` `>` `&` are the
  /// minimal set required to keep the surrounding XML valid. Quotes are
  /// safe in text nodes so we leave them alone.
  static String _xmlText(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  /// Same as [_xmlText] plus quote escaping — for use inside attribute
  /// values where `"` would terminate the string.
  static String _xmlAttr(String value) =>
      _xmlText(value).replaceAll('"', '&quot;').replaceAll("'", '&apos;');

  /// Convenience: pick the right MIME type from a filename. Returns
  /// `application/octet-stream` when the extension isn't recognised.
  static String mimeTypeFor(String filename) {
    final ext = p.extension(filename).toLowerCase();
    return switch (ext) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      '.svg' => 'image/svg+xml',
      _ => 'application/octet-stream',
    };
  }
}
