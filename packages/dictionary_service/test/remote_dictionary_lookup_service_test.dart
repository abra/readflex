import 'dart:async';
import 'dart:convert';

import 'package:dictionary_service/dictionary_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _PendingClient extends http.BaseClient {
  _PendingClient({required this.sendHeaders});
  final bool sendHeaders;
  final started = Completer<void>();
  bool aborted = false;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    started.complete();
    if (request is http.AbortableRequest) {
      if (sendHeaders) {
        final body = StreamController<List<int>>();
        request.abortTrigger?.then((_) {
          aborted = true;
          body.addError(http.RequestAbortedException(request.url));
          unawaited(body.close());
        });
        return http.StreamedResponse(body.stream, 200);
      }
      await request.abortTrigger;
      aborted = true;
      throw http.RequestAbortedException(request.url);
    }
    return Completer<http.StreamedResponse>().future;
  }

  @override
  void close() => closed = true;
}

void main() {
  for (final (cancelExplicitly, sendHeaders) in [
    (true, false),
    (false, false),
    (true, true),
    (false, true),
  ]) {
    test(
      'aborts ${sendHeaders ? 'body' : 'connection'} on ${cancelExplicitly ? 'cancel' : 'timeout'}',
      () async {
        final client = _PendingClient(sendHeaders: sendHeaders);
        final service = RemoteDictionaryLookupService(
          baseUri: Uri.parse('https://api.readflex.app'),
          httpClient: client,
          timeout: const Duration(milliseconds: 50),
        );
        final abort = Completer<void>();
        final operation = service.lookup(
          DictionaryLookupRequest(term: 'power'),
          abortTrigger: abort.future,
        );
        final assertion = expectLater(
          operation,
          throwsA(
            isA<DictionaryLookupException>().having(
              (error) => error.reason,
              'reason',
              cancelExplicitly
                  ? DictionaryLookupFailureReason.cancelled
                  : DictionaryLookupFailureReason.network,
            ),
          ),
        );
        await client.started.future;
        if (cancelExplicitly) abort.complete();
        await assertion;
        await pumpEventQueue();
        expect(client.aborted, isTrue);
        service.dispose();
        expect(client.closed, isFalse);
      },
    );
  }

  test('posts lookup contract with API key and parses response', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'request_id': 'request-1',
          'status': 'not_found',
          'term': 'missing',
          'language': 'en',
          'entries': const [],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = RemoteDictionaryLookupService(
      baseUri: Uri.parse('https://api.readflex.app/base/'),
      apiKey: 'secret',
      httpClient: client,
    );

    final result = await service.lookup(
      DictionaryLookupRequest(
        requestId: 'request-1',
        term: 'missing',
        sourceLanguage: 'en',
        contextText: 'A [[missing]] term.',
      ),
    );

    expect(captured.method, 'POST');
    expect(
      captured.url,
      Uri.parse('https://api.readflex.app/v1/dictionary/lookup'),
    );
    expect(captured.headers['X-API-Key'], 'secret');
    expect(jsonDecode(captured.body), {
      'request_id': 'request-1',
      'term': 'missing',
      'source_language': 'en',
      'context_text': 'A [[missing]] term.',
    });
    expect(result.status, DictionaryLookupStatus.notFound);
    service.dispose();
  });

  test('maps non-success status to a typed HTTP failure', () async {
    final service = RemoteDictionaryLookupService(
      baseUri: Uri.parse('https://api.readflex.app'),
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({'detail': 'Missing or invalid X-API-Key'}),
          401,
        ),
      ),
    );

    expect(
      () => service.lookup(
        DictionaryLookupRequest(requestId: 'request-1', term: 'power'),
      ),
      throwsA(
        isA<DictionaryLookupException>()
            .having(
              (error) => error.reason,
              'reason',
              DictionaryLookupFailureReason.http,
            )
            .having((error) => error.statusCode, 'statusCode', 401)
            .having(
              (error) => error.message,
              'message',
              'Dictionary service authorization failed',
            ),
      ),
    );
  });

  test('rejects a response correlated to another request', () async {
    final service = RemoteDictionaryLookupService(
      baseUri: Uri.parse('https://api.readflex.app'),
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'request_id': 'another-request',
            'status': 'not_found',
            'term': 'power',
            'entries': const [],
          }),
          200,
        ),
      ),
    );

    expect(
      () => service.lookup(
        DictionaryLookupRequest(requestId: 'request-1', term: 'power'),
      ),
      throwsA(
        isA<DictionaryLookupException>().having(
          (error) => error.reason,
          'reason',
          DictionaryLookupFailureReason.invalidResponse,
        ),
      ),
    );
  });

  group('cache', () {
    test('answers a repeated question under the new request ID', () async {
      final backend = _EchoBackend();
      final service = backend.service();

      final first = await service.lookup(_request('first'));
      final second = await service.lookup(_request('second'));

      expect(backend.calls, 1);
      expect(first.requestId, 'first');
      expect(second.requestId, 'second');
      expect(second.entries, first.entries);
      expect(second.status, first.status);
      expect(second.term, first.term);
      expect(second.language, first.language);
    });

    test('asks again for another term, language or context', () async {
      final backend = _EchoBackend();
      final service = backend.service();

      await service.lookup(_request('1'));
      await service.lookup(_request('2', term: 'powers'));
      await service.lookup(_request('3', sourceLanguage: 'de'));
      await service.lookup(_request('4', contextText: 'Other [[power]].'));
      await service.lookup(_request('5'));

      expect(backend.calls, 4);
    });

    test('asks again once the cached answer expires', () async {
      var now = DateTime.utc(2026, 1, 1);
      final backend = _EchoBackend();
      final service = backend.service(
        cache: MemoryDictionaryLookupCache(clock: () => now),
      );

      await service.lookup(_request('first'));
      now = now.add(const Duration(minutes: 29));
      await service.lookup(_request('second'));
      expect(backend.calls, 1);

      now = now.add(const Duration(minutes: 1));
      final refreshed = await service.lookup(_request('third'));
      expect(backend.calls, 2);
      expect(refreshed.requestId, 'third');
    });

    test('caches not found and unsupported language answers', () async {
      for (final status in ['not_found', 'unsupported_language']) {
        final backend = _EchoBackend(status: status, entries: const []);
        final service = backend.service();

        await service.lookup(_request('first'));
        final second = await service.lookup(_request('second'));

        expect(backend.calls, 1, reason: status);
        expect(second.status.wireValue, status);
        expect(second.requestId, 'second');
      }
    });

    test('does not cache a found answer without entries', () async {
      final backend = _EchoBackend(entries: const []);
      final service = backend.service();

      await service.lookup(_request('first'));
      await service.lookup(_request('second'));

      expect(backend.calls, 2);
    });

    for (final (name, failure, reason) in <(String, _Failure, Object)>[
      ('an HTTP error', _Failure.http, DictionaryLookupFailureReason.http),
      (
        'a connection error',
        _Failure.connection,
        DictionaryLookupFailureReason.network,
      ),
      ('a timeout', _Failure.timeout, DictionaryLookupFailureReason.network),
      (
        'a malformed body',
        _Failure.malformed,
        DictionaryLookupFailureReason.invalidResponse,
      ),
      (
        'an answer to another request',
        _Failure.mismatched,
        DictionaryLookupFailureReason.invalidResponse,
      ),
      (
        'a cancellation',
        _Failure.cancelled,
        DictionaryLookupFailureReason.cancelled,
      ),
    ]) {
      test('does not cache $name', () async {
        final backend = _EchoBackend()..failures.add(failure);
        final service = backend.service(
          timeout: const Duration(milliseconds: 50),
        );
        final abort = Completer<void>();

        final failed = service.lookup(
          _request('first'),
          abortTrigger: abort.future,
        );
        if (failure == _Failure.cancelled) {
          await backend.started.future;
          abort.complete();
        }
        await expectLater(
          failed,
          throwsA(
            isA<DictionaryLookupException>().having(
              (error) => error.reason,
              'reason',
              reason,
            ),
          ),
        );

        final retried = await service.lookup(_request('second'));
        expect(backend.calls, 2);
        expect(retried.requestId, 'second');
        expect(retried.status, DictionaryLookupStatus.found);
      });
    }
  });
}

