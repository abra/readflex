import 'dart:io';

import 'package:monitoring/monitoring.dart';
import 'package:path/path.dart' as p;

/// Local HTTP server that serves book files and article HTML to the
/// reader WebView.
///
/// Route families:
///   - `GET /book/<url-encoded-absolute-path>` — streams a raw book file
///     (epub, pdf, fb2, mobi) from disk.
///   - `GET /article/<id>` — reads `<id>/content.html` from [_articlesDir].
///   - `GET /article/<id>/images/<filename>` — serves a downloaded body
///     image from `<id>/images/` inside [_articlesDir].
///   - `GET /assets/<path>` — serves static files (foliate-js, CSS, JS)
///     from [_assetsDir].
///
/// Created once in composition, lives in `DependenciesContainer`.
class ReaderServer {
  ReaderServer({
    required Directory articlesDirectory,
    required Directory assetsDirectory,
    required Logger logger,
  }) : _articlesDir = articlesDirectory,
       _assetsDir = assetsDirectory,
       _logger = logger;

  final Directory _articlesDir;
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
      if (request.method != 'GET') {
        _respond(
          request,
          HttpStatus.methodNotAllowed,
          'Only GET is supported.',
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

    final contentType = _mimeForExtension(p.extension(filePath));
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = contentType;
    await file.openRead().pipe(request.response);
    _logRequest('GET', path, HttpStatus.ok, stopwatch);
  }

  // ── /article/<id>[/images/<filename>] ──

  Future<void> _handleArticle(
    HttpRequest request,
    List<String> segments,
    Stopwatch stopwatch,
  ) async {
    final path = request.uri.path;

    if (segments.length < 2) {
      _respond(request, HttpStatus.badRequest, 'Expected /article/<id>.');
      _logRequest('GET', path, HttpStatus.badRequest, stopwatch);
      return;
    }

    final id = segments[1];

    if (id.contains('/') || id.contains('..')) {
      _respond(request, HttpStatus.badRequest, 'Invalid article id.');
      _logRequest('GET', path, HttpStatus.badRequest, stopwatch);
      return;
    }

    // /article/<id>/images/<filename>
    if (segments.length == 4 && segments[2] == 'images') {
      await _handleArticleImage(request, id, segments[3], stopwatch);
      return;
    }

    // /article/<id>
    if (segments.length != 2) {
      _respond(request, HttpStatus.badRequest, 'Expected /article/<id>.');
      _logRequest('GET', path, HttpStatus.badRequest, stopwatch);
      return;
    }

    final file = File(p.join(_articlesDir.path, id, 'content.html'));
    if (!await file.exists()) {
      _respond(request, HttpStatus.notFound, 'Article not found.');
      _logRequest('GET', path, HttpStatus.notFound, stopwatch);
      return;
    }

    final html = await file.readAsString();

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..write(html);
    await request.response.close();
    _logRequest('GET', path, HttpStatus.ok, stopwatch);
  }

  Future<void> _handleArticleImage(
    HttpRequest request,
    String articleId,
    String filename,
    Stopwatch stopwatch,
  ) async {
    final path = request.uri.path;

    if (filename.contains('..') || filename.contains('/')) {
      _respond(request, HttpStatus.badRequest, 'Invalid image filename.');
      _logRequest('GET', path, HttpStatus.badRequest, stopwatch);
      return;
    }

    final file = File(
      p.join(_articlesDir.path, articleId, 'images', filename),
    );
    if (!await file.exists()) {
      _respond(request, HttpStatus.notFound, 'Image not found.');
      _logRequest('GET', path, HttpStatus.notFound, stopwatch);
      return;
    }

    final contentType = _mimeForExtension(p.extension(filename));
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = contentType;
    await file.openRead().pipe(request.response);
    _logRequest('GET', path, HttpStatus.ok, stopwatch);
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

    final contentType = _mimeForExtension(p.extension(relativePath));
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = contentType;
    await file.openRead().pipe(request.response);
    _logRequest('GET', path, HttpStatus.ok, stopwatch);
  }

  // ── Helpers ──

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
