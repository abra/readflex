import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:readflex/app/dependency_container.dart';

abstract final class AppRoutes {
  static const home = '/';
}

GoRouter buildRouter({required DependenciesContainer dependencies}) {
  dependencies.logger.debug('buildRouter: GoRouter created');

  return GoRouter(
    debugLogDiagnostics: dependencies.config.isDev,
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const Placeholder(),
      ),
    ],
  );
}
