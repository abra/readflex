import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:article_repository/article_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('epub_builder_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Decodes the EPUB at [file] and returns its archive entries by path
  /// for assertion-friendly access.
  Map<String, ArchiveFile> readEpub(File file) {
    final bytes = file.readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    return {for (final f in archive) f.name: f};
  }

  group('EpubBuilder.build', () {
    test('emits a valid zip with all required EPUB entries', () async {
      const builder = EpubBuilder();
      final output = File('${tempDir.path}/article.epub');

      await builder.build(
        id: '00000000-0000-0000-0000-000000000001',
        title: 'Hello',
        author: 'Jane',
        lang: 'en',
        htmlBody: '<p>Body</p>',
        outputFile: output,
      );

      expect(output.existsSync(), isTrue);
      final entries = readEpub(output);

      // Files the EPUB spec requires.
      expect(entries.containsKey('mimetype'), isTrue);
      expect(entries.containsKey('META-INF/container.xml'), isTrue);
      expect(entries.containsKey('OEBPS/content.opf'), isTrue);
      expect(entries.containsKey('OEBPS/toc.xhtml'), isTrue);
      expect(entries.containsKey('OEBPS/chapter1.xhtml'), isTrue);
      expect(entries.containsKey('OEBPS/styles.css'), isTrue);
    });

    test('mimetype entry contains the spec-mandated string', () async {
      const builder = EpubBuilder();
      final output = File('${tempDir.path}/article.epub');

      await builder.build(
        id: '1',
        title: 'x',
        htmlBody: '<p/>',
        outputFile: output,
      );

      final entries = readEpub(output);
      final mimetype = utf8.decode(entries['mimetype']!.content as List<int>);
      expect(mimetype, 'application/epub+zip');
    });

    test('mimetype entry is stored uncompressed', () async {
      const builder = EpubBuilder();
      final output = File('${tempDir.path}/article.epub');

      await builder.build(
        id: '1',
        title: 'x',
        htmlBody: '<p/>',
        outputFile: output,
      );

      final entries = readEpub(output);
      // Spec: mimetype must be stored without compression so the file can
      // be identified by reading bytes 30..60 from the beginning of the zip.
      expect(entries['mimetype']!.compressionType, ArchiveFile.STORE);
    });

    test('container.xml points at OEBPS/content.opf', () async {
      const builder = EpubBuilder();
      final output = File('${tempDir.path}/article.epub');

      await builder.build(
        id: '1',
        title: 'x',
        htmlBody: '<p/>',
        outputFile: output,
      );

      final container = utf8.decode(
        readEpub(output)['META-INF/container.xml']!.content as List<int>,
      );
      expect(container, contains('full-path="OEBPS/content.opf"'));
      expect(container, contains('media-type="application/oebps-package+xml"'));
    });

    test('content.opf contains metadata, manifest, and spine', () async {
      const builder = EpubBuilder();
      final output = File('${tempDir.path}/article.epub');

      await builder.build(
        id: 'abc-123',
        title: 'My Article',
        author: 'Jane Writer',
        lang: 'ru',
        htmlBody: '<p/>',
        outputFile: output,
      );

      final opf = utf8.decode(
        readEpub(output)['OEBPS/content.opf']!.content as List<int>,
      );

      expect(opf, contains('<dc:identifier id="bookid">urn:uuid:abc-123'));
      expect(opf, contains('<dc:title>My Article</dc:title>'));
      expect(opf, contains('<dc:language>ru</dc:language>'));
      expect(opf, contains('<dc:creator>Jane Writer</dc:creator>'));
      expect(opf, contains('<itemref idref="chapter1"/>'));
    });

    test('omits dc:creator when author is null or empty', () async {
      const builder = EpubBuilder();
      final output = File('${tempDir.path}/article.epub');

      await builder.build(
        id: '1',
        title: 'x',
        htmlBody: '<p/>',
        outputFile: output,
      );

      final opf = utf8.decode(
        readEpub(output)['OEBPS/content.opf']!.content as List<int>,
      );
      expect(opf, isNot(contains('<dc:creator>')));
    });

    test('escapes XML special characters in title and author', () async {
      const builder = EpubBuilder();
      final output = File('${tempDir.path}/article.epub');

      await builder.build(
        id: '1',
        title: 'A & B <C> "D"',
        author: 'Doe & Sons',
        htmlBody: '<p/>',
        outputFile: output,
      );

      final opf = utf8.decode(
        readEpub(output)['OEBPS/content.opf']!.content as List<int>,
      );
      expect(opf, contains('A &amp; B &lt;C&gt; "D"'));
      expect(opf, contains('Doe &amp; Sons'));
    });

    test('chapter wraps htmlBody inside an XHTML document', () async {
      const builder = EpubBuilder();
      final output = File('${tempDir.path}/article.epub');

      await builder.build(
        id: '1',
        title: 'A Title',
        lang: 'en',
        htmlBody: '<p>The body</p>',
        outputFile: output,
      );

      final chapter = utf8.decode(
        readEpub(output)['OEBPS/chapter1.xhtml']!.content as List<int>,
      );
      expect(chapter, contains('<?xml version="1.0"'));
      expect(chapter, contains('xmlns="http://www.w3.org/1999/xhtml"'));
      expect(chapter, contains('xml:lang="en"'));
      expect(chapter, contains('<title>A Title</title>'));
      expect(chapter, contains('<h1>A Title</h1>'));
      expect(chapter, contains('<p>The body</p>'));
      expect(chapter, contains('href="styles.css"'));
    });

    test('toc.xhtml lists the single chapter', () async {
      const builder = EpubBuilder();
      final output = File('${tempDir.path}/article.epub');

      await builder.build(
        id: '1',
        title: 'TOC Title',
        htmlBody: '<p/>',
        outputFile: output,
      );

      final toc = utf8.decode(
        readEpub(output)['OEBPS/toc.xhtml']!.content as List<int>,
      );
      expect(toc, contains('epub:type="toc"'));
      expect(toc, contains('<a href="chapter1.xhtml">TOC Title</a>'));
    });

    test('writes images and references them in the manifest', () async {
      const builder = EpubBuilder();
      final output = File('${tempDir.path}/article.epub');

      final imageBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);

      await builder.build(
        id: '1',
        title: 'x',
        htmlBody: '<img src="images/abc.png">',
        images: [
          EpubImage(
            filename: 'abc.png',
            bytes: imageBytes,
            mimeType: 'image/png',
          ),
        ],
        outputFile: output,
      );

      final entries = readEpub(output);
      expect(entries.containsKey('OEBPS/images/abc.png'), isTrue);
      expect(
        entries['OEBPS/images/abc.png']!.content,
        imageBytes,
      );

      final opf = utf8.decode(
        entries['OEBPS/content.opf']!.content as List<int>,
      );
      expect(opf, contains('href="images/abc.png"'));
      expect(opf, contains('media-type="image/png"'));
    });

    test('overwrites an existing file at the output path', () async {
      const builder = EpubBuilder();
      final output = File('${tempDir.path}/article.epub');
      output.writeAsStringSync('not an epub');

      await builder.build(
        id: '1',
        title: 'x',
        htmlBody: '<p/>',
        outputFile: output,
      );

      final entries = readEpub(output);
      expect(entries.containsKey('mimetype'), isTrue);
    });
  });

  group('EpubBuilder.mimeTypeFor', () {
    test('maps common image extensions', () {
      expect(EpubBuilder.mimeTypeFor('a.jpg'), 'image/jpeg');
      expect(EpubBuilder.mimeTypeFor('a.JPG'), 'image/jpeg');
      expect(EpubBuilder.mimeTypeFor('a.jpeg'), 'image/jpeg');
      expect(EpubBuilder.mimeTypeFor('a.png'), 'image/png');
      expect(EpubBuilder.mimeTypeFor('a.gif'), 'image/gif');
      expect(EpubBuilder.mimeTypeFor('a.webp'), 'image/webp');
      expect(EpubBuilder.mimeTypeFor('a.svg'), 'image/svg+xml');
    });

    test('falls back to octet-stream for unknown extensions', () {
      expect(EpubBuilder.mimeTypeFor('a.xyz'), 'application/octet-stream');
      expect(EpubBuilder.mimeTypeFor('noext'), 'application/octet-stream');
    });
  });
}
