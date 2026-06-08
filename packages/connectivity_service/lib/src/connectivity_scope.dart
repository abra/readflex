import 'package:flutter/widgets.dart';

import 'connectivity_service.dart';

/// Listens to [ConnectivityService] and exposes [ConnectivityStatus] to the
/// subtree via an [InheritedWidget].
///
/// Mirrors the shape of [PreferencesScope] / [AuthScope]: a [StatelessWidget]
/// owning a [StreamBuilder] that re-wraps the subtree in a small inherited
/// holder each time the status changes.
///
/// State here is a single enum value, so a plain [InheritedWidget] suffices —
/// no [InheritedModel] aspects needed.
class ConnectivityScope extends StatefulWidget {
  const ConnectivityScope({
    required this.service,
    required this.child,
    super.key,
  });

  final ConnectivityService service;
  final Widget child;

  /// Returns the current [ConnectivityStatus] and subscribes the calling
  /// widget to changes.
  static ConnectivityStatus of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_ConnectivityInherited>();
    if (scope == null) {
      throw FlutterError(
        'ConnectivityScope.of() called with a context that does not contain '
        'a ConnectivityScope.\n'
        'Ensure the widget tree includes a ConnectivityScope ancestor.',
      );
    }
    return scope.status;
  }

  @override
  State<ConnectivityScope> createState() => _ConnectivityScopeState();
}

class _ConnectivityScopeState extends State<ConnectivityScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(ConnectivityScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) widget.service.refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.service.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConnectivityStatus>(
      stream: widget.service.statusStream,
      initialData: widget.service.status,
      builder: (context, snapshot) {
        return _ConnectivityInherited(
          status: snapshot.data ?? widget.service.status,
          child: widget.child,
        );
      },
    );
  }
}

class _ConnectivityInherited extends InheritedWidget {
  const _ConnectivityInherited({required this.status, required super.child});

  final ConnectivityStatus status;

  @override
  bool updateShouldNotify(_ConnectivityInherited old) => status != old.status;
}
