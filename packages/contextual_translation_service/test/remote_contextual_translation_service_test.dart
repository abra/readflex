import 'dart:async';
import 'dart:convert';

import 'package:contextual_translation_service/contextual_translation_service.dart';
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
        final service = RemoteContextualTranslationService(
          baseUri: Uri.parse('https://api.readflex.app'),
          httpClient: client,
          timeout: const Duration(milliseconds: 50),
        );
        final abort = Completer<void>();
        final operation = service.translate(
          _request,
          abortTrigger: abort.future,
        );
        final assertion = expectLater(
          operation,
          throwsA(
            isA<ContextualTranslationException>().having(
              (error) => error.reason,
              'reason',
              cancelExplicitly
                  ? ContextualTranslationFailureReason.cancelled
                  : ContextualTranslationFailureReason.network,
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

  test('posts the contract and accepts a correlated response', () async {
    late http.Request captured;
    final service = RemoteContextualTranslationService(
      baseUri: Uri.parse('https://api.readflex.app/base/'),
      apiKey: 'secret',
      httpClient: MockClient((request) async {
        captured = request;
        return _jsonResponse(_resultJson());
      }),
    );

    final result = await service.translate(_request);

    expect(
      captured.url,
      Uri.parse('https://api.readflex.app/v1/contextual-translation/analyze'),
    );
    expect(captured.headers['X-API-Key'], 'secret');
    expect(jsonDecode(captured.body), _request.toJson());
    expect(result.requestId, _request.requestId);
  });

  test('rejects a response correlated to another request', () async {
    final service = RemoteContextualTranslationService(
      baseUri: Uri.parse('https://api.readflex.app'),
      httpClient: MockClient(
        (_) async => _jsonResponse(_resultJson(requestId: 'another-request')),
      ),
    );

    expect(
      () => service.translate(_request),
      throwsA(
        isA<ContextualTranslationException>().having(
          (error) => error.reason,
          'reason',
          ContextualTranslationFailureReason.invalidResponse,
        ),
      ),
    );
  });

  test('maps a malformed success payload to invalidResponse', () async {
    final service = RemoteContextualTranslationService(
      baseUri: Uri.parse('https://api.readflex.app'),
      httpClient: MockClient(
        (_) async => _jsonResponse({..._resultJson(), 'status': 'complete'}),
      ),
    );

    expect(
      () => service.translate(_request),
      throwsA(
        isA<ContextualTranslationException>().having(
          (error) => error.reason,
          'reason',
          ContextualTranslationFailureReason.invalidResponse,
        ),
      ),
    );
  });

  test('does not expose backend error details', () async {
    final service = RemoteContextualTranslationService(
      baseUri: Uri.parse('https://api.readflex.app'),
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({'detail': 'internal provider credential leaked'}),
          401,
        ),
      ),
    );

    expect(
      () => service.translate(_request),
      throwsA(
        isA<ContextualTranslationException>()
            .having((error) => error.statusCode, 'statusCode', 401)
            .having(
              (error) => error.message,
              'message',
              'Translation service authorization failed',
            ),
      ),
    );
  });
}

final _request = ContextualTranslationRequest(
  requestId: 'request-1',
  sourceLanguage: 'en',
  targetLanguage: 'ru',
  selection: const TranslationSelection(text: 'power'),
  context: const TranslationTextContext(level: 'sentence'),
  anchor: const TranslationAnchor(sourceId: 'article-1', sourceType: 'article'),
);

Map<String, Object?> _resultJson({String requestId = 'request-1'}) => {
  'schema_version': contextualTranslationResultSchemaVersion,
  'request_id': requestId,
  'mode': contextualTranslationMode,
  'provider': 'deepseek',
  'status': 'resolved',
  'reliability': 'verified',
  'detected_source_language': 'en',
  'target_language': 'ru',
  'translation': {'contextual_translation': 'сила'},
  'alternatives': <Object?>[],
  'source': {
    'provider': 'deepseek',
    'schema_version': contextualTranslationResultSchemaVersion,
  },
};

http.Response _jsonResponse(Map<String, Object?> body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
