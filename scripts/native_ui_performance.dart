import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'src/tool_support.dart';

const _usage =
    '''Usage: dart scripts/native_ui_performance.dart --device <id> [options]

  --device <id>       Exact ID from the pinned Flutter SDK's devices command.
  --allow-emulator    Allow diagnostic emulator runs; never attest them as physical.
  --help              Show this help.

Requires the pinned SDK in .fvm/flutter_sdk; run fvm use first.
Runs integration_test/native_ui_performance_test.dart in profile mode.
Device attestations are saved under .local/performance/native-ui/.
Physical devices must have no existing Readflex installation or retained
Android package record; an unknown installation state blocks the build.
''';

const _applicationId = 'io.github.abra.readflex';
const _installationGuidance =
    'No profile build was started. Use a dedicated test device/installation '
    'or the preserve-existing-app workflow in test/ui/README.md.';

typedef NativeUiCommandRunner = Future<ProcessResult> Function(
  List<String> command, {
  String? workingDirectory,
  Map<String, String>? environment,
  Duration? timeout,
  int? maxOutputBytes,
  bool inheritStdio,
});

class _Options {
  const _Options({required this.device, required this.allowEmulator});

  factory _Options.parse(List<String> arguments) {
    String? device;
    var allowEmulator = false;
    for (var index = 0; index < arguments.length; index++) {
      switch (arguments[index]) {
        case '--device':
          if (device != null) {
            throw const FormatException('Repeated option: --device');
          }
          if (++index == arguments.length ||
              arguments[index].startsWith('-') ||
              arguments[index].trim().isEmpty) {
            throw const FormatException('Missing value for --device');
          }
          device = arguments[index];
        case '--allow-emulator' when !allowEmulator:
          allowEmulator = true;
        default:
          throw FormatException('Unexpected argument: ${arguments[index]}');
      }
    }
    if (device == null) throw const FormatException('Missing --device');
    return _Options(device: device, allowEmulator: allowEmulator);
  }

  final String device;
  final bool allowEmulator;
}

class _Device {
  const _Device({
    required this.id,
    required this.name,
    required this.targetPlatform,
    required this.emulator,
  });

  factory _Device.select(String source, _Options options) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const FormatException('Flutter returned invalid device JSON');
    }
    if (decoded is! List) {
      throw const FormatException('Flutter device JSON must be a list');
    }
    final matches = decoded.whereType<Map>().where(
      (device) => device['id'] == options.device,
    );
    if (matches.length != 1) {
      throw const FormatException(
        'The requested device must match exactly one connected Flutter device',
      );
    }
    final device = matches.single;
    final platform = device['targetPlatform'];
    if (platform is! String ||
        (platform != 'ios' && !platform.startsWith('android-'))) {
      throw const FormatException('A mobile Android or iOS device is required');
    }
    if (device['isSupported'] != true) {
      throw const FormatException(
        'Flutter does not support the requested device',
      );
    }
    final emulator = device['emulator'];
    if (emulator is! bool) {
      throw const FormatException(
        'Flutter did not identify the emulator status',
      );
    }
    if (emulator && !options.allowEmulator) {
      throw const FormatException(
        'Physical hardware is required; use --allow-emulator for diagnostics',
      );
    }
    final name = device['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('Flutter did not identify the device model');
    }
    return _Device(
      id: options.device,
      name: name,
      targetPlatform: platform,
      emulator: emulator,
    );
  }

  final String id;
  final String name;
  final String targetPlatform;
  final bool emulator;
}

