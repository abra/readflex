import 'dart:io';

import 'remote_uri_policy.dart';

/// Creates an [HttpClient] that connects directly to an IP address returned by
/// [RemoteUriPolicy], preventing a second DNS lookup between validation and
/// connection.
HttpClient createPublicRemoteHttpClient({
  required RemoteUriPolicy uriPolicy,
  Duration connectionTimeout = const Duration(seconds: 15),
}) {
  if (connectionTimeout <= Duration.zero) {
    throw ArgumentError.value(
      connectionTimeout,
      'connectionTimeout',
      'Must be greater than zero.',
    );
  }

  return HttpClient()
    ..connectionTimeout = connectionTimeout
    ..findProxy = ((_) => 'DIRECT')
    ..connectionFactory = (uri, proxyHost, proxyPort) async {
      if (proxyHost != null || proxyPort != null) {
        throw StateError('Public remote HTTP client does not support proxies.');
      }
      final attempt = _ValidatedConnectionAttempt(uri, uriPolicy);
      return attempt.start();
    };
}

class _ValidatedConnectionAttempt {
  _ValidatedConnectionAttempt(this._uri, this._uriPolicy);

  final Uri _uri;
  final RemoteUriPolicy _uriPolicy;

  ConnectionTask<Socket>? _activeConnection;
  Socket? _activeSocket;
  bool _cancelled = false;

  ConnectionTask<Socket> start() {
    // HttpClient attaches its error handler after the factory returns the
    // task. Defer resolution by one event turn so an immediately rejected DNS
    // answer cannot surface as an unhandled asynchronous error.
    return ConnectionTask.fromSocket(Future<Socket>(_connect), cancel);
  }

  Future<Socket> _connect() async {
    final addresses = await _uriPolicy.resolvePublicAddresses(_uri);
    _throwIfCancelled();

    Object? lastError;
    StackTrace? lastStackTrace;
    for (final address in addresses) {
      try {
        final connection = await Socket.startConnect(address, _uri.port);
        _activeConnection = connection;
        _throwIfCancelled();

        final socket = await connection.socket;
        _activeConnection = null;
        _activeSocket = socket;
        _throwIfCancelled();

        final connectedSocket = _uri.scheme == 'https'
            ? await SecureSocket.secure(socket, host: _uri.host)
            : socket;
        _activeSocket = connectedSocket;
        _throwIfCancelled();
        _activeSocket = null;
        return connectedSocket;
      } on Object catch (error, stackTrace) {
        if (_cancelled) _activeConnection?.cancel();
        _activeConnection = null;
        _activeSocket?.destroy();
        _activeSocket = null;
        if (_cancelled) _throwIfCancelled();
        lastError = error;
        lastStackTrace = stackTrace;
      }
    }

    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _activeConnection?.cancel();
    _activeSocket?.destroy();
  }

  void _throwIfCancelled() {
    if (_cancelled) {
      throw SocketException(
        'Connection attempt cancelled, host: ${_uri.host}, port: ${_uri.port}',
      );
    }
  }
}
