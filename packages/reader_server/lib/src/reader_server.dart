import 'dart:io';

import 'package:monitoring/monitoring.dart';
import 'package:path/path.dart' as p;

/// Local HTTP server that serves book files and reader assets to the
/// reader WebView.
///
/// Route families:
///   - `GET /book/<url-encoded-absolute-path>` — streams a book file
///     (epub, pdf, fb2, mobi) from disk. Articles are packaged as
///     single-chapter EPUBs at import time and served through this same
///     route, so there is no article-specific route family.
///   - `GET /assets/<path>` — serves static files (foliate-js, CSS, JS)
///     from [_assetsDir].
///
/// Created once in composition, lives in `DependenciesContainer`.
class ReaderServer {
  ReaderServer({
    required Directory assetsDirectory,
    required Logger logger,
  }) : _assetsDir = assetsDirectory,
       _logger = logger;

  final Directory _assetsDir;
  final Logger _logger;

  /// The directory where reader assets (foliate-js, CSS, JS) are stored.
  Directory get assetsDirectory => _assetsDir;

  HttpServer? _server;

  /// The port the server is listening on. Only valid after [start].
  int get port {
    final server = _server;
    if (server == null) {
      throw StateError('ReaderServer has not been started.');
    }
    return server.port;
  }

  /// Whether the server is currently running.
  bool get isRunning => _server != null;

