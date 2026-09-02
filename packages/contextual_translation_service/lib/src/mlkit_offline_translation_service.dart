import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import 'contextual_translation_errors.dart';
import 'contextual_translation_models.dart';
import 'contextual_translation_service.dart';

class MlKitOfflineTranslationService
    implements OfflineContextualTranslationService {
  MlKitOfflineTranslationService({OnDeviceTranslatorModelManager? modelManager})
    : _modelManager = modelManager ?? OnDeviceTranslatorModelManager();

  final OnDeviceTranslatorModelManager _modelManager;

  @override
  bool supportsLanguagePair({
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    return _translateLanguageForCode(sourceLanguage) != null &&
        _translateLanguageForCode(targetLanguage) != null &&
        sourceLanguage.toLowerCase() != targetLanguage.toLowerCase();
  }

  @override
  Future<bool> areModelsDownloaded({
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    try {
      final source = _requiredLanguage(sourceLanguage);
      final target = _requiredLanguage(targetLanguage);
      final sourceReady = await _modelManager.isModelDownloaded(source.bcpCode);
      final targetReady = await _modelManager.isModelDownloaded(target.bcpCode);
      return sourceReady && targetReady;
    } on ContextualTranslationException {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        _offlineUnavailable(error, sourceLanguage, targetLanguage),
        stackTrace,
      );
    }
  }

  @override
  Future<void> downloadModels({
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    try {
      final source = _requiredLanguage(sourceLanguage);
      final target = _requiredLanguage(targetLanguage);
      final sourceDownloaded = await _modelManager.downloadModel(
        source.bcpCode,
      );
      final targetDownloaded = source.bcpCode == target.bcpCode
          ? sourceDownloaded
          : await _modelManager.downloadModel(target.bcpCode);
      if (!sourceDownloaded || !targetDownloaded) {
        throw _offlineUnavailable(null, sourceLanguage, targetLanguage);
      }
    } on ContextualTranslationException {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        _offlineUnavailable(error, sourceLanguage, targetLanguage),
        stackTrace,
      );
    }
  }

  @override
  Future<ContextualTranslationResult> translate(
    ContextualTranslationRequest request, {
    required String sourceLanguage,
  }) async {
    final source = _requiredLanguage(sourceLanguage);
    final target = _requiredLanguage(request.targetLanguage);
    final translator = OnDeviceTranslator(
      sourceLanguage: source,
      targetLanguage: target,
    );
    try {
      final selected = await translator.translateText(
        request.selection.effectiveText,
      );
      final currentSentence = request.context.current?.text.trim();
      final sentenceTranslation =
          currentSentence == null ||
              currentSentence.isEmpty ||
              currentSentence == request.selection.effectiveText
          ? null
          : await translator.translateText(currentSentence);
      return ContextualTranslationResult.offline(
        request: request,
        sourceLanguage: source.bcpCode,
        selectedTranslation: selected,
        sentenceTranslation: sentenceTranslation,
      );
    } on ContextualTranslationException {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        _offlineUnavailable(error, sourceLanguage, request.targetLanguage),
        stackTrace,
      );
    } finally {
      await translator.close();
    }
  }
}

TranslateLanguage _requiredLanguage(String code) {
  final language = _translateLanguageForCode(code);
  if (language != null) return language;
  throw ContextualTranslationException(
    ContextualTranslationFailureReason.unsupportedLanguagePair,
    'Unsupported translation language: $code',
    sourceLanguage: code,
  );
}

TranslateLanguage? _translateLanguageForCode(String code) {
  return switch (code.trim().toLowerCase().split(RegExp(r'[-_]')).first) {
    'ar' => TranslateLanguage.arabic,
    'de' => TranslateLanguage.german,
    'en' => TranslateLanguage.english,
    'es' => TranslateLanguage.spanish,
    'fr' => TranslateLanguage.french,
    'hi' => TranslateLanguage.hindi,
    'ja' => TranslateLanguage.japanese,
    'pt' => TranslateLanguage.portuguese,
    'ru' => TranslateLanguage.russian,
    'zh' => TranslateLanguage.chinese,
    _ => null,
  };
}

ContextualTranslationException _offlineUnavailable(
  Object? cause,
  String sourceLanguage,
  String targetLanguage,
) {
  return ContextualTranslationException(
    ContextualTranslationFailureReason.unavailable,
    'Offline translation is unavailable',
    sourceLanguage: sourceLanguage,
    targetLanguage: targetLanguage,
    cause: cause,
  );
}
