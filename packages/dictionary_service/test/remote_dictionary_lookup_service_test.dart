import 'dart:convert';

import 'package:dictionary_service/dictionary_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
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
              'Missing or invalid X-API-Key',
            ),
      ),
    );
  });
}
