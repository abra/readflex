import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:readflex/app/dependency_container.dart';

/// Restarts a stopped reader server on iOS resume; disposes on app detach.
class AppLifecycle extends StatefulWidget {
  const AppLifecycle({
    required this.dependencies,
    required this.child,
    super.key,
  });

  final DependenciesContainer dependencies;
  final Widget child;

  @override
  State<AppLifecycle> createState() => _AppLifecycleState();
}

class _AppLifecycleState extends State<AppLifecycle>
    with WidgetsBindingObserver {
  Future<void>? _restartFuture;
  bool _detached = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_detached) return;
    final dependencies = widget.dependencies;
    // Detach is terminal for this runtime. A new app instance needs new resources.
    if (state == AppLifecycleState.detached) {
      _detached = true;
      unawaited(_disposeAfterRestart(dependencies));
      return;
    }
    // iOS can close the loopback socket while the app is suspended.
    if (state == AppLifecycleState.resumed &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        !dependencies.readerServer.isRunning &&
        _restartFuture == null) {
      _restartFuture = _restartReaderServer(dependencies);
    }
  }

  Future<void> _disposeAfterRestart(DependenciesContainer dependencies) async {
    // A pending bind must finish before disposal, or it could reopen the socket
    // after cleanup. The OS may still terminate without delivering detach.
    await _restartFuture;
    await dependencies.dispose();
  }

  Future<void> _restartReaderServer(DependenciesContainer dependencies) async {
    try {
      await dependencies.readerServer.start();
    } on Object catch (error, stackTrace) {
      dependencies.logger.error(
        'ReaderServer restart after resume failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _restartFuture = null;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
