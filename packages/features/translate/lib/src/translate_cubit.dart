import 'dart:async';

import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:shared/shared.dart';

import 'translation_selection_mode.dart';
import 'word_save_status.dart';

enum TranslateSheetStatus {
  initial,
  loading,
  success,
  failure,
  sourceLanguageRequired,
  offlineModelRequired,
  downloadingOfflineModel,

  /// The text is already in the target language: nothing is translated.
  sameLanguage,
}

class TranslateSheetState extends Equatable {
  const TranslateSheetState({
    required this.sourceLanguageCode,
    required this.targetLanguageCode,
    this.status = TranslateSheetStatus.initial,
    this.result,
    this.failure,
    this.detectedSourceLanguage,
    this.saveStatus = WordSaveStatus.notSaved,
    this.savedEntryId,
  });

  final String sourceLanguageCode;
  final String targetLanguageCode;
  final TranslateSheetStatus status;
  final ContextualTranslationResult? result;
  final ContextualTranslationException? failure;

  /// Language of the selected text as the provider last detected it. It
  /// describes the text, not a request, so it outlives target changes: the
  /// direction label keeps it and a target equal to it needs no request.
  final String? detectedSourceLanguage;

  /// Whether the selected word is in the reader's saved words.
  final WordSaveStatus saveStatus;
  final String? savedEntryId;

  bool get isBusy =>
      status == TranslateSheetStatus.loading ||
      status == TranslateSheetStatus.downloadingOfflineModel;

  /// The source language as far as it is known: the reader's choice, or the
  /// detected language while the source is automatic.
  String? get knownSourceLanguage =>
      sourceLanguageCode == autoSourceLanguageCode
      ? detectedSourceLanguage
      : sourceLanguageCode;

  TranslateSheetState copyWith({
    String? sourceLanguageCode,
    String? targetLanguageCode,
    TranslateSheetStatus? status,
    Object? result = _absent,
    Object? failure = _absent,
    Object? detectedSourceLanguage = _absent,
    WordSaveStatus? saveStatus,
    Object? savedEntryId = _absent,
  }) {
    return TranslateSheetState(
      sourceLanguageCode: sourceLanguageCode ?? this.sourceLanguageCode,
      targetLanguageCode: targetLanguageCode ?? this.targetLanguageCode,
      status: status ?? this.status,
      result: result == _absent
          ? this.result
          : result as ContextualTranslationResult?,
      failure: failure == _absent
          ? this.failure
          : failure as ContextualTranslationException?,
      detectedSourceLanguage: detectedSourceLanguage == _absent
          ? this.detectedSourceLanguage
          : detectedSourceLanguage as String?,
      saveStatus: saveStatus ?? this.saveStatus,
      savedEntryId: savedEntryId == _absent
          ? this.savedEntryId
          : savedEntryId as String?,
    );
  }

  @override
  List<Object?> get props => [
    sourceLanguageCode,
    targetLanguageCode,
    status,
    result,
    failure,
    detectedSourceLanguage,
    saveStatus,
    savedEntryId,
  ];
}

class TranslateCubit extends Cubit<TranslateSheetState> {
  TranslateCubit({
    required ContextualTranslationService translationService,
    required PreferencesService preferencesService,
    DictionaryRepository? dictionaryRepository,
  }) : _translationService = translationService,
       _preferencesService = preferencesService,
       _dictionaryRepository = dictionaryRepository,
       super(
         TranslateSheetState(
           sourceLanguageCode: autoSourceLanguageCode,
           targetLanguageCode:
               preferencesService.current.translationTargetLanguageCode,
         ),
       );

  final ContextualTranslationService _translationService;
  final PreferencesService _preferencesService;
  final DictionaryRepository? _dictionaryRepository;
  bool _savedLookupDone = false;
  int _operationGeneration = 0;
  Completer<void>? _abort;

  int _beginOperation() {
    _abort?.complete();
    _abort = Completer<void>();
    return ++_operationGeneration;
  }

  @override
  Future<void> close() {
    ++_operationGeneration;
    _abort?.complete();
    _abort = null;
    return super.close();
  }

  Future<void> translate(
    TextSelectionContext selection, {
    bool allowOfflineModelDownload = false,
  }) async {
    if (isClosed || state.isBusy) return;
    final operationGeneration = _beginOperation();
    await Future.wait([
      _runTranslation(
        selection,
        operationGeneration: operationGeneration,
        allowOfflineModelDownload: allowOfflineModelDownload,
      ),
      _lookupSavedWord(selection),
    ]);
  }

