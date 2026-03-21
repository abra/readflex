// Widget tree root: assembles the top-level widget hierarchy.
//
// Kept separate from starter.dart so that the bootstrap layer has no
// knowledge of widgets, and the widget layer has no knowledge of
// initialization logic.

import 'package:flutter/widgets.dart';
import 'package:readflex/app/composition.dart';
import 'package:readflex/app/dependency_scope.dart';
import 'package:readflex/app/material_context.dart';

class RootContext extends StatelessWidget {
  const RootContext({required this.compositionResult, super.key});

  final CompositionResult compositionResult;

  @override
  Widget build(BuildContext context) {
    return DependenciesScope(
      dependencies: compositionResult.dependencies,
      child: const MaterialContext(),
    );
  }
}
