import 'dart:convert';

import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
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
