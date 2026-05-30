import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:monitoring/monitoring.dart';
import 'package:reader_server/reader_server.dart';

void main() {
  late Directory tempDir;
  late Directory assetsDir;
  late ReaderServer server;
  late http.Client client;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('reader_server_test_');
    assetsDir = Directory('${tempDir.path}/assets');
    await assetsDir.create();

    server = ReaderServer(
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

    test(
      'streams book file with percent and unicode characters in path',
      () async {
        final bookFile = File(
          '${tempDir.path}/A 100% Guide To… Robots (Joosr [Joosr]).epub',
        );
        await bookFile.writeAsBytes([0x50, 0x4B, 0x03, 0x04]);

        final encodedPath = Uri.encodeComponent(bookFile.path);
        final response = await client.head(
          Uri.parse(url('/book/$encodedPath')),
        );

        expect(response.statusCode, 200);
        expect(
          response.headers['content-type'],
          contains('application/epub+zip'),
        );
        expect(response.headers['content-length'], '4');
      },
    );

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

    // Asset responses should carry a long Cache-Control so the
    // WebView caches static foliate-js sources and fonts across
    // section iframes — without it each new chapter re-fetches the
    // variable font and the text reflows from fallback to target
    // ("выпрямление текста" effect).
    test('non-font asset responses carry a 1-day Cache-Control', () async {
      await File('${assetsDir.path}/style.css').writeAsString('p {}');
      final response = await client.get(
        Uri.parse(url('/assets/style.css')),
      );
      expect(response.statusCode, 200);
      expect(
        response.headers['cache-control'],
        contains('max-age=86400'),
      );
    });

    // Fonts get a year + immutable: their bytes never change once
    // shipped, so the WebView can keep them across chapters and
    // sessions without re-validating.
    test(
      'font asset responses carry a 1-year immutable Cache-Control',
      () async {
        Directory('${assetsDir.path}/fonts').createSync(recursive: true);
        await File(
          '${assetsDir.path}/fonts/Literata-Variable.ttf',
        ).writeAsBytes([0, 1, 2]);
        final response = await client.get(
          Uri.parse(url('/assets/fonts/Literata-Variable.ttf')),
        );
        expect(response.statusCode, 200);
        final cacheControl = response.headers['cache-control']!;
        expect(cacheControl, contains('max-age=31536000'));
        expect(cacheControl, contains('immutable'));
      },
    );

    test('book responses do NOT carry Cache-Control', () async {
      final bookFile = File('${tempDir.path}/test.epub');
      await bookFile.writeAsBytes([1, 2, 3]);
      final response = await client.get(
        Uri.parse(
          url('/book/${Uri.encodeComponent(bookFile.path)}'),
        ),
      );
      expect(response.statusCode, 200);
      expect(response.headers.containsKey('cache-control'), isFalse);
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

    test('rejects absolute path via url-encoded leading slash', () async {
      // Create a sibling file outside assetsDir. An absolute path in the
      // second arg of p.join overrides the first on Unix, so without an
      // explicit guard the server would read files anywhere on disk.
      final secret = File('${tempDir.path}/secret.txt');
      await secret.writeAsString('TOP SECRET');

      final response = await client.get(
        Uri.parse(url('/assets/${Uri.encodeComponent(secret.path)}')),
      );

      expect(response.statusCode, isNot(200));
      expect(response.body, isNot('TOP SECRET'));
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
      final response = await client.post(Uri.parse(url('/book/whatever')));
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

  /// Range-request behaviour. Foliate-js opens books through a `RemoteFile`
  /// that fans out into many small `Range:` reads; the server has to honour
  /// them, send `206 Partial Content`, advertise `Accept-Ranges: bytes` on
  /// every full response, and bail out cleanly on bogus ranges.
  group('Range requests', () {
    /// 256 deterministic bytes (0..255). Lets every assertion below check
    /// content as well as length, since the byte at any offset N is N.
    Uint8List payload() {
      return Uint8List.fromList(List.generate(256, (i) => i));
    }

    test('full GET advertises Accept-Ranges and Content-Length', () async {
      final file = File('${tempDir.path}/full.epub');
      await file.writeAsBytes(payload());

      final response = await client.get(
        Uri.parse(url('/book/${Uri.encodeComponent(file.path)}')),
      );

      expect(response.statusCode, 200);
      expect(response.headers['accept-ranges'], 'bytes');
      expect(response.headers['content-length'], '256');
      expect(response.bodyBytes.length, 256);
    });

    test('returns 206 + slice for `bytes=0-9`', () async {
      final file = File('${tempDir.path}/range.epub');
      await file.writeAsBytes(payload());

      final response = await client.get(
        Uri.parse(url('/book/${Uri.encodeComponent(file.path)}')),
        headers: {'Range': 'bytes=0-9'},
      );

      expect(response.statusCode, 206);
      expect(response.headers['content-range'], 'bytes 0-9/256');
      expect(response.headers['content-length'], '10');
      expect(response.bodyBytes, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
    });

    test('clamps `bytes=200-9999` to file length', () async {
      final file = File('${tempDir.path}/clamp.epub');
      await file.writeAsBytes(payload());

      final response = await client.get(
        Uri.parse(url('/book/${Uri.encodeComponent(file.path)}')),
        headers: {'Range': 'bytes=200-9999'},
      );

      expect(response.statusCode, 206);
      expect(response.headers['content-range'], 'bytes 200-255/256');
      expect(response.headers['content-length'], '56');
      expect(response.bodyBytes.first, 200);
      expect(response.bodyBytes.last, 255);
    });

    test('open-ended `bytes=250-` returns the tail of the file', () async {
      final file = File('${tempDir.path}/openend.epub');
      await file.writeAsBytes(payload());

      final response = await client.get(
        Uri.parse(url('/book/${Uri.encodeComponent(file.path)}')),
        headers: {'Range': 'bytes=250-'},
      );

      expect(response.statusCode, 206);
      expect(response.headers['content-range'], 'bytes 250-255/256');
      expect(response.bodyBytes, [250, 251, 252, 253, 254, 255]);
    });

    test('suffix `bytes=-5` returns the last 5 bytes', () async {
      final file = File('${tempDir.path}/suffix.epub');
      await file.writeAsBytes(payload());

      final response = await client.get(
        Uri.parse(url('/book/${Uri.encodeComponent(file.path)}')),
        headers: {'Range': 'bytes=-5'},
      );

      expect(response.statusCode, 206);
      expect(response.headers['content-range'], 'bytes 251-255/256');
      expect(response.bodyBytes, [251, 252, 253, 254, 255]);
    });

    test('rejects start past EOF with 416', () async {
      final file = File('${tempDir.path}/past.epub');
      await file.writeAsBytes(payload());

      final response = await client.get(
        Uri.parse(url('/book/${Uri.encodeComponent(file.path)}')),
        headers: {'Range': 'bytes=999-1099'},
      );

      expect(response.statusCode, 416);
      expect(response.headers['content-range'], 'bytes */256');
    });

    test('rejects unparseable range with 416', () async {
      final file = File('${tempDir.path}/garbage.epub');
      await file.writeAsBytes(payload());

      final response = await client.get(
        Uri.parse(url('/book/${Uri.encodeComponent(file.path)}')),
        headers: {'Range': 'pages=0-9'},
      );

      expect(response.statusCode, 416);
    });

    test('inverted `bytes=10-5` is rejected with 416', () async {
      final file = File('${tempDir.path}/inverted.epub');
      await file.writeAsBytes(payload());

      final response = await client.get(
        Uri.parse(url('/book/${Uri.encodeComponent(file.path)}')),
        headers: {'Range': 'bytes=10-5'},
      );

      expect(response.statusCode, 416);
    });

    test('Range applies to /assets/ files too', () async {
      await Directory(
        '${assetsDir.path}/foliate-js/src',
      ).create(recursive: true);
      await File(
        '${assetsDir.path}/foliate-js/src/data.bin',
      ).writeAsBytes(payload());

      final response = await client.get(
        Uri.parse(url('/assets/foliate-js/src/data.bin')),
        headers: {'Range': 'bytes=4-7'},
      );

      expect(response.statusCode, 206);
      expect(response.bodyBytes, [4, 5, 6, 7]);
    });

    test('HEAD returns size and content-type without body', () async {
      final file = File('${tempDir.path}/head.epub');
      await file.writeAsBytes(payload());

      final response = await client.head(
        Uri.parse(url('/book/${Uri.encodeComponent(file.path)}')),
      );

      expect(response.statusCode, 200);
      expect(response.headers['content-length'], '256');
      expect(response.headers['accept-ranges'], 'bytes');
      expect(
        response.headers['content-type'],
        contains('application/epub+zip'),
      );
      expect(response.bodyBytes, isEmpty);
    });
  });
}
