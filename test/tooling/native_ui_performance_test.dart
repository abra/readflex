@Tags(['tooling'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../scripts/native_ui_performance.dart';

void main() {
  late Directory temporary;
  late File pinnedFlutter;
  late List<Map<String, Object?>> devices;
  late StringBuffer output;
  late StringBuffer errors;
  late List<_Command> commands;
  late Map<String, String> environment;
  late Map<String, Object?> iosDiscovery;
  late List<String> iosProbeDirectories;
  String? rawDiscovery;
  String? rawIosDiscovery;
  Object? probeError;
  Object? driveError;
  var androidProbeExitCode = 0;
  var androidProbeOutput = '';
  var androidProbeError = '';
  var iosProbeExitCode = 0;
  var iosWriteOutput = true;
  var discoveryExitCode = 0;
  var driveExitCode = 0;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp(
      'native UI runner with spaces-',
    );
    pinnedFlutter = File(
      p.join(
        temporary.path,
        '.fvm',
        'flutter_sdk',
        'bin',
        Platform.isWindows ? 'flutter.bat' : 'flutter',
      ),
    );
    await pinnedFlutter.parent.create(recursive: true);
    await pinnedFlutter.writeAsString('SDK placeholder; never executed');
    devices = [_device()];
    output = StringBuffer();
    errors = StringBuffer();
    commands = [];
    environment = {
      'READFLEX_NATIVE_DEVICE': 'inherited screenshot device',
      'READFLEX_NATIVE_COVERAGE': '1',
      'FLUTTER': 'untrusted alternative SDK',
      'PATH': 'inherited path with spaces',
    };
    iosDiscovery = _iosDiscovery();
    iosProbeDirectories = [];
    rawDiscovery = null;
    rawIosDiscovery = null;
    probeError = null;
    driveError = null;
    androidProbeExitCode = 0;
    androidProbeOutput = '';
    androidProbeError = '';
    iosProbeExitCode = 0;
    iosWriteOutput = true;
    discoveryExitCode = 0;
    driveExitCode = 0;
  });
  tearDown(() => temporary.delete(recursive: true));

  Future<ProcessResult> commandRunner(
    List<String> command, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
    int? maxOutputBytes,
    bool inheritStdio = false,
  }) async {
    commands.add(
      _Command(
        arguments: List.of(command),
        workingDirectory: workingDirectory,
        environment: Map.of(environment ?? {}),
        inheritStdio: inheritStdio,
      ),
    );
    if (command[1] == 'devices') {
      return ProcessResult(
        1,
        discoveryExitCode,
        rawDiscovery ?? jsonEncode(devices),
        '',
      );
    }
    if (command.contains('pm')) {
      if (probeError case final Object error) throw error;
      return ProcessResult(
        2,
        androidProbeExitCode,
        androidProbeOutput,
        androidProbeError,
      );
    }
    if (command.contains('devicectl')) {
      final outputFile = File(command[command.indexOf('--json-output') + 1]);
      iosProbeDirectories.add(outputFile.parent.path);
      if (probeError case final Object error) throw error;
      if (iosWriteOutput) {
        await outputFile.writeAsString(
          rawIosDiscovery ?? jsonEncode(iosDiscovery),
        );
      }
      return ProcessResult(2, iosProbeExitCode, '', '');
    }
    if (driveError case final Object error) throw error;
    return ProcessResult(2, driveExitCode, '', '');
  }

  Future<int> run([List<String> arguments = const ['--device', 'phone']]) =>
      runNativeUiPerformance(
        arguments,
        root: temporary.path,
        commandRunner: commandRunner,
        environment: environment,
        output: output,
        errorOutput: errors,
      );

  Future<Map<String, Object?>> readAttestation() async {
    final files = await Directory(
      p.join(temporary.path, '.local', 'performance', 'native-ui'),
    ).list(recursive: true).where((entity) => entity is File).toList();
    expect(files, hasLength(1));
    expect(p.basename(files.single.path), 'device.json');
    return jsonDecode(await File(files.single.path).readAsString())
        as Map<String, Object?>;
  }

  Future<void> expectNoBuildOrArtifacts() async {
    expect(
      commands.every((command) => !command.arguments.contains('drive')),
      isTrue,
    );
    expect(await Directory(p.join(temporary.path, '.local')).exists(), isFalse);
  }

  test('help and invalid arguments cannot discover or build devices', () async {
    expect(await run(['--help']), 0);
    expect(output.toString(), contains('--allow-emulator'));
    for (final arguments in [
      <String>[],
      ['--device'],
      ['--device', ''],
      ['--device', '--allow-emulator'],
      ['--device', 'phone', '--device', 'other'],
      ['--device', 'phone', '--allow-emulator', '--allow-emulator'],
      ['--device', 'phone', '--dart-define=READFLEX_PHYSICAL_DEVICE=true'],
      ['--device', 'phone', '--debug'],
    ]) {
      expect(await run(arguments), 64, reason: '$arguments');
    }
    expect(commands, isEmpty);
    await expectNoBuildOrArtifacts();
  });

  test('requires the pinned SDK even when FLUTTER points elsewhere', () async {
    await pinnedFlutter.delete();
    expect(await run(), 1);
    expect(errors.toString(), contains('run fvm use'));
    expect(commands, isEmpty);
    await expectNoBuildOrArtifacts();
  });

  test(
    'requires an exact unique device ID rather than a prefix or name',
    () async {
      for (final values in [
        <Map<String, Object?>>[],
        [_device(id: 'phone-extra')],
        [_device(id: 'different', name: 'phone')],
        [_device(), _device()],
      ]) {
        devices = values;
        expect(await run(), 1);
        await expectNoBuildOrArtifacts();
      }
    },
  );

  test('never labels desktop or browser results as mobile hardware', () async {
    for (final platform in [
      'darwin',
      'linux-x64',
      'windows-x64',
      'web-javascript',
    ]) {
      devices = [_device(platform: platform)];
      expect(await run(['--device', 'phone', '--allow-emulator']), 1);
      await expectNoBuildOrArtifacts();
    }
    expect(errors.toString(), contains('mobile Android or iOS'));
  });

  test('rejects unsupported and incomplete discovery evidence', () async {
    for (final values in [
      {..._device(), 'isSupported': false},
      {..._device()}..remove('isSupported'),
      {..._device(), 'isSupported': 'true'},
      {..._device()}..remove('emulator'),
      {..._device(), 'emulator': 'false'},
      {..._device()}..remove('targetPlatform'),
      {..._device()}..remove('name'),
      {..._device(), 'name': ''},
    ]) {
      devices = [values];
      expect(await run(['--device', 'phone', '--allow-emulator']), 1);
      await expectNoBuildOrArtifacts();
    }
  });

  test('malformed JSON and discovery failure never start a build', () async {
    for (final source in ['not JSON', '{}', 'null']) {
      rawDiscovery = source;
      expect(await run(), 1);
      await expectNoBuildOrArtifacts();
    }
    rawDiscovery = '[{"id":"unrequested private serial"}]';
    discoveryExitCode = 7;
    expect(await run(), 1);
    expect(errors.toString(), contains('discovery failed (exit 7)'));
    expect(errors.toString(), isNot(contains('unrequested private serial')));
    await expectNoBuildOrArtifacts();
  });

  test('emulator diagnostics require opt-in and remain nonphysical', () async {
    devices = [_device(emulator: true)];
    expect(await run(), 1);
    await expectNoBuildOrArtifacts();

    expect(await run(['--device', 'phone', '--allow-emulator']), 0);
    final drive = commands.last;
    expect(
      drive.arguments,
      contains('--dart-define=READFLEX_PHYSICAL_DEVICE=false'),
    );
    expect((await readAttestation())['physicalDevice'], isFalse);
    expect(
      output.toString(),
      contains('cannot establish physical-device performance'),
    );
  });

  test(
    'attests only the selected hardware and passes literal argv safely',
    () async {
      const id = r'phone with spaces $(touch unexpected)';
      const model = 'Android phone, "model" = العربية';
      devices = [
        _device(id: 'macos', platform: 'darwin'),
        _device(id: 'emulator-5554', emulator: true),
        {
          ..._device(id: id, name: model),
          'sdk': 'unneeded SDK metadata',
          'privateSerial': 'do not persist this field',
        },
      ];
      expect(await run(['--device', id]), 0);
      expect(commands, hasLength(3));
      final discovery = commands.first;
      final drive = commands.last;
      expect(discovery.arguments, [
        await pinnedFlutter.resolveSymbolicLinks(),
        'devices',
        '--machine',
      ]);
      expect(discovery.inheritStdio, isFalse);
      expect(drive.inheritStdio, isTrue);
      expect(drive.workingDirectory, temporary.path);
      expect(
        drive.arguments,
        containsAll([
          '--profile',
          '--driver=test_driver/ui_driver.dart',
          '--target=integration_test/native_ui_performance_test.dart',
          '--dart-define=READFLEX_PHYSICAL_DEVICE=true',
          '--dart-define=READFLEX_DEVICE_MODEL=$model',
        ]),
      );
      final selector = drive.arguments.indexOf('--device-id');
      expect(drive.arguments[selector + 1], id);
      expect(drive.environment['READFLEX_NATIVE_DEVICE'], isEmpty);
      expect(drive.environment['READFLEX_NATIVE_COVERAGE'], isEmpty);
      expect(drive.environment['PATH'], 'inherited path with spaces');
      final attestation = await readAttestation();
      expect(attestation['deviceId'], id);
      expect(attestation['deviceModel'], model);
      expect(attestation['physicalDevice'], isTrue);
      expect(attestation['mode'], 'profile');
      expect(attestation['source'], 'flutter devices --machine');
      expect(attestation['status'], 'completed');
      expect(attestation['driveExitCode'], 0);
      expect(
        DateTime.parse(attestation['observedAt']! as String).isUtc,
        isTrue,
      );
      final saved = jsonEncode(attestation);
      expect(saved, isNot(contains('privateSerial')));
      expect(saved, isNot(contains('unneeded SDK metadata')));
      expect(saved, isNot(contains('emulator-5554')));
      expect(saved, isNot(contains('macos')));
      expect(
        await File(drive.environment['READFLEX_PERF_ATTESTATION']!).exists(),
        isTrue,
      );
      expect(
        await File(p.join(temporary.path, 'unexpected')).exists(),
        isFalse,
      );
    },
  );

  test('supports a physical iPhone without changing its identity', () async {
    devices = [_device(platform: 'ios', name: 'iPhone')];
    expect(await run(), 0);
    final attestation = await readAttestation();
    expect(attestation['targetPlatform'], 'ios');
    expect(attestation['physicalDevice'], isTrue);
    final probe = commands.singleWhere(
      (command) => command.arguments.contains('devicectl'),
    );
    expect(
      probe.arguments,
      containsAll([
        '--include-all-apps',
        '--bundle-id',
        'io.github.abra.readflex',
      ]),
    );
    for (final path in iosProbeDirectories) {
      expect(await Directory(path).exists(), isFalse);
    }
  });

  test(
    'blocks installed or retained Android records across all users',
    () async {
      androidProbeOutput = 'package:io.github.abra.readflex\n';
      expect(await run(['--device', 'phone', '--allow-emulator']), 1);
      await expectNoBuildOrArtifacts();
      final probe = commands.last.arguments;
      expect(
        probe,
        containsAllInOrder([
          '-s',
          'phone',
          'shell',
          'pm',
          'list',
          'packages',
          '-u',
          '--user',
          'all',
          'io.github.abra.readflex',
        ]),
      );
      expect(errors.toString(), contains('already present'));
      expect(errors.toString(), contains('dedicated test device/installation'));
      expect(errors.toString(), contains('No profile build was started'));
    },
  );

  test('unknown Android package status cannot be treated as absence', () async {
    for (final response in [
      (1, '', ''),
      (0, '', 'Permission denied'),
      (0, 'Error: unsupported user all', ''),
    ]) {
      (androidProbeExitCode, androidProbeOutput, androidProbeError) = response;
      expect(await run(), 1);
      await expectNoBuildOrArtifacts();
    }
    expect(
      errors.toString(),
      contains('Cannot verify that Readflex is absent'),
    );
  });

  test('resolves Android platform tools from SDK configuration', () async {
    for (final source in ['ANDROID_HOME', 'ANDROID_SDK_ROOT', 'sdk.dir']) {
      commands.clear();
      final sdk = Directory(p.join(temporary.path, 'Android SDK $source'));
      final adb = File(
        p.join(
          sdk.path,
          'platform-tools',
          Platform.isWindows ? 'adb.exe' : 'adb',
        ),
      );
      await adb.parent.create(recursive: true);
      await adb.writeAsString('SDK placeholder; never executed');
      if (source == 'sdk.dir') {
        final properties = File(
          p.join(temporary.path, 'android', 'local.properties'),
        );
        await properties.parent.create(recursive: true);
        await properties.writeAsString(
          'sdk.dir=${sdk.path.replaceAll(r'\', r'\\')}\n',
        );
      } else {
        environment[source] = sdk.path;
      }
      androidProbeOutput = 'package:io.github.abra.readflex';
      expect(await run(), 1);
      expect(commands.last.arguments.first, await adb.resolveSymbolicLinks());
      await expectNoBuildOrArtifacts();
      environment.remove(source);
    }
  });

  test(
    'blocks an existing iOS app and deletes transient discovery output',
    () async {
      devices = [_device(platform: 'ios')];
      iosDiscovery = _iosDiscovery(
        apps: [
          {
            'bundleIdentifier': 'io.github.abra.readflex',
            'name': 'private application name',
          },
        ],
      );
      expect(await run(), 1);
      await expectNoBuildOrArtifacts();
      expect(errors.toString(), contains('already present'));
      expect(errors.toString(), isNot(contains('private application name')));
      for (final path in iosProbeDirectories) {
        expect(await Directory(path).exists(), isFalse);
      }
    },
  );

  test('incomplete iOS discovery never establishes safe absence', () async {
    devices = [_device(platform: 'ios')];
    for (final response in [
      {
        'info': {'outcome': 'failure'},
        'result': _iosDiscovery()['result'],
      },
      {
        'info': {'outcome': 'success'},
        'result': {},
      },
      _iosDiscovery(matchingBundle: 'another.bundle'),
      _iosDiscovery(defaultAppsIncluded: false),
      _iosDiscovery(removableAppsIncluded: false),
      _iosDiscovery(hiddenAppsIncluded: false),
      _iosDiscovery(apps: [{}]),
    ]) {
      iosDiscovery = response;
      expect(await run(), 1);
      await expectNoBuildOrArtifacts();
    }
    expect(
      errors.toString(),
      contains('Cannot verify that Readflex is absent'),
    );
    for (final path in iosProbeDirectories) {
      expect(await Directory(path).exists(), isFalse);
    }
  });

  test('failed or malformed iOS discovery cannot start a build', () async {
    devices = [_device(platform: 'ios')];
    rawIosDiscovery = 'not JSON';
    expect(await run(), 1);
    await expectNoBuildOrArtifacts();
    rawIosDiscovery = null;
    iosWriteOutput = false;
    expect(await run(), 1);
    await expectNoBuildOrArtifacts();
    iosWriteOutput = true;
    iosProbeExitCode = 7;
    expect(await run(), 1);
    await expectNoBuildOrArtifacts();
    for (final path in iosProbeDirectories) {
      expect(await Directory(path).exists(), isFalse);
    }
  });

  test(
    'unavailable tools or a locked device fail closed on either platform',
    () async {
      for (final platform in ['android-arm64', 'ios']) {
        devices = [_device(platform: platform)];
        for (final error in [
          ProcessException('probe', [], 'Device locked or tool missing', 1),
          TimeoutException('Device did not respond'),
        ]) {
          probeError = error;
          expect(await run(), 1);
          await expectNoBuildOrArtifacts();
        }
      }
      for (final path in iosProbeDirectories) {
        expect(await Directory(path).exists(), isFalse);
      }
    },
  );

  test(
    'a failed profile subprocess leaves failed, never completed evidence',
    () async {
      driveError = ProcessException('flutter', ['drive'], 'profile failed', 17);
      expect(await run(), 17);
      final attestation = await readAttestation();
      expect(attestation['status'], 'failed');
      expect(attestation['driveExitCode'], 17);
      expect(errors.toString(), contains('profile run failed (exit 17)'));
    },
  );

  test('a returned failure exit code is preserved in the report', () async {
    driveExitCode = 9;
    expect(await run(), 9);
    final attestation = await readAttestation();
    expect(attestation['status'], 'failed');
    expect(attestation['driveExitCode'], 9);
  });

  test('a timed-out profile run remains failed', () async {
    driveError = TimeoutException('profile timed out');
    expect(await run(), 1);
    expect((await readAttestation())['status'], 'failed');
    expect(errors.toString(), contains('timed out'));
  });
}

Map<String, Object?> _device({
  String id = 'phone',
  String name = 'Android phone',
  String platform = 'android-arm64',
  bool emulator = false,
}) => {
  'id': id,
  'name': name,
  'targetPlatform': platform,
  'isSupported': true,
  'emulator': emulator,
};

Map<String, Object?> _iosDiscovery({
  List<Map<String, Object?>> apps = const [],
  String matchingBundle = 'io.github.abra.readflex',
  bool defaultAppsIncluded = true,
  bool removableAppsIncluded = true,
  bool hiddenAppsIncluded = true,
}) => {
  'info': {'outcome': 'success'},
  'result': {
    'apps': apps,
    'matchingBundleIdentifier': matchingBundle,
    'defaultAppsIncluded': defaultAppsIncluded,
    'removableAppsIncluded': removableAppsIncluded,
    'hiddenAppsIncluded': hiddenAppsIncluded,
  },
};

class _Command {
  const _Command({
    required this.arguments,
    required this.workingDirectory,
    required this.environment,
    required this.inheritStdio,
  });

  final List<String> arguments;
  final String? workingDirectory;
  final Map<String, String> environment;
  final bool inheritStdio;
}
