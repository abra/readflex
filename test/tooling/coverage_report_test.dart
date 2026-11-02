@Tags(['tooling'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import '../../scripts/coverage_report.dart';

void main() {
  final directory = path.join(Directory.systemTemp.path, 'coverage-project');
  final packages = {'demo': directory};
  final sourcePath = path.join(directory, 'lib', 'a.dart');

  Map<String, CoverageRecord> merge(
    String text, [
    Map<String, CoverageRecord>? records,
  ]) => mergeLcov(
    text,
    directory: directory,
    packages: packages,
    records: records,
  );

  test('unions duplicate source paths and keeps maximum hits', () {
    final records = merge(
      'SF:lib/a.dart\nDA:10,1\nDA:11,0\nBRDA:10,0,0,-\nend_of_record',
    );
    merge(
      'SF:package:demo/a.dart\nDA:10,0\nDA:11,3\nBRDA:10,0,0,1\nend_of_record',
      records,
    );
    expect(records, hasLength(1));
    expect(records[sourcePath]!.lines, {10: 1, 11: 3});
    expect(summarize(records[sourcePath]).toJson(), {
      'measured': true,
      'linesHit': 2,
      'linesFound': 2,
      'branchesHit': 1,
      'branchesFound': 1,
      'uncoveredLines': <int>[],
      'uncoveredBranches': <String>[],
    });
  });

  test('retains missed lines and branches, and marks unloaded files', () {
    final records = merge(
      'SF:lib/a.dart\nDA:10,0\nBRDA:10,0,1,-\nend_of_record',
    );
    final measured = summarize(records[sourcePath]);
    expect(measured.uncoveredLines, [10]);
    expect(measured.uncoveredBranches, ['10,0,1']);
    expect(measured.measured, isTrue);
    expect(summarize(null).measured, isFalse);
  });

  test('accepts file URIs and ignores optional line checksums', () {
    final records = merge(
      'SF:${File(sourcePath).uri}\nDA:10,2,checksum\nend_of_record',
    );
    expect(summarize(records[sourcePath]).linesHit, 1);
  });

  test('rejects orphan coverage, unknown packages and corrupt counters', () {
    for (final input in [
      'DA:1,1',
      'BRDA:1,0,0,1',
      'SF:package:unknown/a.dart',
      'SF:lib/a.dart\nDA:1,NaN',
      'SF:lib/a.dart\nDA:1,-2',
      'SF:lib/a.dart\nDA:invalid,1',
      'SF:lib/a.dart\nBRDA:1,0',
    ]) {
      expect(() => merge(input), throwsFormatException, reason: input);
    }
  });

  test('test evidence excludes setup, retaining skips and failures', () {
    final events = [
      {
        'type': 'suite',
        'suite': {'id': 1, 'path': 'test/a_test.dart'},
      },
      for (final id in [1, 2, 3])
        {
          'type': 'testStart',
          'test': {'id': id, 'name': 'test-$id', 'suiteID': 1},
        },
      _done(1, hidden: true),
      _done(2, skipped: true),
      _done(3, result: 'failure'),
      {'type': 'done', 'success': false},
    ];
    final report = parseTestEvents(_events(events));
    expect(report.success, isFalse);
    expect(report.tests.map((test) => test.status), ['skipped', 'failure']);
    expect(report.tests.first.file, 'test/a_test.dart');
  });

  test('an interrupted or corrupt test run cannot appear successful', () {
    for (final input in [
      '',
      '{not json}',
      '{"type":"testDone","testID":1}',
      '{"type":"done","success":"true"}',
    ]) {
      expect(() => parseTestEvents(input), throwsFormatException);
    }
  });

  test('done success cannot conceal an unfinished test', () {
    expect(
      () => parseTestEvents(
        _events([
          {
            'type': 'testStart',
            'test': {'id': 1, 'name': 'unfinished'},
          },
          {'type': 'done', 'success': true},
        ]),
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('missing testDone'),
        ),
      ),
    );
  });

  test(
    'native lines union with host hits without inventing branches',
    () async {
      final fixture = await _Fixture.create();
      final report = await buildReport(
        fixture.root.path,
        fixture.output.path,
        [fixture.native.path, fixture.native.path],
      );
      expect(report.successful, isTrue);
      expect(report.packages.single.linesHit, 1);
      expect(report.packages.single.branchesHit, 0);
      expect(
        report.suites,
        hasLength(2),
        reason: 'duplicate native runs count once',
      );
      final native = report.suites.singleWhere(
        (suite) => suite.platform == 'ios',
      );
      expect(native.tests!.single.name, 'native case');
    },
  );

  test('snapshot includes owned code, tests and build pins only', () async {
    final fixture = await _Fixture.create();
    await fixture.write(
      'packages/helper/lib/helper.dart',
      'void helper() {}\n',
    );
    await fixture.write('packages/helper/pubspec.yaml', 'name: helper\n');
    await fixture.write('third_party/external/lib/external.dart', 'external\n');
    await fixture.write('test/app_test.dart', 'a test\n');
    await fixture.write('integration_test/device_test.dart', 'device test\n');
    await fixture.write('test_driver/driver.dart', 'driver\n');
    await fixture.write('pubspec.lock', 'lock\n');
    await fixture.write('.fvmrc', '{"flutter":"3.44.9"}\n');
    await fixture.write(
      '.dart_tool/package_config.json',
      jsonEncode({
        'packages': [
          {'name': 'demo', 'rootUri': '../', 'packageUri': 'lib/'},
          {
            'name': 'helper',
            'rootUri': '../packages/helper/',
            'packageUri': 'lib/',
          },
          {
            'name': 'external',
            'rootUri': '../third_party/external/',
            'packageUri': 'lib/',
          },
        ],
      }),
    );
    final snapshot = await sourceSnapshot(fixture.root.path);
    expect(snapshot.packages, ['demo', 'helper']);
    expect(
      snapshot.files.keys,
      containsAll([
        path.join('test', 'app_test.dart'),
        path.join('packages', 'helper', 'lib', 'helper.dart'),
        path.join('integration_test', 'device_test.dart'),
        path.join('test_driver', 'driver.dart'),
        'pubspec.lock',
        '.fvmrc',
      ]),
    );
    expect(
      snapshot.files.keys.any((file) => file.contains('external')),
      isFalse,
    );
    expect(snapshot.files.values, everyElement(matches(r'^[0-9a-f]{64}$')));
  });

  test('excludes generated code but hashes it and measures wrappers', () async {
    final fixture = await _Fixture.create();
    const native = 'lib/src/formats/mobi/native';
    final generated = [
      for (final file in [
        'api.dart',
        'frb_generated.dart',
        'frb_generated.io.dart',
      ])
        '$native/rust/$file',
      'lib/generated/mapper.dart',
      'lib/model.g.dart',
      'lib/state.freezed.dart',
    ].map(path.normalize).toList();
    final handwritten = [
      '$native/native_mobi_text_reader.dart',
      '$native/native_library.dart',
    ].map(path.normalize).toList();
    for (final file in generated.take(3)) {
      await fixture.write(
        file,
        '// This file is automatically generated.\n'
        '// @generated by `flutter_rust_bridge`@ 2.13.0.\nvoid bridge() {}\n',
      );
    }
    for (final file in generated.skip(3)) {
      await fixture.write(file, 'void generated() {}\n');
    }
    for (final file in handwritten) {
      await fixture.write(
        file,
        '// Native FRB integration.\nvoid wrapper() {}\n',
      );
    }
    final snapshot = await sourceSnapshot(fixture.root.path);
    for (final file in [...generated, ...handwritten]) {
      expect(snapshot.files[file], matches(r'^[0-9a-f]{64}$'));
    }
    await fixture.write('host/sources.json', jsonEncode(snapshot.toJson()));
    await fixture.write(
      'host/app/lcov.info',
      [
        for (final file in [...generated, ...handwritten])
          'SF:$file\nDA:3,0\nend_of_record',
      ].join('\n'),
    );
    final report = await buildReport(fixture.root.path, fixture.output.path);
    expect(report.excludedFiles, unorderedEquals(generated));
    for (final file in handwritten) {
      expect(
        report.files
            .singleWhere((source) => source.file == file)
            .coverage
            .linesFound,
        1,
      );
    }
    expect(report.packages.single.linesFound, handwritten.length);
    await fixture.write(generated.first, '// Changed generated source.\n');
    await expectLater(
      buildReport(fixture.root.path, fixture.output.path),
      throwsA(isA<StateError>()),
    );
  });

  test('missing completion and native failures remain unsuccessful', () async {
    final fixture = await _Fixture.create();
    await File(path.join(fixture.output.path, 'completed')).delete();
    expect(
      (await buildReport(fixture.root.path, fixture.output.path)).successful,
      isFalse,
    );
    await fixture.write('host/completed', 'complete');
    await fixture.nativeEvidence(tests: {'native case': 'failure'});
    expect(
      (await buildReport(fixture.root.path, fixture.output.path, [
        fixture.native.path,
      ])).successful,
      isFalse,
    );
  });

  test(
    'stale host and native snapshots cannot merge with current code',
    () async {
      final fixture = await _Fixture.create();
      await fixture.write('lib/main.dart', 'void main() { print(1); }\n');
      await expectLater(
        buildReport(fixture.root.path, fixture.output.path, [
          fixture.native.path,
        ]),
        throwsA(isA<StateError>()),
      );
      await fixture.write(
        'host/sources.json',
        jsonEncode((await sourceSnapshot(fixture.root.path)).toJson()),
      );
      await expectLater(
        buildReport(fixture.root.path, fixture.output.path, [
          fixture.native.path,
        ]),
        throwsA(isA<StateError>()),
      );
    },
  );

  test(
    'rejects incomplete native evidence and malformed suite manifests',
    () async {
      final fixture = await _Fixture.create();
      for (final evidence in [
        {
          'platform': 'ios',
          'tests': {'case': 'success'},
        },
        {
          'platform': 'web',
          'completedAt': '2026-09-13',
          'tests': {'case': 'success'},
        },
        {
          'platform': 'ios',
          'completedAt': 'not a date',
          'tests': {'case': 'success'},
        },
        {
          'platform': 'android',
          'completedAt': '2026-09-13',
          'tests': <String, String>{},
        },
      ]) {
        await fixture.write('native/results.json', jsonEncode(evidence));
        await expectLater(
          buildReport(fixture.root.path, fixture.output.path, [
            fixture.native.path,
          ]),
          throwsFormatException,
        );
      }
      await fixture.write(
        'host/suites.tsv',
        'app\t${fixture.root.path}\tNaN\ttrue',
      );
      await expectLater(
        buildReport(fixture.root.path, fixture.output.path),
        throwsFormatException,
      );
    },
  );

  test(
    'Markdown distinguishes unmeasured files from zero-hit coverage',
    () async {
      final fixture = await _Fixture.create();
      await fixture.write('lib/unloaded.dart', 'void unloaded() {}\n');
      await fixture.write(
        'host/sources.json',
        jsonEncode((await sourceSnapshot(fixture.root.path)).toJson()),
      );
      final report = await buildReport(fixture.root.path, fixture.output.path);
      final markdown = markdownReport(report);
      expect(markdown, contains('| demo | 0/1 (0.0%) | 0/1 (0.0%) | 1 |'));
      expect(
        markdown,
        contains('${path.join('lib', 'main.dart')}: 1 uncovered lines'),
      );
      expect(
        markdown,
        contains(
          '## Unmeasured Files\n\n- ${path.join('lib', 'unloaded.dart')}',
        ),
      );
    },
  );

  test('snapshot CLI writes hashes and package filter without Node', () async {
    final fixture = await _Fixture.create();
    final result = await _runCli(fixture, ['--snapshot', fixture.output.path]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final data =
        jsonDecode(
              await File(
                path.join(fixture.output.path, 'sources.json'),
              ).readAsString(),
            )
            as Map<String, dynamic>;
    expect(data['packages'], ['demo']);
    expect(
      (data['files'] as Map)[path.join('lib', 'main.dart')],
      matches(r'^[0-9a-f]{64}$'),
    );
    expect(
      await File(
        path.join(fixture.output.path, 'packages.regex'),
      ).readAsString(),
      '^(demo)\$\n',
    );
  });

  test(
    'report CLI writes merged evidence and machine-readable results',
    () async {
      final fixture = await _Fixture.create();
      final result = await _runCli(fixture, [
        fixture.output.path,
        fixture.native.path,
      ]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      final data =
          jsonDecode(
                await File(
                  path.join(fixture.output.path, 'report.json'),
                ).readAsString(),
              )
              as Map<String, dynamic>;
      expect(data['successful'], isTrue);
      expect((data['packages'] as List).single['linesHit'], 1);
      expect((data['suites'] as List).length, 2);
      expect(
        await File(path.join(fixture.output.path, 'report.md')).readAsString(),
        contains('Successful: true'),
      );
    },
  );

  test('report CLI returns failure for incomplete or stale results', () async {
    final fixture = await _Fixture.create();
    await File(path.join(fixture.output.path, 'completed')).delete();
    var result = await _runCli(fixture, [fixture.output.path]);
    expect(result.exitCode, 1);
    expect(
      await File(path.join(fixture.output.path, 'report.md')).readAsString(),
      contains('Successful: false'),
    );
    await fixture.write('lib/main.dart', 'void changed() {}\n');
    result = await _runCli(fixture, [fixture.output.path]);
    expect(result.exitCode, 1);
    expect(result.stderr, contains('Sources changed'));
  });

  test('report CLI rejects missing arguments', () async {
    final fixture = await _Fixture.create();
    final result = await _runCli(fixture, []);
    expect(result.exitCode, 64);
    expect(result.stderr, contains('Usage:'));
  });
}

Map<String, Object?> _done(
  int id, {
  bool hidden = false,
  bool skipped = false,
  String result = 'success',
}) => {
  'type': 'testDone',
  'testID': id,
  'hidden': hidden,
  'skipped': skipped,
  'result': result,
};

String _events(List<Map<String, Object?>> events) =>
    events.map(jsonEncode).join('\n');

final class _Fixture {
  const _Fixture(this.root);

  final Directory root;
  Directory get output => Directory(path.join(root.path, 'host'));
  Directory get native => Directory(path.join(root.path, 'native'));

  static Future<_Fixture> create() async {
    final root = await Directory.systemTemp.createTemp('readflex-coverage-');
    addTearDown(() => root.delete(recursive: true));
    final fixture = _Fixture(root);
    await fixture.write('lib/main.dart', 'void main() {}\n');
    await fixture.write('pubspec.yaml', 'name: demo\n');
    await fixture.write(
      '.dart_tool/package_config.json',
      jsonEncode({
        'packages': [
          {'name': 'demo', 'rootUri': '../', 'packageUri': 'lib/'},
        ],
      }),
    );
    final snapshot = await sourceSnapshot(root.path);
    for (final name in ['host', 'native']) {
      await fixture.write('$name/sources.json', jsonEncode(snapshot.toJson()));
    }
    await fixture.write('host/suites.tsv', 'app\t${root.path}\t0\ttrue\n');
    await fixture.write('host/completed', 'complete\n');
    await fixture.write(
      'host/app/lcov.info',
      'SF:lib/main.dart\nDA:1,0\nBRDA:1,0,0,0\nend_of_record',
    );
    await fixture.write(
      'host/app/tests.jsonl',
      _events([
        {
          'type': 'suite',
          'suite': {'id': 1, 'path': 'test/demo.dart'},
        },
        {
          'type': 'testStart',
          'test': {'id': 1, 'suiteID': 1, 'name': 'host case'},
        },
        _done(1),
        {'type': 'done', 'success': true},
      ]),
    );
    await fixture.write(
      'native/lcov.info',
      'SF:lib/main.dart\nDA:1,1\nend_of_record',
    );
    await fixture.nativeEvidence();
    return fixture;
  }

  Future<void> write(String relative, String contents) async {
    final file = File(path.join(root.path, relative));
    await file.parent.create(recursive: true);
    await file.writeAsString(contents);
  }

  Future<void> nativeEvidence({
    Map<String, String> tests = const {'native case': 'success'},
  }) => write(
    'native/results.json',
    jsonEncode({
      'platform': 'ios',
      'completedAt': '2026-09-13T00:00:00Z',
      'tests': tests,
    }),
  );
}

Future<ProcessResult> _runCli(_Fixture fixture, List<String> args) =>
    Process.run(
      _dartExecutable(),
      [
        '--packages=${File('.dart_tool/package_config.json').absolute.path}',
        File('scripts/coverage_report.dart').absolute.path,
        '--root',
        fixture.root.path,
        ...args,
      ],
    );

String _dartExecutable() {
  final name = Platform.isWindows ? 'dart.exe' : 'dart';
  var directory = File(Platform.resolvedExecutable).parent;
  while (true) {
    for (final candidate in [
      path.join(directory.path, name),
      path.join(directory.path, 'dart-sdk', 'bin', name),
    ]) {
      if (File(candidate).existsSync()) return candidate;
    }
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError(
        'Cannot locate Dart SDK from ${Platform.resolvedExecutable}',
      );
    }
    directory = parent;
  }
}
