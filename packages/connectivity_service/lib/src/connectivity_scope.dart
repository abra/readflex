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
class ConnectivityScope extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return StreamBuilder<ConnectivityStatus>(
      stream: service.statusStream,
      initialData: service.status,
      builder: (context, snapshot) {
        return _ConnectivityInherited(
          status: snapshot.data ?? service.status,
          child: child,
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
