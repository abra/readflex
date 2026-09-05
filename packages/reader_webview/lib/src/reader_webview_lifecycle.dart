import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

typedef ReaderWebViewLifecycleOperation = Future<void> Function();

typedef ReaderWebViewLifecycleErrorHandler =
    void Function(
      bool resuming,
      Object error,
      StackTrace stackTrace,
    );

@visibleForTesting
final class ReaderWebViewLifecycleCoordinator {
  ReaderWebViewLifecycleCoordinator({
    required AppLifecycleState? initialState,
    this.onError,
  }) : _shouldResume =
           initialState == null || initialState == AppLifecycleState.resumed;

  final ReaderWebViewLifecycleErrorHandler? onError;

  bool _shouldResume;
  bool _disposed = false;
  bool? _lastScheduledState;
  int _targetGeneration = 0;
  Future<void> _pendingOperation = Future<void>.value();
  ({
    ReaderWebViewLifecycleOperation pause,
    ReaderWebViewLifecycleOperation resume,
  })?
  _target;

  void attach({
    required ReaderWebViewLifecycleOperation pause,
    required ReaderWebViewLifecycleOperation resume,
  }) {
    if (_disposed) return;
    _target = (pause: pause, resume: resume);
    _targetGeneration += 1;
    _lastScheduledState = null;
    _scheduleCurrentState();
  }

  void handleAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    final shouldResume = state == AppLifecycleState.resumed;
    if (_shouldResume == shouldResume) return;
    _shouldResume = shouldResume;
    _scheduleCurrentState();
  }

  void dispose() {
    _disposed = true;
    _target = null;
    _targetGeneration += 1;
  }

  void detach() {
    _target = null;
    _targetGeneration++;
    _lastScheduledState = null;
  }

  @visibleForTesting
  Future<void> get settled => _pendingOperation;

  void _scheduleCurrentState() {
    final target = _target;
    if (_disposed || target == null) return;

    final shouldResume = _shouldResume;
    if (_lastScheduledState == shouldResume) return;
    _lastScheduledState = shouldResume;
    final targetGeneration = _targetGeneration;

    _pendingOperation = _pendingOperation.then((_) async {
      if (_disposed || targetGeneration != _targetGeneration) return;
      try {
        final operation = shouldResume ? target.resume : target.pause;
        await operation();
      } catch (error, stackTrace) {
        onError?.call(shouldResume, error, stackTrace);
      }
    });
  }
}

mixin ReaderWebViewLifecycleMixin<T extends StatefulWidget> on State<T> {
  ReaderWebViewLifecycleCoordinator? _readerWebViewLifecycle;
  AppLifecycleListener? _readerAppLifecycleListener;

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform != TargetPlatform.android) return;

    final lifecycle = ReaderWebViewLifecycleCoordinator(
      initialState: WidgetsBinding.instance.lifecycleState,
      onError: (resuming, error, stackTrace) {
        if (!kDebugMode) return;
        final action = resuming ? 'resume' : 'pause';
        debugPrint('[reader-webview-lifecycle] $action failed: $error');
      },
    );
    _readerWebViewLifecycle = lifecycle;
    _readerAppLifecycleListener = AppLifecycleListener(
      onStateChange: lifecycle.handleAppLifecycleState,
    );
  }

  void attachReaderWebViewLifecycle(InAppWebViewController controller) {
    _readerWebViewLifecycle?.attach(
      pause: controller.pause,
      resume: controller.resume,
    );
  }

  void detachReaderWebViewLifecycle() => _readerWebViewLifecycle?.detach();

  @override
  void dispose() {
    _readerAppLifecycleListener?.dispose();
    _readerWebViewLifecycle?.dispose();
    super.dispose();
  }
}
