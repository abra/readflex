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
}
