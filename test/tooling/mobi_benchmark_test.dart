@Tags(['tooling'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../scripts/mobi_benchmark.dart';
import '../../scripts/src/tool_support.dart';

JsonObject _report({
  String implementation = 'dart',
  List<num> times = const [100, 200, 300],
}) => {
  'status': 'complete',
  'protocol': mobiBenchmarkProtocol,
  'label': implementation,
  'datasetSha256': 'a' * 64,
  'runtime': 'same-sdk',
  'implementation': implementation,
  'machine': {'fingerprint': 'same-machine'},
  'sampling': {'samples': 21, 'warmups': 5, 'processes': 1},
  'cases': <JsonObject>[
    {
      'id': 'case',
      'compression': 2,
      'records': 1,
      'inputBytes': 10,
      'outputBytes': 20,
      'outputSha256': 'b' * 64,
      'runs': <JsonObject>[
        {
          'protocol': mobiBenchmarkProtocol,
          'mode': 'aot',
          'caseId': 'case',
          'implementation': implementation,
          'runtime': 'same-sdk',
          'verified': true,
          'records': 1,
          'inputBytes': 10,
          'outputBytes': 20,
          'setupUs': 10,
          'firstBatchUs': 500,
          'samplesUs': List.generate(
            21,
            (index) => times[index % times.length],
          ),
          'processPeakRssBytes': 1048576,
        },
      ],
    },
  ],
};

JsonObject _case(JsonObject report) =>
    (report['cases'] as List).first as JsonObject;
JsonObject _run(JsonObject report) =>
    (_case(report)['runs'] as List).first as JsonObject;
JsonObject _clone(JsonObject value) =>
    jsonDecode(jsonEncode(value)) as JsonObject;

void main() {
  test('compares complete matching runs without modifying samples', () {
    final baseline = _report();
    final original = _clone(baseline);
    final candidate = _report(
      implementation: 'rust-frb',
      times: [50, 100, 150],
    );
    final row = compareReports(baseline, candidate).single;
    expect(row.speedup, 2);
    expect(row.before.medianMs, .2);
    expect(row.after.p95Ms, .15);
    expect(row.before.coldMs, .51);
    expect(row.before.peakRssMiB, 1);
    expect(baseline, original);
  });

  test('rejects different input, output, runtime, machine and sampling', () {
    for (final mutate in <void Function(JsonObject)>[
      (report) => report['datasetSha256'] = 'c' * 64,
      (report) => _case(report)['outputSha256'] = 'c' * 64,
      (report) => report['runtime'] = 'other-sdk',
      (report) => (report['machine'] as JsonObject)['fingerprint'] = 'other',
      (report) => (report['sampling'] as JsonObject)['warmups'] = 10,
      (report) => _case(report)['compression'] = 17480,
    ]) {
      final candidate = _report();
      mutate(candidate);
      expect(() => compareReports(_report(), candidate), throwsFormatException);
    }
  });

  test('rejects partial, unverified and JIT reports', () {
    for (final mutate in <void Function(JsonObject)>[
      (report) => report['status'] = 'running',
      (report) => _case(report)['runs'] = <Object?>[],
      (report) => _run(report)['verified'] = false,
      (report) => _run(report)['mode'] = 'jit',
      (report) => (_run(report)['samplesUs'] as List).removeLast(),
      (report) => _run(report)['records'] = 2,
      (report) => (report['cases'] as List).add(_clone(_case(report))),
      (report) => _run(report)['processPeakRssBytes'] = 0,
      (report) => _run(report)['setupUs'] = -1,
    ]) {
      final candidate = _report();
      mutate(candidate);
      expect(() => compareReports(_report(), candidate), throwsFormatException);
    }
  });

  test('worker evidence must match frozen bytes and sample count', () {
    final input = <String, Object?>{
      'id': 'case',
      'records': [base64Encode(List.filled(10, 0))],
      'expected': [base64Encode(List.filled(20, 0))],
    };
    final result = _run(_report());
    final sampling = BenchmarkSampling(processes: 1);
    expect(() => validateWorker(result, input, sampling), returnsNormally);
    expect(
      () => validateWorker({...result, 'outputBytes': 21}, input, sampling),
      throwsFormatException,
    );
    expect(
      () => validateWorker(
        {
          ...result,
          'samplesUs': [1],
        },
        input,
        sampling,
      ),
      throwsFormatException,
    );
    expect(
      () => validateWorker(
        {
          ...result,
          'samplesUs': [double.nan, ...List.filled(20, 1)],
        },
        input,
        sampling,
      ),
      throwsFormatException,
    );
  });

  test('percentiles preserve raw data and reject corrupt timings', () {
    final values = [30, 10, 20];
    expect(statistics(values), (median: 20, p95: 30));
    expect(values, [30, 10, 20]);
    expect(statistics([10, 20]), (median: 20, p95: 20));
    for (final invalid in <List<num>>[
      [],
      [double.nan],
      [-1],
      [double.infinity],
    ]) {
      expect(() => statistics(invalid), throwsFormatException);
    }
  });

  group('CLI', () {
    final root = Directory.current.absolute.path;
    late Directory compiler;
    late String executable;

    setUpAll(() async {
      compiler = await Directory.systemTemp.createTemp('mobi-tool-worker-');
      final source = File(p.join(compiler.path, 'worker.dart'));
      await source.writeAsString(_stubSource);
      executable = p.join(
        compiler.path,
        Platform.isWindows ? 'worker.exe' : 'worker',
      );
      await runCommand(
        [
          ...dartCommand(root: root),
          'compile',
          'exe',
          source.path,
          '-o',
          executable,
        ],
        workingDirectory: compiler.path,
        timeout: const Duration(minutes: 2),
      );
    });
    tearDownAll(() => compiler.delete(recursive: true));

    Future<_Fixture> fixture({String behavior = 'valid'}) async {
      final directory = await Directory.systemTemp.createTemp(
        'mobi-benchmark with spaces-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final bundle = p.join(directory.path, 'original', 'bundle');
      await Directory(p.join(bundle, 'bin')).create(recursive: true);
      await Directory(p.join(bundle, 'lib')).create();
      final worker = p.join(bundle, 'bin', p.basename(executable));
      await copyFilePreservingMode(executable, worker);
      final library = File(
        p.join(directory.path, 'original', 'native library'),
      );
      await library.writeAsString('original native library');
      final asset = File(p.join(bundle, 'lib', 'asset'));
      await asset.writeAsString('original bundled asset');
      final dataset = File(p.join(directory.path, 'dataset.json'));
      await dataset.writeAsString(
        jsonEncode({
          'protocol': mobiBenchmarkProtocol,
          'cases': [
            {
              'id': 'case',
              'source': 'test stub',
              'compression': 2,
              'records': ['YQ=='],
              'expected': ['YQ=='],
              'testBehavior': behavior,
              'originalWorker': worker,
              'originalLibrary': library.path,
              'originalDataset': dataset.path,
            },
          ],
        }),
      );
      return _Fixture(
        directory.path,
        bundle,
        worker,
        library.path,
        dataset.path,
      );
    }

    Future<ProcessResult> invoke(
      _Fixture fixture, {
      List<String> extra = const [],
    }) => Process.run(
      dartCommand(root: root).first,
      [
        ...dartCommand(root: root).skip(1),
        '--packages=${p.join(root, '.dart_tool', 'package_config.json')}',
        p.join(root, 'scripts', 'mobi_benchmark.dart'),
        'run',
        '--label',
        'test',
        '--dataset',
        fixture.dataset,
        '--worker',
        fixture.worker,
        '--bundle',
        fixture.bundle,
        '--library',
        fixture.library,
        '--samples',
        '20',
        '--warmups',
        '1',
        '--processes',
        '1',
        '--output-dir',
        p.join(fixture.directory, 'reports'),
        ...extra,
      ],
      workingDirectory: root,
    ).timeout(const Duration(minutes: 2));

    test(
      'freezes executable, assets, library and dataset before execution',
      () async {
        final input = await fixture();
        final originalHash = await hashFile(input.worker);
        final process = await invoke(input);
        expect(process.exitCode, 0, reason: '${process.stderr}');
        final output = (process.stdout as String).trim();
        final report =
            jsonDecode(await File(output).readAsString()) as JsonObject;
        final frozen = p.dirname(output);
        final execution = report['execution'] as JsonObject;
        await File(input.worker).writeAsString('changed worker');
        await File(input.library).writeAsString('changed library');
        await File(
          p.join(input.bundle, 'lib', 'asset'),
        ).writeAsString('changed asset');
        await File(input.dataset).writeAsString('changed dataset');
        expect(
          await hashFile(p.join(frozen, execution['worker'] as String)),
          originalHash,
        );
        expect(
          await File(
            p.join(frozen, execution['nativeLibrary'] as String),
          ).readAsString(),
          'original native library',
        );
        expect(
          await File(p.join(frozen, 'bundle', 'lib', 'asset')).readAsString(),
          'original bundled asset',
        );
        final data = jsonDecode(
          await File(p.join(frozen, 'dataset.json')).readAsString(),
        ) as JsonObject;
        expect((data['cases'] as List).single['id'], 'case');
        expect(report['artifacts'], hasLength(3));
        expect(report['status'], 'complete');
        expect(_case(report)['runs'], hasLength(1));
        expect((_run(report)['samplesUs'] as List).length, 20);
      },
    );

    for (final behavior in ['exit-failure', 'unverified', 'wrong-counts']) {
      test('fails without a complete report for $behavior worker', () async {
        final input = await fixture(behavior: behavior);
        final process = await invoke(input);
        expect(process.exitCode, isNot(0));
        expect(process.stderr, isNotEmpty);
        final reports = await Directory(p.join(input.directory, 'reports'))
            .list(recursive: true)
            .where((entry) => p.basename(entry.path) == 'report.json')
            .toList();
        expect(reports, isEmpty);
      });
    }

    test('rejects undersampling before starting a worker', () async {
      final input = await fixture();
      final process = await invoke(input, extra: ['--samples', '19']);
      expect(process.exitCode, isNot(0));
      expect(process.stderr, contains('>=20 samples'));
      expect(
        await Directory(p.join(input.directory, 'reports')).exists(),
        isFalse,
      );
    });
  });
}

class _Fixture {
  const _Fixture(
    this.directory,
    this.bundle,
    this.worker,
    this.library,
    this.dataset,
  );

  final String directory;
  final String bundle;
  final String worker;
  final String library;
  final String dataset;
}

// This worker tests orchestration, not decoder speed. Its timings are synthetic.
const _stubSource = r'''
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final dataset = jsonDecode(File(args[0]).readAsStringSync()) as Map;
  final input = (dataset['cases'] as List).single as Map;
  if (Platform.resolvedExecutable == input['originalWorker'] ||
      args[0] == input['originalDataset'] ||
      Platform.environment['MOBI_RUST_LIBRARY'] == input['originalLibrary']) {
    throw StateError('The runner used original inputs instead of frozen copies');
  }
  if (File(Platform.environment['MOBI_RUST_LIBRARY']!).readAsStringSync() !=
          'original native library' ||
      File.fromUri(Uri.file(Platform.resolvedExecutable).resolve('../lib/asset'))
              .readAsStringSync() != 'original bundled asset') {
    throw StateError('The frozen assets are missing');
  }
  if (input['testBehavior'] == 'exit-failure') {
    stderr.writeln('intentional worker failure');
    exitCode = 7;
    return;
  }
  stdout.writeln(jsonEncode({
    'protocol': 'mobi-decoder-batch-v1',
    'mode': 'aot',
    'verified': input['testBehavior'] != 'unverified',
    'implementation': 'test-stub',
    'runtime': 'test-sdk',
    'caseId': args[1],
    'records': 1,
    'inputBytes': 1,
    'outputBytes': input['testBehavior'] == 'wrong-counts' ? 2 : 1,
    'setupUs': 0,
    'firstBatchUs': 1,
    'samplesUs': List.filled(int.parse(args[2]), 1),
    'processPeakRssBytes': 1,
  }));
}
''';
