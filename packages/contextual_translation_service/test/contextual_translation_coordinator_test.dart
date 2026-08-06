import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns remote result and caches it', () async {
    final remote = _FakeRemoteService();
    final offline = _FakeOfflineService();
    final coordinator = ContextualTranslationCoordinator(
      remoteService: remote,
      offlineService: offline,
    );

    final request = _request();
    final first = await coordinator.translate(request);
    final second = await coordinator.translate(request);

    expect(first.translation.contextualTranslation, 'remote');
    expect(identical(first, second), isTrue);
    expect(remote.calls, 1);
    expect(offline.calls, 0);
  });

  test('falls back offline when remote has a network failure', () async {
    final remote = _FakeRemoteService(
      error: const ContextualTranslationException(
        ContextualTranslationFailureReason.network,
        'offline',
      ),
    );
    final offline = _FakeOfflineService(downloaded: true);
    final coordinator = ContextualTranslationCoordinator(
      remoteService: remote,
      offlineService: offline,
    );

    final result = await coordinator.translate(_request());

    expect(result.reliability, ContextualTranslationReliability.offline);
    expect(result.translation.contextualTranslation, 'offline');
    expect(offline.calls, 1);
  });

  test('falls back offline when remote has a transient HTTP failure', () async {
    final remote = _FakeRemoteService(
      error: const ContextualTranslationException(
        ContextualTranslationFailureReason.http,
        'service unavailable',
        statusCode: 503,
      ),
    );
    final offline = _FakeOfflineService(downloaded: true);
    final coordinator = ContextualTranslationCoordinator(
      remoteService: remote,
      offlineService: offline,
    );

    final result = await coordinator.translate(_request());

    expect(result.reliability, ContextualTranslationReliability.offline);
    expect(result.translation.contextualTranslation, 'offline');
    expect(offline.calls, 1);
  });

  test('does not fall back offline on backend authorization errors', () async {
    const error = ContextualTranslationException(
      ContextualTranslationFailureReason.http,
      'unauthorized',
      statusCode: 401,
    );
    final offline = _FakeOfflineService(downloaded: true);
    final coordinator = ContextualTranslationCoordinator(
      remoteService: _FakeRemoteService(error: error),
      offlineService: offline,
    );

    await expectLater(coordinator.translate(_request()), throwsA(error));
    expect(offline.calls, 0);
  });

  test('requires source language for offline fallback', () async {
    final coordinator = ContextualTranslationCoordinator(
      remoteService: _FakeRemoteService(
        error: const ContextualTranslationException(
          ContextualTranslationFailureReason.network,
          'offline',
        ),
      ),
      offlineService: _FakeOfflineService(downloaded: true),
    );

    expect(
      coordinator.translate(_request(sourceHint: null)),
      throwsA(
        isA<ContextualTranslationException>().having(
          (e) => e.reason,
          'reason',
          ContextualTranslationFailureReason.sourceLanguageRequired,
        ),
      ),
    );
  });

  test('can download missing offline models when allowed', () async {
    final offline = _FakeOfflineService(downloaded: false);
    final coordinator = ContextualTranslationCoordinator(
      remoteService: _FakeRemoteService(
        error: const ContextualTranslationException(
          ContextualTranslationFailureReason.network,
          'offline',
        ),
      ),
      offlineService: offline,
    );

    final result = await coordinator.translate(
      _request(),
      allowOfflineModelDownload: true,
    );

    expect(result.translation.contextualTranslation, 'offline');
    expect(offline.downloads, 1);
  });
}

ContextualTranslationRequest _request({String? sourceHint = 'en'}) {
  return ContextualTranslationRequest(
    requestId: 'request-1',
    sourceLanguage: autoSourceLanguageCode,
    sourceLanguageHint: sourceHint,
    targetLanguage: 'ru',
    selection: const TranslationSelection(text: 'hello'),
    context: const TranslationTextContext(
      level: 'sentence',
      current: TranslationContextPassage(text: 'hello'),
    ),
    anchor: const TranslationAnchor(sourceId: 'source-1', sourceType: 'book'),
  );
}

class _FakeRemoteService implements ContextualTranslationService {
  _FakeRemoteService({this.error});

  final ContextualTranslationException? error;
  var calls = 0;

  @override
  Future<ContextualTranslationResult> translate(
    ContextualTranslationRequest request, {
    bool allowOfflineModelDownload = false,
  }) async {
    calls++;
    final error = this.error;
    if (error != null) throw error;
    return ContextualTranslationResult(
      requestId: request.requestId,
      status: ContextualTranslationStatus.resolved,
      reliability: ContextualTranslationReliability.verified,
      detectedSourceLanguage: 'en',
      targetLanguage: 'ru',
      translation: const ContextualTranslationText(
        contextualTranslation: 'remote',
      ),
    );
  }

  @override
  void dispose() {}
}

class _FakeOfflineService implements OfflineContextualTranslationService {
  _FakeOfflineService({this.downloaded = false});

  bool downloaded;
  var calls = 0;
  var downloads = 0;

  @override
  Future<bool> areModelsDownloaded({
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    return downloaded;
  }

  @override
  Future<void> downloadModels({
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    downloads++;
    downloaded = true;
  }

  @override
  bool supportsLanguagePair({
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    return true;
  }

  @override
  Future<ContextualTranslationResult> translate(
    ContextualTranslationRequest request, {
    required String sourceLanguage,
  }) async {
    calls++;
    return ContextualTranslationResult.offline(
      request: request,
      sourceLanguage: sourceLanguage,
      selectedTranslation: 'offline',
    );
  }
}
