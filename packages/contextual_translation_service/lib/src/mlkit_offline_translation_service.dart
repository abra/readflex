import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import 'contextual_translation_errors.dart';
import 'contextual_translation_models.dart';
import 'contextual_translation_service.dart';

// Each native translator holds its loaded models in memory, so one idle for
// this long is released; lookups while reading a page or two reuse it.
const _translatorIdleTimeout = Duration(minutes: 2);

/// Keeps one native translator for the current language pair. It is closed
/// on a pair change, after two idle minutes, after a failure, and on
/// [dispose], each time only once no request still uses it.
class MlKitOfflineTranslationService
    implements OfflineContextualTranslationService {
  MlKitOfflineTranslationService({OnDeviceTranslatorModelManager? modelManager})
    : this._(
        modelManager: modelManager,
        translatorFactory: OnDeviceTranslator.new,
      );

  /// Test entry point that creates translators without the native plugin.
  @visibleForTesting
  MlKitOfflineTranslationService.forTesting({
    required OnDeviceTranslator Function({
      required TranslateLanguage sourceLanguage,
      required TranslateLanguage targetLanguage,
    })
    translatorFactory,
    OnDeviceTranslatorModelManager? modelManager,
  }) : this._(modelManager: modelManager, translatorFactory: translatorFactory);

  MlKitOfflineTranslationService._({
    required OnDeviceTranslatorModelManager? modelManager,
    required OnDeviceTranslator Function({
      required TranslateLanguage sourceLanguage,
      required TranslateLanguage targetLanguage,
    })
    translatorFactory,
  }) : _modelManager = modelManager ?? OnDeviceTranslatorModelManager(),
       _createTranslator = translatorFactory;

  final OnDeviceTranslatorModelManager _modelManager;
  final OnDeviceTranslator Function({
    required TranslateLanguage sourceLanguage,
    required TranslateLanguage targetLanguage,
  })
  _createTranslator;
  _SharedTranslator? _current;
  Timer? _idleTimer;
  var _disposed = false;

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
    _SharedTranslator? shared;
    var failed = true;
    try {
      shared = _acquire(source, target);
      final translator = shared.translator;
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
      failed = false;
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
      if (shared != null) _release(shared, discard: failed);
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _idleTimer?.cancel();
    _idleTimer = null;
    final current = _current;
    _current = null;
    if (current != null) _retire(current);
  }

  _SharedTranslator _acquire(
    TranslateLanguage source,
    TranslateLanguage target,
  ) {
    if (_disposed) throw StateError('Offline translation service is disposed');
    var current = _current;
    if (current == null || !current.translates(source, target)) {
      // Created before the old pair is retired, so a failing factory leaves
      // the current translator and its idle timer untouched.
      final created = _SharedTranslator(
        _createTranslator(sourceLanguage: source, targetLanguage: target),
      );
      if (current != null) _retire(current);
      current = _current = created;
    }
    _idleTimer?.cancel();
    _idleTimer = null;
    current.users++;
    return current;
  }

  // A translator that failed is not reused: the next request starts fresh.
  void _release(_SharedTranslator shared, {required bool discard}) {
    shared.users--;
    if (identical(shared, _current)) {
      if (!discard) {
        if (shared.users == 0) {
          _idleTimer = Timer(_translatorIdleTimeout, _closeIdleTranslator);
        }
        return;
      }
      _current = null;
      _idleTimer?.cancel();
      _idleTimer = null;
    }
    _retire(shared);
  }

  void _closeIdleTranslator() {
    _idleTimer = null;
    final current = _current;
    if (current == null || current.users > 0) return;
    _current = null;
    _retire(current);
  }

  // Native close only after the last request: the plugin (Android and iOS)
  // silently recreates, and then leaks, a translator used after its close.
  void _retire(_SharedTranslator shared) {
    if (shared.users > 0 || shared.closed) return;
    shared.closed = true;
    shared.translator.close().ignore();
  }
}

class _SharedTranslator {
  _SharedTranslator(this.translator);

  final OnDeviceTranslator translator;
  var users = 0;
  var closed = false;

  bool translates(TranslateLanguage source, TranslateLanguage target) {
    return translator.sourceLanguage == source &&
        translator.targetLanguage == target;
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
