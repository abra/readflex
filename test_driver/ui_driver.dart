import 'dart:convert';
import 'dart:io';

import 'package:coverage/coverage.dart';
import 'package:integration_test/integration_test_driver_extended.dart';

import '../test/support/native_screenshots.dart';

Future<void> main() async {
  final root = Directory('.local/ui-device');
  await root.create(recursive: true);
  final directory = await root.createTemp('run-');
  stdout.writeln('Native UI artifacts: ${directory.path}');
  final measureCoverage =
      Platform.environment['READFLEX_NATIVE_COVERAGE'] == '1';
  if (measureCoverage) {
    final snapshot = await Process.run('node', [
      'scripts/coverage_report.mjs',
      '--snapshot',
      directory.path,
    ]);
    if (snapshot.exitCode != 0) throw StateError('${snapshot.stderr}');
  }
  final screenshots = <String>[];
  Future<bool> saveScreenshot(
    String name,
    List<int> bytes, [
    Map<String, Object?>? args,
  ]) async {
    if (!RegExp(r'^[a-z0-9_-]+$').hasMatch(name) || bytes.isEmpty) {
      return false;
    }
    await File('${directory.path}/$name.png').writeAsBytes(bytes);
    screenshots.add('$name.png');
    // These are inspection artifacts, not device-independent goldens.
    return true;
  }

  NativeScreenshotServer? nativeScreenshots;
  final device = Platform.environment['READFLEX_NATIVE_DEVICE'];
  if (device != null && device.isNotEmpty) {
    var isAndroid = false;
    try {
      final state = await Process.run('adb', ['-s', device, 'get-state']);
      isAndroid = state.exitCode == 0;
    } on ProcessException {
      // iOS-only hosts need no Android tooling.
    }
    if (isAndroid) {
      nativeScreenshots = await NativeScreenshotServer.start(
        capture: () => captureAdbScreenshot(device),
        save: saveScreenshot,
      );
      final reverse = await Process.run('adb', [
        '-s',
        device,
        'reverse',
        'tcp:$nativeScreenshotPort',
        'tcp:${nativeScreenshots.port}',
      ]);
      if (reverse.exitCode != 0) {
        await nativeScreenshots.close();
        throw StateError('Cannot connect Android screenshot transport');
      }
    }
  }
  Future<void> closeNativeScreenshots() async {
    final server = nativeScreenshots;
    nativeScreenshots = null;
    if (server == null) return;
    await server.close();
    await Process.run('adb', [
      '-s',
      device!,
      'reverse',
      '--remove',
      'tcp:$nativeScreenshotPort',
    ]);
  }

  try {
    await integrationDriver(
      onScreenshot: saveScreenshot,
      writeResponseOnFailure: true,
      responseDataCallback: (data) async {
        try {
          await File('${directory.path}/results.json').writeAsString(
            const JsonEncoder.withIndent('  ').convert({
              ...?data,
              'screenshots': screenshots,
            }),
          );
          if (measureCoverage) await collectNativeCoverage(directory);
        } finally {
          // integrationDriver calls exit(), which bypasses the outer finally.
          await closeNativeScreenshots();
        }
      },
    );
  } finally {
    await closeNativeScreenshots();
  }
}

Future<void> collectNativeCoverage(Directory directory) async {
  final serviceUrl = Platform.environment['VM_SERVICE_URL'];
  if (serviceUrl == null) {
    throw StateError('Native coverage needs VM_SERVICE_URL');
  }
  final snapshot =
      jsonDecode(await File('${directory.path}/sources.json').readAsString())
          as Map<String, dynamic>;
  final packages = (snapshot['packages'] as List).cast<String>();
  // Collect after the actions, not while measuring UI responsiveness. Device
  // runs provide line coverage; branch instrumentation stays in host tests.
  final raw = await collect(
    Uri.parse(serviceUrl),
    false,
    false,
    false,
    packages.toSet(),
    timeout: const Duration(seconds: 60),
  ).timeout(const Duration(seconds: 90));
  final root = Directory.current.path;
  final hits = await HitMap.parseJson(
    (raw['coverage'] as List).cast<Map<String, dynamic>>(),
    packagePath: root,
  );
  final resolver = await Resolver.create(packagePath: root);
  final lcov = hits.formatLcov(
    resolver,
    basePath: root,
    reportOn: ['$root/lib', '$root/packages'],
  );
  if (lcov.isEmpty) {
    throw StateError('Native coverage returned no owned sources');
  }
  await File('${directory.path}/lcov.info').writeAsString(lcov);
  stdout.writeln('Native line coverage: ${directory.path}/lcov.info');
}
