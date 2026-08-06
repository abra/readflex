import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:shared/shared.dart';

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

  Future<void> translate(
    TextSelectionContext selection, {
    bool allowOfflineModelDownload = false,
  }) async {
    if (state.isBusy) return;
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
      );
      emit(
        state.copyWith(status: TranslateSheetStatus.success, result: result),
      );
    } on ContextualTranslationException catch (error) {
      emit(
        state.copyWith(
          status: _statusFor(error.reason),
          failure: error,
          result: null,
        ),
      );
    }
  }

  Future<void> setSourceLanguage(
    TextSelectionContext selection,
    String code,
  ) async {
    if (state.sourceLanguageCode == code) return;
    emit(
      state.copyWith(
        sourceLanguageCode: code,
        status: TranslateSheetStatus.initial,
        result: null,
        failure: null,
      ),
    );
    await translate(selection);
  }

  Future<void> setTargetLanguage(
    TextSelectionContext selection,
    String code,
  ) async {
    if (state.targetLanguageCode == code) return;
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
    await translate(selection);
  }

  ContextualTranslationRequest _requestFor(TextSelectionContext selection) {
    final contextText = selection.contextText?.trim();
    final currentText = contextText == null || contextText.isEmpty
        ? selection.effectiveSelectedText
        : contextText;
    return ContextualTranslationRequest(
      sourceLanguage: state.sourceLanguageCode,
      sourceLanguageHint: selection.sourceLanguageHint,
      targetLanguage: state.targetLanguageCode,
      selection: TranslationSelection(
        text: selection.selectedText,
        normalizedText: selection.normalizedSelectedText,
        kind: selection.selectionKind,
      ),
      context: TranslationTextContext(
        level: 'sentence',
        current: TranslationContextPassage(
          text: currentText,
          markedText: selection.markedContextText,
          normalizedMarkedText: selection.normalizedMarkedContextText,
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
