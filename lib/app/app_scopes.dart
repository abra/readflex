// Mounts the running application's dependencies and reactive preference scopes.

import 'package:connectivity_service/connectivity_service.dart'
    show ConnectivityScope;
import 'package:flutter/widgets.dart';
import 'package:preferences_service/preferences_service.dart'
    show PreferencesScope;
import 'package:readflex/app/app_lifecycle.dart';
import 'package:readflex/app/dependency_container.dart';
import 'package:readflex/app/dependency_scope.dart';
import 'package:readflex/app/readflex_app.dart';

class AppScopes extends StatelessWidget {
  const AppScopes({required this.dependencies, super.key});

  final DependenciesContainer dependencies;

  @override
  Widget build(BuildContext context) {
    return DependenciesScope(
      dependencies: dependencies,
      child: PreferencesScope(
        service: dependencies.preferencesService,
        child: ConnectivityScope(
          service: dependencies.connectivityService,
          child: AppLifecycle(
            dependencies: dependencies,
            child: const ReadflexApp(),
          ),
        ),
      ),
    );
  }
}
