import 'package:flutter/material.dart';

import 'auth_service.dart';

/// [InheritedWidget] that exposes an [AuthService] to descendant widgets.
///
/// Mounted once near the app root (`RootContext`). Descendants obtain the
/// service via [AuthScope.of] and can call its methods or subscribe to
/// [AuthService.statusStream] for reactive auth state.
class AuthScope extends InheritedWidget {
  const AuthScope({required this.service, required super.child, super.key});

  final AuthService service;

  /// Returns the [AuthService] from the nearest ancestor [AuthScope].
  /// Throws if no [AuthScope] is present in the tree.
  static AuthService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    if (scope == null) {
      throw FlutterError(
        'AuthScope.of() called with a context that does not contain an AuthScope.\n'
        'Ensure the widget tree includes an AuthScope ancestor.',
      );
    }
    return scope.service;
  }

  @override
  bool updateShouldNotify(AuthScope old) => service != old.service;
}
