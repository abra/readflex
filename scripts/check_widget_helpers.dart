// Fails when production code declares a function, method or getter that
// returns a widget, or a list of widgets, instead of a widget class.
//
// Usage: dart run scripts/check_widget_helpers.dart <package root>...
//
// Each package's lib/ is resolved, so inferred return types count too. Not
// flagged: @override members (framework hooks such as build or
// childForSlot), abstract members, and closures passed as builders. Files
// excluded by the package's analysis options (generated code) are skipped.
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/file_system/file_system.dart';

Future<void> main(List<String> packageRoots) async {
  if (packageRoots.isEmpty) {
    stderr.writeln(
      'Usage: dart run scripts/check_widget_helpers.dart <package root>...',
    );
    exitCode = 64;
    return;
  }
  final libraries = [
    for (final root in packageRoots)
      Directory(root).absolute.uri.resolve('lib').toFilePath(),
  ].where((path) => Directory(path).existsSync()).toList();
  final helpers = await findWidgetHelpers(libraries);
  final cwd = '${Directory.current.path}${Platform.pathSeparator}';
  for (final helper in helpers) {
    final path = helper.path.startsWith(cwd)
        ? helper.path.substring(cwd.length)
        : helper.path;
    stdout.writeln(
      '$path:${helper.line} • ${helper.name} returns '
      '${helper.type}',
    );
  }
  if (helpers.isEmpty) {
    stdout.writeln('No widget-returning helpers.');
  } else {
    stderr.writeln(
      '${helpers.length} widget-returning helper(s): extract a widget class.',
    );
    exitCode = 1;
  }
}

/// A declaration that builds widgets outside a widget class.
class WidgetHelper {
  const WidgetHelper({
    required this.path,
    required this.line,
    required this.name,
    required this.type,
  });

  final String path;
  final int line;
  final String name;
  final String type;
}

/// Resolves the Dart files under [paths] (absolute, normalized) and returns
/// their widget-returning helpers in path and line order.
Future<List<WidgetHelper>> findWidgetHelpers(
  List<String> paths, {
  ResourceProvider? resourceProvider,
}) async {
  final collection = AnalysisContextCollection(
    includedPaths: paths,
    resourceProvider: resourceProvider,
    sdkPath: _flutterDartSdkPath(),
  );
  try {
    final helpers = <WidgetHelper>[];
    for (final context in collection.contexts) {
      for (final path in context.contextRoot.analyzedFiles()) {
        if (!path.endsWith('.dart')) continue;
        final result = await context.currentSession.getResolvedUnit(path);
        if (result is ResolvedUnitResult) {
          result.unit.accept(_WidgetHelperVisitor(result, helpers));
        }
      }
    }
    return helpers..sort(
      (a, b) => a.path == b.path
          ? a.line.compareTo(b.line)
          : a.path.compareTo(b.path),
    );
  } finally {
    await collection.dispose();
  }
}

// Inside `flutter test` the executable is the engine's tester, not `dart`,
// so the analyzer cannot find its SDK on its own.
String? _flutterDartSdkPath() {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) return null;
  return Directory(flutterRoot).uri.resolve('bin/cache/dart-sdk').toFilePath();
}

class _WidgetHelperVisitor extends RecursiveAstVisitor<void> {
  _WidgetHelperVisitor(this._result, this._helpers);

  final ResolvedUnitResult _result;
  final List<WidgetHelper> _helpers;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final isOverride = node.metadata.any((a) => a.name.name == 'override');
    if (!node.isSetter && !node.isAbstract && !isOverride) {
      _check(node.name, node.declaredFragment?.element.returnType);
    }
    super.visitMethodDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (!node.isSetter) {
      _check(node.name, node.declaredFragment?.element.returnType);
    }
    super.visitFunctionDeclaration(node);
  }

  void _check(Token name, DartType? type) {
    if (type is! InterfaceType || !_buildsWidgets(type)) return;
    _helpers.add(
      WidgetHelper(
        path: _result.path,
        line: _result.lineInfo.getLocation(name.offset).lineNumber,
        name: name.lexeme,
        type: type.getDisplayString(),
      ),
    );
  }
}

bool _buildsWidgets(InterfaceType type) {
  if (_isWidget(type)) return true;
  for (final candidate in [type, ...type.allSupertypes]) {
    final element = candidate.element;
    if (element.name == 'Iterable' && element.library.isDartCore) {
      final item = candidate.typeArguments.single;
      return item is InterfaceType && _isWidget(item);
    }
  }
  return false;
}

bool _isWidget(InterfaceType type) => [type, ...type.allSupertypes].any(
  (candidate) =>
      candidate.element.name == 'Widget' &&
      candidate.element.library.uri.toString() ==
          'package:flutter/src/widgets/framework.dart',
);
