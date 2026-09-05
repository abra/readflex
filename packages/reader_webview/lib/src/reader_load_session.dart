import 'dart:async';

enum ReaderLoadFailureKind { document, network, timeout, rendererTerminated }

final class ReaderLoadFailure implements Exception {
  const ReaderLoadFailure(this.kind);

  final ReaderLoadFailureKind kind;

  @override
  String toString() => 'ReaderLoadFailure(${kind.name})';
}

/// Bounded recovery and a terminal result for each native WebView instance.
final class ReaderLoadSession {
  ReaderLoadSession({
    required this.onFailed,
    this.timeout = const Duration(seconds: 60),
  });

  final void Function(ReaderLoadFailure) onFailed;
  final Duration timeout;
  Timer? _watchdog;
  bool _failed = false;
  bool _disposed = false;
  int _generation = 0;

  int get generation => _generation;

  void start() {
    if (_disposed || _failed) return;
    _watchdog?.cancel();
    _watchdog = Timer(
      timeout,
      () => fail(const ReaderLoadFailure(ReaderLoadFailureKind.timeout)),
    );
  }

  bool markReady() {
    if (_disposed || _failed) return false;
    _watchdog?.cancel();
    return true;
  }

  bool recoverRenderer() {
    if (_disposed || _failed) return false;
    _watchdog?.cancel();
    if (_generation >= 1) {
      fail(const ReaderLoadFailure(ReaderLoadFailureKind.rendererTerminated));
      return false;
    }
    _generation++;
    return true;
  }

  void fail(ReaderLoadFailure failure) {
    if (_disposed || _failed) return;
    _failed = true;
    _watchdog?.cancel();
    onFailed(failure);
  }

  void dispose() {
    _disposed = true;
    _watchdog?.cancel();
  }
}
