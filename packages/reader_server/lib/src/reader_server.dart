import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:monitoring/monitoring.dart';
import 'package:path/path.dart' as p;

/// Local HTTP server that serves book files and reader assets to the
/// reader WebView.
///
/// Requests use an unguessable, process-local URL prefix. Book and article
/// paths are accepted only when they resolve inside their configured storage
/// roots. A file selected from outside the app storage can be exposed for the
/// duration of metadata extraction through [grantTemporaryBookAccess].
///
/// Created once in composition, lives in `DependenciesContainer`.
class ReaderServer {
  ReaderServer({
    required Directory assetsDirectory,
    required Directory booksDirectory,
    required Directory articlesDirectory,
    required Logger logger,
  }) : _assetsDir = assetsDirectory,
       _booksDir = booksDirectory,
       _articlesDir = articlesDirectory,
       _accessToken = _generateAccessToken(),
       _logger = logger;

  final Directory _assetsDir;
  final Directory _booksDir;
  final Directory _articlesDir;
  final String _accessToken;
  final Logger _logger;
  final Map<String, int> _temporaryBookPaths = {};

  String? _resolvedAssetsRoot;
  String? _resolvedBooksRoot;
  String? _resolvedArticlesRoot;

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

  /// Base URI for all reader routes, including the process-local access token.
  ///
  /// The URI always ends in `/`, so consumers can safely call [Uri.resolve]
  /// with relative paths such as `assets/foliate-js/index.html`.
  Uri get baseUri {
    final server = _server;
    if (server == null) {
      throw StateError('ReaderServer has not been started.');
    }
    return Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: server.port,
      path: '/r/$_accessToken/',
    );
  }

  /// Whether the server is currently running.
  bool get isRunning => _server != null;

  /// Starts listening on `127.0.0.1` with a system-assigned port.
  ///
  /// Throws [SocketException] if the port cannot be bound.
  Future<void> start() async {
    if (_server != null) return;
    try {
      await Future.wait([
        _assetsDir.create(recursive: true),
        _booksDir.create(recursive: true),
        _articlesDir.create(recursive: true),
      ]);
      _resolvedAssetsRoot = await _assetsDir.resolveSymbolicLinks();
      _resolvedBooksRoot = await _booksDir.resolveSymbolicLinks();
      _resolvedArticlesRoot = await _articlesDir.resolveSymbolicLinks();
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
    _resolvedAssetsRoot = null;
    _resolvedBooksRoot = null;
    _resolvedArticlesRoot = null;
    _temporaryBookPaths.clear();
    _logger.info('ReaderServer stopped (was port $port)');
  }

  /// Temporarily allows metadata extraction to read [file] when it lives
  /// outside the managed books directory (for example, a file-picker result).
  ///
  /// The caller must revoke the returned grant in a `finally` block. Grants
  /// are reference-counted so overlapping imports of the same file cannot
  /// revoke each other's access.
  Future<ReaderServerBookAccessGrant> grantTemporaryBookAccess(
    File file,
  ) async {
    if (_server == null || _resolvedBooksRoot == null) {
      throw StateError('ReaderServer has not been started.');
    }
    if (!await file.exists()) {
      throw FileSystemException('Book file does not exist.', file.path);
    }

    final resolvedPath = await file.resolveSymbolicLinks();
    _temporaryBookPaths.update(
      resolvedPath,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    return ReaderServerBookAccessGrant._(() {
      final count = _temporaryBookPaths[resolvedPath];
      if (count == null) return;
      if (count <= 1) {
        _temporaryBookPaths.remove(resolvedPath);
      } else {
        _temporaryBookPaths[resolvedPath] = count - 1;
      }
    });
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

      final allSegments = request.uri.pathSegments;
      if (allSegments.length < 3 ||
          allSegments.first != 'r' ||
          !_secureEquals(allSegments[1], _accessToken)) {
        _respond(request, HttpStatus.notFound, 'No route.');
        _logRequest('GET', path, HttpStatus.notFound, stopwatch);
        return;
      }

      final segments = allSegments.sublist(2);

      switch (segments.first) {
        case 'book':
          await _handleBook(request, segments, stopwatch);
        case 'article':
          await _handleArticle(request, segments, stopwatch);
        case 'assets':
          await _handleAsset(request, segments, stopwatch);
        default:
          _respond(request, HttpStatus.notFound, 'Unknown route.');
          _logRequest('GET', path, HttpStatus.notFound, stopwatch);
      }
    } catch (e, stackTrace) {
      _respond(request, HttpStatus.internalServerError, 'Internal error.');
      _logger.error(
        'ReaderServer error: GET ${_safeRequestPath(path)}',
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
    final safePath = _safeRequestPath(path);
    _logger.trace(
      'ReaderServer: $method $safePath → $status '
      '(${stopwatch.elapsedMilliseconds}ms)',
    );
  }

  String _safeRequestPath(String path) {
    final segments = Uri(path: path).pathSegments;
    if (segments.length < 3 || segments.first != 'r') return '/<unscoped>';
    return '/${segments[2]}/…';
  }

  // ── /r/<token>/book/<url-encoded-absolute-path> ──

  Future<void> _handleBook(
    HttpRequest request,
    List<String> segments,
    Stopwatch stopwatch,
  ) async {
    final path = request.uri.path;

    if (segments.length != 2) {
      _respond(request, HttpStatus.badRequest, 'Missing book path.');
      _logRequest('GET', path, HttpStatus.badRequest, stopwatch);
      return;
    }

    final filePath = segments[1];
    if (filePath.isEmpty) {
      _respond(request, HttpStatus.badRequest, 'Missing book path.');
      _logRequest('GET', path, HttpStatus.badRequest, stopwatch);
      return;
    }

    final file = File(filePath);

    if (!await file.exists()) {
      _respond(request, HttpStatus.notFound, 'Book file not found.');
      _logRequest('GET', path, HttpStatus.notFound, stopwatch);
      return;
    }

    final resolvedPath = await file.resolveSymbolicLinks();
    final booksRoot = _resolvedBooksRoot;
    final isManagedBook =
        booksRoot != null && _isPathWithin(booksRoot, resolvedPath);
    if (!isManagedBook && !_temporaryBookPaths.containsKey(resolvedPath)) {
      _respond(request, HttpStatus.notFound, 'Book file not found.');
      _logRequest('GET', path, HttpStatus.notFound, stopwatch);
      return;
    }

    await _serveFile(
      request: request,
      file: File(resolvedPath),
      contentType: _mimeForExtension(p.extension(filePath)),
      stopwatch: stopwatch,
    );
  }

  // ── /r/<token>/article/<url-encoded-absolute-dir>/<relative-path> ──

  Future<void> _handleArticle(
    HttpRequest request,
    List<String> segments,
    Stopwatch stopwatch,
  ) async {
    final path = request.uri.path;

    if (segments.length < 3) {
      _respond(request, HttpStatus.badRequest, 'Missing article path.');
      _logRequest('GET', path, HttpStatus.badRequest, stopwatch);
      return;
    }

    final root = Directory(segments[1]);
    final relativePath = segments.sublist(2).join('/');
    if (!_isSafeRelativePath(relativePath)) {
      _respond(request, HttpStatus.badRequest, 'Invalid article path.');
      _logRequest('GET', path, HttpStatus.badRequest, stopwatch);
      return;
    }

    if (!await root.exists()) {
      _respond(request, HttpStatus.notFound, 'Article file not found.');
      _logRequest('GET', path, HttpStatus.notFound, stopwatch);
      return;
    }

    final resolvedRoot = await root.resolveSymbolicLinks();
    final articlesRoot = _resolvedArticlesRoot;
    if (articlesRoot == null || !_isPathWithin(articlesRoot, resolvedRoot)) {
      _respond(request, HttpStatus.notFound, 'Article file not found.');
      _logRequest('GET', path, HttpStatus.notFound, stopwatch);
      return;
    }

    final file = File(p.join(resolvedRoot, relativePath));
    if (!await file.exists()) {
      _respond(request, HttpStatus.notFound, 'Article file not found.');
      _logRequest('GET', path, HttpStatus.notFound, stopwatch);
      return;
    }

    final resolvedFile = await file.resolveSymbolicLinks();
    if (!_isPathWithin(resolvedRoot, resolvedFile)) {
      _respond(request, HttpStatus.notFound, 'Article file not found.');
      _logRequest('GET', path, HttpStatus.notFound, stopwatch);
      return;
    }

    await _serveFile(
      request: request,
      file: File(resolvedFile),
      contentType: _mimeForExtension(p.extension(relativePath)),
      stopwatch: stopwatch,
      cacheStaticFile: true,
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

    if (!_isSafeRelativePath(relativePath)) {
      _respond(request, HttpStatus.badRequest, 'Invalid asset path.');
      _logRequest('GET', path, HttpStatus.badRequest, stopwatch);
      return;
    }

    final assetsRoot = _resolvedAssetsRoot;
    if (assetsRoot == null) {
      _respond(request, HttpStatus.serviceUnavailable, 'Assets unavailable.');
      _logRequest('GET', path, HttpStatus.serviceUnavailable, stopwatch);
      return;
    }

    final file = File(p.join(assetsRoot, relativePath));
    if (!await file.exists()) {
      _respond(request, HttpStatus.notFound, 'Asset not found.');
      _logRequest('GET', path, HttpStatus.notFound, stopwatch);
      return;
    }

    final resolvedFile = await file.resolveSymbolicLinks();
    if (!_isPathWithin(assetsRoot, resolvedFile)) {
      _respond(request, HttpStatus.badRequest, 'Invalid asset path.');
      _logRequest('GET', path, HttpStatus.badRequest, stopwatch);
      return;
    }

    await _serveFile(
      request: request,
      file: File(resolvedFile),
      contentType: _mimeForExtension(p.extension(relativePath)),
      stopwatch: stopwatch,
      cacheStaticFile: true,
      cacheImmutableFile: relativePath.startsWith('fonts/'),
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
    bool cacheStaticFile = false,
    bool cacheImmutableFile = false,
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

    // Cache static assets so each new section iframe doesn't re-fetch
    // them and FOUT-reflow ("text straightens out") on every chapter
    // cross. Fonts get a year (their bytes never change once shipped);
    // foliate-js JS/CSS get a day so an app upgrade that re-extracts
    // assets isn't shadowed by a stale WebView HTTP cache.
    // Books are ranged-streamed differently and live at /book/ — no
    // caching for those, content can change between sessions.
    if (cacheImmutableFile) {
      response.headers.set(
        HttpHeaders.cacheControlHeader,
        'public, max-age=31536000, immutable',
      );
    } else if (cacheStaticFile) {
      response.headers.set(
        HttpHeaders.cacheControlHeader,
        'public, max-age=86400',
      );
    }

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

  static bool _isPathWithin(String rootPath, String candidatePath) =>
      p.equals(rootPath, candidatePath) || p.isWithin(rootPath, candidatePath);

  static bool _isSafeRelativePath(String path) {
    if (path.isEmpty || path.startsWith('/') || path.startsWith(r'\')) {
      return false;
    }
    final segments = path.split(RegExp(r'[/\\]+'));
    return !segments.contains('..');
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

/// Revocable access to a file selected outside the managed books directory.
final class ReaderServerBookAccessGrant {
  ReaderServerBookAccessGrant._(this._onRevoke);

  final void Function() _onRevoke;
  bool _revoked = false;

  /// Revokes this grant. Calling this method more than once is safe.
  void revoke() {
    if (_revoked) return;
    _revoked = true;
    _onRevoke();
  }
}

String _generateAccessToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}

bool _secureEquals(String left, String right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left.codeUnitAt(index) ^ right.codeUnitAt(index);
  }
  return difference == 0;
}
