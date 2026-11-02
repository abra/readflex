import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

typedef JsonMap = Map<String, Object?>;

/// Hits are unioned across suites; running a line again cannot uncover it.
final class CoverageRecord {
  final lines = <int, int>{};
  final branches = <String, int>{};
}

final class CoverageSummary {
  const CoverageSummary({
    required this.measured,
    required this.linesHit,
    required this.linesFound,
    required this.branchesHit,
    required this.branchesFound,
    required this.uncoveredLines,
    required this.uncoveredBranches,
  });

  final bool measured;
  final int linesHit;
  final int linesFound;
  final int branchesHit;
  final int branchesFound;
  final List<int> uncoveredLines;
  final List<String> uncoveredBranches;

  JsonMap toJson() => {
    'measured': measured,
    'linesHit': linesHit,
    'linesFound': linesFound,
    'branchesHit': branchesHit,
    'branchesFound': branchesFound,
    'uncoveredLines': uncoveredLines,
    'uncoveredBranches': uncoveredBranches,
  };
}

final class CoverageTest {
  const CoverageTest({required this.name, required this.status, this.file});

  final String name;
  final String status;
  final String? file;

  JsonMap toJson() => {
    'name': name,
    if (file != null) 'file': file,
    'status': status,
  };
}

final class TestRunEvidence {
  const TestRunEvidence({required this.success, required this.tests});

  final bool success;
  final List<CoverageTest> tests;
}

final class SourceSnapshot {
  const SourceSnapshot({required this.packages, required this.files});

  factory SourceSnapshot.fromJson(JsonMap json) => SourceSnapshot(
    packages: (json['packages']! as List).cast<String>(),
    files: _object(json['files'], 'snapshot files').cast<String, String>(),
  );

  final List<String> packages;
  final Map<String, String> files;

  JsonMap toJson() => {'packages': packages, 'files': files};
}

final class SourceCoverage {
  const SourceCoverage({
    required this.package,
    required this.file,
    required this.coverage,
  });

  final String package;
  final String file;
  final CoverageSummary coverage;

  JsonMap toJson() => {
    'package': package,
    'file': file,
    ...coverage.toJson(),
  };
}

final class PackageCoverage {
  const PackageCoverage({
    required this.name,
    required this.files,
    required this.unmeasuredFiles,
    required this.linesHit,
    required this.linesFound,
    required this.branchesHit,
    required this.branchesFound,
  });

  final String name;
  final int files;
  final int unmeasuredFiles;
  final int linesHit;
  final int linesFound;
  final int branchesHit;
  final int branchesFound;

  JsonMap toJson() => {
    'name': name,
    'files': files,
    'unmeasuredFiles': unmeasuredFiles,
    'linesHit': linesHit,
    'linesFound': linesFound,
    'branchesHit': branchesHit,
    'branchesFound': branchesFound,
  };
}

final class SuiteCoverage {
  const SuiteCoverage({
    required this.name,
    required this.exitCode,
    required this.dartCoverage,
    this.success,
    this.platform,
    this.tests,
  });

  final String name;
  final int exitCode;
  final bool dartCoverage;
  final bool? success;
  final String? platform;
  final List<CoverageTest>? tests;

  JsonMap toJson() => {
    'name': name,
    'exitCode': exitCode,
    'dartCoverage': dartCoverage,
    if (success != null) 'success': success,
    if (platform != null) 'platform': platform,
    if (tests != null) 'tests': [for (final test in tests!) test.toJson()],
  };
}

final class CoverageReport {
  const CoverageReport({
    required this.createdAt,
    required this.complete,
    required this.successful,
    required this.excludedFiles,
    required this.packages,
    required this.files,
    required this.suites,
  });

  static const scope =
      'Owned active Dart packages. Suites without Dart instrumentation are '
      'execution evidence, not Dart coverage. Explicitly supplied native runs '
      'add line coverage only.';
  static const limitation =
      'Percentages cover VM-reported executable lines only. Unmeasured files '
      '(including export-only files) are listed, never treated as covered.';

  final String createdAt;
  final bool complete;
  final bool successful;
  final List<String> excludedFiles;
  final List<PackageCoverage> packages;
  final List<SourceCoverage> files;
  final List<SuiteCoverage> suites;

