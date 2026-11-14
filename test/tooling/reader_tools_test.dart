@Tags(['tooling'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../scripts/reader_corpus.dart';
import '../../scripts/reader_parts.dart';

void main() {
  late Directory temporary;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('reader-tools-test-');
  });
  tearDown(() async {
    await temporary.delete(recursive: true);
  });

  test('benchmark fingerprints reference existing source and lock files', () {
    for (final file in readerPartsSourceFiles) {
      expect(File(file).existsSync(), isTrue, reason: file);
    }
  });

  group('reader corpus', () {
    test('selects default size quantiles with stable IDs and hashes', () async {
      for (var size = 1; size <= 20; size++) {
        await _writeBytes(temporary, '$size.epub', List.filled(size, size));
      }

      final result = await selectReaderCorpus(temporary);

      expect(result.available, {'epub': 20});
      expect(result.selected, {'epub': 12});
      expect(
        result.files.map((file) => file['bytes']),
        [1, 3, 4, 6, 8, 10, 11, 13, 15, 17, 18, 20],
      );
      for (var index = 0; index < result.files.length; index++) {
        final file = result.files[index];
        final size = file['bytes']! as int;
        expect(file['id'], 'epub-${(index + 1).toString().padLeft(2, '0')}');
        expect(file['path'], p.join(temporary.path, '$size.epub'));
        expect(file['sha256'], _hash(List.filled(size, size)));
      }
    });

    test(
      'inventories supported formats and skips hidden and device files',
      () async {
        for (final name in [
          'nested/book.FB2.ZIP',
          'book.azw3',
          'book.cbz',
          'book.pdf',
          'book.cbr',
          'book.djvu',
          'unrelated.txt',
          '.hidden.epub',
          '.hidden/book.mobi',
          'System/book.epub',
          'nested/System/book.epub',
        ]) {
          await _write(temporary, name, name);
        }
        if (!Platform.isWindows) {
          await Link(p.join(temporary.path, 'linked.epub')).create(
            p.join(temporary.path, 'unrelated.txt'),
          );
          await Link(p.join(temporary.path, 'linked-directory')).create(
            p.join(temporary.path, 'nested'),
          );
        }

        final result = await selectReaderCorpus(temporary);

        expect(result.available, {
          'azw3': 1,
          'cbz': 1,
          'pdf': 1,
          'cbr': 1,
          'djvu': 1,
          'fb2.zip': 1,
        });
        expect(result.selected, {'azw3': 1, 'fb2.zip': 1, 'cbz': 1});
        expect(result.files.map((file) => file['id']), [
          'azw3-01',
          'fb2-zip-01',
          'cbz-01',
        ]);
      },
    );

    test(
      'uses one deterministic representative per size and exact hash',
      () async {
        await _write(temporary, 'a.epub', 'aaa');
        await _write(temporary, 'Z.epub', 'ZZZ');
        await _write(temporary, 'duplicate.epub', 'aaa');
        await _write(temporary, 'larger.epub', 'larger');

        final result = await selectReaderCorpus(temporary);

        // Equal-size paths use code-unit order rather than host locale collation.
        expect(result.available, {'epub': 4});
        expect(
          result.files.map((file) => p.basename(file['path']! as String)),
          [
            'duplicate.epub',
            'larger.epub',
          ],
        );
        expect(
          result.files.map((file) => file['sha256']).toSet(),
          hasLength(2),
        );
      },
    );

    test('rejects invalid limits and missing source directories', () async {
      await expectLater(
        selectReaderCorpus(temporary, limits: {'epub': 0}),
        throwsArgumentError,
      );
      await expectLater(
        selectReaderCorpus(Directory(p.join(temporary.path, 'missing'))),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('reader worker protocol', () {
    test('validates raw samples, identity and output hash', () {
      final job = ReaderPartsDataset.parse(_dataset()).cases.single;
      final output = _worker(job.id, 'dart', job.expected);
      expect(validateReaderWorker(output, job, 'dart'), output);

      for (final mutation in <String, Object?>{
        'protocol': 'wrong',
        'caseId': 'wrong',
        'implementation': 'rust',
        'outputSha256': _hash(utf8.encode('wrong')),
        'runtime': '',
        'setupUs': -1,
        'firstUs': double.nan,
        'maxRssBytes': 0,
        'samplesUs': [1, 2],
        'medianUs': 1,
        'p95Us': 1,
      }.entries) {
        expect(
          () => validateReaderWorker(
            {...output, mutation.key: mutation.value},
            job,
            'dart',
          ),
          throwsFormatException,
          reason: mutation.key,
        );
      }
      expect(
        () => validateReaderWorker(
          {
            ...output,
            'samplesUs': [double.infinity, ...List.filled(20, 10)],
          },
          job,
          'dart',
        ),
        throwsFormatException,
      );
    });

    test('checks statistics against unsorted raw samples', () {
      final job = ReaderPartsDataset.parse(_dataset()).cases.single;
      final samples = List.generate(21, (index) => 21 - index);
      final result = {
        ..._worker(job.id, 'dart', job.expected),
        'samplesUs': samples,
        'medianUs': 11,
        'p95Us': 20,
      };
      expect(validateReaderWorker(result, job, 'dart'), result);
      expect(result['samplesUs'], samples);
    });

    test('rejects unsafe manifests and unknown input references', () {
      for (final name in [
        '../input',
        'a/b',
        r'a\b',
        '.',
        '..',
        '',
        'dataset.json',
      ]) {
        expect(
          () => ReaderPartsDataset.parse({
            ..._dataset(),
            'files': {name: _hash(utf8.encode('input'))},
          }),
          throwsFormatException,
          reason: name,
        );
      }
      final dataset = _dataset();
      final job = (dataset['cases']! as List).single as Map<String, Object?>;
      for (final mutation in <String, Object?>{
        'protocol': 'wrong',
        'files': <String, Object?>{},
        'cases': <Object?>[],
      }.entries) {
        expect(
          () => ReaderPartsDataset.parse({
            ...dataset,
            mutation.key: mutation.value,
          }),
          throwsFormatException,
        );
      }
      for (final jobs in [
        [job, job],
        [
          {
            ...job,
            'inputs': ['missing'],
          },
        ],
        [
          {...job, 'expected': 'invalid'},
        ],
        [
          {...job, 'kind': ''},
        ],
      ]) {
        expect(
          () => ReaderPartsDataset.parse({...dataset, 'cases': jobs}),
          throwsFormatException,
        );
      }
    });
  });

  group('frozen reader comparison', () {
    test(
      'runs fresh ABBA workers over frozen inputs and keeps raw evidence',
      () async {
        final fixture = await _ReaderFixture.create(temporary, cases: 2);
        final calls = <List<String>>[];
        final output = StringBuffer();
        final errors = StringBuffer();
        var mutated = false;
        Future<ProcessResult> run(
          List<String> command, {
          String? workingDirectory,
          Map<String, String>? environment,
          Duration? timeout,
          int? maxOutputBytes,
        }) async {
          if (environment == null) return _toolchain(command);
          calls.add(command);
          expect(command, hasLength(5));
          expect(command.last, '21');
          expect(timeout, const Duration(minutes: 2));
          expect(maxOutputBytes, 1024 * 1024);
          final frozen = Directory(workingDirectory!);
          expect(
            command.first,
            p.join(frozen.path, 'bundle', 'bin', fixture.workerName),
          );
          expect(command[1], p.join(frozen.path, 'data', 'dataset.json'));
          expect(
            environment['READER_BENCHMARK_LIBRARY'],
            p.join(frozen.path, 'native.bin'),
          );
          if (!mutated) {
            mutated = true;
            await fixture.input.writeAsString('changed original input');
            await fixture.dataset.writeAsString('changed original manifest');
            await fixture.library.writeAsString('changed original library');
            await fixture.worker.writeAsString('changed original worker');
            await File(
              p.join(fixture.root.path, readerPartsSourceFiles.first),
            ).writeAsString('changed original source');
          }
          expect(
            await File(command.first).readAsString(),
            'AOT worker fixture',
          );
          expect(
            await File(environment['READER_BENCHMARK_LIBRARY']!).readAsString(),
            'native fixture',
          );
          expect(
            await File(p.join(frozen.path, 'data', 'input.txt')).readAsString(),
            'input',
          );
          expect(
            jsonDecode(await File(command[1]).readAsString()),
            fixture.manifest,
          );
          final backend = command[3];
          final expected =
              fixture.jobs.singleWhere(
                    (job) => job['id'] == command[2],
                  )['expected']!
                  as String;
          final evidence = _worker(command[2], backend, expected);
          if (backend == 'dart' && calls.length > 6) {
            evidence.addAll({
              'samplesUs': List.filled(21, 22),
              'medianUs': 22,
              'p95Us': 22,
            });
          }
          return ProcessResult(
            calls.length,
            0,
            jsonEncode(evidence),
            '',
          );
        }

        final result = await fixture.run(run, output: output, errors: errors);

        expect(result.successful, isTrue);
        expect(errors.toString(), isEmpty);
        expect(calls.map((call) => '${call[3]}:${call[2]}'), [
          'dart:case-0',
          'dart:case-1',
          'rust:case-0',
          'rust:case-1',
          'rust:case-0',
          'rust:case-1',
          'dart:case-0',
          'dart:case-1',
        ]);
        final report = jsonDecode(await result.file.readAsString()) as Map;
        expect(report['protocol'], readerPartsProtocol);
        expect(report['order'], ['dart', 'rust', 'rust', 'dart']);
        expect(report['samplesPerProcess'], 21);
        expect(report['warmups'], 3);
        expect(report['inputs'], fixture.manifest['files']);
        expect(report['runs'], hasLength(8));
        expect(report['failures'], isEmpty);
        for (final summary in report['summary'] as List) {
          // The upper median of 42 pooled samples is 22, rather than 21.
          expect(summary['speedup'], 2.2);
          expect(summary['dart']['medianUs'], 22);
          expect(summary['rust']['medianUs'], 10);
          expect(summary['dart']['processMediansUs'], [20, 22]);
        }
        for (final raw in report['runs'] as List) {
          expect(raw['samplesUs'], hasLength(21));
          expect(raw['runtime'], 'Dart test runtime');
          expect(raw['round'], inInclusiveRange(0, 3));
        }
        final artifacts = report['artifacts'] as Map;
        expect(artifacts['native.bin'], _hash(utf8.encode('native fixture')));
        expect(
          artifacts[p.join('bundle', 'bin', fixture.workerName)],
          _hash(utf8.encode('AOT worker fixture')),
        );
        final sourceHashes = report['sourcesAtRun'] as Map;
        expect(sourceHashes.keys, containsAll(readerPartsSourceFiles));
        for (final entry in sourceHashes.entries) {
          final frozenBytes = await File(
            p.join(result.file.parent.path, 'sources', entry.key as String),
          ).readAsBytes();
          expect(_hash(frozenBytes), entry.value);
        }
        final progress = jsonDecode(
          await File(
            p.join(result.file.parent.path, 'progress.json'),
          ).readAsString(),
        ) as Map;
        expect(progress['runs'], report['runs']);
        expect(progress['failures'], isEmpty);
        expect(output.toString().trim().split('\n').last, result.file.path);
      },
    );

    test('retains failed cases and refuses incomplete summaries', () async {
      final fixture = await _ReaderFixture.create(temporary);
      Future<ProcessResult> run(
        List<String> command, {
        String? workingDirectory,
        Map<String, String>? environment,
        Duration? timeout,
        int? maxOutputBytes,
      }) async {
        if (environment == null) return _toolchain(command);
        return ProcessResult(1, 0, '{"protocol":"wrong"}', '');
      }

      final result = await fixture.run(run);

      expect(result.successful, isFalse);
      expect(result.report['runs'], isEmpty);
      final failures = result.report['failures']! as List;
      expect(failures, hasLength(4));
      expect(
        failures.map((failure) => failure['implementation']),
        readerPartsOrder,
      );
      final summary = (result.report['summary']! as List).single as Map;
      expect(summary, {
        'caseId': 'case-0',
        'dart': null,
        'rust': null,
        'speedup': null,
      });
      expect(await result.file.exists(), isTrue);
    });

    test('rejects changed input bytes before running any workers', () async {
      final fixture = await _ReaderFixture.create(temporary);
      await fixture.input.writeAsString('changed input');
      var calls = 0;
      Future<ProcessResult> run(
        List<String> command, {
        String? workingDirectory,
        Map<String, String>? environment,
        Duration? timeout,
        int? maxOutputBytes,
      }) async {
        calls++;
        return _toolchain(command);
      }

      await expectLater(fixture.run(run), throwsStateError);
      expect(calls, 0);
    });
  });
}

class _ReaderFixture {
  const _ReaderFixture({
    required this.root,
    required this.dataset,
    required this.input,
    required this.bundle,
    required this.worker,
    required this.library,
    required this.manifest,
  });

  final Directory root;
  final File dataset;
  final File input;
  final Directory bundle;
  final File worker;
  final File library;
  final Map<String, Object?> manifest;

  String get workerName => Platform.isWindows
      ? 'reader_parts_benchmark.exe'
      : 'reader_parts_benchmark';
  List<Map<String, Object?>> get jobs =>
      (manifest['cases']! as List).cast<Map<String, Object?>>();

  static Future<_ReaderFixture> create(
    Directory temporary, {
    int cases = 1,
  }) async {
    final root = Directory(p.join(temporary.path, 'repository'));
    await root.create();
    for (final directory in readerPartsSourceDirectories) {
      await _write(root, '$directory/source', 'source fixture $directory');
    }
    for (final file in readerPartsSourceFiles) {
      await _write(root, file, 'source fixture $file');
    }
    final input = await _write(root, 'original-data/input.txt', 'input');
    final manifest = _dataset(cases: cases);
    final dataset = await _write(
      root,
      'original-data/dataset.json',
      jsonEncode(manifest),
    );
    final workerName = Platform.isWindows
        ? 'reader_parts_benchmark.exe'
        : 'reader_parts_benchmark';
    final worker = await _write(
      root,
      'original-bundle/bin/$workerName',
      'AOT worker fixture',
    );
    await _write(root, 'original-bundle/lib/asset', 'bundle asset');
    final library = await _write(
      root,
      'original-library/native.bin',
      'native fixture',
    );
    return _ReaderFixture(
      root: root,
      dataset: dataset,
      input: input,
      bundle: Directory(p.join(root.path, 'original-bundle')),
      worker: worker,
      library: library,
      manifest: manifest,
    );
  }

  Future<ReaderPartsResult> run(
    ReaderCommandRunner commandRunner, {
    StringSink? output,
    StringSink? errors,
  }) => runReaderParts(
    root: root.path,
    datasetPath: dataset.path,
    bundlePath: bundle.path,
    libraryPath: library.path,
    commandRunner: commandRunner,
    machineProvider: () async => {'platform': 'test', 'arch': 'test'},
    output: output ?? StringBuffer(),
    errors: errors ?? StringBuffer(),
  );
}

Map<String, Object?> _dataset({int cases = 1}) => {
  'protocol': readerPartsProtocol,
  'files': {'input.txt': _hash(utf8.encode('input'))},
  'cases': [
    for (var index = 0; index < cases; index++)
      {
        'id': 'case-$index',
        'kind': 'html',
        'inputs': ['input.txt'],
        'expected': _hash(utf8.encode('expected output $index')),
      },
  ],
};

Map<String, Object?> _worker(String id, String backend, String expected) {
  final time = backend == 'dart' ? 20 : 10;
  return {
    'protocol': readerPartsProtocol,
    'caseId': id,
    'implementation': backend,
    'runtime': 'Dart test runtime',
    'setupUs': 1,
    'firstUs': 2,
    'samplesUs': List.filled(21, time),
    'medianUs': time,
    'p95Us': time,
    'maxRssBytes': 1024,
    'outputSha256': expected,
  };
}

ProcessResult _toolchain(List<String> command) => ProcessResult(
  1,
  0,
  command.first == 'rustup' ? '/frozen-toolchain/rustc\n' : 'rustc fixture\n',
  '',
);

Future<File> _write(Directory root, String path, String value) =>
    _writeBytes(root, path, utf8.encode(value));

Future<File> _writeBytes(Directory root, String path, List<int> value) async {
  final file = File(p.join(root.path, path));
  await file.parent.create(recursive: true);
  await file.writeAsBytes(value);
  return file;
}

String _hash(List<int> bytes) => sha256.convert(bytes).toString();
