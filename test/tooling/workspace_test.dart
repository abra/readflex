@Tags(['tooling'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../../scripts/src/tool_support.dart';

void main() {
  final root = Directory.current.absolute.path;
  final manifest = _pubspec(root);
  final members = (manifest['workspace'] as YamlList).cast<String>().toList();

  test('the workspace includes all production packages and vendored forks', () {
    final expected = <String>{};
    for (final directory in ['packages', 'packages/features', 'third_party']) {
      for (final entry in Directory(p.join(root, directory)).listSync()) {
        if (entry is Directory &&
            File(p.join(entry.path, 'pubspec.yaml')).existsSync()) {
          expected.add(p.relative(entry.path, from: root));
        }
      }
    }
    expect(members, unorderedEquals(expected));
    for (final member in members) {
      expect(
        _pubspec(p.join(root, member))['resolution'],
        'workspace',
        reason: member,
      );
    }
  });

  test(
    'Pub resolves every member through the root package configuration',
    () async {
      final result = await runCommand(
        [...dartCommand(root: root), 'pub', 'workspace', 'list', '--json'],
        workingDirectory: root,
        timeout: const Duration(seconds: 20),
      );
      final packages =
          (jsonDecode(result.stdout as String) as Map)['packages'] as List;
      expect(
        packages.map((entry) => p.normalize(entry['path'] as String)),
        unorderedEquals([
          root,
          for (final member in members) p.join(root, member),
        ]),
      );

      final config = File(p.join(root, '.dart_tool/package_config.json'));
      final configured = {
        for (final entry
            in (jsonDecode(config.readAsStringSync()) as Map)['packages']
                as List)
          entry['name'] as String: p.normalize(
            config.uri.resolve(entry['rootUri'] as String).toFilePath(),
          ),
      };
      for (final member in ['.', ...members]) {
        final directory = p.normalize(p.join(root, member));
        expect(configured[_pubspec(directory)['name']], directory);
        if (member == '.') continue;
        expect(
          File(p.join(directory, 'pubspec.lock')).existsSync(),
          isFalse,
          reason: member,
        );
        expect(
          File(p.join(directory, '.dart_tool/package_config.json'))
              .existsSync(),
          isFalse,
          reason: member,
        );
      }
    },
  );

  test('native benchmark experiments retain independent dependency pins', () {
    for (final directory in [
      'benchmarks/mobi_rust',
      'benchmarks/reader_native',
    ]) {
      final experiment = _pubspec(p.join(root, directory));
      expect(members, isNot(contains(directory)));
      expect(experiment['resolution'], isNull);
      expect(experiment['workspace'], isNull);
      expect(
        File(p.join(root, directory, 'pubspec.lock')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(root, directory, 'rust/Cargo.lock')).existsSync(),
        isTrue,
      );
    }
  });

  test('Drift generation targets the locked runtime API family', () {
    final lock = loadYaml(
      File(p.join(root, 'pubspec.lock')).readAsStringSync(),
    ) as YamlMap;
    final packages = lock['packages'] as YamlMap;
    List<String> apiVersion(String name) =>
        (packages[name]['version'] as String).split('.').take(2).toList();
    expect(apiVersion('drift_dev'), apiVersion('drift'));
  });
}

YamlMap _pubspec(String directory) =>
    loadYaml(File(p.join(directory, 'pubspec.yaml')).readAsStringSync())
        as YamlMap;
