import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'local launch script',
    () {
      late Directory project;
      late Directory outsideProject;
      late File defines;
      late File arguments;
      late File launchDirectory;

      setUp(() async {
        final temporary = await Directory.systemTemp.createTemp(
          'readflex-run-',
        );
        addTearDown(() => temporary.delete(recursive: true));
        project = await Directory(
          '${temporary.path}/project with spaces',
        ).create();
        outsideProject = await Directory('${temporary.path}/outside').create();
        await File('run.sh').copy('${project.path}/run.sh');
        await Directory('${project.path}/config').create();
        await File('config/run-defines.example.json').copy(
          '${project.path}/config/run-defines.example.json',
        );
        defines = File('${project.path}/.local/run-defines.json');
        arguments = File('${temporary.path}/arguments');
        launchDirectory = File('${temporary.path}/launch-directory');

        final bin = await Directory('${project.path}/bin').create();
        final launcher = await File('${bin.path}/fvm').writeAsString(r'''
#!/bin/sh
printf '%s\n' "$@" > "$TEST_ARGUMENTS_FILE"
pwd > "$TEST_DIRECTORY_FILE"
exit "${TEST_EXIT_CODE:-0}"
''');
        final result = await Process.run('chmod', ['+x', launcher.path]);
        expect(result.exitCode, 0);
      });

      Future<ProcessResult> launch({
        List<String> flags = const [],
        int exitCode = 0,
      }) => Process.run(
        '/bin/sh',
        ['${project.path}/run.sh', ...flags],
        workingDirectory: outsideProject.path,
        environment: {
          'PATH': '${project.path}/bin:${Platform.environment['PATH']}',
          'TEST_ARGUMENTS_FILE': arguments.path,
          'TEST_DIRECTORY_FILE': launchDirectory.path,
          'TEST_EXIT_CODE': '$exitCode',
        },
      );

      Future<void> configure() async {
        await defines.parent.create();
        await defines.writeAsString(
          jsonEncode({
            'ENVIRONMENT': 'DEV',
            'READFLEX_API_KEY': 'test-only-credential',
          }),
        );
      }

      test('creates a private template without starting Flutter', () async {
        final result = await launch();

        expect(result.exitCode, 2);
        expect(await arguments.exists(), isFalse);
        expect(
          jsonDecode(await defines.readAsString()),
          jsonDecode(
            await File('config/run-defines.example.json').readAsString(),
          ),
        );
        expect((await defines.stat()).mode & 0x1ff, 0x180); // 0600.
        expect(result.stdout, contains('READFLEX_API_KEY'));
      });

      test(
        'preserves secrets and forwards arguments from any directory',
        () async {
          await configure();
          final original = await defines.readAsString();

          final result = await launch(
            flags: [
              '--release',
              '-d',
              'iPhone 17 Pro Max',
              '--dart-define=TRACE=true',
            ],
          );

          expect(result.exitCode, 0, reason: '${result.stderr}');
          expect(await defines.readAsString(), original);
          expect(await arguments.readAsLines(), [
            'flutter',
            'run',
            '--dart-define-from-file=${defines.path}',
            '--release',
            '-d',
            'iPhone 17 Pro Max',
            '--dart-define=TRACE=true',
          ]);
          final actualDirectory = Directory(
            (await launchDirectory.readAsString()).trim(),
          );
          expect(
            await actualDirectory.resolveSymbolicLinks(),
            await project.resolveSymbolicLinks(),
          );
          expect(
            '${result.stdout}${result.stderr}',
            isNot(contains('credential')),
          );
          expect(await arguments.readAsString(), isNot(contains('credential')));
        },
      );

      test(
        'propagates Flutter failure without replacing configuration',
        () async {
          await configure();
          final original = await defines.readAsString();

          final result = await launch(exitCode: 42);

          expect(result.exitCode, 42);
          expect(await defines.readAsString(), original);
        },
      );
    },
    skip: Platform.isWindows ? 'The launcher is a POSIX shell script.' : false,
  );
}
