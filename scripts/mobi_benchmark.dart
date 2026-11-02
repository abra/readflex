import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'src/tool_support.dart';

const mobiBenchmarkProtocol = 'mobi-decoder-batch-v1';
const _maxOutputBytes = 64 * 1024 * 1024;

typedef JsonObject = Map<String, Object?>;

class BenchmarkSampling {
  BenchmarkSampling({
    this.samples = 21,
    this.warmups = 5,
    this.processes = 3,
  }) {
    if (samples < 20 || warmups < 1 || processes < 1) {
      throw const FormatException(
        'Use >=20 samples, >=1 warmup and >=1 process',
      );
    }
  }

  final int samples;
  final int warmups;
  final int processes;

  JsonObject toJson() => {
    'samples': samples,
    'warmups': warmups,
    'processes': processes,
  };
}

({num median, num p95}) statistics(Iterable<num> samples) {
  final sorted = samples.toList();
  if (sorted.isEmpty || sorted.any((value) => !value.isFinite || value < 0)) {
    throw const FormatException('Invalid timing samples');
  }
  sorted.sort();
  return (
    median: sorted[sorted.length ~/ 2],
    p95: sorted[(sorted.length * .95).ceil() - 1],
  );
}

void validateWorker(
  JsonObject result,
  JsonObject input,
  BenchmarkSampling sampling,
) {
  final records = _list(input['records'], 'input records');
  final expected = _list(input['expected'], 'expected records');
  final inputBytes = _decodedBytes(records);
  final outputBytes = _decodedBytes(expected);
  _validateRun(
    result,
    id: _string(input['id'], 'case id'),
    records: records.length,
    inputBytes: inputBytes,
    outputBytes: outputBytes,
    samples: sampling.samples,
  );
}

class BenchmarkSummary {
  const BenchmarkSummary({
    required this.coldMs,
    required this.medianMs,
    required this.p95Ms,
    required this.mibPerSecond,
    required this.peakRssMiB,
  });

  final double coldMs;
  final double medianMs;
  final double p95Ms;
  final double? mibPerSecond;
  final double peakRssMiB;

  JsonObject toJson() => {
    'coldMs': coldMs,
    'medianMs': medianMs,
    'p95Ms': p95Ms,
    'mibPerSecond': mibPerSecond,
    'peakRssMiB': peakRssMiB,
  };
}

class BenchmarkComparison {
  const BenchmarkComparison({
    required this.id,
    required this.before,
    required this.after,
    required this.speedup,
  });

  final String id;
  final BenchmarkSummary before;
  final BenchmarkSummary after;
  final double? speedup;

  JsonObject toJson() => {
    'id': id,
    'before': before.toJson(),
    'after': after.toJson(),
    'speedup': speedup,
  };
}

List<BenchmarkComparison> compareReports(
  JsonObject baseline,
  JsonObject candidate,
) {
  _validateReport(baseline);
  _validateReport(candidate);
  for (final key in ['datasetSha256', 'runtime']) {
    if (baseline[key] != candidate[key]) {
      throw FormatException('Incompatible $key');
    }
  }
  if (_object(baseline['machine'], 'machine')['fingerprint'] !=
      _object(candidate['machine'], 'machine')['fingerprint']) {
    throw const FormatException('Different machines');
  }
  final beforeSampling = _object(baseline['sampling'], 'sampling');
  final afterSampling = _object(candidate['sampling'], 'sampling');
  for (final key in ['samples', 'warmups', 'processes']) {
    if (beforeSampling[key] != afterSampling[key]) {
      throw FormatException('Different sampling: $key');
    }
  }
  final beforeCases = _objects(baseline['cases'], 'cases');
  final afterCases = _objects(candidate['cases'], 'cases');
  if (beforeCases.length != afterCases.length) {
    throw const FormatException('Different cases');
  }
  final byId = {for (final input in afterCases) input['id']: input};
  return [
    for (final beforeCase in beforeCases)
      _compareCase(beforeCase, byId[beforeCase['id']]),
  ];
}

