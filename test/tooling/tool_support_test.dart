@Tags(['tooling'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../scripts/src/tool_support.dart';

void main() {
  final root = Directory.current.absolute.path;
  final dart = dartCommand(root: root);
  late Directory temporary;
  late String child;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp(
      'tool support with spaces-',
    );
    child = p.join(temporary.path, 'child.dart');
    await File(child).writeAsString(_childSource);
  });
  tearDown(() => temporary.delete(recursive: true));

  List<String> command(String mode, [List<String> args = const []]) => [
    ...dart,
    child,
    mode,
    ...args,
  ];

  test('splits POSIX commands without expanding shell syntax', () {
    expect(
      splitCommand(
        r'''"/SDK with spaces/dart" --flag 'literal $HOME' escaped\ value "a\"b" ""''',
        windows: false,
      ),
      [
        '/SDK with spaces/dart',
        '--flag',
        r'literal $HOME',
        'escaped value',
        'a"b',
        '',
      ],
    );
    expect(splitCommand('fvm dart', windows: false), ['fvm', 'dart']);
    for (final invalid in ['', ' ', '"unterminated', 'dart \\']) {
      expect(
        () => splitCommand(invalid, windows: false),
        throwsFormatException,
      );
    }
  });

  test('preserves Windows paths and quoted command arguments', () {
    expect(
      splitCommand(
        r'"C:\Program Files\Dart\bin\dart.exe" --flag C:\books\book.epub "two words"',
        windows: true,
      ),
      [
        r'C:\Program Files\Dart\bin\dart.exe',
        '--flag',
        r'C:\books\book.epub',
        'two words',
      ],
    );
    expect(
      splitCommand(r'dart "a\"b"', windows: true),
      ['dart', 'a"b'],
    );
  });

  test(
    'resolves pinned FVM Dart from an isolated project',
    () async {
      final project = Directory(p.join(temporary.path, 'FVM project'));
      final sdk = File(
        p.join(
          project.path,
          '.fvm',
          'flutter_sdk',
          'bin',
          'cache',
          'dart-sdk',
          'bin',
          Platform.isWindows ? 'dart.exe' : 'dart',
        ),
      );
      await sdk.parent.create(recursive: true);
      await sdk.writeAsString('SDK path fixture; never executed');
      final pinned = dartCommand(
        environment: {'DART': 'fvm dart --enable-asserts'},
        root: project.path,
      );
      expect(pinned, [await sdk.resolveSymbolicLinks(), '--enable-asserts']);
    },
  );

  test('explicit FVM requests require a configured project SDK', () {
    expect(
      () => dartCommand(
        environment: {'DART': 'fvm dart'},
        root: temporary.path,
      ),
      throwsStateError,
    );
  });

  test('preserves explicitly configured Dart commands and arguments', () {
    expect(
      dartCommand(
        environment: {'DART': 'dart --enable-asserts'},
        root: temporary.path,
      ),
      ['dart', '--enable-asserts'],
    );
  });

  test(
    'configured Dart runs outside a project without FVM',
    () async {
      final sdk = dartCommand(environment: const {}, root: root).first;
      final configured = dartCommand(
        environment: {'DART': '"$sdk" --enable-asserts'},
        root: temporary.path,
      );
      expect(configured, [sdk, '--enable-asserts']);
      final result = await runCommand(
        [...configured, child, 'echo'],
        workingDirectory: temporary.path,
      );
      final output =
          jsonDecode(result.stdout as String) as Map<String, Object?>;
      expect(
        await Directory(output['cwd'] as String).resolveSymbolicLinks(),
        await temporary.resolveSymbolicLinks(),
      );
    },
  );

  test(
    'passes argv and environment literally and captures both output streams',
    () async {
      final arguments = [
        'two words',
        r'$(touch unexpected)',
        'quote"value',
        'العربية',
      ];
      final result = await runCommand(
        command('echo', arguments),
        workingDirectory: temporary.path,
        environment: {'TOOL_TEST_VALUE': 'literal value'},
      );
      final output =
          jsonDecode(result.stdout as String) as Map<String, Object?>;
      expect(output['args'], arguments);
      expect(output['environment'], 'literal value');
      expect(result.stderr, 'diagnostic');
      expect(
        await File(p.join(temporary.path, 'unexpected')).exists(),
        isFalse,
      );
    },
  );

  test(
    'closes stdin and supports inherited stdio for quiet commands',
    () async {
      final closed = await runCommand(
        command('stdin'),
        workingDirectory: temporary.path,
      );
      expect(closed.stdout, 'closed');
      final inherited = await runCommand(command('quiet'), inheritStdio: true);
      expect(inherited.exitCode, 0);
      expect(inherited.stdout, '');
      expect(inherited.stderr, '');
    },
  );

  test('reports command exit status and stderr', () async {
    await expectLater(
      runCommand(command('fail')),
      throwsA(
        isA<ProcessException>()
            .having((error) => error.errorCode, 'exit status', 17)
            .having(
              (error) => error.message,
              'stderr',
              contains('worker failed'),
            ),
      ),
    );
  });

  test('rejects invalid commands and output limits', () async {
    await expectLater(runCommand([]), throwsArgumentError);
    await expectLater(
      runCommand(command('quiet'), maxOutputBytes: 0),
      throwsArgumentError,
    );
  });

  Future<void> checkCleanup(
    String mode, {
    Duration? timeout,
    int? limit,
  }) async {
    final marker = File(p.join(temporary.path, '$mode.pid'));
    addTearDown(() async {
      if (await marker.exists()) {
        Process.killPid(
          int.parse(await marker.readAsString()),
          ProcessSignal.sigkill,
        );
      }
    });
    final result = runCommand(
      command(mode, [marker.path]),
      workingDirectory: temporary.path,
      timeout: timeout,
      maxOutputBytes: limit,
    );
    await expectLater(
      result,
      throwsA(
        timeout != null
            ? isA<TimeoutException>()
            : isA<StateError>().having(
                (error) => error.message,
                'output limit',
                contains('exceeds'),
              ),
      ),
    ).timeout(const Duration(seconds: 10));
    expect(
      await marker.exists(),
      isTrue,
      reason: 'The child must reach its signal handler',
    );
    final id = int.parse(await marker.readAsString());
    final running = Platform.isWindows
        ? Process.killPid(id)
        : Process.killPid(id, ProcessSignal.sigcont);
    expect(running, isFalse, reason: 'runCommand must await child termination');
  }

  test('times out and reaps a child that ignores SIGTERM', () async {
    await checkCleanup('hang', timeout: const Duration(seconds: 3));
  });

  for (final stream in ['stdout', 'stderr']) {
    test(
      'output limit reaps stubborn $stream writer without a command timeout',
      () async {
        await checkCleanup('overflow-$stream', limit: 128);
      },
    );
  }

  test('hashes file contents with SHA-256', () async {
    final file = File(p.join(temporary.path, 'hash input'));
    await file.writeAsString('abc');
    expect(
      await hashFile(file.path),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });

  test('copies executable bytes and mode and rejects overwrites', () async {
    final source = File(p.join(temporary.path, 'original executable'));
    final target = p.join(temporary.path, 'frozen', 'executable');
    await source.writeAsBytes([0, 1, 127, 255]);
    if (!Platform.isWindows) await runCommand(['chmod', '751', source.path]);
    await copyFilePreservingMode(source.path, target);
    expect(await File(target).readAsBytes(), [0, 1, 127, 255]);
    if (!Platform.isWindows) {
      expect((await File(target).stat()).mode & 0x1ff, 0x1e9);
    }
    await source.writeAsString('changed source');
    await expectLater(
      copyFilePreservingMode(source.path, target),
      throwsA(isA<FileSystemException>()),
    );
    expect(await File(target).readAsBytes(), [0, 1, 127, 255]);
  });

  test(
    'copies bundle directories, preserves modes and requires a new target',
    () async {
      final source = Directory(p.join(temporary.path, 'bundle'));
      final nested = await Directory(
        p.join(source.path, 'lib'),
      ).create(recursive: true);
      await File(p.join(nested.path, 'asset')).writeAsString('bundle asset');
      if (!Platform.isWindows) await runCommand(['chmod', '750', nested.path]);
      final target = p.join(temporary.path, 'frozen bundle');
      await copyTree(source.path, target);
      expect(
        await File(p.join(target, 'lib', 'asset')).readAsString(),
        'bundle asset',
      );
      if (!Platform.isWindows) {
        expect(
          (await Directory(p.join(target, 'lib')).stat()).mode & 0x1ff,
          0x1e8,
        );
      }
      await expectLater(
        copyTree(source.path, target),
        throwsA(isA<FileSystemException>()),
      );
      await expectLater(
        copyTree(source.path, p.join(source.path, 'inside')),
        throwsArgumentError,
      );
      expect(await Directory(p.join(source.path, 'inside')).exists(), isFalse);
    },
  );

  test(
    'rejects source links and links inside frozen bundles',
    () async {
      final source = File(p.join(temporary.path, 'source'));
      await source.writeAsString('source');
      final link = await Link(
        p.join(temporary.path, 'source link'),
      ).create(source.path);
      await expectLater(
        copyFilePreservingMode(link.path, p.join(temporary.path, 'copy')),
        throwsA(isA<FileSystemException>()),
      );
      final bundle = await Directory(p.join(temporary.path, 'bundle')).create();
      await Link(p.join(bundle.path, 'asset link')).create(source.path);
      await expectLater(
        copyTree(bundle.path, p.join(temporary.path, 'frozen')),
        throwsA(isA<FileSystemException>()),
      );
      final directoryLink = await Link(
        p.join(temporary.path, 'directory link'),
      ).create(bundle.path);
      await expectLater(
        copyTree(directoryLink.path, p.join(temporary.path, 'other frozen')),
        throwsA(isA<FileSystemException>()),
      );
    },
    skip: Platform.isWindows
        ? 'Creating Windows links requires additional privileges'
        : false,
  );

  test(
    'rejects a nested destination reached through a physical path alias',
    () async {
      final source = await Directory(p.join(temporary.path, 'bundle')).create();
      final alias = await Link(
        p.join(temporary.path, 'alias'),
      ).create(source.path);
      final target = p.join(alias.path, 'missing', 'output');
      await expectLater(copyTree(source.path, target), throwsArgumentError);
      expect(await source.list().toList(), isEmpty);
    },
    skip: Platform.isWindows
        ? 'Creating Windows links requires additional privileges'
        : false,
  );
}

const _childSource = r'''
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  switch (args.first) {
    case 'echo':
      stdout.write(jsonEncode({
        'args': args.skip(1).toList(),
        'cwd': Directory.current.path,
        'environment': Platform.environment['TOOL_TEST_VALUE'],
      }));
      stderr.write('diagnostic');
    case 'stdin':
      await stdin.drain<void>();
      stdout.write('closed');
    case 'quiet':
      return;
    case 'fail':
      stderr.write('worker failed');
      exitCode = 17;
    case 'hang':
    case 'overflow-stdout':
    case 'overflow-stderr':
      if (!Platform.isWindows) ProcessSignal.sigterm.watch().listen((_) {});
      File(args[1]).writeAsStringSync('$pid');
      if (args.first == 'overflow-stdout') {
        stdout.add(List.filled(4096, 120));
        await stdout.flush();
      } else if (args.first == 'overflow-stderr') {
        stderr.add(List.filled(4096, 120));
        await stderr.flush();
      }
      Timer.periodic(const Duration(seconds: 1), (_) {});
  }
}
''';