  JsonMap toJson() => {
    'createdAt': createdAt,
    'complete': complete,
    'successful': successful,
    'scope': scope,
    'limitation': limitation,
    'excludedFiles': excludedFiles,
    'packages': [for (final package in packages) package.toJson()],
    'files': [for (final file in files) file.toJson()],
    'suites': [for (final suite in suites) suite.toJson()],
  };
}

Map<String, CoverageRecord> mergeLcov(
  String text, {
  required String directory,
  required Map<String, String> packages,
  Map<String, CoverageRecord>? records,
}) {
  final merged = records ?? <String, CoverageRecord>{};
  CoverageRecord? record;
  for (final line in const LineSplitter().convert(text)) {
    if (line.startsWith('SF:')) {
      var source = line.substring(3);
      if (source.startsWith('package:')) {
        final parts = source.substring(8).split('/');
        final root = packages[parts.first];
        if (root == null) {
          throw FormatException('Unknown package in LCOV: ${parts.first}');
        }
        source = path.joinAll([root, 'lib', ...parts.skip(1)]);
      } else if (source.startsWith('file:')) {
        source = Uri.parse(source).toFilePath();
      } else {
        source = path.join(directory, source);
      }
      source = path.normalize(path.absolute(source));
      record = merged.putIfAbsent(source, CoverageRecord.new);
    } else if (line == 'end_of_record') {
      record = null;
    } else if (line.startsWith('DA:') || line.startsWith('BRDA:')) {
      if (record == null) {
        throw const FormatException('Coverage entry without source file');
      }
      final values = line.substring(line.indexOf(':') + 1).split(',');
      final branch = line.startsWith('BRDA:');
      if (values.length < (branch ? 4 : 2)) {
        throw FormatException('Malformed coverage entry: $line');
      }
      final rawHits = values[branch ? 3 : 1];
      final hits = rawHits == '-' ? 0 : int.tryParse(rawHits);
      if (hits == null || hits < 0) {
        throw FormatException('Invalid hits: $line');
      }
      if (branch) {
        final key = values.take(3).join(',');
        record.branches[key] = math.max(record.branches[key] ?? 0, hits);
      } else {
        final number = int.tryParse(values[0]);
        if (number == null || number <= 0) {
          throw FormatException('Invalid line number: $line');
        }
        record.lines[number] = math.max(record.lines[number] ?? 0, hits);
      }
    }
  }
  return merged;
}

TestRunEvidence parseTestEvents(String text) {
  final suites = <int, String>{};
  final tests = <int, JsonMap>{};
  bool? success;
  for (final line in const LineSplitter().convert(text)) {
    if (line.trim().isEmpty) continue;
    final event = _object(jsonDecode(line), 'test event');
    switch (event['type']) {
      case 'suite':
        final suite = _object(event['suite'], 'suite');
        suites[suite['id']! as int] = suite['path']! as String;
      case 'testStart':
        final test = _object(event['test'], 'test');
        tests[test['id']! as int] = {...test};
      case 'testDone':
        final test = tests[event['testID']];
        if (test == null) {
          throw const FormatException('Test completed without testStart');
        }
        test.addAll({
          'result': event['result'],
          'skipped': event['skipped'],
          'hidden': event['hidden'],
        });
      case 'done':
        final value = event['success'];
        if (value is! bool) {
          throw const FormatException('Invalid test completion status');
        }
        success = value;
    }
  }
  if (success == null) {
    throw const FormatException('Incomplete test run: missing done');
  }
  if (tests.values.any((test) => test['result'] == null)) {
    throw const FormatException('Incomplete test run: missing testDone');
  }
  return TestRunEvidence(
    success: success,
    tests: [
      for (final test in tests.values)
        if (test['hidden'] != true)
          CoverageTest(
            name: test['name']! as String,
            file: suites[test['suiteID']],
            status: test['skipped'] == true
                ? 'skipped'
                : test['result']! as String,
          ),
    ],
  );
}

