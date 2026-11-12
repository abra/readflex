// Checks owned production package boundaries without resolving third-party code.
// Usage: dart run scripts/check_architecture.dart [repository root]
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

void main(List<String> arguments) {
  if (arguments.length > 1 || arguments.any((value) => value.startsWith('-'))) {
    stderr.writeln(
      'Usage: dart run scripts/check_architecture.dart [repo-root]',
    );
    exitCode = 64;
    return;
  }
  try {
    final violations = checkArchitecture(
      Directory(arguments.singleOrNull ?? '.'),
    );
    for (final violation in violations) {
      stderr.writeln(violation);
    }
    if (violations.isEmpty) {
      stdout.writeln('Owned production package boundaries are valid.');
    } else {
      stderr.writeln('${violations.length} architecture violation(s).');
      exitCode = 1;
    }
  } on FormatException catch (error) {
    stderr.writeln('Architecture configuration error: ${error.message}');
    exitCode = 64;
  } on FileSystemException catch (error) {
    stderr.writeln('Architecture input error: $error');
    exitCode = 64;
  }
}

/// A production dependency that violates an owned package boundary.
class ArchitectureViolation {
  const ArchitectureViolation(this.path, this.line, this.rule, this.message);

  final String path;
  final int line;
  final String rule;
  final String message;

  @override
  String toString() => '$path:$line [$rule] $message';
}