Future<String> _androidAdb(String root, Map<String, String> environment) async {
  final sdkDirectories = <String>[
    if (environment['ANDROID_HOME'] case final String path) path,
    if (environment['ANDROID_SDK_ROOT'] case final String path) path,
  ];
  final properties = File(p.join(root, 'android', 'local.properties'));
  if (await properties.exists()) {
    for (final line in await properties.readAsLines()) {
      final match = RegExp(r'^\s*sdk\.dir\s*=(.*)$').firstMatch(line);
      if (match != null) {
        sdkDirectories.add(
          match
              .group(1)!
              .trim()
              .replaceAll(r'\\', r'\')
              .replaceAll(r'\:', ':')
              .replaceAll(r'\ ', ' '),
        );
      }
    }
  }
  for (final sdk in sdkDirectories.where((path) => path.isNotEmpty)) {
    final adb = File(
      p.join(sdk, 'platform-tools', Platform.isWindows ? 'adb.exe' : 'adb'),
    );
    if (await adb.exists()) return adb.resolveSymbolicLinks();
  }
  return 'adb';
}

Future<bool> _hasAndroidInstallation(
  _Device device, {
  required String root,
  required Map<String, String> environment,
  required NativeUiCommandRunner commandRunner,
}) async {
  final adb = await _androidAdb(root, environment);
  final result = await commandRunner(
    [
      adb,
      '-s',
      device.id,
      'shell',
      'pm',
      'list',
      'packages',
      '-u',
      '--user',
      'all',
      _applicationId,
    ],
    workingDirectory: root,
    environment: environment,
    timeout: const Duration(seconds: 30),
    maxOutputBytes: 1024 * 1024,
  );
  if (result.exitCode != 0 || (result.stderr as String).trim().isNotEmpty) {
    throw const FormatException('Android package discovery failed');
  }
  final lines = (result.stdout as String)
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty);
  if (lines.any(
    (line) => !RegExp(r'^package:[A-Za-z0-9_.]+$').hasMatch(line),
  )) {
    throw const FormatException(
      'Android package discovery returned unknown output',
    );
  }
  // Include every user and retained records, rather than only user 0's APK path.
  return lines.contains('package:$_applicationId');
}

Future<bool> _hasIosInstallation(
  _Device device, {
  required String root,
  required Map<String, String> environment,
  required NativeUiCommandRunner commandRunner,
}) async {
  final temporary = await Directory.systemTemp.createTemp(
    'readflex-app-probe-',
  );
  try {
    final jsonFile = File(p.join(temporary.path, 'app.json'));
    final result = await commandRunner(
      [
        'xcrun',
        'devicectl',
        'device',
        'info',
        'apps',
        '--device',
        device.id,
        '--include-all-apps',
        '--bundle-id',
        _applicationId,
        '--timeout',
        '30',
        '--json-output',
        jsonFile.path,
      ],
      workingDirectory: root,
      environment: environment,
      timeout: const Duration(seconds: 35),
      maxOutputBytes: 1024 * 1024,
    );
    if (result.exitCode != 0) {
      throw const FormatException('iOS application discovery failed');
    }
    final decoded = jsonDecode(await jsonFile.readAsString());
    if (decoded is! Map ||
        decoded['info'] is! Map ||
        decoded['result'] is! Map) {
      throw const FormatException(
        'iOS application discovery returned unknown JSON',
      );
    }
    final info = decoded['info'] as Map;
    final appsResult = decoded['result'] as Map;
    final apps = appsResult['apps'];
    if (info['outcome'] != 'success' ||
        apps is! List ||
        appsResult['matchingBundleIdentifier'] != _applicationId) {
      throw const FormatException('iOS application discovery was incomplete');
    }
    if (apps.any(
      (app) => app is! Map || app['bundleIdentifier'] != _applicationId,
    )) {
      throw const FormatException(
        'iOS application discovery did not honor the bundle filter',
      );
    }
    if (apps.isNotEmpty) return true;
    if (appsResult['defaultAppsIncluded'] != true ||
        appsResult['removableAppsIncluded'] != true ||
        appsResult['hiddenAppsIncluded'] != true) {
      throw const FormatException(
        'iOS tooling did not confirm discovery of all default, removable and hidden apps',
      );
    }
    return false;
  } finally {
    await temporary.delete(recursive: true);
  }
}

Future<void> _requireDisposableInstallation(
  _Device device, {
  required String root,
  required Map<String, String> environment,
  required NativeUiCommandRunner commandRunner,
}) async {
  if (device.emulator) return;
  final bool installed;
  try {
    installed = await (device.targetPlatform == 'ios'
        ? _hasIosInstallation(
            device,
            root: root,
            environment: environment,
            commandRunner: commandRunner,
          )
        : _hasAndroidInstallation(
            device,
            root: root,
            environment: environment,
            commandRunner: commandRunner,
          ));
  } on Exception catch (error) {
    final reason = error is FormatException
        ? error.message
        : 'the read-only installation probe failed';
    throw StateError(
      'Cannot verify that Readflex is absent: $reason. $_installationGuidance',
    );
  }
  if (installed) {
    throw StateError(
      'Readflex is already present on this physical device; Flutter drive '
      'can replace and uninstall that app. $_installationGuidance',
    );
  }
}

