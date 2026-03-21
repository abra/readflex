// InheritedWidget that exposes DependenciesContainer to the widget tree.
//
// Avoids prop-drilling: any widget in the tree can call
// DependenciesScope.of(context) to access a dependency without
// it being passed through every intermediate constructor.

import 'package:flutter/widgets.dart';
import 'package:nota/app/dependency_container.dart';
import 'package:nota/utils/inherited_extension.dart';

/// A scope that provides [DependenciesContainer] to the application.
class DependenciesScope extends StatelessWidget {
  const DependenciesScope({
    required this.dependencies,
    required this.child,
    super.key,
  });

  final DependenciesContainer dependencies;
  final Widget child;

  /// Get the dependencies from the [context].
  static DependenciesContainer of(BuildContext context) =>
      context.inhOf<_DependenciesInherited>(listen: false).dependencies;

  @override
  Widget build(BuildContext context) {
    return _DependenciesInherited(dependencies: dependencies, child: child);
  }
}

class _DependenciesInherited extends InheritedWidget {
  const _DependenciesInherited({
    required super.child,
    required this.dependencies,
  });

  final DependenciesContainer dependencies;

  @override
  bool updateShouldNotify(_DependenciesInherited oldWidget) =>
      !identical(dependencies, oldWidget.dependencies);
}