CoverageSummary summarize(CoverageRecord? record) {
  final lines = record?.lines ?? const <int, int>{};
  final branches = record?.branches ?? const <String, int>{};
  return CoverageSummary(
    measured: lines.isNotEmpty,
    linesHit: lines.values.where((hits) => hits > 0).length,
    linesFound: lines.length,
    branchesHit: branches.values.where((hits) => hits > 0).length,
    branchesFound: branches.length,
    uncoveredLines: [
      for (final MapEntry(key: line, value: hits) in lines.entries)
        if (hits == 0) line,
    ],
    uncoveredBranches: [
      for (final MapEntry(key: branch, value: hits) in branches.entries)
        if (hits == 0) branch,
    ],
  );
}

Future<List<String>> _dartSources(String directory) async {
  final files = <String>[];
  await for (final entry in Directory(directory).list(followLinks: false)) {
    if (entry is Directory) {
      files.addAll(await _dartSources(entry.path));
    } else if (entry is File && entry.path.endsWith('.dart')) {
      files.add(entry.path);
    }
  }
  return files..sort();
}

Future<Map<String, String>> _packagePaths(String root) async {
  final config = File(path.join(root, '.dart_tool', 'package_config.json'));
  final data = _object(
    jsonDecode(await config.readAsString()),
    'package config',
  );
  return {
    for (final entry in data['packages']! as List)
      (_object(entry, 'package')['name']! as String): path.normalize(
        config.uri
            .resolve(_object(entry, 'package')['rootUri']! as String)
            .toFilePath(),
      ),
  };
}

Map<String, String> _owned(String root, Map<String, String> packages) => {
  for (final MapEntry(key: name, value: directory) in packages.entries)
    if (path.equals(directory, root) ||
        path.isWithin(path.join(root, 'packages'), directory))
      name: directory,
};

Future<SourceSnapshot> sourceSnapshot(String root) async {
  root = path.normalize(path.absolute(root));
  final packages = _owned(root, await _packagePaths(root));
  final files = <String>{};
  for (final directory in packages.values) {
    files.addAll(await _dartSources(path.join(directory, 'lib')));
    final test = Directory(path.join(directory, 'test'));
    if (await test.exists()) files.addAll(await _dartSources(test.path));
    files.add(path.join(directory, 'pubspec.yaml'));
  }
  for (final name in ['integration_test', 'test_driver']) {
    final directory = Directory(path.join(root, name));
    if (await directory.exists()) {
      files.addAll(await _dartSources(directory.path));
    }
  }
  for (final name in ['pubspec.lock', '.fvmrc']) {
    final file = File(path.join(root, name));
    if (await file.exists()) files.add(file.path);
  }
  return SourceSnapshot(
    packages: packages.keys.toList()..sort(),
    files: {
      for (final file in files.toList()..sort())
        path.relative(file, from: root): sha256
            .convert(await File(file).readAsBytes())
            .toString(),
    },
  );
}

Future<void> _verifySnapshot(String directory, SourceSnapshot current) async {
  final file = File(path.join(directory, 'sources.json'));
  final previous = SourceSnapshot.fromJson(
    _object(jsonDecode(await file.readAsString()), 'source snapshot'),
  );
  final packagesMatch =
      previous.packages.length == current.packages.length &&
      previous.packages.indexed.every(
        (entry) => entry.$2 == current.packages[entry.$1],
      );
  final filesMatch =
      previous.files.length == current.files.length &&
      previous.files.entries.every(
        (entry) => current.files[entry.key] == entry.value,
      );
  if (!packagesMatch || !filesMatch) {
    throw StateError(
      'Sources changed since $directory; rerun tests before merging coverage',
    );
  }
}

