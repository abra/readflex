import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bounded_http/bounded_http.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:test/test.dart';

final _uri = Uri.parse('https://example.com/backend');

Future<http.Response> _post(
  http.Client client, {
  int limit = 4,
  Duration timeout = const Duration(seconds: 2),
  Future<void>? abortTrigger,
}) => postBoundedResponse(
  client: client,
  uri: _uri,
  headers: {'content-type': 'application/json'},
  body: '{}',
  maxResponseBytes: limit,
  timeout: timeout,
  abortTrigger: abortTrigger,
);

void main() {
  test(
    'accepts the exact byte limit and preserves response metadata',
    () async {
      final client = _Client((request) async {
        expect(request.method, 'POST');
        expect(utf8.decode(await request.finalize().toBytes()), '{}');
        return http.StreamedResponse(
          Stream.value(utf8.encode('test')),
          201,
          headers: {'content-type': 'text/plain'},
          reasonPhrase: 'Created',
          request: request,
        );
      });
      final response = await _post(client);
      expect(response.body, 'test');
      expect(response.statusCode, 201);
      expect(response.reasonPhrase, 'Created');
      expect(response.headers['content-type'], 'text/plain');
      expect(response.request!.url, _uri);
      expect(client.closed, isFalse);
    },
  );

  for (final status in [200, 503]) {
    for (final declared in [null, 1]) {
      test(
        'caps actual bytes for status $status / declared $declared',
        () async {
          var cancelled = false;
          var aborted = false;
          var yielded = 0;
          Stream<List<int>> body() async* {
            try {
              for (var i = 0; i < 4; i++) {
                yielded++;
                yield [65, 66, 67];
              }
            } finally {
              cancelled = true;
            }
          }

          final client = _Client((request) async {
            (request as http.AbortableRequest).abortTrigger!.then(
              (_) => aborted = true,
            );
            return http.StreamedResponse(
              body(),
              status,
              contentLength: declared,
            );
          });
          await expectLater(
            _post(client),
            throwsA(isA<HttpResponseTooLargeException>()),
          );
          await pumpEventQueue();
          expect(cancelled, isTrue);
          expect(aborted, isTrue);
          expect(
            yielded,
            2,
            reason: 'the rest of an oversized body is not drained',
          );
          expect(client.closed, isFalse);
        },
      );
    }
  }

  for (final external in [false, true]) {
    test(
      '${external ? 'external abort' : 'deadline'} cancels a stalled body',
      () async {
        var cancelled = false;
        var aborted = false;
        final started = Completer<void>();
        final body = StreamController<List<int>>(
          onCancel: () => cancelled = true,
        );
        final client = _Client((request) async {
          (request as http.AbortableRequest).abortTrigger!.then(
            (_) => aborted = true,
          );
          started.complete();
          return http.StreamedResponse(body.stream, 200);
        });
        final abort = Completer<void>();
        final operation = _post(
          client,
          timeout: const Duration(milliseconds: 30),
          abortTrigger: abort.future,
        );
        final assertion = expectLater(
          operation,
          throwsA(
            external
                ? isA<http.RequestAbortedException>()
                : isA<TimeoutException>(),
          ),
        );
        await started.future;
        if (external) abort.complete();
        await assertion;
        await pumpEventQueue();
        expect(cancelled, isTrue);
        expect(aborted, isTrue);
        expect(client.closed, isFalse);
        await body.close();
      },
    );
  }

  test('discards a late response even when the client ignores abort', () async {
    final pending = Completer<http.StreamedResponse>();
    final client = _Client((_) => pending.future);
    await expectLater(
      _post(client, timeout: const Duration(milliseconds: 20)),
      throwsA(isA<TimeoutException>()),
    );
    var cancelled = false;
    final body = StreamController<List<int>>(onCancel: () => cancelled = true);
    pending.complete(http.StreamedResponse(body.stream, 200));
    await pumpEventQueue();
    expect(cancelled, isTrue);
    expect(client.closed, isFalse);
    await body.close();
  });

  test('an already completed abort does not send a request', () async {
    var sent = false;
    final client = _Client((_) async {
      sent = true;
      return http.StreamedResponse(const Stream.empty(), 200);
    });
    await expectLater(
      _post(client, abortTrigger: Future.value()),
      throwsA(isA<http.RequestAbortedException>()),
    );
    expect(sent, isFalse);
  });

  test('stream errors abort the request without closing the client', () async {
    var aborted = false;
    final client = _Client((request) async {
      (request as http.AbortableRequest).abortTrigger!.then(
        (_) => aborted = true,
      );
      return http.StreamedResponse(
        Stream.error(StateError('broken body')),
        200,
      );
    });
    await expectLater(_post(client), throwsStateError);
    await pumpEventQueue();
    expect(aborted, isTrue);
    expect(client.closed, isFalse);
  });

  test(
    'counts decompressed IOClient bytes rather than compressed length',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) {
        final compressed = gzip.encode(List.filled(4096, 65));
        request.response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
        request.response.contentLength = compressed.length;
        request.response.add(compressed);
        unawaited(request.response.close());
      });
      final client = IOClient();
      addTearDown(client.close);
      await expectLater(
        postBoundedResponse(
          client: client,
          uri: Uri.parse('http://127.0.0.1:${server.port}/'),
          headers: const {},
          body: '{}',
          maxResponseBytes: 1024,
          timeout: const Duration(seconds: 2),
        ),
        throwsA(isA<HttpResponseTooLargeException>()),
      );
    },
  );

  test('rejects invalid budgets before sending', () async {
    final client = _Client((_) => throw StateError('must not send'));
    await expectLater(_post(client, limit: 0), throwsArgumentError);
    await expectLater(
      _post(client, timeout: Duration.zero),
      throwsArgumentError,
    );
  });
}

class _Client extends http.BaseClient {
  _Client(this.onSend);
  final Future<http.StreamedResponse> Function(http.BaseRequest) onSend;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      onSend(request);

  @override
  void close() => closed = true;
}
