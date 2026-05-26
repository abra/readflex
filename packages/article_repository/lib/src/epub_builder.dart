import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:domain_models/domain_models.dart';
import 'package:path/path.dart' as p;

class EpubImage {
  const EpubImage({
    required this.filename,
    required this.bytes,
    required this.mimeType,
  });

  final String filename;
  final Uint8List bytes;
  final String mimeType;
}

/// Builds a minimal single-chapter EPUB for cleaned web articles.
class EpubBuilder {
  const EpubBuilder();

  Future<File> build({
    required String id,
    required String title,
    required String htmlBody,
    required File outputFile,
    String? author,
    String? lang,
    ArticleTextDirection? textDirection,
    List<EpubImage> images = const [],
  }) async {
    final resolvedLang = normalizeArticleLanguage(lang) ?? 'en';
    final resolvedDirection =
        textDirection ?? articleTextDirectionForLanguage(resolvedLang);
    final archive = Archive()
      ..addFile(_rawFile('mimetype', 'application/epub+zip'))
      ..addFile(_textFile('META-INF/container.xml', _containerXml))
      ..addFile(_textFile('OEBPS/styles.css', _stylesheet))
      ..addFile(
        _textFile(
          'OEBPS/content.opf',
          _contentOpf(
            id: id,
            title: title,
            author: author,
            lang: resolvedLang,
            images: images,
          ),
        ),
      )
      ..addFile(_textFile('OEBPS/toc.xhtml', _toc(title, resolvedDirection)))
      ..addFile(
        _textFile(
          'OEBPS/chapter1.xhtml',
          _chapter(
            title: title,
            lang: resolvedLang,
            textDirection: resolvedDirection,
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
    if (encoded == null) throw StateError('Failed to encode EPUB');
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsBytes(encoded, flush: true);
    return outputFile;
  }

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

  static const _stylesheet =
      'html { text-rendering: optimizeLegibility !important; }\n'
      'body, p, li, td, th, code, pre, kbd, samp { '
      'word-break: break-word !important; overflow-wrap: anywhere !important; }\n'
      'body { font-family: serif; line-height: 1.5; margin: 0; padding: 0; }\n'
      'body > *:first-child { margin-top: 0 !important; padding-top: 0 !important; }\n'
      'body > *:last-child { margin-bottom: 0 !important; padding-bottom: 0 !important; }\n'
      'img { max-width: 100%; height: auto; }\n'
      'figure { margin: 1em 0; }\n'
      'figure img { display: block; margin: 0 auto; }\n'
      'pre, code, kbd, samp { font-family: ui-monospace, monospace; }\n'
      'pre { white-space: pre-wrap; word-wrap: break-word; }\n'
      'blockquote { border-left: 3px solid #ccc; padding-left: 1em; '
      'margin-left: 0; font-style: italic; }\n'
      '.rf-table-scroll { display: block; max-width: 100%; overflow: auto !important; '
      'break-inside: avoid !important; -webkit-overflow-scrolling: touch; margin: 1em 0; }\n'
      'table { display: table !important; border-collapse: collapse; width: 100%; '
      'font-size: 0.8em !important; line-height: 1.3 !important; }\n'
      'th, td { display: table-cell; border: 1px solid #ccc; padding: 0.3em 0.45em !important; '
      'vertical-align: top; white-space: normal; }\n'
      'th { background-color: rgba(0, 0, 0, 0.04); font-weight: bold; }\n';

  String _contentOpf({
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
      imageManifest.writeln(
        '    <item id="img${i + 1}" href="images/${_xmlAttr(image.filename)}" '
        'media-type="${_xmlAttr(image.mimeType)}"/>',
      );
    }
    final creator = author != null && author.isNotEmpty
        ? '    <dc:creator>${_xmlText(author)}</dc:creator>\n'
        : '';

    return '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<package xmlns="http://www.idpf.org/2007/opf" '
        'version="3.0" unique-identifier="bookid">\n'
        '  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">\n'
        '    <dc:identifier id="bookid">urn:uuid:${_xmlText(id)}</dc:identifier>\n'
        '    <dc:title>${_xmlText(title)}</dc:title>\n'
        '    <dc:language>${_xmlAttr(lang)}</dc:language>\n'
        '$creator'
        '    <meta property="dcterms:modified">${modified}Z</meta>\n'
        '  </metadata>\n'
        '  <manifest>\n'
        '    <item id="nav" href="toc.xhtml" media-type="application/xhtml+xml" properties="nav"/>\n'
        '    <item id="chapter1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>\n'
        '    <item id="styles" href="styles.css" media-type="text/css"/>\n'
        '$imageManifest'
        '  </manifest>\n'
        '  <spine>\n'
        '    <itemref idref="chapter1"/>\n'
        '  </spine>\n'
        '</package>\n';
  }

  String _toc(String title, ArticleTextDirection? textDirection) {
    final dirAttr = _dirAttr(textDirection);
    return '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<!DOCTYPE html>\n'
        '<html xmlns="http://www.w3.org/1999/xhtml" '
        'xmlns:epub="http://www.idpf.org/2007/ops">\n'
        '<head><title>Table of Contents</title></head>\n'
        '<body$dirAttr><nav epub:type="toc"><ol>'
        '<li><a href="chapter1.xhtml">${_xmlText(title)}</a></li>'
        '</ol></nav></body></html>\n';
  }

  String _chapter({
    required String title,
    required String lang,
    required ArticleTextDirection? textDirection,
    required String htmlBody,
  }) {
    final dirAttr = _dirAttr(textDirection);
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
        '<main class="readflex-article-content"$dirAttr>\n'
        '<h1>${_xmlText(title)}</h1>\n'
        '$htmlBody\n'
        '</main>\n'
        '</body>\n'
        '</html>\n';
  }

  static String _dirAttr(ArticleTextDirection? direction) =>
      direction == null ? '' : ' dir="${_xmlAttr(direction.value)}"';

  static String _xmlText(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  static String _xmlAttr(String value) =>
      _xmlText(value).replaceAll('"', '&quot;').replaceAll("'", '&apos;');

  static String mimeTypeFor(String filename) {
    return switch (p.extension(filename).toLowerCase()) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      '.svg' => 'image/svg+xml',
      _ => 'application/octet-stream',
    };
  }
}