/// Checks the root app, packages/* and packages/features/*, scanning lib only.
/// Symbolic links and development dependencies are deliberately not traversed.
/// Invalid pubspecs throw [FormatException]; unreadable inputs throw
/// [FileSystemException], rather than silently passing an incomplete graph.
List<ArchitectureViolation> checkArchitecture(Directory root) {
  final rootPath = p.normalize(root.absolute.path);
  final packages = <_Package>[
    _Package.read(rootPath, isRoot: true),
    for (final directory in _directories(p.join(rootPath, 'packages')))
      if (_isFile(p.join(directory.path, 'pubspec.yaml')))
        _Package.read(directory.path),
    for (final directory in _directories(
      p.join(rootPath, 'packages', 'features'),
    ))
      if (_isFile(p.join(directory.path, 'pubspec.yaml')))
        _Package.read(directory.path, isFeature: true),
  ];
  final byName = <String, _Package>{};
  for (final package in packages) {
    if (byName.containsKey(package.name)) {
      throw FormatException('Duplicate owned package name: ${package.name}');
    }
    byName[package.name] = package;
  }
  final violations = <ArchitectureViolation>[];
  final edges = <String, Map<String, _Edge>>{
    for (final package in packages) package.name: {},
  };
  void report(String path, int line, String rule, String message) {
    violations.add(
      ArchitectureViolation(
        p.relative(path, from: rootPath).split(p.separator).join('/'),
        line,
        rule,
        message,
      ),
    );
  }

  void connect(_Package source, _Package target, String path, int line) {
    edges[source.name]!.putIfAbsent(target.name, () => _Edge(path, line));
    final rule = switch ((source, target)) {
      (_, final target) when target.isRoot && !source.isRoot => 'package-root',
      (final source, final target)
          when source.isFeature && target.isFeature && source != target =>
        'feature-sibling',
      (final source, final target)
          when !source.isRoot && !source.isFeature && target.isFeature =>
        'infrastructure-feature',
      (final source, final target)
          when source.isFeature && target.name == 'local_storage' =>
        'feature-storage',
      (final source, final target)
          when source.name == 'domain_models' && source != target =>
        'domain-purity',
      _ => null,
    };
    if (rule != null) {
      report(
        path,
        line,
        rule,
        '${source.name} must not depend on ${target.name}.',
      );
    }
  }

  _Package? owner(String path) {
    _Package? result;
    for (final package in packages) {
      if ((p.equals(package.directory, path) ||
              p.isWithin(package.directory, path)) &&
          (result == null ||
              package.directory.length > result.directory.length)) {
        result = package;
      }
    }
    return result;
  }

  for (final source in packages) {
    final declared = <String>{};
    for (final entry in source.dependencies.nodes.entries) {
      final name = entry.key.value;
      if (name is! String) {
        throw FormatException('${source.name}: invalid dependency name');
      }
      final line = entry.key.span.start.line + 1;
      final specification = entry.value.value;
      final dependencyPath = specification is YamlMap
          ? specification['path']
          : null;
      final targetPath = dependencyPath is String
          ? p.normalize(p.join(source.directory, dependencyPath))
          : null;
      final target =
          packages.where((item) => item.directory == targetPath).firstOrNull ??
          byName[name];
      declared.add(target?.name ?? name);
      if (target != null) connect(source, target, source.pubspec, line);
      if (source.name == 'domain_models' &&
          const {'flutter', 'material_ui', 'cupertino_ui'}.contains(name)) {
        report(
          source.pubspec,
          line,
          'domain-purity',
          'domain_models must not depend on Flutter or its UI libraries.',
        );
      }
    }
    for (final file in _dartFiles(source.lib)) {
      final parsed = parseString(
        content: file.readAsStringSync(),
        path: file.path,
        throwIfDiagnostics: false,
      );
      for (final directive in parsed.unit.directives) {
        final uris = <StringLiteral>[
          if (directive is UriBasedDirective) directive.uri,
          if (directive is PartOfDirective && directive.uri != null)
            directive.uri!,
          if (directive is NamespaceDirective)
            for (final configuration in directive.configurations)
              configuration.uri,
        ];
        for (final literal in uris) {
          final value = literal.stringValue;
          if (value == null) continue;
          final uri = Uri.tryParse(value);
          if (uri == null) continue;
          // Uri.parse normalizes dot segments, which could erase the package
          // name before an escaping path is checked against its public lib.
          final packageSegments = uri.scheme == 'package'
              ? value
                    .substring(value.indexOf(':') + 1)
                    .split('/')
                    .map(Uri.decodeComponent)
                    .toList()
              : const <String>[];
          final line = parsed.lineInfo.getLocation(literal.offset).lineNumber;
          if (value == 'package:flutter/material.dart' ||
              value == 'package:flutter/cupertino.dart') {
            report(
              file.path,
              line,
              'legacy-design-import',
              'Use standalone design libraries, or Flutter core imports for '
                  'presentation-neutral code.',
            );
          }
          if (source.name == 'domain_models' &&
              (value == 'dart:ui' ||
                  (uri.scheme == 'package' &&
                      const {
                        'flutter',
                        'material_ui',
                        'cupertino_ui',
                      }.contains(packageSegments.firstOrNull)))) {
            report(
              file.path,
              line,
              'domain-purity',
              'domain_models must not import Flutter, UI libraries or dart:ui.',
            );
          }
          _Package? target;
          _Package? uriPackage;
          String? targetFile;
          if (uri.scheme == 'package' && packageSegments.isNotEmpty) {
            uriPackage = byName[packageSegments.first];
            if (uriPackage != null) {
              targetFile = p.normalize(
                p.joinAll([uriPackage.lib, ...packageSegments.skip(1)]),
              );
              target = owner(targetFile) ?? uriPackage;
            }
          } else if (uri.scheme.isEmpty || uri.scheme == 'file') {
            targetFile = p.normalize(
              File.fromUri(file.uri.resolveUri(uri)).path,
            );
            target = owner(targetFile);
          }
          final publicOwner = uriPackage ?? target;
          if (publicOwner != null &&
              targetFile != null &&
              !p.isWithin(publicOwner.lib, targetFile)) {
            report(
              file.path,
              line,
              'non-public-import',
              'Use ${publicOwner.name} public APIs inside its lib directory.',
            );
          }
          if (target == null || target == source) continue;
          connect(source, target, file.path, line);
          if (!declared.contains(target.name)) {
            report(
              file.path,
              line,
              'undeclared-dependency',
              '${target.name} must be declared in ${source.name} dependencies.',
            );
          }
          if (uri.scheme != 'package') {
            report(
              file.path,
              line,
              'relative-package-import',
              'Use the public package:${target.name} API across package boundaries.',
            );
          }
          if (targetFile != null &&
              p.isWithin(p.join(target.lib, 'src'), targetFile)) {
            report(
              file.path,
              line,
              'private-import',
              '${source.name} must not access ${target.name}/src.',
            );
          }
        }
      }
    }
  }
  _checkCycles(edges, report);
  return violations..sort((a, b) {
    final path = a.path.compareTo(b.path);
    if (path != 0) return path;
    final line = a.line.compareTo(b.line);
    return line != 0 ? line : a.rule.compareTo(b.rule);
  });
}

