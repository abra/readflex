// Fails when production code declares a function, method or getter that
// returns a widget, or a list of widgets, instead of a widget class. Also
// rejects infrastructure fields/constructor arguments in feature Views.
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
  final checks = await _findDeclarations(libraries);
  final helpers = checks.helpers;
  final dependencies = checks.dependencies;
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
  for (final dependency in dependencies) {
    final path = dependency.path.startsWith(cwd)
        ? dependency.path.substring(cwd.length)
        : dependency.path;
    stdout.writeln(
      '$path:${dependency.line} • ${dependency.name} receives '
      '${dependency.type}',
    );
  }
  if (dependencies.isEmpty) {
    stdout.writeln('No infrastructure dependencies in feature Views.');
  } else {
    stderr.writeln(
      '${dependencies.length} View dependency violation(s): inject '
      'infrastructure into a Bloc/Cubit through Screen/Sheet instead.',
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

/// An infrastructure object received by a feature View or its State.
class ViewDependency {
  const ViewDependency({
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
}) async => (await _findDeclarations(
  paths,
  resourceProvider: resourceProvider,
  checkViews: false,
)).helpers;

/// Checks direct fields and constructor parameters of feature widgets named
/// `*View`, and their `State<View>` classes. Does not inspect captured callbacks,
/// local dependency lookups or unnamed child widgets. Screen/Sheet composition
/// and rendering hosts remain outside this deliberately bounded check.
Future<List<ViewDependency>> findViewDependencies(
  List<String> paths, {
  ResourceProvider? resourceProvider,
}) async => (await _findDeclarations(
  paths,
  resourceProvider: resourceProvider,
  checkHelpers: false,
)).dependencies;

class _DeclarationChecks {
  final helpers = <WidgetHelper>[];
  final dependencies = <ViewDependency>[];
}

Future<_DeclarationChecks> _findDeclarations(
  List<String> paths, {
  ResourceProvider? resourceProvider,
  bool checkHelpers = true,
  bool checkViews = true,
}) async {
  final collection = AnalysisContextCollection(
    includedPaths: paths,
    resourceProvider: resourceProvider,
    sdkPath: _flutterDartSdkPath(),
  );
  try {
    final checks = _DeclarationChecks();
    for (final context in collection.contexts) {
      for (final path in context.contextRoot.analyzedFiles()) {
        if (!path.endsWith('.dart')) continue;
        final result = await context.currentSession.getResolvedUnit(path);
        if (result is ResolvedUnitResult) {
          result.unit.accept(
            _DeclarationVisitor(
              result,
              checks,
              checkHelpers: checkHelpers,
              checkViews: checkViews && _isFeaturePath(path),
            ),
          );
        }
      }
    }
    checks.helpers.sort(
      (a, b) => a.path == b.path
          ? a.line.compareTo(b.line)
          : a.path.compareTo(b.path),
    );
    checks.dependencies.sort(
      (a, b) => a.path == b.path
          ? a.line.compareTo(b.line)
          : a.path.compareTo(b.path),
    );
    return checks;
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

class _DeclarationVisitor extends RecursiveAstVisitor<void> {
  _DeclarationVisitor(
    this._result,
    this._checks, {
    required this.checkHelpers,
    required this.checkViews,
  });

  final ResolvedUnitResult _result;
  final _DeclarationChecks _checks;
  final bool checkHelpers;
  final bool checkViews;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final type = node.declaredFragment?.element.thisType;
    final body = node.body;
    if (checkViews &&
        type != null &&
        (_isView(type) || _isViewState(type)) &&
        body is BlockClassBody) {
      final reported = <String>{};
      // A field-formal parameter and its field are the same dependency;
      // prefer the field's declaration instead of emitting both locations.
      for (final member in body.members.whereType<FieldDeclaration>()) {
        for (final variable in member.fields.variables) {
          _checkDependency(
            type.element.name!,
            variable.name,
            variable.declaredFragment?.element.type,
            reported,
          );
        }
      }
      for (final member in body.members.whereType<ConstructorDeclaration>()) {
        for (final parameter in member.parameters.parameters) {
          final name = parameter.name;
          if (name == null) continue;
          _checkDependency(
            type.element.name!,
            name,
            parameter.declaredFragment?.element.type,
            reported,
          );
        }
      }
    }
    super.visitClassDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final isOverride = node.metadata.any((a) => a.name.name == 'override');
    if (checkHelpers && !node.isSetter && !node.isAbstract && !isOverride) {
      _check(node.name, node.declaredFragment?.element.returnType);
    }
    super.visitMethodDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (checkHelpers && !node.isSetter) {
      _check(node.name, node.declaredFragment?.element.returnType);
    }
    super.visitFunctionDeclaration(node);
  }

  void _check(Token name, DartType? type) {
    if (type is! InterfaceType || !_buildsWidgets(type)) return;
    _checks.helpers.add(
      WidgetHelper(
        path: _result.path,
        line: _result.lineInfo.getLocation(name.offset).lineNumber,
        name: name.lexeme,
        type: type.getDisplayString(),
      ),
    );
  }

  void _checkDependency(
    String className,
    Token name,
    DartType? type,
    Set<String> reported,
  ) {
    if (!_hasInfrastructure(type) || !reported.add(name.lexeme)) return;
    _checks.dependencies.add(
      ViewDependency(
        path: _result.path,
        line: _result.lineInfo.getLocation(name.offset).lineNumber,
        name: '$className.${name.lexeme}',
        type: type!.getDisplayString(),
      ),
    );
  }
}

bool _isFeaturePath(String path) =>
    path.replaceAll('\\', '/').contains('/packages/features/');

bool _isView(InterfaceType type) =>
    (type.element.name?.endsWith('View') ?? false) && _isWidget(type);

bool _isViewState(InterfaceType type) => type.allSupertypes.any((candidate) {
  if (!_isFlutterType(candidate, 'State')) return false;
  final widget = candidate.typeArguments.single;
  return widget is InterfaceType && _isView(widget);
});

bool _hasInfrastructure(DartType? type) =>
    _containsInfrastructure(type, <DartType>{});

bool _containsInfrastructure(DartType? type, Set<DartType> visited) {
  if (type == null || !visited.add(type)) return false;
  if (type is TypeParameterType) {
    return _containsInfrastructure(type.bound, visited);
  }
  if (type is RecordType) {
    return [...type.positionalFields, ...type.namedFields].any(
      (field) => _containsInfrastructure(field.type, visited),
    );
  }
  if (type is! InterfaceType) return false;
  return [type, ...type.allSupertypes].any(_isInfrastructure) ||
      type.typeArguments.any(
        (argument) => _containsInfrastructure(argument, visited),
      );
}

bool _isInfrastructure(InterfaceType type) {
  final name = type.element.name ?? '';
  final uri = type.element.library.uri;
  final package = uri.scheme == 'package' ? uri.pathSegments.first : null;
  // dart:io re-exports the SDK's HTTP interface from dart:_http.
  if (uri.scheme == 'dart' &&
      const {'io', '_http'}.contains(uri.path) &&
      name == 'HttpClient') {
    return true;
  }
  if (uri.scheme == 'dart' || package == 'flutter') return false;
  if (const ['Repository', 'Service', 'Parser', 'Dao', 'DAO'].any(
        name.endsWith,
      ) ||
      name == 'AppDatabase') {
    return true;
  }
  if (package?.endsWith('_service') == true && name.endsWith('Storage')) {
    return true;
  }
  return switch (package) {
    'http' => name == 'Client',
    'dio' => name == 'Dio',
    'drift' => const {
      'DatabaseConnectionUser',
      'DatabaseAccessor',
      'QueryExecutor',
    }.contains(name),
    'pagecraft' => const {
      'EpubBook',
      'Fb2Book',
      'MobiBook',
      'Mobi6Book',
      'Kf8Book',
      'ComicBook',
      'PdfBook',
      'DjvuBook',
      'TextBookSource',
      'ArticleTextSource',
      'EpubFiles',
      'ComicPageSource',
      'FixedPageSource',
      'ZipArchive',
      'PdbFile',
      'MobiContainer',
    }.contains(name),
    _ => false,
  };
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
  (candidate) => _isFlutterType(candidate, 'Widget'),
);

bool _isFlutterType(InterfaceType type, String name) =>
    type.element.name == name &&
    type.element.library.uri.toString() ==
        'package:flutter/src/widgets/framework.dart';