DictionaryLookupRequest _request(
  String requestId, {
  String term = 'power',
  String sourceLanguage = 'en',
  String contextText = 'The [[power]] bank.',
}) {
  return DictionaryLookupRequest(
    requestId: requestId,
    term: term,
    sourceLanguage: sourceLanguage,
    contextText: contextText,
  );
}

enum _Failure { http, connection, timeout, malformed, mismatched, cancelled }

/// Answers each lookup with its own request ID unless a failure is queued.
class _EchoBackend extends http.BaseClient {
  _EchoBackend({
    this.status = 'found',
    this.entries = const [
      {
        'lemma': 'power',
        'definitions': [
          {'text': 'The ability to act.'},
        ],
      },
    ],
  });

  final String status;
  final List<Map<String, Object?>> entries;
  final failures = <_Failure>[];
  final started = Completer<void>();
  var calls = 0;

  RemoteDictionaryLookupService service({
    DictionaryLookupCache? cache,
    Duration timeout = const Duration(seconds: 40),
  }) {
    return RemoteDictionaryLookupService(
      baseUri: Uri.parse('https://api.readflex.app'),
      httpClient: this,
      cache: cache,
      timeout: timeout,
    );
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls++;
    if (!started.isCompleted) started.complete();
    final body =
        jsonDecode(await request.finalize().bytesToString())
            as Map<String, Object?>;
    final failure = failures.isEmpty ? null : failures.removeAt(0);
    switch (failure) {
      case _Failure.http:
        return _response(request, 503, '{}');
      case _Failure.connection:
        throw http.ClientException('connection refused', request.url);
      case _Failure.timeout:
        return Completer<http.StreamedResponse>().future;
      case _Failure.cancelled:
        await (request as http.AbortableRequest).abortTrigger;
        throw http.RequestAbortedException(request.url);
      case _Failure.malformed:
        return _response(request, 200, '{"request_id":');
      case _Failure.mismatched:
      case null:
        return _response(
          request,
          200,
          jsonEncode({
            'request_id': failure == null ? body['request_id'] : 'other',
            'status': status,
            'term': body['term'],
            'language': 'en',
            'entries': entries,
          }),
        );
    }
  }
}

http.StreamedResponse _response(
  http.BaseRequest request,
  int statusCode,
  String body,
) {
  return http.StreamedResponse(
    Stream.value(utf8.encode(body)),
    statusCode,
    request: request,
  );
}
