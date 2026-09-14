import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'support/native_screenshots.dart';

void main() {
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aTWkAAAAASUVORK5CYII=',
  );
  late NativeScreenshotServer server;
  late HttpClient client;
  late Future<List<int>> Function() capture;
  late bool accept;
  late Map<String, List<int>> saved;

  setUp(() async {
    client = HttpClient();
    saved = {};
    accept = true;
    capture = () async => png;
    server = await NativeScreenshotServer.start(
      capture: () => capture(),
      save: (name, bytes) async {
        if (accept) saved[name] = bytes;
        return accept;
      },
    );
  });
  tearDown(() async {
    client.close(force: true);
    await server.close();
  });

  Future<int> request(String path) async {
    final request = await client.getUrl(
      Uri.http('127.0.0.1:${server.port}', path),
    );
    final response = await request.close();
    await response.drain<void>();
    return response.statusCode;
  }

  test('captures the native PNG before acknowledging the screenshot', () async {
    expect(await request('/screenshot/book-selection'), HttpStatus.noContent);
    expect(saved['book-selection'], png);
  });

  test('rejects invalid names without accessing the device', () async {
    capture = () => throw StateError('Must not be called');
    for (final path in [
      '/screenshot/a.png',
      '/screenshot/a/b',
      '/other/book',
    ]) {
      expect(await request(path), HttpStatus.badRequest);
    }
    expect(saved, isEmpty);
  });

  test(
    'does not report broken captures or rejected artifacts as successful',
    () async {
      capture = () async => [1, 2, 3];
      expect(
        await request('/screenshot/broken'),
        HttpStatus.internalServerError,
      );
      capture = () => throw StateError('Device disconnected');
      expect(
        await request('/screenshot/disconnected'),
        HttpStatus.internalServerError,
      );
      capture = () async => png;
      accept = false;
      expect(
        await request('/screenshot/rejected'),
        HttpStatus.internalServerError,
      );
      expect(saved, isEmpty);
    },
  );

  test('serializes captures and can recover after a busy request', () async {
    final pending = Completer<List<int>>();
    final started = Completer<void>();
    capture = () {
      started.complete();
      return pending.future;
    };
    final first = request('/screenshot/first');
    await started.future;
    expect(await request('/screenshot/second'), HttpStatus.conflict);
    pending.complete(png);
    expect(await first, HttpStatus.noContent);
    capture = () async => png;
    expect(await request('/screenshot/second'), HttpStatus.noContent);
    expect(saved.keys, ['first', 'second']);
  });
}