BenchmarkComparison _compareCase(JsonObject before, JsonObject? after) {
  final id = _string(before['id'], 'case id');
  if (after == null ||
      [
        'outputSha256',
        'records',
        'inputBytes',
        'outputBytes',
        'compression',
      ].any((key) => before[key] != after[key])) {
    throw FormatException('Different input or output for $id');
  }
  final beforeSummary = _summarize(before);
  final afterSummary = _summarize(after);
  return BenchmarkComparison(
    id: id,
    before: beforeSummary,
    after: afterSummary,
    speedup: afterSummary.medianMs == 0
        ? null
        : beforeSummary.medianMs / afterSummary.medianMs,
  );
}

BenchmarkSummary _summarize(JsonObject input) {
  final runs = _objects(input['runs'], 'runs');
  final warm = statistics(
    runs.expand((run) => _numbers(run['samplesUs'], 'timing samples')),
  );
  final cold = statistics(
    runs.map(
      (run) =>
          _number(run['setupUs'], 'setupUs') +
          _number(run['firstBatchUs'], 'firstBatchUs'),
    ),
  );
  final peakRss = runs
      .map((run) => _number(run['processPeakRssBytes'], 'processPeakRssBytes'))
      .reduce((a, b) => a > b ? a : b);
  return BenchmarkSummary(
    coldMs: cold.median / 1000,
    medianMs: warm.median / 1000,
    p95Ms: warm.p95 / 1000,
    mibPerSecond: warm.median == 0
        ? null
        : _integer(input['outputBytes'], 'outputBytes') /
              1048576 /
              (warm.median / 1000000),
    peakRssMiB: peakRss / 1048576,
  );
}

void _validateReport(JsonObject report) {
  if (report['status'] != 'complete' ||
      report['protocol'] != mobiBenchmarkProtocol) {
    throw const FormatException('Incomplete benchmark report');
  }
  _hash(report['datasetSha256'], 'datasetSha256');
  _string(_object(report['machine'], 'machine')['fingerprint'], 'fingerprint');
  final runtime = _string(report['runtime'], 'runtime');
  final implementation = _string(report['implementation'], 'implementation');
  final settings = _object(report['sampling'], 'sampling');
  final sampling = BenchmarkSampling(
    samples: _integer(settings['samples'], 'samples'),
    warmups: _integer(settings['warmups'], 'warmups'),
    processes: _integer(settings['processes'], 'processes'),
  );
  final cases = _objects(report['cases'], 'cases');
  if (cases.isEmpty ||
      cases.map((input) => input['id']).toSet().length != cases.length) {
    throw const FormatException('Incomplete or duplicated benchmark cases');
  }
  for (final input in cases) {
    final id = _string(input['id'], 'case id');
    _hash(input['outputSha256'], 'outputSha256');
    final records = _integer(input['records'], 'records', minimum: 1);
    final inputBytes = _integer(input['inputBytes'], 'inputBytes');
    final outputBytes = _integer(input['outputBytes'], 'outputBytes');
    final runs = _objects(input['runs'], 'runs');
    if (runs.length != sampling.processes) {
      throw const FormatException('Incomplete worker runs');
    }
    for (final run in runs) {
      _validateRun(
        run,
        id: id,
        records: records,
        inputBytes: inputBytes,
        outputBytes: outputBytes,
        samples: sampling.samples,
        runtime: runtime,
        implementation: implementation,
      );
    }
  }
}

void _validateRun(
  JsonObject run, {
  required String id,
  required int records,
  required int inputBytes,
  required int outputBytes,
  required int samples,
  String? runtime,
  String? implementation,
}) {
  if (run['protocol'] != mobiBenchmarkProtocol ||
      run['mode'] != 'aot' ||
      run['verified'] != true ||
      run['caseId'] != id ||
      run['records'] != records ||
      run['inputBytes'] != inputBytes ||
      run['outputBytes'] != outputBytes ||
      (runtime != null && run['runtime'] != runtime) ||
      (implementation != null && run['implementation'] != implementation)) {
    throw FormatException('Invalid or unverified worker result for $id');
  }
  _string(run['runtime'], 'runtime');
  _string(run['implementation'], 'implementation');
  _number(run['setupUs'], 'setupUs');
  _number(run['firstBatchUs'], 'firstBatchUs');
  if (_number(run['processPeakRssBytes'], 'processPeakRssBytes') <= 0) {
    throw const FormatException('Invalid process peak RSS');
  }
  final timings = _numbers(run['samplesUs'], 'timing samples');
  if (timings.length != samples) {
    throw const FormatException('Incomplete timing samples');
  }
  statistics(timings);
}

