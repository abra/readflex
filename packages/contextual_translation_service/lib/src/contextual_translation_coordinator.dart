import 'contextual_translation_cache.dart';
import 'contextual_translation_errors.dart';
import 'contextual_translation_models.dart';
import 'contextual_translation_service.dart';
import 'translation_language_code.dart';

class ContextualTranslationCoordinator implements ContextualTranslationService {
  ContextualTranslationCoordinator({
    required ContextualTranslationService remoteService,
    required OfflineContextualTranslationService offlineService,
    ContextualTranslationCache? cache,
  }) : _remoteService = remoteService,
       _offlineService = offlineService,
       _cache = cache ?? MemoryContextualTranslationCache();

  final ContextualTranslationService _remoteService;
  final OfflineContextualTranslationService _offlineService;
  final ContextualTranslationCache _cache;

  @override
  Future<ContextualTranslationResult> translate(
    ContextualTranslationRequest request, {
    bool allowOfflineModelDownload = false,
    Future<void>? abortTrigger,
  }) async {
    var cancelled = false;
    abortTrigger?.then((_) => cancelled = true);
    void checkCancellation() {
      if (cancelled) {
        throw const ContextualTranslationException(
          ContextualTranslationFailureReason.cancelled,
          'Translation request cancelled',
        );
      }
    }

    // Observe an already completed signal before reading cache or starting I/O.
    await Future<void>.value();
    checkCancellation();
    // A source the reader chose that equals the target needs no provider.
    _throwIfSameLanguage(request.sourceLanguage, request);
    final cached = _cache.read(request);
    if (cached != null &&
        cached.reliability != ContextualTranslationReliability.offline) {
      return _resultForRequest(
        _checkedLanguages(cached, request),
        request.requestId,
      );
    }

    try {
      final result = await _remoteService.translate(
        request,
        abortTrigger: abortTrigger,
      );
      checkCancellation();
      // Checked before caching, so a result that answers another question
      // is never served again.
      _cache.write(request, _checkedLanguages(result, request));
      return result;
    } on ContextualTranslationException catch (error) {
      checkCancellation();
      if (!_canFallbackOffline(error)) rethrow;
    }

    // Retry the contextual provider even when an earlier offline result exists.
    if (cached != null) return _resultForRequest(cached, request.requestId);

    final sourceLanguage = request.concreteSourceLanguage;
    if (sourceLanguage == null) {
      throw ContextualTranslationException(
        ContextualTranslationFailureReason.sourceLanguageRequired,
        'Choose the source language to translate offline',
        targetLanguage: request.targetLanguage,
      );
    }
    // Before any model check or download: there is nothing to translate.
    _throwIfSameLanguage(sourceLanguage, request);

    if (!_offlineService.supportsLanguagePair(
      sourceLanguage: sourceLanguage,
      targetLanguage: request.targetLanguage,
    )) {
      throw ContextualTranslationException(
        ContextualTranslationFailureReason.unsupportedLanguagePair,
        'This language pair is not available offline',
        sourceLanguage: sourceLanguage,
        targetLanguage: request.targetLanguage,
      );
    }

    final downloaded = await _offlineService.areModelsDownloaded(
      sourceLanguage: sourceLanguage,
      targetLanguage: request.targetLanguage,
    );
    checkCancellation();
    if (!downloaded) {
      if (!allowOfflineModelDownload) {
        throw ContextualTranslationException(
          ContextualTranslationFailureReason.offlineModelRequired,
          'Download offline translation models',
          sourceLanguage: sourceLanguage,
          targetLanguage: request.targetLanguage,
        );
      }
      await _offlineService.downloadModels(
        sourceLanguage: sourceLanguage,
        targetLanguage: request.targetLanguage,
      );
      checkCancellation();
      final modelsReady = await _offlineService.areModelsDownloaded(
        sourceLanguage: sourceLanguage,
        targetLanguage: request.targetLanguage,
      );
      checkCancellation();
      if (!modelsReady) {
        throw ContextualTranslationException(
          ContextualTranslationFailureReason.unavailable,
          'Offline translation models could not be downloaded',
          sourceLanguage: sourceLanguage,
          targetLanguage: request.targetLanguage,
        );
      }
    }

    final result = await _offlineService.translate(
      request,
      sourceLanguage: sourceLanguage,
    );
    checkCancellation();
    _cache.write(request, result);
    return result;
  }

  /// Disposes both providers, which this coordinator owns.
  @override
  void dispose() {
    try {
      _remoteService.dispose();
    } finally {
      _offlineService.dispose();
    }
  }
}

/// Rejects a [result] that answers another question than [request]: text
/// already in the target language, or a translation into another language.
///
/// Lives here rather than in a provider so remote and offline results follow
/// the same rule.
ContextualTranslationResult _checkedLanguages(
  ContextualTranslationResult result,
  ContextualTranslationRequest request,
) {
  _throwIfSameLanguage(result.detectedSourceLanguage, request);
  final answered = result.targetLanguage;
  if (answered != null &&
      !isSameTranslationLanguage(answered, request.targetLanguage)) {
    throw ContextualTranslationException(
      ContextualTranslationFailureReason.invalidResponse,
      'Translation response is in another language than requested',
      sourceLanguage: result.detectedSourceLanguage,
      targetLanguage: answered,
    );
  }
  return result;
}

void _throwIfSameLanguage(
  String? sourceLanguage,
  ContextualTranslationRequest request,
) {
  if (!isSameTranslationLanguage(sourceLanguage, request.targetLanguage)) {
    return;
  }
  throw ContextualTranslationException(
    ContextualTranslationFailureReason.sameLanguage,
    'The text is already in the target language',
    sourceLanguage: translationLanguagePrimaryCode(sourceLanguage),
    targetLanguage: request.targetLanguage,
  );
}

bool _canFallbackOffline(ContextualTranslationException error) {
  return switch (error.reason) {
    ContextualTranslationFailureReason.network ||
    ContextualTranslationFailureReason.unavailable => true,
    ContextualTranslationFailureReason.http => _isTransientHttpStatus(
      error.statusCode,
    ),
    ContextualTranslationFailureReason.invalidResponse ||
    ContextualTranslationFailureReason.cancelled ||
    ContextualTranslationFailureReason.sourceLanguageRequired ||
    ContextualTranslationFailureReason.offlineModelRequired ||
    ContextualTranslationFailureReason.unsupportedLanguagePair ||
    ContextualTranslationFailureReason.sameLanguage => false,
  };
}

bool _isTransientHttpStatus(int? statusCode) {
  if (statusCode == null) return false;
  return statusCode == 408 || statusCode == 429 || statusCode >= 500;
}

ContextualTranslationResult _resultForRequest(
  ContextualTranslationResult result,
  String requestId,
) {
  if (result.requestId == requestId) return result;
  return ContextualTranslationResult(
    requestId: requestId,
    mode: result.mode,
    provider: result.provider,
    status: result.status,
    reliability: result.reliability,
    detectedSourceLanguage: result.detectedSourceLanguage,
    targetLanguage: result.targetLanguage,
    analysis: result.analysis,
    translation: result.translation,
    contextualExpression: result.contextualExpression,
    explanation: result.explanation,
    alternatives: result.alternatives,
    source: result.source,
  );
}
