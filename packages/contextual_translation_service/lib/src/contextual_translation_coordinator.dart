import 'contextual_translation_cache.dart';
import 'contextual_translation_errors.dart';
import 'contextual_translation_models.dart';
import 'contextual_translation_service.dart';

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
  }) async {
    final cached = _cache.read(request);
    if (cached != null) return cached;

    try {
      final result = await _remoteService.translate(request);
      _cache.write(request, result);
      return result;
    } on ContextualTranslationException catch (error) {
      if (!_canFallbackOffline(error)) rethrow;
    }

    final sourceLanguage = request.concreteSourceLanguage;
    if (sourceLanguage == null) {
      throw ContextualTranslationException(
        ContextualTranslationFailureReason.sourceLanguageRequired,
        'Choose the source language to translate offline',
        targetLanguage: request.targetLanguage,
      );
    }

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
    }

    final result = await _offlineService.translate(
      request,
      sourceLanguage: sourceLanguage,
    );
    _cache.write(request, result);
    return result;
  }

  @override
  void dispose() {
    _remoteService.dispose();
  }
}

bool _canFallbackOffline(ContextualTranslationException error) {
  return switch (error.reason) {
    ContextualTranslationFailureReason.network ||
    ContextualTranslationFailureReason.unavailable => true,
    ContextualTranslationFailureReason.http => _isTransientHttpStatus(
      error.statusCode,
    ),
    ContextualTranslationFailureReason.invalidResponse ||
    ContextualTranslationFailureReason.sourceLanguageRequired ||
    ContextualTranslationFailureReason.offlineModelRequired ||
    ContextualTranslationFailureReason.unsupportedLanguagePair => false,
  };
}

bool _isTransientHttpStatus(int? statusCode) {
  if (statusCode == null) return false;
  return statusCode == 408 || statusCode == 429 || statusCode >= 500;
}