  /// Starts listening on `127.0.0.1` with a system-assigned port.
  ///
  /// Throws [SocketException] if the port cannot be bound.
  Future<void> start() async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _server!.listen(_handleRequest);
      _logger.info('ReaderServer started on port ${_server!.port}');
    } catch (e, st) {
      _logger.error('ReaderServer failed to start', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Stops the server and releases the port.
  Future<void> stop() async {
    final port = _server?.port;
    await _server?.close();
    _server = null;
    _logger.info('ReaderServer stopped (was port $port)');
  }

  void _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    final stopwatch = Stopwatch()..start();

    try {
      // HEAD is treated like GET — `_serveFile` checks the request method
      // and skips the body for HEAD so clients can probe size/content-type
      // without downloading. Used by `RemoteFile.open()` on the JS side.
      if (request.method != 'GET' && request.method != 'HEAD') {
        _respond(
          request,
          HttpStatus.methodNotAllowed,
          'Only GET and HEAD are supported.',
        );
        _logRequest(
          request.method,
          path,
          HttpStatus.methodNotAllowed,
          stopwatch,
        );
        return;
      }

      final segments = request.uri.pathSegments;
      if (segments.isEmpty) {
        _respond(request, HttpStatus.notFound, 'No route.');
        _logRequest('GET', path, HttpStatus.notFound, stopwatch);
        return;
      }

      switch (segments.first) {
        case 'book':
          await _handleBook(request, segments, stopwatch);
        case 'assets':
          await _handleAsset(request, segments, stopwatch);
        default:
          _respond(request, HttpStatus.notFound, 'Unknown route.');
          _logRequest('GET', path, HttpStatus.notFound, stopwatch);
      }
    } catch (e, stackTrace) {
      _respond(request, HttpStatus.internalServerError, 'Internal error.');
      _logger.error(
        'ReaderServer error: GET $path',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void _logRequest(
    String method,
    String path,
    int status,
    Stopwatch stopwatch,
  ) {
    stopwatch.stop();
    _logger.trace(
      'ReaderServer: $method $path → $status (${stopwatch.elapsedMilliseconds}ms)',
    );
  }

  // ── /book/<url-encoded-absolute-path> ──

  Future<void> _handleBook(
    HttpRequest request,
    List<String> segments,
    Stopwatch stopwatch,
  ) async {
    final path = request.uri.path;

    if (segments.length < 2) {
      _respond(request, HttpStatus.badRequest, 'Missing book path.');
      _logRequest('GET', path, HttpStatus.badRequest, stopwatch);
      return;
    }

    final encodedPath = segments.sublist(1).join('/');
    final filePath = Uri.decodeComponent(encodedPath);
    final file = File(filePath);

    if (!await file.exists()) {
      _respond(request, HttpStatus.notFound, 'Book file not found.');
      _logRequest('GET', path, HttpStatus.notFound, stopwatch);
      return;
    }

    await _serveFile(
      request: request,
      file: file,
      contentType: _mimeForExtension(p.extension(filePath)),
      stopwatch: stopwatch,
    );
  }

  // ── /assets/<path> ──

  Future<void> _handleAsset(
    HttpRequest request,
    List<String> segments,
    Stopwatch stopwatch,
  ) async {
    final path = request.uri.path;

    if (segments.length < 2) {
      _respond(request, HttpStatus.badRequest, 'Missing asset path.');
      _logRequest('GET', path, HttpStatus.badRequest, stopwatch);
      return;
    }

    final relativePath = segments.sublist(1).join('/');

    if (!_isWithin(_assetsDir, relativePath)) {
      _respond(request, HttpStatus.badRequest, 'Invalid asset path.');
      _logRequest('GET', path, HttpStatus.badRequest, stopwatch);
      return;
    }

    final file = File(p.join(_assetsDir.path, relativePath));
    if (!await file.exists()) {
      _respond(request, HttpStatus.notFound, 'Asset not found.');
      _logRequest('GET', path, HttpStatus.notFound, stopwatch);
      return;
    }

    await _serveFile(
      request: request,
      file: file,
      contentType: _mimeForExtension(p.extension(relativePath)),
      stopwatch: stopwatch,
    );
  }

  // ── Helpers ──

  /// Streams [file] to the response, honouring an `Range: bytes=...` request
  /// header when present.
  ///
  /// Without a Range header: replies `200 OK` with the full file body and a
  /// `Content-Length` (so clients see total size up front), `Accept-Ranges:
  /// bytes` advertises that partial requests are supported.
  ///
  /// With a Range header: replies `206 Partial Content` and the requested
  /// byte slice (inclusive bounds, like the spec). Open-ended ranges
  /// (`bytes=N-`) and suffix ranges (`bytes=-N`) are both handled. Invalid
  /// or unsatisfiable ranges produce `416 Range Not Satisfiable` with a
  /// proper `Content-Range: bytes */<size>` so the client can recover.
  ///
  /// Why we need this: zip-based formats (EPUB, CBZ) only need a small slice
  /// to render a chapter, but a naive 200-OK download forces the WebView to
  /// keep the whole book in memory. The `RemoteFile` shim on the JS side
  /// uses HTTP Range to read just the bytes zip.js asks for.
  Future<void> _serveFile({
    required HttpRequest request,
    required File file,
    required ContentType contentType,
    required Stopwatch stopwatch,
  }) async {
    final path = request.uri.path;
    final method = request.method;
    final isHead = method == 'HEAD';
    final fileLength = await file.length();
    final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
    final response = request.response;

    response.headers
      ..contentType = contentType
      ..set(HttpHeaders.acceptRangesHeader, 'bytes');

    if (rangeHeader == null) {
      response
        ..statusCode = HttpStatus.ok
        ..contentLength = fileLength;
      if (isHead) {
        await response.close();
      } else {
        await file.openRead().pipe(response);
      }
      _logRequest(method, path, HttpStatus.ok, stopwatch);
      return;
    }

    final range = _parseRange(rangeHeader, fileLength);
    if (range == null) {
      response
        ..statusCode = HttpStatus.requestedRangeNotSatisfiable
        ..headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes */$fileLength',
        )
        ..contentLength = 0;
      await response.close();
      _logRequest(
        method,
        path,
        HttpStatus.requestedRangeNotSatisfiable,
        stopwatch,
      );
      return;
    }

    final (start, end) = range;
    response
      ..statusCode = HttpStatus.partialContent
      ..contentLength = end - start + 1
      ..headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-$end/$fileLength',
      );
    if (isHead) {
      await response.close();
    } else {
      // openRead end is exclusive, the Range header end is inclusive.
      await file.openRead(start, end + 1).pipe(response);
    }
    _logRequest(method, path, HttpStatus.partialContent, stopwatch);
  }

  /// Parses an HTTP `Range` header value against a known [totalLength] and
  /// returns an `(start, end)` tuple with inclusive bounds, clamped into
  /// `[0, totalLength - 1]`.
  ///
  /// Returns `null` for headers that are syntactically invalid, address an
  /// empty file, or specify a start past the end of the file — in those
  /// cases the caller must reply `416`.
  ///
  /// Multi-range syntax (`bytes=0-100,200-300`) is intentionally not
  /// supported: every consumer we ship issues single-range requests, and
  /// supporting multipart/byteranges responses adds noise without payoff.
  static (int, int)? _parseRange(String header, int totalLength) {
    if (totalLength <= 0) return null;
    if (!header.startsWith('bytes=')) return null;
    final spec = header.substring('bytes='.length);
    if (spec.isEmpty || spec.contains(',')) return null;

    final dashIndex = spec.indexOf('-');
    if (dashIndex == -1) return null;
    final startStr = spec.substring(0, dashIndex);
    final endStr = spec.substring(dashIndex + 1);

    final lastByte = totalLength - 1;

    // Suffix range: `bytes=-N` — last N bytes of the file.
    if (startStr.isEmpty) {
      final suffix = int.tryParse(endStr);
      if (suffix == null || suffix <= 0) return null;
      final start = suffix >= totalLength ? 0 : totalLength - suffix;
      return (start, lastByte);
    }

    final start = int.tryParse(startStr);
    if (start == null || start < 0 || start > lastByte) return null;

    // Open-ended range: `bytes=N-` — N to the end of the file.
    if (endStr.isEmpty) return (start, lastByte);

    final end = int.tryParse(endStr);
    if (end == null || end < start) return null;
    return (start, end > lastByte ? lastByte : end);
  }

  /// Verifies that joining [root] with [relativePath] stays inside [root].
  /// Catches absolute-path substitution (`p.join('/root', '/etc/x') → '/etc/x'`)
  /// and `..` segments that survive percent-decoding.
  static bool _isWithin(Directory root, String relativePath) {
    final resolved = p.canonicalize(p.join(root.path, relativePath));
    final rootPath = p.canonicalize(root.path);
    return p.isWithin(rootPath, resolved) || resolved == rootPath;
  }

  void _respond(HttpRequest request, int status, String body) {
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.text
      ..write(body);
    request.response.close();
  }

  static ContentType _mimeForExtension(String ext) {
    return switch (ext.toLowerCase()) {
      '.html' || '.htm' => ContentType.html,
      '.css' => ContentType('text', 'css', charset: 'utf-8'),
      '.js' ||
      '.mjs' => ContentType('application', 'javascript', charset: 'utf-8'),
      '.json' => ContentType('application', 'json', charset: 'utf-8'),
      '.epub' => ContentType('application', 'epub+zip'),
      '.pdf' => ContentType('application', 'pdf'),
      '.mobi' => ContentType('application', 'x-mobipocket-ebook'),
      '.fb2' => ContentType('application', 'xml', charset: 'utf-8'),
      '.png' => ContentType('image', 'png'),
      '.jpg' || '.jpeg' => ContentType('image', 'jpeg'),
      '.gif' => ContentType('image', 'gif'),
      '.svg' => ContentType('image', 'svg+xml'),
      '.webp' => ContentType('image', 'webp'),
      '.woff' => ContentType('font', 'woff'),
      '.woff2' => ContentType('font', 'woff2'),
      '.ttf' => ContentType('font', 'ttf'),
      _ => ContentType.binary,
    };
  }
}