Future<CoverageReport> buildReport(
  String root,
  String output, [
  List<String> nativeDirectories = const [],
]) async {
  root = path.normalize(path.absolute(root));
  final packages = await _packagePaths(root);
  final ownedPackages = _owned(root, packages);
  final snapshot = await sourceSnapshot(root);
  await _verifySnapshot(output, snapshot);
  final manifest = (await File(
    path.join(output, 'suites.tsv'),
  ).readAsString()).trim();
  if (manifest.isEmpty) throw const FormatException('Empty coverage run');
  final completed = File(path.join(output, 'completed'));
  final complete =
      await completed.exists() &&
      (await completed.readAsString()).trim() == 'complete';
  final records = <String, CoverageRecord>{};
  final suites = <SuiteCoverage>[];
  for (final row in const LineSplitter().convert(manifest)) {
    final fields = row.split('\t');
    if (fields.length != 4 || int.tryParse(fields[2]) == null) {
      throw FormatException('Malformed coverage suite: $row');
    }
    final [name, directory, status, measured] = fields;
    TestRunEvidence? evidence;
    if (measured == 'true') {
      mergeLcov(
        await File(path.join(output, name, 'lcov.info')).readAsString(),
        directory: directory,
        packages: packages,
        records: records,
      );
      evidence = parseTestEvents(
        await File(path.join(output, name, 'tests.jsonl')).readAsString(),
      );
    }
    suites.add(
      SuiteCoverage(
        name: name,
        exitCode: int.parse(status),
        dartCoverage: measured == 'true',
        success: evidence?.success,
        tests: evidence?.tests,
      ),
    );
  }
  for (final directory in nativeDirectories.toSet()) {
    await _verifySnapshot(directory, snapshot);
    final data = _object(
      jsonDecode(
        await File(path.join(directory, 'results.json')).readAsString(),
      ),
      'native test evidence',
    );
    final tests = _object(data['tests'] ?? <String, Object?>{}, 'native tests');
    final platform = data['platform'];
    final completedAt = data['completedAt'];
    if (tests.isEmpty ||
        !const ['android', 'ios'].contains(platform) ||
        completedAt is! String ||
        DateTime.tryParse(completedAt) == null) {
      throw FormatException('Incomplete native test evidence: $directory');
    }
    final success = tests.values.every((status) => status == 'success');
    mergeLcov(
      await File(path.join(directory, 'lcov.info')).readAsString(),
      directory: root,
      packages: packages,
      records: records,
    );
    suites.add(
      SuiteCoverage(
        name: 'native:${path.relative(directory, from: root)}',
        platform: platform! as String,
        exitCode: success ? 0 : 1,
        success: success,
        dartCoverage: true,
        tests: [
          for (final entry in tests.entries)
            CoverageTest(name: entry.key, status: entry.value! as String),
        ],
      ),
    );
  }
  final files = <SourceCoverage>[];
  final excludedFiles = <String>[];
  for (final MapEntry(key: name, value: directory) in ownedPackages.entries) {
    for (final file in await _dartSources(path.join(directory, 'lib'))) {
      final relative = path.relative(file, from: root);
      if (path.split(relative).contains('generated') ||
          RegExp(r'\.(g|freezed)\.dart$').hasMatch(file) ||
          RegExp(
            r'^// @generated by `flutter_rust_bridge`',
            multiLine: true,
          ).hasMatch(await File(file).readAsString())) {
        excludedFiles.add(relative);
      } else {
        files.add(
          SourceCoverage(
            package: name,
            file: relative,
            coverage: summarize(records[file]),
          ),
        );
      }
    }
  }
  final packageTotals = <PackageCoverage>[];
  for (final name in ownedPackages.keys) {
    final sources = files.where((file) => file.package == name).toList();
    packageTotals.add(
      PackageCoverage(
        name: name,
        files: sources.length,
        unmeasuredFiles: sources
            .where((file) => !file.coverage.measured)
            .length,
        linesHit: sources.fold(0, (sum, file) => sum + file.coverage.linesHit),
        linesFound: sources.fold(
          0,
          (sum, file) => sum + file.coverage.linesFound,
        ),
        branchesHit: sources.fold(
          0,
          (sum, file) => sum + file.coverage.branchesHit,
        ),
        branchesFound: sources.fold(
          0,
          (sum, file) => sum + file.coverage.branchesFound,
        ),
      ),
    );
  }
  packageTotals.sort((a, b) => a.name.compareTo(b.name));
  return CoverageReport(
    createdAt: DateTime.now().toUtc().toIso8601String(),
    complete: complete,
    successful:
        complete &&
        suites.every((suite) => suite.exitCode == 0 && suite.success != false),
    excludedFiles: excludedFiles,
    packages: packageTotals,
    files: files,
    suites: suites,
  );
}

