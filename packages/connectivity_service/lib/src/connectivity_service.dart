import 'dart:async';

/// Network connectivity status.
enum ConnectivityStatus { online, offline }

/// Reactive connectivity monitor.
///
/// Wraps `connectivity_plus` in production. Provides a [Stream] of
/// [ConnectivityStatus] for UI (offline banner) and services (fallback logic).
abstract class ConnectivityService {
  /// Current connectivity status.
  ConnectivityStatus get status;

  /// Reactive connectivity stream.
  Stream<ConnectivityStatus> get statusStream;

  /// Dispose resources.
  void dispose();
}

/// Stub — always online.
class NoopConnectivityService implements ConnectivityService {
  NoopConnectivityService();

  final _controller = StreamController<ConnectivityStatus>.broadcast();

  @override
  ConnectivityStatus get status => ConnectivityStatus.online;

  @override
  Stream<ConnectivityStatus> get statusStream => _controller.stream;

  @override
  void dispose() => _controller.close();
}
