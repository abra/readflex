// Widget tree root: assembles the top-level widget hierarchy.
//
// Kept separate from starter.dart so that the bootstrap layer has no
// knowledge of widgets, and the widget layer has no knowledge of
// initialization logic.

import 'package:flutter/widgets.dart';
import 'package:nota/app/composition.dart';
import 'package:nota/app/dependency_scope.dart';
import 'package:nota/app/material_context.dart';
import 'package:preferences_service/preferences_service.dart'
    show PreferencesScope;

class RootContext extends StatelessWidget {
  const RootContext({required this.compositionResult, super.key});

  final CompositionResult compositionResult;

  @override
  Widget build(BuildContext context) {
    return DependenciesScope(
      dependencies: compositionResult.dependencies,
      child: PreferencesScope(
        service: compositionResult.dependencies.preferencesService,
        child: const MaterialContext(),
      ),
    );
  }
}
