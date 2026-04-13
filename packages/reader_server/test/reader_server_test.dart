import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:monitoring/monitoring.dart';
import 'package:reader_server/reader_server.dart';

void main() {
  late Directory tempDir;
  late Directory articlesDir;
  late Directory assetsDir;
  late ReaderServer server;
  late http.Client client;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('reader_server_test_');
    articlesDir = Directory('${tempDir.path}/articles');
    assetsDir = Directory('${tempDir.path}/assets');
    await articlesDir.create();
    await assetsDir.create();

    server = ReaderServer(
      articlesDirectory: articlesDir,
      assetsDirectory: assetsDir,
      logger: Logger(),
    );
    await server.start();
    client = http.Client();
  });

  tearDown(() async {
    client.close();
    await server.stop();
    await tempDir.delete(recursive: true);
  });

  String url(String path) => 'http://127.0.0.1:${server.port}$path';

  group('lifecycle', () {
    test('port is available after start', () {
      expect(server.port, isPositive);
    });

    test('isRunning is true after start', () {
      expect(server.isRunning, isTrue);
    });

    test('isRunning is false after stop', () async {
      await server.stop();
      expect(server.isRunning, isFalse);
    });

    test('port throws before start', () {
      final unstarted = ReaderServer(
        articlesDirectory: articlesDir,
        assetsDirectory: assetsDir,
        logger: Logger(),
      );
      expect(() => unstarted.port, throwsStateError);
    });

    test('start is idempotent', () async {
      final portBefore = server.port;
      await server.start();
      expect(server.port, portBefore);
    });

    test('stop is idempotent', () async {
      await server.stop();
      await server.stop();
      expect(server.isRunning, isFalse);
    });
  });

  group('GET /article/<id>', () {
    test('returns article HTML from per-article directory', () async {
      final articleDir = Directory('${articlesDir.path}/abc123');
      await articleDir.create();
      await File('${articleDir.path}/content.html').writeAsString(
        '<p>Hello world</p>',
      );

      final response = await client.get(Uri.parse(url('/article/abc123')));

      expect(response.statusCode, 200);
      expect(response.body, '<p>Hello world</p>');
      expect(response.headers['content-type'], contains('text/html'));
    });

    test('returns 404 for missing article', () async {
      final response = await client.get(
        Uri.parse(url('/article/nonexistent')),
      );
      expect(response.statusCode, 404);
    });

    test('rejects path traversal with ..', () async {
      final response = await client.get(
        Uri.parse(url('/article/..%2F..%2Fetc%2Fpasswd')),
      );
      expect(response.statusCode, 400);
    });

    test('returns 400 when id is missing', () async {
      final response = await client.get(Uri.parse(url('/article')));
      expect(response.statusCode, 400);
    });

    test('serves article body image', () async {
      final imgDir = Directory('${articlesDir.path}/art-1/images');
      await imgDir.create(recursive: true);
      await File('${imgDir.path}/abc123.jpg').writeAsBytes(
        [0xFF, 0xD8, 0xFF, 0xE0],
      );

      final response = await client.get(
        Uri.parse(url('/article/art-1/images/abc123.jpg')),
      );

      expect(response.statusCode, 200);
      expect(response.bodyBytes, [0xFF, 0xD8, 0xFF, 0xE0]);
      expect(response.headers['content-type'], contains('image/jpeg'));
    });

    test('returns 404 for missing article image', () async {
      final response = await client.get(
        Uri.parse(url('/article/art-1/images/nonexistent.jpg')),
      );
      expect(response.statusCode, 404);
    });

    test('rejects path traversal in image filename', () async {
      final response = await client.get(
        Uri.parse(url('/article/art-1/images/..%2F..%2Fsecret')),
      );
      expect(response.statusCode, 400);
    });
  });

  group('GET /book/<path>', () {
    test('streams book file', () async {
      final bookFile = File('${tempDir.path}/test.epub');
      await bookFile.writeAsBytes([0x50, 0x4B, 0x03, 0x04]); // PK zip header

      final encodedPath = Uri.encodeComponent(bookFile.path);
      final response = await client.get(
        Uri.parse(url('/book/$encodedPath')),
      );

      expect(response.statusCode, 200);
      expect(response.bodyBytes, [0x50, 0x4B, 0x03, 0x04]);
      expect(
        response.headers['content-type'],
        contains('application/epub+zip'),
      );
    });

    test('returns correct content-type for pdf', () async {
      final pdfFile = File('${tempDir.path}/test.pdf');
      await pdfFile.writeAsBytes([0x25, 0x50, 0x44, 0x46]); // %PDF header

      final encodedPath = Uri.encodeComponent(pdfFile.path);
      final response = await client.get(
        Uri.parse(url('/book/$encodedPath')),
      );

      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('application/pdf'));
    });

    test('returns 404 for missing book', () async {
      final encodedPath = Uri.encodeComponent('/nonexistent/book.epub');
      final response = await client.get(
        Uri.parse(url('/book/$encodedPath')),
      );
      expect(response.statusCode, 404);
    });

    test('returns 400 when path is missing', () async {
      final response = await client.get(Uri.parse(url('/book')));
      expect(response.statusCode, 400);
    });
  });

  group('GET /assets/<path>', () {
    test('serves JS file with correct content-type', () async {
      final jsDir = Directory('${assetsDir.path}/foliate-js/src');
      await jsDir.create(recursive: true);
      await File('${jsDir.path}/book.js').writeAsString('const x = 1;');

      final response = await client.get(
        Uri.parse(url('/assets/foliate-js/src/book.js')),
      );

      expect(response.statusCode, 200);
      expect(response.body, 'const x = 1;');
      expect(
        response.headers['content-type'],
        contains('application/javascript'),
      );
    });

    test('serves HTML file', () async {
      await File('${assetsDir.path}/index.html').writeAsString(
        '<!DOCTYPE html><html></html>',
      );

      final response = await client.get(
        Uri.parse(url('/assets/index.html')),
      );

      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('text/html'));
    });

    test('serves CSS file', () async {
      await File('${assetsDir.path}/style.css').writeAsString(
        'body { margin: 0; }',
      );

      final response = await client.get(
        Uri.parse(url('/assets/style.css')),
      );

      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('text/css'));
    });

    test('returns 404 for missing asset', () async {
      final response = await client.get(
        Uri.parse(url('/assets/nonexistent.js')),
      );
      expect(response.statusCode, 404);
    });

    test('rejects path traversal with ..', () async {
      final response = await client.get(
        Uri.parse(url('/assets/..%2F..%2Fetc%2Fpasswd')),
      );
      expect(response.statusCode, 400);
    });

    test('returns 400 when path is missing', () async {
      final response = await client.get(Uri.parse(url('/assets')));
      expect(response.statusCode, 400);
    });

    test('serves nested subdirectory files', () async {
      final nested = Directory('${assetsDir.path}/a/b/c');
      await nested.create(recursive: true);
      await File('${nested.path}/deep.json').writeAsString('{"ok":true}');

      final response = await client.get(
        Uri.parse(url('/assets/a/b/c/deep.json')),
      );

      expect(response.statusCode, 200);
      expect(response.body, '{"ok":true}');
      expect(response.headers['content-type'], contains('application/json'));
    });
  });

  group('general', () {
    test('returns 404 for unknown route', () async {
      final response = await client.get(Uri.parse(url('/unknown')));
      expect(response.statusCode, 404);
    });

    test('returns 404 for root path', () async {
      final response = await client.get(Uri.parse(url('/')));
      expect(response.statusCode, 404);
    });

    test('returns 405 for POST requests', () async {
      final response = await client.post(Uri.parse(url('/article/abc')));
      expect(response.statusCode, 405);
    });
  });

  group('_mimeForExtension', () {
    test('serves font files with correct content-type', () async {
      await File('${assetsDir.path}/font.woff2').writeAsBytes([0x00]);

      final response = await client.get(
        Uri.parse(url('/assets/font.woff2')),
      );

      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('font/woff2'));
    });

    test('serves image files with correct content-type', () async {
      await File('${assetsDir.path}/cover.png').writeAsBytes([0x89, 0x50]);

      final response = await client.get(
        Uri.parse(url('/assets/cover.png')),
      );

      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('image/png'));
    });

    test('unknown extension returns binary content-type', () async {
      await File('${assetsDir.path}/data.xyz').writeAsBytes([0x00]);

      final response = await client.get(
        Uri.parse(url('/assets/data.xyz')),
      );

      expect(response.statusCode, 200);
      expect(
        response.headers['content-type'],
        contains('application/octet-stream'),
      );
    });
  });
}
