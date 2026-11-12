import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'src/tool_support.dart';

const readerPartsProtocol = 'reader-parts-v1';
const readerPartsOrder = ['dart', 'rust', 'rust', 'dart'];
const readerPartsSamples = 21;
const readerPartsWarmups = 3;
const readerPartsSourceDirectories = [
  'benchmarks/reader_native/bin',
  'benchmarks/reader_native/lib',
  'benchmarks/reader_native/rust/src',
  'packages/pagecraft/lib',
  'packages/pagecraft/rust/src',
  'packages/pagecraft/hook',
];
const readerPartsSourceFiles = [
  'benchmarks/reader_native/pubspec.lock',
  'benchmarks/reader_native/flutter_rust_bridge.yaml',
  'benchmarks/reader_native/rust/Cargo.toml',
  'benchmarks/reader_native/rust/Cargo.lock',
  'packages/pagecraft/pubspec.yaml',
  'packages/pagecraft/pubspec.lock',
  'packages/pagecraft/rust/Cargo.toml',
  'packages/pagecraft/rust/Cargo.lock',
  'packages/pagecraft/rust/rust-toolchain.toml',
  'packages/pagecraft/flutter_rust_bridge.yaml',
  'benchmarks/mobi_rust/rust/src/decoder.rs',
  'scripts/reader_parts.dart',
  'scripts/src/tool_support.dart',
  'pubspec.yaml',
  'pubspec.lock',
  '.fvmrc',
];

typedef ReaderCommandRunner = Future<ProcessResult> Function(
  List<String> command, {
  String? workingDirectory,
  Map<String, String>? environment,
  Duration? timeout,
  int? maxOutputBytes,
});

class ReaderPartsResult {
  const ReaderPartsResult({required this.file, required this.report});

  final File file;
  final Map<String, Object?> report;

  bool get successful => (report['failures']! as List).isEmpty;
}

class ReaderPartsCase {
  const ReaderPartsCase({
    required this.id,
    required this.expected,
    required this.data,
  });

  final String id;
  final String expected;
  final Map<String, Object?> data;
}

class ReaderPartsDataset {
  const ReaderPartsDataset({required this.files, required this.cases});

  factory ReaderPartsDataset.parse(Object? value) {
    final object = _object(value, 'dataset');
    if (object['protocol'] != readerPartsProtocol) {
      throw const FormatException('Dataset protocol differs');
    }
    final inputs = _object(object['files'], 'dataset files');
    final files = <String, String>{};
    for (final entry in inputs.entries) {
      if (!_flatFile(entry.key) || entry.key == 'dataset.json') {
        throw FormatException('Expected flat dataset file: ${entry.key}');
      }
      files[entry.key] = _digest(entry.value, 'input hash for ${entry.key}');
    }
    if (files.isEmpty) throw const FormatException('Dataset has no files');
    final rawCases = object['cases'];
    if (rawCases is! List || rawCases.isEmpty) {
      throw const FormatException('Dataset has no cases');
    }
    final ids = <String>{};
    final cases = <ReaderPartsCase>[];
    for (final value in rawCases) {
      final job = _object(value, 'case');
      final id = _text(job['id'], 'case ID');
      if (!ids.add(id)) throw FormatException('Duplicate case ID: $id');
      _text(job['kind'], 'case kind');
      final names = job['inputs'];
      if (names is! List || names.isEmpty) {
        throw FormatException('Case $id has no inputs');
      }
      for (final name in names) {
        if (name is! String || !files.containsKey(name)) {
          throw FormatException('Case $id references unknown input: $name');
        }
      }
      cases.add(
        ReaderPartsCase(
          id: id,
          expected: _digest(job['expected'], 'expected output for $id'),
          data: job,
        ),
      );
    }
    return ReaderPartsDataset(files: files, cases: cases);
  }

  final Map<String, String> files;
  final List<ReaderPartsCase> cases;
}

/// Rejects incomplete or mismatched worker evidence before using its timings.
Map<String, Object?> validateReaderWorker(
  Object? value,
  ReaderPartsCase job,
  String implementation, {
  int samples = readerPartsSamples,
}) {
  final result = _object(value, 'worker result');
  if (result['protocol'] != readerPartsProtocol ||
      result['caseId'] != job.id ||
      result['implementation'] != implementation ||
      result['outputSha256'] != job.expected) {
    throw FormatException('Worker evidence differs for ${job.id}');
  }
  _text(result['runtime'], 'worker runtime');
  for (final field in ['setupUs', 'firstUs']) {
    _timing(result[field], field);
  }
  final rss = _timing(result['maxRssBytes'], 'maxRssBytes');
  if (rss <= 0) throw const FormatException('Missing process RSS');
  final values = result['samplesUs'];
  if (values is! List || values.length != samples) {
    throw FormatException('Expected $samples worker samples');
  }
  final timings = [
    for (final value in values) _timing(value, 'sample'),
  ]..sort();
  if (samples < 1 ||
      result['medianUs'] != timings[timings.length ~/ 2] ||
      result['p95Us'] != timings[(timings.length * .95).ceil() - 1]) {
    throw const FormatException('Worker statistics differ from raw samples');
  }
  return result;
}