class _Package {
  _Package(
    this.directory,
    this.name,
    this.dependencies,
    this.isRoot,
    this.isFeature,
  );

  factory _Package.read(
    String directory, {
    bool isRoot = false,
    bool isFeature = false,
  }) {
    final pubspec = p.join(directory, 'pubspec.yaml');
    if (!_isFile(pubspec)) {
      throw FormatException('$pubspec must be a regular file.');
    }
    Object? document;
    try {
      document = loadYaml(
        File(pubspec).readAsStringSync(),
        sourceUrl: Uri.file(pubspec),
      );
    } on YamlException catch (error) {
      throw FormatException('$pubspec: ${error.message}');
    }
    if (document is! YamlMap ||
        document['name'] is! String ||
        (document['name'] as String).isEmpty) {
      throw FormatException('$pubspec must declare a package name.');
    }
    final dependencies = document['dependencies'];
    if (dependencies != null && dependencies is! YamlMap) {
      throw FormatException('$pubspec dependencies must be a mapping.');
    }
    return _Package(
      directory,
      document['name'] as String,
      dependencies as YamlMap? ?? YamlMap(),
      isRoot,
      isFeature,
    );
  }

  final String directory;
  final String name;
  final YamlMap dependencies;
  final bool isRoot;
  final bool isFeature;
  String get lib => p.join(directory, 'lib');
  String get pubspec => p.join(directory, 'pubspec.yaml');
}

class _Edge {
  const _Edge(this.path, this.line);
  final String path;
  final int line;
}

List<Directory> _directories(String path) =>
    FileSystemEntity.typeSync(path, followLinks: false) ==
        FileSystemEntityType.directory
    ? (Directory(
          path,
        ).listSync(followLinks: false).whereType<Directory>().toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
    : const [];

Iterable<File> _dartFiles(String path) sync* {
  if (FileSystemEntity.typeSync(path, followLinks: false) !=
      FileSystemEntityType.directory) {
    return;
  }
  final entries = Directory(path).listSync(followLinks: false)
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final entry in entries) {
    if (entry is Directory) yield* _dartFiles(entry.path);
    if (entry is File && entry.path.endsWith('.dart')) yield entry;
  }
}

bool _isFile(String path) =>
    FileSystemEntity.typeSync(path, followLinks: false) ==
    FileSystemEntityType.file;

// At this repository's scale, reachability keeps cycle diagnostics simpler
// than a second graph abstraction. Emit one real cycle per connected component.
void _checkCycles(
  Map<String, Map<String, _Edge>> edges,
  void Function(String, int, String, String) report,
) {
  Set<String> reachable(String start, {bool reverse = false}) {
    final seen = <String>{};
    void visit(String name) {
      if (!seen.add(name)) return;
      for (final next
          in reverse
              ? edges.keys.where((key) => edges[key]!.containsKey(name))
              : edges[name]!.keys) {
        visit(next);
      }
    }

    visit(start);
    return seen;
  }

  final checked = <String>{};
  for (final name in edges.keys) {
    if (checked.contains(name)) continue;
    final component = reachable(
      name,
    ).intersection(reachable(name, reverse: true));
    checked.addAll(component);
    if (component.length == 1 && !edges[name]!.containsKey(name)) continue;
    final path = [name];
    bool findCycle(String current) {
      for (final next in edges[current]!.keys.where(component.contains)) {
        if (next == name) {
          path.add(name);
          return true;
        }
        if (path.contains(next)) continue;
        path.add(next);
        if (findCycle(next)) return true;
        path.removeLast();
      }
      return false;
    }

    findCycle(name);
    final edge = edges[path.first]![path[1]]!;
    report(
      edge.path,
      edge.line,
      'dependency-cycle',
      'Owned dependency cycle: ${path.join(' → ')}.',
    );
  }
}