class _Options {
  _Options(List<String> arguments) {
    const supported = {
      'dataset',
      'worker',
      'bundle',
      'library',
      'label',
      'samples',
      'warmups',
      'processes',
      'output-dir',
    };
    for (var index = 0; index < arguments.length; index += 2) {
      if (!arguments[index].startsWith('--') || index + 1 == arguments.length) {
        throw const FormatException('Expected --option value pairs');
      }
      final key = arguments[index].substring(2);
      final value = arguments[index + 1];
      if (key == 'book') {
        books.add(value);
      } else if (key == 'artifact') {
        artifacts.add(value);
      } else if (supported.contains(key)) {
        values[key] = value;
      } else {
        throw FormatException('Unknown option: --$key');
      }
    }
  }

  final books = <String>[];
  final artifacts = <String>[];
  final values = <String, String>{};

  String? operator [](String key) => values[key];

  int integer(String key, int fallback) => values.containsKey(key)
      ? int.tryParse(values[key]!) ??
            (throw FormatException('Invalid --$key: ${values[key]}'))
      : fallback;
}

Future<void> runMobiBenchmark(
  List<String> arguments, {
  required String root,
}) async {
  final command = arguments.firstOrNull;
  final args = arguments.skip(1).toList();
  if (command == 'compare') {
    if (args.length != 2) {
      throw const FormatException('compare needs baseline.json candidate.json');
    }
    final baseline = await _readObject(p.absolute(args[0]));
    final candidate = await _readObject(p.absolute(args[1]));
    final rows = compareReports(baseline, candidate);
    stdout.writeln(
      '| Case | Warm median ms (${baseline['label']} → ${candidate['label']}) | '
      'p95 ms | Speedup | Peak process RSS MiB |\n'
      '|---|---:|---:|---:|---:|',
    );
    for (final row in rows) {
      stdout.writeln(
        '| ${row.id} | ${_format(row.before.medianMs)} → '
        '${_format(row.after.medianMs)} | ${_format(row.before.p95Ms)} → '
        '${_format(row.after.p95Ms)} | ${_format(row.speedup)}× | '
        '${_format(row.before.peakRssMiB)} → ${_format(row.after.peakRssMiB)} |',
      );
    }
    stdout.writeln(
      'Cold/setup samples, throughput inputs and artifact sizes remain '
      'in the JSON reports.',
    );
  } else if (command == 'baseline' || command == 'run') {
    final output = await _run(command!, _Options(args), root);
    stdout.writeln(output);
  } else {
    throw const FormatException(
      'Use baseline [options], run --dataset ... --worker ..., '
      'or compare baseline.json candidate.json',
    );
  }
}

