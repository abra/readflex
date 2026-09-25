import 'dart:async';

import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:shared/shared.dart';

import 'translation_selection_mode.dart';

enum TranslateSheetStatus {
  initial,
  loading,
  success,
  failure,
  sourceLanguageRequired,
  offlineModelRequired,
  downloadingOfflineModel,
}

class TranslateSheetState extends Equatable {
  const TranslateSheetState({
    required this.sourceLanguageCode,
    required this.targetLanguageCode,
    this.status = TranslateSheetStatus.initial,
    this.result,
    this.failure,
  });

  final String sourceLanguageCode;
  final String targetLanguageCode;
  final TranslateSheetStatus status;
  final ContextualTranslationResult? result;
  final ContextualTranslationException? failure;

  bool get isBusy =>
      status == TranslateSheetStatus.loading ||
      status == TranslateSheetStatus.downloadingOfflineModel;

  TranslateSheetState copyWith({
    String? sourceLanguageCode,
    String? targetLanguageCode,
    TranslateSheetStatus? status,
    Object? result = _absent,
    Object? failure = _absent,
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
    );
  }

  @override
  List<Object?> get props => [
    sourceLanguageCode,
    targetLanguageCode,
    status,
    result,
    failure,
  ];
}

class TranslateCubit extends Cubit<TranslateSheetState> {
  TranslateCubit({
    required ContextualTranslationService translationService,
    required PreferencesService preferencesService,
  }) : _translationService = translationService,
       _preferencesService = preferencesService,
       super(
         TranslateSheetState(
           sourceLanguageCode: autoSourceLanguageCode,
           targetLanguageCode:
               preferencesService.current.translationTargetLanguageCode,
         ),
       );

  final ContextualTranslationService _translationService;
  final PreferencesService _preferencesService;
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
    await _runTranslation(
      selection,
      operationGeneration: operationGeneration,
      allowOfflineModelDownload: allowOfflineModelDownload,
    );
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
        state.copyWith(status: TranslateSheetStatus.success, result: result),
      );
    } on ContextualTranslationException catch (error) {
      if (!_isCurrentOperation(operationGeneration)) return;
      emit(
        state.copyWith(
          status: _statusFor(error.reason),
          failure: error,
          result: null,
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

  Future<void> setSourceLanguage(
    TextSelectionContext selection,
    String code,
  ) async {
    if (isClosed || state.sourceLanguageCode == code) return;
    final operationGeneration = _beginOperation();
    emit(
      state.copyWith(
        sourceLanguageCode: code,
        status: TranslateSheetStatus.initial,
        result: null,
        failure: null,
      ),
    );
    await _runTranslation(selection, operationGeneration: operationGeneration);
  }

  Future<void> setTargetLanguage(
    TextSelectionContext selection,
    String code,
  ) async {
    if (isClosed || state.targetLanguageCode == code) return;
    final operationGeneration = _beginOperation();
    emit(
      state.copyWith(
        targetLanguageCode: code,
        status: TranslateSheetStatus.initial,
        result: null,
        failure: null,
      ),
    );
    await _preferencesService.update(
      (prefs) => prefs.copyWith(translationTargetLanguageCode: code),
    );
    if (!_isCurrentOperation(operationGeneration)) return;
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
    _ => TranslateSheetStatus.failure,
  };
}

const _absent = Object();
