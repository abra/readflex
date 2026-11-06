import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// The actual response stream exceeded its caller's buffering budget.
class HttpResponseTooLargeException implements Exception {
  const HttpResponseTooLargeException(this.maxBytes);

  final int maxBytes;

  @override
  String toString() => 'HTTP response exceeds $maxBytes bytes';
}

/// Sends a backend POST with one deadline covering headers and the entire body.
///
/// Counts bytes delivered by the client (after its transport decompression),
/// independently of Content-Length and status. Failure aborts this request and
/// cancels its stream; a client that ignores abort has its late response
/// discarded. The caller retains ownership of [client].
Future<http.Response> postBoundedResponse({
  required http.Client client,
  required Uri uri,
  required Map<String, String> headers,
  required String body,
  required int maxResponseBytes,
  required Duration timeout,
  Future<void>? abortTrigger,
}) {
  if (maxResponseBytes <= 0 || timeout <= Duration.zero) {
    return Future.error(
      ArgumentError('Response byte limit and timeout must be positive'),
    );
  }
  return _BoundedPost(
    client: client,
    uri: uri,
    headers: headers,
    body: body,
    maxBytes: maxResponseBytes,
    timeout: timeout,
  ).send(abortTrigger);
}

class _BoundedPost {
  _BoundedPost({
    required this.client,
    required this.uri,
    required this.headers,
    required this.body,
    required this.maxBytes,
    required this.timeout,
  });

  final http.Client client;
  final Uri uri;
  final Map<String, String> headers;
  final String body;
  final int maxBytes;
  final Duration timeout;
  final _result = Completer<http.Response>();
  final _abort = Completer<void>();
  final _bytes = BytesBuilder(copy: false);
  StreamSubscription<List<int>>? _subscription;
  Timer? _timer;
  int _received = 0;

  Future<http.Response> send(Future<void>? abortTrigger) {
    _timer = Timer(
      timeout,
      () => _fail(TimeoutException('Backend request timed out', timeout)),
    );
    abortTrigger?.then(
      (_) => _fail(http.RequestAbortedException(uri)),
      onError: (Object _, StackTrace _) =>
          _fail(http.RequestAbortedException(uri)),
    );
    // Observe an already completed abort before opening a connection.
    scheduleMicrotask(_start);
    return _result.future;
  }

  void _start() {
    if (_result.isCompleted) return;
    final request =
        http.AbortableRequest('POST', uri, abortTrigger: _abort.future)
          ..headers.addAll(headers)
          ..body = body;
    try {
      unawaited(
        client
            .send(request)
            .then<void>(
              _receive,
              onError: (Object error, StackTrace stack) => _fail(error, stack),
            ),
      );
    } catch (error, stack) {
      _fail(error, stack);
    }
  }

  void _receive(http.StreamedResponse response) {
    if (_result.isCompleted) {
      // An injected transport may ignore AbortableRequest while connecting.
      response.stream.listen(null, onError: (Object _) {}).cancel().ignore();
      return;
    }
    try {
      _subscription = response.stream.listen(
        (chunk) {
          if (_result.isCompleted) return;
          if (chunk.length > maxBytes - _received) {
            _fail(HttpResponseTooLargeException(maxBytes));
            return;
          }
          _received += chunk.length;
          _bytes.add(chunk);
        },
        onError: (Object error, StackTrace stack) => _fail(error, stack),
        onDone: () {
          if (_result.isCompleted) return;
          _timer?.cancel();
          _subscription = null;
          _result.complete(
            http.Response.bytes(
              _bytes.takeBytes(),
              response.statusCode,
              headers: response.headers,
              request: response.request,
              isRedirect: response.isRedirect,
              persistentConnection: response.persistentConnection,
              reasonPhrase: response.reasonPhrase,
            ),
          );
        },
        cancelOnError: true,
      );
      if (_result.isCompleted) _subscription?.cancel().ignore();
    } catch (error, stack) {
      _fail(error, stack);
    }
  }

  void _fail(Object error, [StackTrace? stack]) {
    if (_result.isCompleted) return;
    _timer?.cancel();
    _abort.complete();
    _subscription?.cancel().ignore();
    _subscription = null;
    _bytes.clear();
    _result.completeError(error, stack);
  }
}