Future<String> _run(String command, _Options options, String root) async {
  final sampling = BenchmarkSampling(
    samples: options.integer('samples', 21),
    warmups: options.integer('warmups', 5),
    processes: options.integer('processes', 3),
  );
  final label =
      options['label'] ?? (command == 'baseline' ? 'dart-aot' : 'candidate');
  if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(label)) {
    throw const FormatException(
      'Label must contain only letters, digits, _ and -',
    );
  }
  final parent = Directory(
    _resolve(root, options['output-dir'] ?? '.local/performance/mobi'),
  );
  await parent.create(recursive: true);
  final directory = (await parent.createTemp('$label-')).absolute.path;
  final artifacts = <String>[];
  final environment = {...Platform.environment};
  late String worker;
  final dataset = p.join(directory, 'dataset.json');
  if (command == 'baseline') {
    final name = Platform.isWindows
        ? 'mobi_decoder_benchmark.exe'
        : 'mobi_decoder_benchmark';
    final bundle = p.join(directory, 'bundle');
    worker = p.join(bundle, 'bin', name);
    stderr.writeln('Compiling Dart reference decoder in AOT...');
    await runCommand(
      [
        ...dartCommand(root: root),
        'build',
        'cli',
        '--target',
        'bin/mobi_decoder_benchmark.dart',
        '--output',
        directory,
      ],
      workingDirectory: root,
      maxOutputBytes: _maxOutputBytes,
    );
    artifacts.addAll(
      (await _bundleFiles(bundle)).where((file) => file != worker),
    );
    final books = options.books.isEmpty
        ? ['packages/pagecraft/test/fixtures/mobi/six.mobi']
        : options.books;
    await runCommand(
      [worker, 'prepare', dataset, ...books],
      workingDirectory: root,
      maxOutputBytes: _maxOutputBytes,
    );
  } else {
    if (options['worker'] == null || options['dataset'] == null) {
      throw const FormatException('run needs --worker and --dataset');
    }
    final originalWorker = _resolve(root, options['worker']!);
    if (options['bundle'] case final bundlePath?) {
      final originalBundle = _resolve(root, bundlePath);
      final relative = p.relative(originalWorker, from: originalBundle);
      if (relative == '.' ||
          p.isAbsolute(relative) ||
          p.split(relative).first == '..') {
        throw const FormatException('Worker must be inside the bundle');
      }
      final bundle = p.join(directory, 'bundle');
      await copyTree(originalBundle, bundle);
      worker = p.join(bundle, relative);
      artifacts.addAll(
        (await _bundleFiles(bundle)).where((file) => file != worker),
      );
    } else {
      worker = p.join(directory, 'worker${p.extension(originalWorker)}');
      await copyFilePreservingMode(originalWorker, worker);
    }
    await _writeNew(
      dataset,
      await File(_resolve(root, options['dataset']!)).readAsBytes(),
    );
  }
  String? library;
  for (final file in [
    ...options.artifacts,
    ?options['library'],
  ]) {
    final original = _resolve(root, file);
    final copy = p.join(
      directory,
      'artifact-${artifacts.length}-${p.basename(original)}',
    );
    await copyFilePreservingMode(original, copy);
    artifacts.add(copy);
    if (file == options['library']) {
      environment['MOBI_RUST_LIBRARY'] = copy;
      library = copy;
    }
  }
  final datasetBytes = await File(dataset).readAsBytes();
  final inputs = _object(jsonDecode(utf8.decode(datasetBytes)), 'dataset');
  final cases = _objects(inputs['cases'], 'dataset cases');
  if (inputs['protocol'] != mobiBenchmarkProtocol || cases.isEmpty) {
    throw const FormatException('Invalid dataset');
  }
  final host = await machineInfo();
  final machine = <String, Object?>{
    for (final key in [
      'platform',
      'arch',
      'release',
      'cpu',
      'logicalCpus',
      'memoryBytes',
    ])
      key: host[key],
  };
  machine['fingerprint'] = sha256
      .convert(
        utf8.encode(jsonEncode({...machine, 'host': host['hostname']})),
      )
      .toString();
  final report = <String, Object?>{
    'status': 'complete',
    'protocol': mobiBenchmarkProtocol,
    'label': label,
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'datasetSha256': sha256.convert(datasetBytes).toString(),
    'machine': machine,
    'sampling': sampling.toJson(),
    'scope':
        'host AOT, in-memory decoder batches; excludes file I/O, UI, '
        'process startup and library initialization',
    'execution': {
      'worker': p.relative(worker, from: directory),
      'nativeLibrary': library == null
          ? null
          : p.relative(library, from: directory),
    },
  };
  final measured = <JsonObject>[];
  for (final input in cases) {
    final id = _string(input['id'], 'case id');
    stderr.writeln('Measuring $id (${sampling.processes} fresh processes)...');
    final runs = <JsonObject>[];
    for (var process = 0; process < sampling.processes; process++) {
      final result = await runCommand(
        [worker, dataset, id, '${sampling.samples}', '${sampling.warmups}'],
        workingDirectory: root,
        environment: environment,
        maxOutputBytes: _maxOutputBytes,
      );
      final run = _object(jsonDecode(result.stdout as String), 'worker result');
      validateWorker(run, input, sampling);
      report['runtime'] ??= run['runtime'];
      report['implementation'] ??= run['implementation'];
      if (report['runtime'] != run['runtime'] ||
          report['implementation'] != run['implementation']) {
        throw const FormatException('Worker identity changed');
      }
      runs.add(run);
    }
    measured.add({
      'id': id,
      if (input.containsKey('source')) 'source': input['source'],
      if (input.containsKey('compression')) 'compression': input['compression'],
      'records': runs.first['records'],
      'inputBytes': runs.first['inputBytes'],
      'outputBytes': runs.first['outputBytes'],
      'outputSha256': sha256
          .convert(utf8.encode(jsonEncode(input['expected'])))
          .toString(),
      'runs': runs,
    });
  }
  report['cases'] = measured;
  report['artifacts'] = [
    for (final file in [worker, ...artifacts])
      {
        'name': p.relative(file, from: directory),
        'bytes': await File(file).length(),
        'sha256': await hashFile(file),
      },
  ];
  _validateReport(report);
  final output = p.join(directory, 'report.json');
  await _writeNew(
    output,
    utf8.encode('${const JsonEncoder.withIndent('  ').convert(report)}\n'),
  );
  return output;
}