Future<ReaderPartsResult> runReaderParts({
  required String root,
  required String datasetPath,
  required String bundlePath,
  required String libraryPath,
  ReaderCommandRunner commandRunner = runCommand,
  Future<Map<String, Object?>> Function() machineProvider = machineInfo,
  StringSink? output,
  StringSink? errors,
}) async {
  final progress = output ?? stdout;
  final diagnostics = errors ?? stderr;
  root = p.normalize(p.absolute(root));
  datasetPath = p.normalize(p.absolute(datasetPath));
  bundlePath = p.normalize(p.absolute(bundlePath));
  libraryPath = p.normalize(p.absolute(libraryPath));
  final libraryName = p.basename(libraryPath);
  if (const {
    'bundle',
    'data',
    'sources',
    'progress.json',
    'report.json',
  }.contains(libraryName)) {
    throw ArgumentError.value(libraryName, 'library', 'reserved output name');
  }
  final originalDataset = await File(datasetPath).readAsBytes();
  final data = ReaderPartsDataset.parse(
    jsonDecode(utf8.decode(originalDataset)),
  );
  final parent = Directory(p.join(root, '.local/performance/reader-parts'));
  await parent.create(recursive: true);
  final directory = await parent.createTemp('comparison-');
  await copyTree(bundlePath, p.join(directory.path, 'bundle'));
  final library = await File(
    libraryPath,
  ).copy(p.join(directory.path, libraryName));
  final dataDirectory = Directory(p.join(directory.path, 'data'));
  await dataDirectory.create();
  for (final entry in data.files.entries) {
    final bytes = await File(
      p.join(p.dirname(datasetPath), entry.key),
    ).readAsBytes();
    if (sha256.convert(bytes).toString() != entry.value) {
      throw StateError('Input hash differs: ${entry.key}');
    }
    await _writeNewFile(File(p.join(dataDirectory.path, entry.key)), bytes);
  }
  final dataset = File(p.join(dataDirectory.path, 'dataset.json'));
  await _writeNewFile(dataset, originalDataset);
  final artifacts = await _hashTree(
    p.join(directory.path, 'bundle'),
    prefix: 'bundle',
  );
  artifacts[libraryName] = await hashFile(library.path);
  artifacts['dataset.json'] = await hashFile(dataset.path);
  final sources = <String, String>{};
  for (final relative in readerPartsSourceDirectories) {
    sources.addAll(
      await _hashTree(p.join(root, relative), prefix: relative),
    );
  }
  for (final relative in readerPartsSourceFiles) {
    sources[relative] = await hashFile(p.join(root, relative));
  }
  for (final entry in sources.entries) {
    final bytes = await File(p.join(root, entry.key)).readAsBytes();
    if (sha256.convert(bytes).toString() != entry.value) {
      throw StateError('Source changed during freezing: ${entry.key}');
    }
    final target = File(p.join(directory.path, 'sources', entry.key));
    await target.parent.create(recursive: true);
    await _writeNewFile(target, bytes);
  }
  final worker = p.join(
    directory.path,
    'bundle',
    'bin',
    Platform.isWindows
        ? 'reader_parts_benchmark.exe'
        : 'reader_parts_benchmark',
  );
  if (!await File(worker).exists()) {
    throw StateError('Missing AOT worker: $worker');
  }
  // Resolve toolchains before starting the potentially long measurement run.
  final machine = await machineProvider();
  final rustc = await commandRunner(['rustc', '--version', '--verbose']);
  final compiler = await commandRunner(
    ['rustup', 'which', 'rustc'],
    workingDirectory: p.join(root, 'packages/pagecraft/rust'),
  );
  final compilerPath = _text(compiler.stdout.toString().trim(), 'rustc path');
  final productionRustc = await commandRunner([
    compilerPath,
    '--version',
    '--verbose',
  ]);
  final runs = <Map<String, Object?>>[];
  final failures = <Map<String, Object?>>[];
  for (var round = 0; round < readerPartsOrder.length; round++) {
    final implementation = readerPartsOrder[round];
    for (final job in data.cases) {
      try {
        final process = await commandRunner(
          [worker, dataset.path, job.id, implementation, '$readerPartsSamples'],
          workingDirectory: directory.path,
          environment: {'READER_BENCHMARK_LIBRARY': library.path},
          timeout: const Duration(minutes: 2),
          maxOutputBytes: 1024 * 1024,
        );
        if (process.exitCode != 0) {
          throw StateError(
            'Worker exited with ${process.exitCode}: ${process.stderr}',
          );
        }
        final result = validateReaderWorker(
          jsonDecode(process.stdout.toString()),
          job,
          implementation,
        );
        runs.add({...result, 'round': round});
        progress.writeln(
          '${round + 1} $implementation ${job.id}: '
          '${((result['medianUs']! as num) / 1000).toStringAsFixed(3)} ms',
        );
      } catch (error) {
        final detail = error.toString();
        failures.add({
          'round': round,
          'implementation': implementation,
          'caseId': job.id,
          'error': detail,
        });
        diagnostics.writeln(
          '$implementation ${job.id}: ${detail.split('\n').first}',
        );
      }
    }
    await _writeJson(File(p.join(directory.path, 'progress.json')), {
      'runs': runs,
      'failures': failures,
    });
  }
  final summary = <Map<String, Object?>>[];
  for (final job in data.cases) {
    final backends = <String, Map<String, Object?>?>{};
    for (final implementation in const ['dart', 'rust']) {
      final items = runs
          .where(
            (run) =>
                run['caseId'] == job.id &&
                run['implementation'] == implementation,
          )
          .toList();
      backends[implementation] = items.length == 2
          ? {
              'medianUs': _median([
                for (final item in items)
                  ...(item['samplesUs']! as List).cast<num>(),
              ]),
              'processMediansUs': [for (final item in items) item['medianUs']],
              'maxRssBytes': items
                  .map((item) => item['maxRssBytes']! as num)
                  .reduce((a, b) => a > b ? a : b),
              'setupUs': [for (final item in items) item['setupUs']],
              'firstUs': [for (final item in items) item['firstUs']],
            }
          : null;
    }
    final dart = backends['dart'];
    final rust = backends['rust'];
    final rustMedian = rust?['medianUs'] as num?;
    summary.add({
      'caseId': job.id,
      ...backends,
      'speedup': dart != null && rustMedian != null && rustMedian > 0
          ? (dart['medianUs']! as num) / rustMedian
          : null,
    });
  }
  final report = <String, Object?>{
    'protocol': readerPartsProtocol,
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'machine': machine,
    'rustc': rustc.stdout.toString(),
    'productionRustc': productionRustc.stdout.toString(),
    'order': readerPartsOrder,
    'samplesPerProcess': readerPartsSamples,
    'warmups': readerPartsWarmups,
    'artifacts': artifacts,
    'sourcesAtRun': sources,
    'frozenSources': 'sources/',
    'inputs': data.files,
    'cases': [for (final job in data.cases) job.data],
    'summary': summary,
    'runs': runs,
    'failures': failures,
  };
  final file = File(p.join(directory.path, 'report.json'));
  await _writeJson(file, report);
  progress.writeln(file.path);
  return ReaderPartsResult(file: file, report: report);
}

