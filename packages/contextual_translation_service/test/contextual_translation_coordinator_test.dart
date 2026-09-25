import 'dart:async';

import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an already cancelled operation performs no I/O', () async {
    final remote = _FakeRemoteService();
    final offline = _FakeOfflineService();
    final coordinator = ContextualTranslationCoordinator(
      remoteService: remote,
      offlineService: offline,
    );
    final abort = Completer<void>()..complete();
    await expectLater(
      coordinator.translate(_request(), abortTrigger: abort.future),
      throwsA(
        isA<ContextualTranslationException>().having(
          (e) => e.reason,
          'reason',
          ContextualTranslationFailureReason.cancelled,
        ),
      ),
    );
    expect(remote.calls, 0);
    expect(offline.downloads, 0);
    expect(offline.calls, 0);
  });

  test('cancellation during model lookup cannot start a download', () async {
    final abort = Completer<void>();
    final remote = _FakeRemoteService(
      error: const ContextualTranslationException(
        ContextualTranslationFailureReason.network,
        'offline',
      ),
    );
    final offline = _FakeOfflineService()..modelCheckGate = Completer<void>();
    final coordinator = ContextualTranslationCoordinator(
      remoteService: remote,
      offlineService: offline,
    );
    final operation = coordinator.translate(
      _request(),
      allowOfflineModelDownload: true,
      abortTrigger: abort.future,
    );
    final assertion = expectLater(
      operation,
      throwsA(
        isA<ContextualTranslationException>().having(
          (e) => e.reason,
          'reason',
          ContextualTranslationFailureReason.cancelled,
        ),
      ),
    );
    await offline.modelCheckStarted.future;
    abort.complete();
    offline.modelCheckGate!.complete();
    await assertion;
    expect(offline.downloads, 0);
    expect(offline.calls, 0);
  });

  test('explicit remote cancellation never falls back offline', () async {
    final remote = _FakeRemoteService(
      error: const ContextualTranslationException(
        ContextualTranslationFailureReason.cancelled,
        'cancelled',
      ),
    );
    final offline = _FakeOfflineService(downloaded: true);
    final coordinator = ContextualTranslationCoordinator(
      remoteService: remote,
      offlineService: offline,
    );
    await expectLater(
      coordinator.translate(_request()),
      throwsA(isA<ContextualTranslationException>()),
    );
    expect(offline.calls, 0);
    expect(offline.modelCheckStarted.isCompleted, isFalse);
  });

  test(
    'retries remote after fallback, reusing offline cache only on failure',
    () async {
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
      expect(
        (await coordinator.translate(_request())).reliability,
        ContextualTranslationReliability.offline,
      );
      expect(
        (await coordinator.translate(_request(requestId: 'retry'))).requestId,
        'retry',
      );
      expect(remote.calls, 2);
      expect(offline.calls, 1);
      remote.error = null;
      final recovered = await coordinator.translate(
        _request(requestId: 'recovered'),
      );
      expect(recovered.reliability, ContextualTranslationReliability.verified);
      expect(recovered.requestId, 'recovered');
      expect(remote.calls, 3);
      await coordinator.translate(_request());
      expect(remote.calls, 3, reason: 'Remote results remain cacheable');
    },
  );
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

  test('correlates a cached result with the current request', () async {
    final remote = _FakeRemoteService();
    final coordinator = ContextualTranslationCoordinator(
      remoteService: remote,
      offlineService: _FakeOfflineService(),
    );

    final first = await coordinator.translate(_request(requestId: 'first'));
    final second = await coordinator.translate(_request(requestId: 'second'));

    expect(first.requestId, 'first');
    expect(second.requestId, 'second');
    expect(second.translation, first.translation);
    expect(first.contextualExpression, isNotNull);
    expect(second.contextualExpression, first.contextualExpression);
    expect(remote.calls, 1);
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

  test(
    'does not translate when downloaded models remain unavailable',
    () async {
      final offline = _FakeOfflineService(
        downloaded: false,
        completesDownload: false,
      );
      final coordinator = ContextualTranslationCoordinator(
        remoteService: _FakeRemoteService(
          error: const ContextualTranslationException(
            ContextualTranslationFailureReason.network,
            'offline',
          ),
        ),
        offlineService: offline,
      );

      await expectLater(
        coordinator.translate(_request(), allowOfflineModelDownload: true),
        throwsA(
          isA<ContextualTranslationException>().having(
            (error) => error.reason,
            'reason',
            ContextualTranslationFailureReason.unavailable,
          ),
        ),
      );
      expect(offline.downloads, 1);
      expect(offline.calls, 0);
    },
  );
}

ContextualTranslationRequest _request({
  String requestId = 'request-1',
  String? sourceHint = 'en',
}) {
  return ContextualTranslationRequest(
    requestId: requestId,
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

  ContextualTranslationException? error;
  var calls = 0;

  @override
  Future<ContextualTranslationResult> translate(
    ContextualTranslationRequest request, {
    bool allowOfflineModelDownload = false,
    Future<void>? abortTrigger,
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
      contextualExpression: const ContextualTranslationExpression(
        text: 'hello there',
        translation: 'привет',
      ),
    );
  }

  @override
  void dispose() {}
}

class _FakeOfflineService implements OfflineContextualTranslationService {
  _FakeOfflineService({this.downloaded = false, this.completesDownload = true});

  bool downloaded;
  final bool completesDownload;
  var calls = 0;
  var downloads = 0;
  final modelCheckStarted = Completer<void>();
  Completer<void>? modelCheckGate;

  @override
  Future<bool> areModelsDownloaded({
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    if (!modelCheckStarted.isCompleted) modelCheckStarted.complete();
    await modelCheckGate?.future;
    return downloaded;
  }

  @override
  Future<void> downloadModels({
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    downloads++;
    if (completesDownload) downloaded = true;
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
