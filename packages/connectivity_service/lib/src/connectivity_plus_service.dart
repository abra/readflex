import 'dart:async' show StreamController, StreamSubscription;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;

import 'connectivity_service.dart';

/// Production [ConnectivityService] backed by the `connectivity_plus` plugin.
///
/// Reports `online` whenever the OS sees a real network interface (wifi,
/// cellular, ethernet, …) and `offline` when all interfaces are absent. A
/// VPN entry alone does not count as online because Android can keep a VPN
/// interface visible after Airplane mode disables the underlying network.
/// This intentionally does not do a reachability probe — services still have
/// to try the request and handle failure. Connectivity is a UX signal, not a
/// gate.
///
/// Construction goes through [create] in production and [forTesting] in tests;
/// the constructor is private because plumbing an initial status and an event
/// stream has to stay in one place.
class ConnectivityPlusService implements ConnectivityService {
  ConnectivityPlusService._({
    required ConnectivityStatus initial,
    required Stream<List<ConnectivityResult>> events,
    required Future<List<ConnectivityResult>> Function() read,
  }) : _current = initial,
       _read = read {
    _subscription = events.listen(_onEvent);
  }

  final StreamController<ConnectivityStatus> _controller =
      StreamController<ConnectivityStatus>.broadcast();
  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  final Future<List<ConnectivityResult>> Function() _read;
  ConnectivityStatus _current;
  bool _disposed = false;

  /// Production entry point — uses the real `connectivity_plus` singleton.
  static Future<ConnectivityPlusService> create() async {
    final connectivity = Connectivity();
    final initialResults = await connectivity.checkConnectivity();
    final initial = _map(initialResults);
    _log('initial', initialResults, initial);
    return ConnectivityPlusService._(
      initial: initial,
      events: connectivity.onConnectivityChanged,
      read: connectivity.checkConnectivity,
    );
  }

  /// Test entry point that skips platform channels — callers drive the
  /// service with their own [events] stream and pre-set [initial] status.
  @visibleForTesting
  static ConnectivityPlusService forTesting({
    required ConnectivityStatus initial,
    required Stream<List<ConnectivityResult>> events,
    Future<List<ConnectivityResult>> Function()? read,
  }) => ConnectivityPlusService._(
    initial: initial,
    events: events,
    read: read ?? () async => _resultsFor(initial),
  );

  @override
  ConnectivityStatus get status => _current;

  @override
  Stream<ConnectivityStatus> get statusStream => _controller.stream;

  @override
  Future<void> refresh() async {
    if (_disposed) return;
    try {
      _applyResults('refresh', await _read());
    } catch (error) {
      _debugLog('[connectivity] refresh failed: $error');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription.cancel();
    _controller.close();
  }

  void _onEvent(List<ConnectivityResult> results) => _applyResults(
    'event',
    results,
  );

  void _applyResults(String source, List<ConnectivityResult> results) {
    final next = _map(results);
    _log(source, results, next);
    if (_disposed || next == _current) return;
    _current = next;
    _controller.add(next);
  }

  static void _log(
    String source,
    List<ConnectivityResult> results,
    ConnectivityStatus status,
  ) {
    final raw = results.map((r) => r.name).join(',');
    _debugLog('[connectivity] $source raw=[$raw] status=${status.name}');
  }

  static void _debugLog(String message) {
    assert(() {
      debugPrint(message);
      return true;
    }());
  }

  static List<ConnectivityResult> _resultsFor(ConnectivityStatus status) =>
      status == ConnectivityStatus.online
      ? const [ConnectivityResult.wifi]
      : const [ConnectivityResult.none];

  /// Maps the plugin's active interfaces to a single status.
  ///
  /// VPN is deliberately ignored unless another interface is present: on
  /// Android, Airplane mode can leave a stale VPN interface visible even though
  /// there is no underlying network path.
  static ConnectivityStatus _map(List<ConnectivityResult> results) {
    final hasNetwork = results.any(
      (r) => r != ConnectivityResult.none && r != ConnectivityResult.vpn,
    );
    return hasNetwork ? ConnectivityStatus.online : ConnectivityStatus.offline;
  }
}