String markdownReport(CoverageReport report) {
  final gaps =
      report.files.indexed
          .where((entry) => entry.$2.coverage.uncoveredLines.isNotEmpty)
          .toList()
        ..sort((a, b) {
          final count = b.$2.coverage.uncoveredLines.length.compareTo(
            a.$2.coverage.uncoveredLines.length,
          );
          return count == 0 ? a.$1.compareTo(b.$1) : count;
        });
  return [
    '# Coverage Run',
    '',
    CoverageReport.scope,
    '',
    CoverageReport.limitation,
    '',
    'Successful: ${report.successful}',
    '',
    '| Package | Lines | Branches | Unmeasured files |',
    '| --- | --- | --- | --- |',
    for (final package in report.packages)
      '| ${package.name} | ${_ratio(package.linesHit, package.linesFound)} | '
          '${_ratio(package.branchesHit, package.branchesFound)} | '
          '${package.unmeasuredFiles} |',
    '',
    '## Largest Measured Gaps',
    '',
    for (final (_, file) in gaps.take(40))
      '- ${file.file}: ${file.coverage.uncoveredLines.length} uncovered lines; '
          '${file.coverage.uncoveredBranches.length} uncovered branches.',
    '',
    '## Unmeasured Files',
    '',
    for (final file in report.files)
      if (!file.coverage.measured) '- ${file.file}',
    '',
    'Full per-line/per-branch gaps, exclusions and test names: report.json.',
    '',
  ].join('\n');
}

String coveragePackageFilter(SourceSnapshot snapshot) =>
    '^(${snapshot.packages.map(RegExp.escape).join('|')})\$';

String _ratio(int hit, int total) => total == 0
    ? 'unmeasured'
    : '$hit/$total (${(100 * hit / total).toStringAsFixed(1)}%)';

JsonMap _object(Object? value, String label) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('Expected $label to be a JSON object');
  }
  return value.cast<String, Object?>();
}

const _usage =
    'Usage: dart scripts/coverage_report.dart [--root <project>] '
    '[--snapshot] <run-directory> [native-run-directories...]';

Future<void> main(List<String> arguments) async {
  try {
    final args = [...arguments];
    var root = path.dirname(path.dirname(Platform.script.toFilePath()));
    final rootIndex = args.indexOf('--root');
    if (rootIndex >= 0) {
      if (rootIndex + 1 >= args.length) {
        stderr.writeln(_usage);
        exitCode = 64;
        return;
      }
      root = path.absolute(args[rootIndex + 1]);
      args.removeRange(rootIndex, rootIndex + 2);
    }
    final snapshotOnly = args.isNotEmpty && args.first == '--snapshot';
    if (snapshotOnly) args.removeAt(0);
    if (args.isEmpty || args.any((arg) => arg.startsWith('--'))) {
      stderr.writeln(_usage);
      exitCode = 64;
      return;
    }
    final output = path.absolute(args.first);
    if (snapshotOnly) {
      if (args.length != 1) {
        stderr.writeln(_usage);
        exitCode = 64;
        return;
      }
      final snapshot = await sourceSnapshot(root);
      await File(path.join(output, 'sources.json')).writeAsString(
        jsonEncode(snapshot.toJson()),
      );
      await File(path.join(output, 'packages.regex')).writeAsString(
        '${coveragePackageFilter(snapshot)}\n',
      );
      return;
    }
    final report = await buildReport(
      root,
      output,
      args.skip(1).map(path.absolute).toList(),
    );
    final markdown = markdownReport(report);
    await File(path.join(output, 'report.json')).writeAsString(
      const JsonEncoder.withIndent('  ').convert(report.toJson()),
    );
    await File(path.join(output, 'report.md')).writeAsString(markdown);
    stdout.writeln(markdown.split('## Largest').first);
    stdout.writeln('Report: ${path.join(output, 'report.md')}');
    if (!report.successful) exitCode = 1;
  } catch (error) {
    stderr.writeln('Coverage report failed: $error');
    exitCode = 1;
  }
}