  /// Whether the word was saved earlier, checked once per sheet.
  Future<void> _lookupSavedWord(TextSelectionContext selection) async {
    final repository = _dictionaryRepository;
    if (repository == null || _savedLookupDone) return;
    _savedLookupDone = true;
    try {
      final entry = await repository.findEntry(
        selection.effectiveSelectedText,
        sourceId: selection.sourceId,
      );
      if (isClosed || entry == null) return;
      emit(
        state.copyWith(
          saveStatus: WordSaveStatus.saved,
          savedEntryId: entry.id,
        ),
      );
    } on StorageException catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }

  /// Saves the translated word to Vocabulary, or removes it when already saved.
  /// Nothing happens without a translation to save or a repository.
  Future<void> toggleSaved(TextSelectionContext selection) async {
    final repository = _dictionaryRepository;
    final result = state.result;
    if (isClosed ||
        repository == null ||
        state.saveStatus == WordSaveStatus.saving) {
      return;
    }
    final savedEntryId = state.savedEntryId;
    emit(state.copyWith(saveStatus: WordSaveStatus.saving));
    try {
      if (savedEntryId != null) {
        await repository.deleteEntry(savedEntryId);
        if (isClosed) return;
        emit(
          state.copyWith(
            saveStatus: WordSaveStatus.notSaved,
            savedEntryId: null,
          ),
        );
        return;
      }
      if (result == null || state.status != TranslateSheetStatus.success) {
        emit(state.copyWith(saveStatus: WordSaveStatus.notSaved));
        return;
      }
      final entry = await repository.addEntry(
        word: selection.effectiveSelectedText.trim(),
        translation: _primaryTranslation(result),
        lemma: result.analysis?.lemma,
        baseTranslation: result.translation.baseTranslation,
        contextTranslation: result.translation.sentenceTranslation,
        pronunciation:
            result.analysis?.pronunciation ?? result.analysis?.reading,
        partOfSpeech: result.analysis?.partOfSpeech,
        context: selection.contextText,
        sourceId: selection.sourceId,
        sourceType: selection.sourceType,
        anchorText: selection.effectiveSelectedText,
        anchorContext: selection.contextText,
        anchorCfiRange: selection.cfiRange,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          saveStatus: WordSaveStatus.saved,
          savedEntryId: entry.id,
        ),
      );
    } on StorageException catch (error, stackTrace) {
      addError(error, stackTrace);
      if (isClosed) return;
      emit(state.copyWith(saveStatus: WordSaveStatus.failure));
    }
  }

  // The same answer the sheet shows first.
  static String _primaryTranslation(ContextualTranslationResult result) {
    for (final candidate in [
      result.contextualExpression?.translation,
      result.translation.contextualTranslation,
      result.translation.translatedFragment,
      result.translation.baseTranslation,
      result.translation.sentenceTranslation,
    ]) {
      final text = candidate?.trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return '';
  }

  Future<void> _runTranslation(
    TextSelectionContext selection, {
    required int operationGeneration,
    bool allowOfflineModelDownload = false,
  }) async {
    if (!_isCurrentOperation(operationGeneration)) return;
    emit(
      state.copyWith(
        status: allowOfflineModelDownload
            ? TranslateSheetStatus.downloadingOfflineModel
            : TranslateSheetStatus.loading,
        result: null,
        failure: null,
      ),
    );

    try {
      final result = await _translationService.translate(
        _requestFor(selection),
        allowOfflineModelDownload: allowOfflineModelDownload,
        abortTrigger: _abort!.future,
      );
      if (!_isCurrentOperation(operationGeneration)) return;
      emit(
        state.copyWith(
          status: TranslateSheetStatus.success,
          result: result,
          detectedSourceLanguage:
              result.detectedSourceLanguage ?? state.detectedSourceLanguage,
        ),
      );
    } on ContextualTranslationException catch (error) {
      if (!_isCurrentOperation(operationGeneration)) return;
      // A same-language answer to an automatic source names the text's
      // language; with a chosen source it only repeats that choice.
      final detected =
          error.reason == ContextualTranslationFailureReason.sameLanguage &&
              state.sourceLanguageCode == autoSourceLanguageCode
          ? error.sourceLanguage
          : null;
      emit(
        state.copyWith(
          status: _statusFor(error.reason),
          failure: error,
          result: null,
          detectedSourceLanguage: detected ?? state.detectedSourceLanguage,
        ),
      );
    } catch (error, stackTrace) {
      if (!_isCurrentOperation(operationGeneration)) return;
      addError(error, stackTrace);
      emit(
        state.copyWith(
          status: TranslateSheetStatus.failure,
          result: null,
          failure: const ContextualTranslationException(
            ContextualTranslationFailureReason.invalidResponse,
            'Unexpected translation failure',
          ),
        ),
      );
    }
  }

  /// Translates from [code]. A source equal to the target needs no request:
  /// the sheet says so at once.
  Future<void> setSourceLanguage(
    TextSelectionContext selection,
    String code,
  ) async {
    if (isClosed || state.sourceLanguageCode == code) return;
    final operationGeneration = _beginOperation();
    final next = state.copyWith(sourceLanguageCode: code);
    final sameLanguage = isSameTranslationLanguage(
      next.knownSourceLanguage,
      next.targetLanguageCode,
    );
    emit(
      next.copyWith(
        status: sameLanguage
            ? TranslateSheetStatus.sameLanguage
            : TranslateSheetStatus.initial,
        result: null,
        failure: null,
      ),
    );
    if (sameLanguage) return;
    await _runTranslation(selection, operationGeneration: operationGeneration);
  }

  /// Translates into [code] and keeps it as the default target. A target
  /// equal to the text's known language needs no request: the sheet says so
  /// at once, and any running request is cancelled.
  Future<void> setTargetLanguage(
    TextSelectionContext selection,
    String code,
  ) async {
    if (isClosed || state.targetLanguageCode == code) return;
    final operationGeneration = _beginOperation();
    final sameLanguage = isSameTranslationLanguage(
      state.knownSourceLanguage,
      code,
    );
    emit(
      state.copyWith(
        targetLanguageCode: code,
        status: sameLanguage
            ? TranslateSheetStatus.sameLanguage
            : TranslateSheetStatus.initial,
        result: null,
        failure: null,
      ),
    );
    await _preferencesService.update(
      (prefs) => prefs.copyWith(translationTargetLanguageCode: code),
    );
    if (sameLanguage || !_isCurrentOperation(operationGeneration)) return;
    await _runTranslation(selection, operationGeneration: operationGeneration);
  }

  bool _isCurrentOperation(int generation) {
    return !isClosed && generation == _operationGeneration;
  }

  ContextualTranslationRequest _requestFor(TextSelectionContext selection) {
    final contextText = selection.contextText?.trim();
    final normalizedText = selection.compatibleNormalizedSelectedText;
    final currentText = contextText == null || contextText.isEmpty
        ? selection.effectiveSelectedText
        : contextText;
    final mode = translationModeForSelection(selection);
    return ContextualTranslationRequest(
      sourceLanguage: state.sourceLanguageCode,
      sourceLanguageHint: selection.sourceLanguageHint,
      targetLanguage: state.targetLanguageCode,
      mode: mode,
      selection: TranslationSelection(
        text: selection.selectedText,
        normalizedText: normalizedText,
        kind: selection.selectionKind,
      ),
      context: TranslationTextContext(
        level: mode == selectedTextTranslationMode ? 'selection' : 'sentence',
        current: TranslationContextPassage(
          text: currentText,
          markedText: selection.markedContextText,
          normalizedMarkedText: normalizedText == null
              ? null
              : selection.normalizedMarkedContextText,
        ),
      ),
      anchor: TranslationAnchor(
        sourceId: selection.sourceId,
        sourceType: selection.sourceType.name,
        cfiRange: selection.cfiRange,
        normalizedCfiRange: selection.normalizedCfiRange,
        progress: selection.progress,
        chapterTitle: selection.chapterTitle,
      ),
    );
  }
}

TranslateSheetStatus _statusFor(ContextualTranslationFailureReason reason) {
  return switch (reason) {
    ContextualTranslationFailureReason.sourceLanguageRequired =>
      TranslateSheetStatus.sourceLanguageRequired,
    ContextualTranslationFailureReason.offlineModelRequired =>
      TranslateSheetStatus.offlineModelRequired,
    ContextualTranslationFailureReason.sameLanguage =>
      TranslateSheetStatus.sameLanguage,
    _ => TranslateSheetStatus.failure,
  };
}

const _absent = Object();
