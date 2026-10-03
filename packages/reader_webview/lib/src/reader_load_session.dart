import 'dart:async';

const readerStartupTracingEnabled = bool.fromEnvironment(
  'READFLEX_TRACE_READER_STARTUP',
);

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
    this.onTiming,
  }) : _startupWatch = onTiming == null ? null : (Stopwatch()..start());

  final void Function(ReaderLoadFailure) onFailed;
  final Duration timeout;
  final void Function(String stage, Duration elapsed)? onTiming;
  final Stopwatch? _startupWatch;
  Timer? _watchdog;
  bool _ready = false;
  bool _loadComplete = false;
  bool _failed = false;
  bool _disposed = false;
  int _generation = 0;

  int get generation => _generation;

  void start() {
    if (_disposed || _failed) return;
    _reportTiming('webview-created');
    _watchdog?.cancel();
    _watchdog = Timer(
      timeout,
      () => fail(const ReaderLoadFailure(ReaderLoadFailureKind.timeout)),
    );
  }

  // First relocation makes content usable before initial location restore ends.
  bool markReady({bool loadComplete = false}) {
    if (_disposed || _failed) return false;
    _watchdog?.cancel();
    if (!_ready) {
      _ready = true;
      _reportTiming('first-content-ready');
    }
    if (loadComplete && !_loadComplete) {
      _loadComplete = true;
      _reportTiming('initial-location-ready');
      _startupWatch?.stop();
    }
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
    _ready = false;
    _loadComplete = false;
    _startupWatch
      ?..reset()
      ..start();
    return true;
  }

  void fail(ReaderLoadFailure failure) {
    if (_disposed || _failed) return;
    _failed = true;
    if (!_loadComplete) _reportTiming('failed-${failure.kind.name}');
    _startupWatch?.stop();
    _watchdog?.cancel();
    onFailed(failure);
  }

  void dispose() {
    _disposed = true;
    _startupWatch?.stop();
    _watchdog?.cancel();
  }

  void _reportTiming(String stage) {
    final watch = _startupWatch;
    if (watch == null) return;
    // Optional diagnostics cannot change the reader's load/recovery outcome.
    try {
      onTiming?.call(stage, watch.elapsed);
    } on Object catch (_) {}
  }
}
