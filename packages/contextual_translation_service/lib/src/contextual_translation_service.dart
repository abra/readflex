import 'contextual_translation_models.dart';

abstract class ContextualTranslationService {
  Future<ContextualTranslationResult> translate(
    ContextualTranslationRequest request, {
    bool allowOfflineModelDownload = false,
  });

  void dispose() {}
}

abstract class OfflineContextualTranslationService {
  bool supportsLanguagePair({
    required String sourceLanguage,
    required String targetLanguage,
  });

  Future<bool> areModelsDownloaded({
    required String sourceLanguage,
    required String targetLanguage,
  });

  Future<void> downloadModels({
    required String sourceLanguage,
    required String targetLanguage,
  });

  Future<ContextualTranslationResult> translate(
    ContextualTranslationRequest request, {
    required String sourceLanguage,
  });
}