/// Validates Flutter's device identity before starting a profile build.
///
/// The identity comes from host-side discovery, never a caller-supplied physical
/// flag. FrameTiming results still exclude native compositor and input latency.
Future<int> runNativeUiPerformance(
  List<String> arguments, {
  String? root,
  NativeUiCommandRunner commandRunner = runCommand,
  Map<String, String>? environment,
  StringSink? output,
  StringSink? errorOutput,
}) async {
  final out = output ?? stdout;
  final err = errorOutput ?? stderr;
  if (arguments.length == 1 && arguments.single == '--help') {
    out.write(_usage);
    return 0;
  }
  late _Options options;
  try {
    options = _Options.parse(arguments);
  } on FormatException catch (error) {
    err.writeln(error.message);
    err.write(_usage);
    return 64;
  }

  try {
    final project = p.normalize(p.absolute(root ?? repositoryRootFromScript()));
    final pinned = File(
      p.join(
        project,
        '.fvm',
        'flutter_sdk',
        'bin',
        Platform.isWindows ? 'flutter.bat' : 'flutter',
      ),
    );
    if (!await pinned.exists()) {
      throw StateError('Pinned Flutter SDK missing; run fvm use in $project');
    }
    final flutter = await pinned.resolveSymbolicLinks();
    final childEnvironment = {
      ...environment ?? Platform.environment,
      // Override inherited values: this run must not start screenshot transport
      // or coverage instrumentation while collecting frame timings.
      'READFLEX_NATIVE_DEVICE': '',
      'READFLEX_NATIVE_COVERAGE': '',
    };
    final discovery = await commandRunner(
      [flutter, 'devices', '--machine'],
      workingDirectory: project,
      environment: childEnvironment,
      timeout: const Duration(seconds: 60),
      maxOutputBytes: 4 * 1024 * 1024,
    );
    if (discovery.exitCode != 0) {
      throw ProcessException(
        flutter,
        ['devices', '--machine'],
        '',
        discovery.exitCode,
      );
    }
    final device = _Device.select(discovery.stdout as String, options);
    await _requireDisposableInstallation(
      device,
      root: project,
      environment: childEnvironment,
      commandRunner: commandRunner,
    );
    final reports = Directory(
      p.join(project, '.local', 'performance', 'native-ui'),
    );
    await reports.create(recursive: true);
    final run = await reports.createTemp('run-');
    final attestation = File(p.join(run.path, 'device.json'));
    final identity = <String, Object?>{
      'source': 'flutter devices --machine',
      'observedAt': DateTime.now().toUtc().toIso8601String(),
      'deviceId': device.id,
      'deviceModel': device.name,
      'targetPlatform': device.targetPlatform,
      'physicalDevice': !device.emulator,
      'mode': 'profile',
    };
    Future<void> record(String status, {int? exitCode}) async {
      await attestation.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert({
          ...identity,
          'status': status,
          'driveExitCode': ?exitCode,
        })}\n',
      );
    }

    await record('running');
    out.writeln('Native UI device attestation: ${attestation.path}');
    if (device.emulator) {
      out.writeln(
        'Emulator diagnostics cannot establish physical-device performance.',
      );
    }
    var driveExitCode = 1;
    try {
      final drive = await commandRunner(
        [
          flutter,
          'drive',
          '--profile',
          '--driver=test_driver/ui_driver.dart',
          '--target=integration_test/native_ui_performance_test.dart',
          '--device-id',
          device.id,
          '--dart-define=READFLEX_PHYSICAL_DEVICE=${!device.emulator}',
          '--dart-define=READFLEX_DEVICE_MODEL=${device.name}',
        ],
        workingDirectory: project,
        environment: {
          ...childEnvironment,
          'READFLEX_PERF_ATTESTATION': attestation.path,
        },
        timeout: const Duration(minutes: 20),
        inheritStdio: true,
      );
      driveExitCode = drive.exitCode;
    } on ProcessException catch (error) {
      driveExitCode = error.errorCode > 0 ? error.errorCode : 1;
      err.writeln('Flutter profile run failed (exit $driveExitCode).');
    } finally {
      await record(
        driveExitCode == 0 ? 'completed' : 'failed',
        exitCode: driveExitCode,
      );
    }
    return driveExitCode;
  } on FormatException catch (error) {
    err.writeln(error.message);
  } on StateError catch (error) {
    err.writeln(error.message);
  } on FileSystemException catch (error) {
    err.writeln(error);
  } on ProcessException catch (error) {
    err.writeln('Flutter device discovery failed (exit ${error.errorCode}).');
  } on TimeoutException {
    err.writeln('Flutter command timed out.');
  }
  return 1;
}

Future<void> main(List<String> arguments) async {
  exitCode = await runNativeUiPerformance(arguments);
}
