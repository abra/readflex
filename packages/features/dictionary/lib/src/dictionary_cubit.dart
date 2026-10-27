import 'dart:async';

import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:dictionary_service/dictionary_service.dart';
import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';

import 'word_save_status.dart';

enum DictionarySheetStatus {
  initial,
  loading,
  success,
  notFound,
  unsupportedLanguage,
  failure,
}

class DictionarySheetState extends Equatable {
  const DictionarySheetState({
    this.status = DictionarySheetStatus.initial,
    this.result,
    this.failure,
    this.saveStatus = WordSaveStatus.notSaved,
    this.savedEntryId,
  });

  final DictionarySheetStatus status;
  final DictionaryLookupResult? result;
  final DictionaryLookupException? failure;

  /// Whether the selected word is in the reader's saved words.
  final WordSaveStatus saveStatus;
  final String? savedEntryId;

  DictionarySheetState copyWith({
    DictionarySheetStatus? status,
    Object? result = _absent,
    Object? failure = _absent,
    WordSaveStatus? saveStatus,
    Object? savedEntryId = _absent,
  }) {
    return DictionarySheetState(
      status: status ?? this.status,
      result: result == _absent
          ? this.result
          : result as DictionaryLookupResult?,
      failure: failure == _absent
          ? this.failure
          : failure as DictionaryLookupException?,
      saveStatus: saveStatus ?? this.saveStatus,
      savedEntryId: savedEntryId == _absent
          ? this.savedEntryId
          : savedEntryId as String?,
    );
  }

  @override
  List<Object?> get props => [
    status,
    result,
    failure,
    saveStatus,
    savedEntryId,
  ];
}

class DictionaryCubit extends Cubit<DictionarySheetState> {
  DictionaryCubit({
    required DictionaryLookupService dictionaryService,
    DictionaryRepository? dictionaryRepository,
  }) : _dictionaryService = dictionaryService,
       _dictionaryRepository = dictionaryRepository,
       super(const DictionarySheetState());

  final DictionaryLookupService _dictionaryService;
  final DictionaryRepository? _dictionaryRepository;
  bool _savedLookupDone = false;
  int _lookupGeneration = 0;
  Completer<void>? _abort;

  @override
  Future<void> close() {
    ++_lookupGeneration;
    _abort?.complete();
    _abort = null;
    return super.close();
  }

  Future<void> lookup(TextSelectionContext selection) async {
    if (isClosed || state.status == DictionarySheetStatus.loading) return;
    unawaited(_lookupSavedWord(selection));
    final lookupGeneration = ++_lookupGeneration;
    _abort?.complete();
    _abort = Completer<void>();
    emit(
      state.copyWith(
        status: DictionarySheetStatus.loading,
        result: null,
        failure: null,
      ),
    );
    try {
      final result = await _dictionaryService.lookup(
        DictionaryLookupRequest(
          term: selection.effectiveSelectedText,
          sourceLanguage: selection.sourceLanguageHint,
          contextText:
              selection.effectiveMarkedContextText ?? selection.contextText,
        ),
        abortTrigger: _abort!.future,
      );
      if (!_isCurrentLookup(lookupGeneration)) return;
      emit(
        state.copyWith(
          status: _statusFor(result),
          result: result,
          failure: null,
        ),
      );
    } on DictionaryLookupException catch (error) {
      if (!_isCurrentLookup(lookupGeneration)) return;
      emit(
        state.copyWith(
          status: DictionarySheetStatus.failure,
          result: null,
          failure: error,
        ),
      );
    } catch (error, stackTrace) {
      if (!_isCurrentLookup(lookupGeneration)) return;
      addError(error, stackTrace);
      emit(
        state.copyWith(
          status: DictionarySheetStatus.failure,
          result: null,
          failure: const DictionaryLookupException(
            DictionaryLookupFailureReason.invalidResponse,
            'Unexpected dictionary lookup failure',
          ),
        ),
      );
    }
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

  /// Saves the defined word to Vocabulary, or removes it when already saved.
  /// The first definition stands in for a translation; an "in this context"
  /// entry takes that place and the word's own definition becomes the base
  /// meaning.
  Future<void> toggleSaved(TextSelectionContext selection) async {
    final repository = _dictionaryRepository;
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
      final entries = state.result?.entries ?? const [];
      if (state.status != DictionarySheetStatus.success || entries.isEmpty) {
        emit(state.copyWith(saveStatus: WordSaveStatus.notSaved));
        return;
      }
      final word = entries.first;
      final inContext = entries.length > 1 ? entries[1] : null;
      final wordMeaning = word.definitions.firstOrNull?.text;
      final contextMeaning = inContext?.definitions.firstOrNull?.text;
      final entry = await repository.addEntry(
        word: selection.effectiveSelectedText.trim(),
        translation: contextMeaning ?? wordMeaning ?? word.lemma,
        lemma: word.lemma,
        baseTranslation: contextMeaning == null ? null : wordMeaning,
        pronunciation: word.pronunciation ?? word.reading,
        partOfSpeech: word.partOfSpeech,
        context: selection.contextText,
        usageExamples: [
          for (final definition in word.definitions) ...definition.examples,
        ].take(3).toList(),
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

  bool _isCurrentLookup(int generation) {
    return !isClosed && generation == _lookupGeneration;
  }
}

// A found term without entries has nothing to show; it reads as not found.
DictionarySheetStatus _statusFor(DictionaryLookupResult result) {
  return switch (result.status) {
    DictionaryLookupStatus.found when result.entries.isEmpty =>
      DictionarySheetStatus.notFound,
    DictionaryLookupStatus.found => DictionarySheetStatus.success,
    DictionaryLookupStatus.notFound => DictionarySheetStatus.notFound,
    DictionaryLookupStatus.unsupportedLanguage =>
      DictionarySheetStatus.unsupportedLanguage,
  };
}

const _absent = Object();
