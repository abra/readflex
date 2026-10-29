import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:readflex/app/dependency_container.dart';

/// Disposes the app's dependencies when the app detaches.
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
    // Detach is terminal for this runtime. A new app instance needs new
    // resources. The OS may still terminate without delivering detach.
    if (_detached || state != AppLifecycleState.detached) return;
    _detached = true;
    unawaited(widget.dependencies.dispose());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