Future<Map<String, String>> _hashTree(
  String directory, {
  required String prefix,
}) async {
  final result = <String, String>{};
  final entries = await Directory(directory).list(followLinks: false).toList();
  entries.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
  for (final entry in entries) {
    final relative = p.join(prefix, p.basename(entry.path));
    if (entry is Directory) {
      result.addAll(await _hashTree(entry.path, prefix: relative));
    } else if (entry is File) {
      result[relative] = await hashFile(entry.path);
    } else {
      throw FileSystemException('Cannot freeze symbolic links', entry.path);
    }
  }
  return result;
}

Future<void> _writeNewFile(File file, List<int> bytes) async {
  await file.create(exclusive: true);
  await file.writeAsBytes(bytes);
}

Future<void> _writeJson(File file, Object value) async {
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(value));
}

Map<String, Object?> _object(Object? value, String label) {
  if (value is! Map<String, Object?>) {
    throw FormatException('Expected $label object');
  }
  return value;
}

String _text(Object? value, String label) {
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing $label');
  }
  return value;
}

String _digest(Object? value, String label) {
  final text = _text(value, label);
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(text)) {
    throw FormatException('Invalid $label');
  }
  return text;
}

bool _flatFile(String name) =>
    name.isNotEmpty &&
    name != '.' &&
    name != '..' &&
    !name.contains('/') &&
    !name.contains(String.fromCharCode(92));

num _timing(Object? value, String label) {
  if (value is! num || !value.isFinite || value < 0) {
    throw FormatException('Invalid $label');
  }
  return value;
}

num _median(List<num> values) {
  final sorted = [...values]..sort();
  return sorted[sorted.length ~/ 2];
}

Future<void> main(List<String> arguments) async {
  try {
    if (arguments.length != 3) {
      throw ArgumentError(
        'Use dart scripts/reader_parts.dart '
        '<dataset.json> <AOT bundle> <release library>',
      );
    }
    final result = await runReaderParts(
      root: repositoryRootFromScript(),
      datasetPath: arguments[0],
      bundlePath: arguments[1],
      libraryPath: arguments[2],
    );
    if (!result.successful) exitCode = 1;
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
