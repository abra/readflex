import 'dart:async' show StreamController, StreamSubscription;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'connectivity_service.dart';

/// Production [ConnectivityService] backed by the `connectivity_plus` plugin.
///
/// Reports `online` whenever the OS sees any network interface (wifi, cellular,
/// ethernet, vpn, …) and `offline` only when all interfaces are absent. This
/// intentionally does not do a reachability probe — "the device has wifi"
/// does not guarantee "your backend is reachable", so services still have to
/// try the request and handle failure. Connectivity is a UX signal, not a gate.
///
/// Construction goes through [create] in production and [forTesting] in tests;
/// the constructor is private because plumbing an initial status and an event
/// stream has to stay in one place.
class ConnectivityPlusService implements ConnectivityService {
  ConnectivityPlusService._({
    required ConnectivityStatus initial,
    required Stream<List<ConnectivityResult>> events,
  }) : _current = initial {
    _subscription = events.listen(_onEvent);
  }

  final StreamController<ConnectivityStatus> _controller =
      StreamController<ConnectivityStatus>.broadcast();
  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  ConnectivityStatus _current;

  /// Production entry point — uses the real `connectivity_plus` singleton.
  static Future<ConnectivityPlusService> create() async {
    final connectivity = Connectivity();
    final initial = _map(await connectivity.checkConnectivity());
    return ConnectivityPlusService._(
      initial: initial,
      events: connectivity.onConnectivityChanged,
    );
  }

  /// Test entry point that skips platform channels — callers drive the
  /// service with their own [events] stream and pre-set [initial] status.
  @visibleForTesting
  static ConnectivityPlusService forTesting({
    required ConnectivityStatus initial,
    required Stream<List<ConnectivityResult>> events,
  }) => ConnectivityPlusService._(initial: initial, events: events);

  @override
  ConnectivityStatus get status => _current;

  @override
  Stream<ConnectivityStatus> get statusStream => _controller.stream;

  @override
  void dispose() {
    _subscription.cancel();
    _controller.close();
  }

  void _onEvent(List<ConnectivityResult> results) {
    final next = _map(results);
    if (next == _current) return;
    _current = next;
    _controller.add(next);
  }

  /// Maps the plugin's list of active interfaces to a single status.
  /// Any interface other than [ConnectivityResult.none] counts as online.
  static ConnectivityStatus _map(List<ConnectivityResult> results) {
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);
    return hasNetwork ? ConnectivityStatus.online : ConnectivityStatus.offline;
  }
}
