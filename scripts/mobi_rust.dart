import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'mobi_benchmark.dart' show runMobiBenchmark;
import 'src/tool_support.dart';

class MobiRustBuild {
  const MobiRustBuild({
    required this.worker,
    required this.bundle,
    required this.library,
    required this.manifest,
  });

  final String? worker;
  final String? bundle;
  final String library;
  final String manifest;

  Map<String, Object?> toJson() => {
    if (worker != null) 'worker': worker,
    if (bundle != null) 'bundle': bundle,
    'library': library,
    'manifest': manifest,
  };
}

Future<MobiRustBuild> buildMobiRust(
  String root, {
  bool compileWorker = true,
}) async {
  final libraryName = switch (Platform.operatingSystem) {
    'macos' => 'libpagecraft_mobi_benchmark.dylib',
    'linux' => 'libpagecraft_mobi_benchmark.so',
    'windows' => 'pagecraft_mobi_benchmark.dll',
    final other => throw UnsupportedError('Unsupported host: $other'),
  };
  final packageRoot = p.join(root, 'benchmarks', 'mobi_rust');
  final rustRoot = p.join(packageRoot, 'rust');
  // Keep the artifact location independent of shell target-dir overrides.
  await runCommand(
    ['cargo', 'build', '--locked', '--release', '--target-dir', 'target'],
    workingDirectory: rustRoot,
    inheritStdio: true,
  );
  final parent = Directory(p.join(root, '.local', 'performance', 'mobi-rust'));
  await parent.create(recursive: true);
  final directory = (await parent.createTemp('build-')).absolute.path;
  final library = p.join(directory, libraryName);
  final bundle = compileWorker ? p.join(directory, 'bundle') : null;
  final worker = bundle == null
      ? null
      : p.join(
          bundle,
          'bin',
          Platform.isWindows
              ? 'mobi_rust_benchmark.exe'
              : 'mobi_rust_benchmark',
        );
  if (compileWorker) {
    await runCommand(
      [
        ...dartCommand(root: root),
        'build',
        'cli',
        '--target',
        'bin/mobi_rust_benchmark.dart',
        '--output',
        directory,
      ],
      workingDirectory: packageRoot,
      inheritStdio: true,
    );
  }
  await copyFilePreservingMode(
    p.join(rustRoot, 'target', 'release', libraryName),
    library,
  );
  final sources = <String, String>{};
  for (final file in [
    'pubspec.lock',
    'flutter_rust_bridge.yaml',
    'rust/Cargo.toml',
    'rust/Cargo.lock',
    'rust/src/api.rs',
    'rust/src/decoder.rs',
    'rust/src/frb_generated.rs',
    'bin/mobi_rust_backend.dart',
    'bin/mobi_rust_benchmark.dart',
    '../mobi_decoder_benchmark.dart',
    '../mobi_huff_fixture.dart',
    '../../scripts/mobi_rust.dart',
    '../../scripts/mobi_benchmark.dart',
    '../../scripts/src/tool_support.dart',
  ]) {
    sources[file] = await hashFile(p.normalize(p.join(packageRoot, file)));
  }
  final compiler = await runCommand(
    ['rustc', '--version', '--verbose'],
    workingDirectory: rustRoot,
  );
  final manifest = p.join(directory, 'build.json');
  final output = await File(manifest).create(exclusive: true);
  await output.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert({
      'rustc': (compiler.stdout as String).trim(),
      'profile': 'release',
      'flutterRustBridge': '2.13.0',
      'bridgeConfiguration': await File(
        p.join(packageRoot, 'flutter_rust_bridge.yaml'),
      ).readAsString(),
      'sources': sources,
    })}\n',
  );
  return MobiRustBuild(
    worker: worker,
    bundle: bundle,
    library: library,
    manifest: manifest,
  );
}

Future<void> runMobiRust(List<String> arguments, {required String root}) async {
  final command = arguments.firstOrNull;
  final args = arguments.skip(1).toList();
  if (command == 'build' && args.isEmpty) {
    stdout.writeln(jsonEncode((await buildMobiRust(root)).toJson()));
  } else if (command == 'test' && args.isEmpty) {
    final packageRoot = p.join(root, 'benchmarks', 'mobi_rust');
    final rustRoot = p.join(packageRoot, 'rust');
    for (final args in [
      ['fmt', '--check'],
      ['clippy', '--locked', '--all-targets', '--', '-D', 'warnings'],
      ['test', '--locked'],
    ]) {
      await runCommand(
        ['cargo', ...args],
        workingDirectory: rustRoot,
        inheritStdio: true,
      );
    }
    final build = await buildMobiRust(root, compileWorker: false);
    final dart = dartCommand(root: root);
    await runCommand(
      [...dart, 'analyze', 'bin', 'test'],
      workingDirectory: packageRoot,
      inheritStdio: true,
    );
    await runCommand(
      [...dart, 'test', '--reporter', 'expanded'],
      workingDirectory: packageRoot,
      environment: {
        ...Platform.environment,
        'MOBI_RUST_LIBRARY': build.library,
      },
      inheritStdio: true,
    );
  } else if (command == 'benchmark' && args.contains('--dataset')) {
    final build = await buildMobiRust(root);
    await runMobiBenchmark([
      'run',
      '--label',
      'rust-frb',
      ...args,
      '--worker',
      build.worker!,
      '--bundle',
      build.bundle!,
      '--library',
      build.library,
      '--artifact',
      build.manifest,
    ], root: root);
  } else {
    throw const FormatException(
      'Use build, test, or benchmark --dataset <frozen-dataset.json> '
      '[runner options]',
    );
  }
}

Future<void> main(List<String> arguments) async {
  try {
    await runMobiRust(arguments, root: repositoryRootFromScript());
  } catch (error, stack) {
    stderr.writeln('$error\n$stack');
    exitCode = 1;
  }
}