Future<List<String>> _bundleFiles(String directory) async {
  final files = <String>[];
  await for (final entry in Directory(directory).list(followLinks: false)) {
    if (entry is Directory) {
      files.addAll(await _bundleFiles(entry.path));
    } else if (entry is File) {
      files.add(entry.path);
    } else {
      throw FileSystemException('Unsupported bundle entry', entry.path);
    }
  }
  return files..sort();
}

Future<void> _writeNew(String path, List<int> bytes) async {
  final file = await File(path).create(exclusive: true);
  await file.writeAsBytes(bytes);
}

Future<JsonObject> _readObject(String path) async =>
    _object(jsonDecode(await File(path).readAsString()), path);

String _resolve(String root, String path) =>
    p.normalize(p.isAbsolute(path) ? path : p.join(root, path));

String _format(double? value) => value?.toStringAsFixed(3) ?? 'n/a';

JsonObject _object(Object? value, String field) {
  if (value is! Map<String, Object?>) {
    throw FormatException('Expected object: $field');
  }
  return value;
}

List<Object?> _list(Object? value, String field) {
  if (value is! List<Object?>) throw FormatException('Expected list: $field');
  return value;
}

List<JsonObject> _objects(Object? value, String field) =>
    _list(value, field).map((entry) => _object(entry, field)).toList();

List<num> _numbers(Object? value, String field) =>
    _list(value, field).map((entry) => _number(entry, field)).toList();

num _number(Object? value, String field) {
  if (value is! num || !value.isFinite || value < 0) {
    throw FormatException('Invalid number: $field');
  }
  return value;
}

int _integer(Object? value, String field, {int minimum = 0}) {
  if (value is! int || value < minimum) {
    throw FormatException('Invalid integer: $field');
  }
  return value;
}

String _string(Object? value, String field) {
  if (value is! String || value.isEmpty) {
    throw FormatException('Invalid string: $field');
  }
  return value;
}

void _hash(Object? value, String field) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(_string(value, field))) {
    throw FormatException('Invalid hash: $field');
  }
}

int _decodedBytes(List<Object?> records) => records.fold<int>(
  0,
  (total, record) => total + base64Decode(_string(record, 'record')).length,
);

Future<void> main(List<String> arguments) async {
  try {
    await runMobiBenchmark(arguments, root: repositoryRootFromScript());
  } catch (error, stack) {
    stderr.writeln('$error\n$stack');
    exitCode = 1;
  }
}
