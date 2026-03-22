import 'package:flutter/material.dart';

import 'auth_service.dart';

/// Provides [AuthService] to the widget tree via [InheritedWidget].
class AuthScope extends InheritedWidget {
  const AuthScope({required this.service, required super.child, super.key});

  final AuthService service;

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
