import 'dart:io';

// Device-side port is forwarded to an ephemeral host port by the test driver.
const nativeScreenshotPort = 34179;

Future<void> captureAndroidScreenshot(String name) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final request = await client.getUrl(
      Uri.http('127.0.0.1:$nativeScreenshotPort', '/screenshot/$name'),
    );
    final response = await request.close().timeout(const Duration(seconds: 20));
    await response.drain<void>();
    if (response.statusCode != HttpStatus.noContent) {
      throw StateError('Native screenshot failed: HTTP ${response.statusCode}');
    }
  } on SocketException {
    throw StateError(
      'Android screenshots require make test-device DEVICE=<id>',
    );
  } finally {
    client.close(force: true);
  }
}

/// Test-only screenshot transport. No Flutter surface conversion or app hooks.
final class NativeScreenshotServer {
  NativeScreenshotServer._(this._server);

  final HttpServer _server;
  int get port => _server.port;

  static Future<NativeScreenshotServer> start({
    required Future<List<int>> Function() capture,
    required Future<bool> Function(String, List<int>) save,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var busy = false;
    server.listen((request) async {
      final path = request.uri.pathSegments;
      if (request.method != 'GET' ||
          path.length != 2 ||
          path.first != 'screenshot' ||
          !RegExp(r'^[a-z0-9_-]+$').hasMatch(path.last)) {
        request.response.statusCode = HttpStatus.badRequest;
      } else if (busy) {
        request.response.statusCode = HttpStatus.conflict;
      } else {
        busy = true;
        try {
          final bytes = await capture().timeout(const Duration(seconds: 15));
          const signature = [137, 80, 78, 71, 13, 10, 26, 10];
          if (bytes.length <= signature.length ||
              !signature.indexed.every(
                (entry) => bytes[entry.$1] == entry.$2,
              ) ||
              !await save(path.last, bytes)) {
            throw StateError('Invalid or rejected screenshot');
          }
          request.response.statusCode = HttpStatus.noContent;
        } catch (_) {
          request.response.statusCode = HttpStatus.internalServerError;
        } finally {
          busy = false;
        }
      }
      await request.response.close();
    });
    return NativeScreenshotServer._(server);
  }

  Future<void> close() => _server.close(force: true);
}

Future<List<int>> captureAdbScreenshot(String device) async {
  final process = await Process.start('adb', [
    '-s',
    device,
    'exec-out',
    'screencap',
    '-p',
  ]);
  final bytes = process.stdout.fold<List<int>>(
    [],
    (data, chunk) => data..addAll(chunk),
  );
  final errors = process.stderr.drain<void>();
  try {
    final code = await process.exitCode.timeout(const Duration(seconds: 10));
    await errors;
    if (code != 0) throw StateError('ADB screenshot failed ($code)');
    return await bytes;
  } finally {
    process.kill();
  }
}
