@Tags(['tooling'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../scripts/check_architecture.dart';
import '../../scripts/src/tool_support.dart';

void main() {
  late _Repository repository;
  setUp(() {
    repository = _Repository(
      Directory.systemTemp.createTempSync('architecture-'),
    );
    repository.package('.', 'app');
  });
  tearDown(() => repository.root.deleteSync(recursive: true));

  test('allows root composition, public APIs and external service DTOs', () {
    repository.package(
      '.',
      'app',
      dependencies: {'library_feature': '{path: packages/features/catalog}'},
    );
    repository.package(
      'packages/features/catalog',
      'library_feature',
      dependencies: {'api_service': '{path: ../../api_service}'},
    );
    repository.package(
      'packages/api_service',
      'api_service',
      dependencies: {'domain_models': '{path: ../domain_models}'},
    );
    repository.package(
      'packages/domain_models',
      'domain_models',
      dependencies: {'equatable': 'any'},
    );
    repository.write(
      'lib/main.dart',
      "import 'package:library_feature/library.dart';",
    );
    repository.write(
      'packages/features/catalog/lib/library.dart',
      "import 'package:api_service/api_service.dart';\nimport 'package:external_client/dto.dart';",
    );
    repository.write(
      'packages/api_service/lib/api_service.dart',
      "export 'package:domain_models/domain_models.dart';",
    );
    repository.write(
      'packages/domain_models/lib/domain_models.dart',
      "import 'package:equatable/equatable.dart';",
    );
    expect(repository.check(), isEmpty);
  });

  test(
    'uses pubspec names rather than feature directory names or import aliases',
    () {
      repository.package(
        'packages/features/catalog',
        'library_feature',
        dependencies: {'practice': '{path: ../vocabulary}'},
      );
      repository.package('packages/features/vocabulary', 'practice');
      repository.write(
        'packages/features/catalog/lib/library.dart',
        "// import 'package:practice/comment.dart';\nimport 'package:practice/practice.dart' as vocabulary;",
      );
      final violations = repository.check();
      expect(
        violations.where((item) => item.rule == 'feature-sibling'),
        hasLength(2),
      );
      expect(
        violations.any(
          (item) =>
              item.path == 'packages/features/catalog/lib/library.dart' &&
              item.line == 2 &&
              item.message.contains('library_feature'),
        ),
        isTrue,
      );
      expect(
        violations.any(
          (item) => item.path.endsWith('pubspec.yaml') && item.line == 3,
        ),
        isTrue,
      );
    },
  );

  test(
    'resolves local dependency paths even if their key disguises the target',
    () {
      repository.package(
        'packages/features/a',
        'a',
        dependencies: {'harmless_alias': '{path: ../b}'},
      );
      repository.package('packages/features/b', 'b');
      expect(repository.rules(), contains('feature-sibling'));
    },
  );

  test(
    'checks unused production dependencies for all forbidden directions',
    () {
      repository.package(
        'packages/service',
        'service',
        dependencies: {
          'practice': '{path: ../features/practice}',
          'app': '{path: ../..}',
        },
      );
      repository.package(
        'packages/features/practice',
        'practice',
        dependencies: {'local_storage': '{path: ../../local_storage}'},
      );
      repository.package('packages/local_storage', 'local_storage');
      expect(
        repository.rules(),
        containsAll([
          'infrastructure-feature',
          'package-root',
          'feature-storage',
        ]),
      );
    },
  );

  test(
    'ignores dev dependencies, test files, benchmarks and nested third party packages',
    () {
      repository.package(
        'packages/service',
        'service',
        development: {'practice': '{path: ../features/practice}'},
      );
      repository.package(
        'packages/features/practice',
        'practice',
        development: {'service': '{path: ../../service}'},
      );
      repository.write(
        'packages/service/test/service_test.dart',
        "import 'package:practice/practice.dart';",
      );
      repository.write(
        'test/application_test.dart',
        "import 'package:practice/practice.dart';",
      );
      repository.package(
        'benchmarks/example',
        'benchmark',
        dependencies: {'practice': 'any'},
      );
      repository.package(
        'third_party/external',
        'external',
        dependencies: {'practice': 'any'},
      );
      repository.package(
        'packages/service/third_party/external',
        'nested',
        dependencies: {'practice': 'any'},
      );
      expect(repository.check(), isEmpty);
    },
  );

  test('production imports cannot use dev-only owned dependencies', () {
    repository.package('packages/a', 'a', development: {'b': '{path: ../b}'});
    repository.package('packages/b', 'b');
    repository.write('packages/a/lib/a.dart', "import 'package:b/b.dart';");
    expect(repository.rules(), ['undeclared-dependency']);
  });

  test('checks every conditional import and export URI', () {
    repository.package(
      'packages/features/a',
      'a',
      dependencies: {'b': '{path: ../b}', 'c': '{path: ../c}'},
    );
    repository.package('packages/features/b', 'b');
    repository.package('packages/features/c', 'c');
    repository.write('packages/features/a/lib/a.dart', """
import 'local.dart'
  if (dart.library.io) 'package:b/b.dart'
  if (dart.library.html) 'package:c/c.dart';
export 'local.dart' if (dart.library.io) 'package:b/b.dart';
""");
    final imports = repository.check().where(
      (item) => item.path.endsWith('a.dart') && item.rule == 'feature-sibling',
    );
    expect(imports.map((item) => item.line), [2, 3, 4]);
  });

  for (final directive in ['import', 'export', 'part', 'part of']) {
    test('resolves a cross-package relative $directive URI', () {
      repository.package(
        'packages/a',
        'a',
        dependencies: {'b': '{path: ../b}'},
      );
      repository.package('packages/b', 'b');
      repository.write(
        'packages/a/lib/a.dart',
        "$directive '../../b/lib/b.dart';",
      );
      repository.write('packages/b/lib/b.dart', 'library;');
      expect(repository.rules(), ['relative-package-import']);
    });
  }

  test('allows same-package private imports and parts', () {
    repository.package('packages/a', 'a');
    repository.write(
      'packages/a/lib/a.dart',
      "import 'package:a/src/internal.dart';\npart 'src/part.dart';",
    );
    repository.write('packages/a/lib/src/internal.dart', 'library;');
    repository.write('packages/a/lib/src/part.dart', "part of '../a.dart';");
    expect(repository.check(), isEmpty);
  });

  for (final directory in ['test', 'bin']) {
    test('detects owned feature dependencies through a $directory bridge', () {
      repository.package('packages/a', 'a');
      repository.package('packages/features/b', 'b');
      repository.write(
        'packages/a/lib/a.dart',
        "import '../../features/b/$directory/bridge.dart';",
      );
      repository.write(
        'packages/features/b/$directory/bridge.dart',
        "export '../lib/b.dart';",
      );
      expect(
        repository.rules(),
        containsAll([
          'infrastructure-feature',
          'non-public-import',
          'relative-package-import',
          'undeclared-dependency',
        ]),
      );
      expect(repository.check().map((item) => item.path).toSet(), {
        'packages/a/lib/a.dart',
      });
    });
  }

  test('resolves sibling feature ownership outside lib', () {
    repository.package('packages/features/a', 'a');
    repository.package('packages/features/b', 'b');
    repository.write(
      'packages/features/a/lib/a.dart',
      "import '../../b/test/bridge.dart';",
    );
    expect(
      repository.rules(),
      containsAll(['feature-sibling', 'non-public-import']),
    );
  });

  test('rejects package URI escapes into non-public directories', () {
    repository.package('packages/a', 'a', dependencies: {'b': '{path: ../b}'});
    repository.package('packages/b', 'b');
    repository.write(
      'packages/a/lib/a.dart',
      "import 'package:b/../test/bridge.dart';",
    );
    expect(repository.rules(), ['non-public-import']);
  });

  test('package URI escapes use the actual target package ownership', () {
    repository.package('packages/a', 'a', dependencies: {'b': '{path: ../b}'});
    repository.package('packages/b', 'b');
    repository.package('packages/features/c', 'c');
    repository.write(
      'packages/a/lib/a.dart',
      "import 'package:b/../../features/c/test/bridge.dart';",
    );
    expect(
      repository.rules(),
      containsAll([
        'infrastructure-feature',
        'non-public-import',
        'undeclared-dependency',
      ]),
    );
  });

  test('root scripts remain app-owned when imported by a package', () {
    repository.package('packages/features/a', 'a');
    repository.write(
      'packages/features/a/lib/a.dart',
      "import '../../../../scripts/bridge.dart';",
    );
    repository.write('scripts/bridge.dart', "export '../lib/main.dart';");
    expect(
      repository.rules(),
      containsAll(['package-root', 'non-public-import']),
    );
  });

  for (final directive in ['import', 'export', 'part', 'part of']) {
    test('rejects same-package $directive targets outside lib', () {
      repository.package('packages/a', 'a');
      repository.write(
        'packages/a/lib/a.dart',
        "$directive '../test/bridge.dart';",
      );
      repository.write(
        'packages/a/test/bridge.dart',
        "export 'package:app/main.dart';",
      );
      expect(repository.rules(), ['non-public-import']);
    });
  }

  test('forbids another package src through package and relative URIs', () {
    repository.package('packages/a', 'a', dependencies: {'b': '{path: ../b}'});
    repository.package('packages/b', 'b');
    repository.write(
      'packages/a/lib/a.dart',
      "import 'package:b/src/internal.dart';\nexport '../../b/lib/src/internal.dart';",
    );
    final violations = repository.check();
    expect(
      violations
          .where((item) => item.rule == 'private-import')
          .map((item) => item.line),
      [1, 2],
    );
    expect(
      violations.where((item) => item.rule == 'relative-package-import'),
      hasLength(1),
    );
  });

  test('rejects legacy design imports but allows core and standalone UI', () {
    repository.write(
      'lib/main.dart',
      "import 'package:flutter/material.dart';\n"
          "export 'package:flutter/cupertino.dart';\n"
          "import 'package:flutter/widgets.dart';\n"
          "import 'package:material_ui/material_ui.dart';\n"
          "import 'package:cupertino_ui/cupertino_ui.dart';\n"
          "// import 'package:flutter/material.dart';",
    );
    final violations = repository.check();
    expect(violations.map((item) => item.rule), [
      'legacy-design-import',
      'legacy-design-import',
    ]);
    expect(violations.map((item) => item.line), [1, 2]);
  });

  test('domain models cannot depend on standalone UI libraries', () {
    repository.package(
      'packages/model',
      'domain_models',
      dependencies: {'material_ui': 'any', 'cupertino_ui': 'any'},
    );
    repository.write(
      'packages/model/lib/model.dart',
      "import 'package:material_ui/material_ui.dart';\n"
          "export 'package:cupertino_ui/cupertino_ui.dart';",
    );
    expect(
      repository.check().where((item) => item.rule == 'domain-purity'),
      hasLength(4),
    );
  });

  test('domain models remain independent of owned packages and Flutter', () {
    repository.package(
      'packages/model',
      'domain_models',
      dependencies: {
        'service': '{path: ../service}',
        'flutter': '{sdk: flutter}',
      },
    );
    repository.package('packages/service', 'service');
    repository.write(
      'packages/model/lib/model.dart',
      "import 'dart:ui';\nexport 'package:flutter/widgets.dart';\nimport 'package:service/service.dart';",
    );
    expect(
      repository.check().where((item) => item.rule == 'domain-purity'),
      hasLength(5),
    );
  });

  test(
    'finds cycles from unused runtime declarations and reports a real path',
    () {
      repository.package(
        'packages/a',
        'a',
        dependencies: {'b': '{path: ../b}'},
      );
      repository.package(
        'packages/b',
        'b',
        dependencies: {'c': '{path: ../c}'},
      );
      repository.package(
        'packages/c',
        'c',
        dependencies: {'a': '{path: ../a}'},
      );
      final cycles = repository
          .check()
          .where((item) => item.rule == 'dependency-cycle')
          .toList();
      expect(cycles, hasLength(1));
      expect(cycles.single.message, 'Owned dependency cycle: a → b → c → a.');
      expect(cycles.single.path, 'packages/a/pubspec.yaml');
      expect(cycles.single.line, 3);
    },
  );

  test('actual imports and relative paths participate in cycle detection', () {
    repository.package('packages/a', 'a');
    repository.package('packages/b', 'b');
    repository.write('packages/a/lib/a.dart', "import 'package:b/b.dart';");
    repository.write('packages/b/lib/b.dart', "import '../../a/lib/a.dart';");
    expect(
      repository.rules(),
      containsAll([
        'dependency-cycle',
        'relative-package-import',
        'undeclared-dependency',
      ]),
    );
  });

  test('reports a declared self dependency as a cycle', () {
    repository.package('packages/a', 'a', dependencies: {'a': '{path: .}'});
    expect(repository.rules(), ['dependency-cycle']);
  });

  test('comments and string contents do not create dependencies', () {
    repository.package('packages/a', 'a');
    repository.package('packages/features/b', 'b');
    repository.write('packages/a/lib/a.dart', """
// import 'package:b/b.dart';
/* export 'package:b/b.dart'; */
const documentation = "import 'package:b/b.dart';";
""");
    expect(repository.check(), isEmpty);
  });

  test(
    'skips symlinked packages, lib directories and source files',
    () {
      repository.package(
        'outside',
        'outside',
        dependencies: {'app': '{path: ..}'},
      );
      Directory(p.join(repository.root.path, 'packages')).createSync();
      Link(
        p.join(repository.root.path, 'packages', 'alias'),
      ).createSync(p.join(repository.root.path, 'outside'));
      repository.package('packages/a', 'a');
      repository.write(
        'outside/forbidden.dart',
        "import 'package:app/main.dart';",
      );
      Link(
        p.join(repository.root.path, 'packages/a/lib'),
      ).createSync(p.join(repository.root.path, 'outside'));
      repository.package('packages/b', 'b');
      Directory(p.join(repository.root.path, 'packages/b/lib')).createSync();
      Link(
        p.join(repository.root.path, 'packages/b/lib/alias.dart'),
      ).createSync(p.join(repository.root.path, 'outside/forbidden.dart'));
      expect(repository.check(), isEmpty);
    },
    skip: Platform.isWindows
        ? 'Creating links requires additional privileges.'
        : false,
  );

  test(
    'rejects duplicate canonical names and malformed package configuration',
    () {
      repository.package('packages/a', 'same');
      repository.package('packages/b', 'same');
      expect(repository.check, throwsFormatException);
      repository.package('packages/b', 'b');
      repository.write(
        'packages/a/pubspec.yaml',
        'name: a\ndependencies: []\n',
      );
      expect(repository.check, throwsFormatException);
      repository.write(
        'packages/a/pubspec.yaml',
        'description: missing name\n',
      );
      expect(repository.check, throwsFormatException);
      repository.write('packages/a/pubspec.yaml', 'name: [invalid yaml\n');
      expect(repository.check, throwsFormatException);
    },
  );

  test(
    'CLI distinguishes violations from usage and configuration errors',
    () async {
      final root = Directory.current.absolute.path;
      final command = dartCommand(root: root);
      final snapshot = p.join(repository.root.path, 'check_architecture.dill');
      // Compile once: these cases check exit codes, not repeated SDK startup.
      await runCommand(
        [
          ...command,
          'compile',
          'kernel',
          p.join(root, 'scripts/check_architecture.dart'),
          '-o',
          snapshot,
        ],
        workingDirectory: root,
        timeout: const Duration(minutes: 1),
      );
      Future<ProcessResult> run(List<String> arguments) => Process.run(
        command.first,
        [
          ...command.skip(1),
          snapshot,
          ...arguments,
        ],
        workingDirectory: root,
      );
      expect((await run([repository.root.path])).exitCode, 0);
      repository.package(
        'packages/a',
        'a',
        dependencies: {'app': '{path: ../..}'},
      );
      final invalid = await run([repository.root.path]);
      expect(invalid.exitCode, 1);
      expect(invalid.stderr, contains('[package-root]'));
      expect((await run(['one', 'two'])).exitCode, 64);
      repository.write('pubspec.yaml', 'description: no package name\n');
      final configuration = await run([repository.root.path]);
      expect(configuration.exitCode, 64);
      expect(configuration.stderr, contains('configuration error'));
      repository.write('pubspec.yaml', 'name: [invalid yaml\n');
      final malformedYaml = await run([repository.root.path]);
      expect(malformedYaml.exitCode, 64);
      expect(malformedYaml.stderr, contains('configuration error'));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _Repository {
  _Repository(this.root);
  final Directory root;

  void package(
    String directory,
    String name, {
    Map<String, String> dependencies = const {},
    Map<String, String> development = const {},
  }) {
    write(
      p.join(directory, 'pubspec.yaml'),
      [
        'name: $name',
        if (dependencies.isNotEmpty) 'dependencies:',
        for (final entry in dependencies.entries)
          '  ${entry.key}: ${entry.value}',
        if (development.isNotEmpty) 'dev_dependencies:',
        for (final entry in development.entries)
          '  ${entry.key}: ${entry.value}',
        '',
      ].join('\n'),
    );
  }

  void write(String path, String content) {
    final file = File(p.join(root.path, path));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  List<ArchitectureViolation> check() => checkArchitecture(root);
  List<String> rules() => check().map((item) => item.rule).toList();
}
