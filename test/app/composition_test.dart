import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:dictionary_service/dictionary_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http/testing.dart';
import 'package:monitoring/monitoring.dart';
import 'package:readflex/app/composition.dart';
import 'package:readflex/app/config/application_config.dart';
import 'package:readflex/app/resource_disposer.dart';

void main() {
  group('backend services', () {
    test('send every request through the one shared client', () async {
      final events = <String>[];
      final resources = ResourceDisposer(logger: Logger());
      addTearDown(resources.dispose);
      final services = createBackendServices(
        config: const ApplicationConfig(),
        resources: resources,
        backendHttpClient: _BackendClient(events),
        offlineTranslationService: _FakeOfflineService(events),
      );

      await services.dictionaryLookupService.lookup(
        DictionaryLookupRequest(term: 'power'),
      );
      await services.contextualTranslationService.translate(_translation());
      await services.articleExtractionService.extract('https://example.com/a');

      expect(events, [
        'POST /v1/dictionary/lookup',
        'POST /v1/contextual-translation/analyze',
        'POST /v1/extract',
      ]);
    });

    test('dispose closes the shared client once, after its services', () async {
      final events = <String>[];
      final resources = ResourceDisposer(logger: Logger())
        ..add('earlier', () => events.add('earlier'));
      createBackendServices(
        config: const ApplicationConfig(),
        resources: resources,
        backendHttpClient: _BackendClient(events),
        offlineTranslationService: _FakeOfflineService(events),
      );
      resources.add('later', () => events.add('later'));

      await resources.dispose();

      expect(events, [
        'later',
        'offline.dispose',
        'backendHttpClient.close',
        'earlier',
      ]);
    });

    test('bootstrap rollback closes the shared client', () async {
      final events = <String>[];
      final resources = ResourceDisposer(logger: Logger());
      createBackendServices(
        config: const ApplicationConfig(),
        resources: resources,
        backendHttpClient: _BackendClient(events),
        offlineTranslationService: _FakeOfflineService(events),
      );

      await resources.dispose(rollback: true);

      expect(events, ['offline.dispose', 'backendHttpClient.close']);
    });

    test('a connect timeout reaches the offline translation', () async {
      final events = <String>[];
      final httpClient = createBackendHttpClient()
        ..connectionTimeout = const Duration(milliseconds: 100)
        ..findProxy = ((_) => 'DIRECT')
        // An unreachable host: the TCP connection never completes.
        ..connectionFactory = (uri, proxyHost, proxyPort) async {
          return ConnectionTask.fromSocket(Completer<Socket>().future, () {});
        };
      final resources = ResourceDisposer(logger: Logger());
      addTearDown(resources.dispose);
      final services = createBackendServices(
        config: const ApplicationConfig(),
        resources: resources,
        backendHttpClient: IOClient(httpClient),
        offlineTranslationService: _FakeOfflineService(events),
      );

      final result = await services.contextualTranslationService.translate(
        _translation(),
      );

      expect(result.reliability, ContextualTranslationReliability.offline);
      expect(events, ['offline.translate']);
    });
  });

  test('the backend client times out connections, not idle reuse', () {
    final client = createBackendHttpClient();
    addTearDown(() => client.close(force: true));

    expect(client.connectionTimeout, const Duration(seconds: 10));
    expect(
      client.idleTimeout,
      const Duration(seconds: 15),
      reason: 'the backend keep-alive is unknown; keep the dart:io default',
    );
  });
}

ContextualTranslationRequest _translation() {
  return ContextualTranslationRequest(
    sourceLanguage: 'en',
    targetLanguage: 'ru',
    selection: const TranslationSelection(text: 'power'),
    context: const TranslationTextContext(level: 'sentence'),
    anchor: const TranslationAnchor(sourceId: 'source-1', sourceType: 'book'),
  );
}

/// Answers each Readflex API endpoint and records requests and its close.
class _BackendClient extends MockClient {
  _BackendClient(this._events) : super((request) => _answer(request, _events));

  final List<String> _events;

  @override
  void close() => _events.add('backendHttpClient.close');

  static Future<http.Response> _answer(
    http.Request request,
    List<String> events,
  ) async {
    events.add('${request.method} ${request.url.path}');
    final body = jsonDecode(request.body) as Map<String, Object?>;
    final json = switch (request.url.path) {
      '/v1/dictionary/lookup' => {
        'request_id': body['request_id'],
        'status': 'not_found',
        'term': body['term'],
      },
      '/v1/contextual-translation/analyze' => {
        'schema_version': contextualTranslationResultSchemaVersion,
        'request_id': body['request_id'],
        'mode': contextualTranslationMode,
        'status': 'resolved',
        'reliability': 'verified',
        'detected_source_language': 'en',
        'target_language': 'ru',
        'translation': {'contextual_translation': 'сила'},
        'source': <String, Object?>{},
      },
      '/v1/extract' => {
        'requested_url': body['url'],
        'resolved_url': body['url'],
        'title': 'Article',
        'body_format': 'blocks',
        'body': [
          {'type': 'paragraph', 'text': 'Text'},
        ],
        'plain_text': 'Text',
      },
      _ => throw StateError('Unexpected ${request.url}'),
    };
    return http.Response(
      jsonEncode(json),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

class _FakeOfflineService implements OfflineContextualTranslationService {
  _FakeOfflineService(this._events);

  final List<String> _events;

  @override
  bool supportsLanguagePair({
    required String sourceLanguage,
    required String targetLanguage,
  }) => true;

  @override
  Future<bool> areModelsDownloaded({
    required String sourceLanguage,
    required String targetLanguage,
  }) async => true;

  @override
  Future<void> downloadModels({
    required String sourceLanguage,
    required String targetLanguage,
  }) async {}

  @override
  Future<ContextualTranslationResult> translate(
    ContextualTranslationRequest request, {
    required String sourceLanguage,
  }) async {
    _events.add('offline.translate');
    return ContextualTranslationResult.offline(
      request: request,
      sourceLanguage: sourceLanguage,
      selectedTranslation: 'сила',
    );
  }

  @override
  void dispose() => _events.add('offline.dispose');
}
