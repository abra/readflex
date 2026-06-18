import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:translation_service/translation_service.dart';

part 'translate_state.dart';

/// Drives the translate bottom sheet.
///
/// Triggers a translation through [TranslationService] and, on demand,
/// persists the result as a [DictionaryEntry] plus a matching FSRS review row
/// so the word enters the practice queue. The production translation service
/// owns the actual source choice: bundled SQLite, direct online enrichment, or
/// a future on-device adapter.
///
/// FSRS registration failure is treated as non-fatal — the entry is
/// still saved and the error is surfaced through [addError].
class TranslateCubit extends Cubit<TranslateState> {
  TranslateCubit({
    required TranslationService translationService,
    required DictionaryRepository dictionaryRepository,
    required FsrsRepository fsrsRepository,
  }) : _translationService = translationService,
       _dictionaryRepository = dictionaryRepository,
       _fsrsRepository = fsrsRepository,
       super(const TranslateState());

  final TranslationService _translationService;
  final DictionaryRepository _dictionaryRepository;
  final FsrsRepository _fsrsRepository;

  Future<void> translate({
    required String text,
    required String fromLang,
    required String toLang,
    String? contextText,
    String? markedContextText,
  }) async {
    final normalizedContextText = contextText?.trim();
    final normalizedMarkedContextText = markedContextText?.trim();
    final translationContextText =
        normalizedMarkedContextText == null ||
            normalizedMarkedContextText.isEmpty
        ? normalizedContextText
        : normalizedMarkedContextText;
    final storedMarkedContextText =
        normalizedMarkedContextText == null ||
            normalizedMarkedContextText.isEmpty
        ? normalizedContextText
        : normalizedMarkedContextText;
    emit(
      state.copyWith(
        status: TranslateStatus.translating,
        selectionContextText:
            normalizedContextText == null || normalizedContextText.isEmpty
            ? null
            : normalizedContextText,
        selectionMarkedContextText:
            storedMarkedContextText == null || storedMarkedContextText.isEmpty
            ? null
            : storedMarkedContextText,
      ),
    );

    try {
      final result = await _translationService.translate(
        text,
        fromLang: fromLang,
        toLang: toLang,
        contextText: translationContextText,
      );
      // Sheet may be dismissed while the network call is in flight; the
      // cubit is then closed and emit would throw StateError. Bail out
      // silently — the user already left.
      if (isClosed) return;
      emit(
        state.copyWith(
          status: TranslateStatus.translated,
          translatedText: result.translatedText,
          source: result.source,
          answerType: result.answerType,
          confidence: result.confidence,
          sense: result.sense,
          expression: result.expression,
          context: result.context,
          usageExamples: result.usageExamples,
          naturalEquivalents: result.naturalEquivalents,
          literalTranslation: result.literalTranslation,
          expressionTranslation: result.expressionTranslation,
          suggestedFullPhrase: result.suggestedFullPhrase,
          notes: result.notes,
          savingEntryKey: null,
          savedEntryIds: const {},
        ),
      );
    } catch (e, st) {
      if (isClosed) return;
      addError(e, st);
      emit(
        state.copyWith(
          status: TranslateStatus.failure,
          errorMessage: 'Translation failed',
        ),
      );
    }
  }

  Future<void> saveToDictionary({
    required String word,
    String? entryKey,
    String? translation,
    String? pronunciation,
    String? partOfSpeech,
    String? context,
    List<String>? usageExamples,
    String? sourceId,
    SourceType? sourceType,
    String? anchorText,
    String? anchorContext,
    String? anchorCfiRange,
    DictionaryAnchorKind? anchorKind,
  }) async {
    final normalizedWord = word.trim();
    final resolvedTranslation = (translation ?? state.translatedText).trim();
    final normalizedEntryKey = _nonEmpty(entryKey);
    if (normalizedWord.isEmpty || resolvedTranslation.isEmpty) return;
    if (normalizedEntryKey != null &&
        state.savedEntryIds.containsKey(normalizedEntryKey)) {
      return;
    }

    emit(
      state.copyWith(
        status: TranslateStatus.saving,
        savingEntryKey: normalizedEntryKey,
      ),
    );

    try {
      final entry = await _dictionaryRepository.addEntry(
        word: normalizedWord,
        translation: resolvedTranslation,
        sourceId: sourceId,
        sourceType: sourceType,
        pronunciation:
            pronunciation ??
            state.sense?.transcription ??
            state.sense?.lemmaTranscription,
        partOfSpeech:
            partOfSpeech ??
            state.sense?.partOfSpeech ??
            state.expression?.partOfSpeech,
        context: context ?? state.dictionaryContextText,
        usageExamples: usageExamples ?? state.usageExamples,
        anchorText: anchorText,
        anchorContext: anchorContext ?? context ?? state.dictionaryContextText,
        anchorCfiRange: anchorCfiRange,
        anchorKind: anchorKind,
      );
      // Same isClosed-after-await guard as in `translate`: the user can
      // dismiss the sheet between addEntry and the FSRS register, which
      // closes the cubit. Don't continue past that point.
      if (isClosed) return;
      try {
        await _fsrsRepository.createReviewItem(
          itemId: entry.id,
          itemType: ReviewableType.dictionary,
          sourceId: sourceId,
        );
      } catch (e, st) {
        // Non-fatal: entry is saved; missing FSRS row just means it won't
        // appear in review queue until next manual registration.
        if (!isClosed) addError(e, st);
      }
      if (isClosed) return;
      final savedEntryIds = normalizedEntryKey == null
          ? state.savedEntryIds
          : {
              ...state.savedEntryIds,
              normalizedEntryKey: entry.id,
            };
      emit(
        state.copyWith(
          status: TranslateStatus.saved,
          savingEntryKey: null,
          savedEntryIds: savedEntryIds,
        ),
      );
    } catch (e, st) {
      if (isClosed) return;
      addError(e, st);
      emit(
        state.copyWith(
          status: TranslateStatus.failure,
          savingEntryKey: null,
          errorMessage: 'Failed to save to dictionary',
        ),
      );
    }
  }

  Future<void> undoDictionarySave(String entryKey) async {
    final normalizedEntryKey = _nonEmpty(entryKey);
    if (normalizedEntryKey == null) return;

    final entryId = state.savedEntryIds[normalizedEntryKey];
    if (entryId == null) return;

    emit(
      state.copyWith(
        status: TranslateStatus.saving,
        savingEntryKey: normalizedEntryKey,
      ),
    );

    try {
      await _dictionaryRepository.deleteEntry(entryId);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: TranslateStatus.translated,
          savingEntryKey: null,
          savedEntryIds: {
            for (final entry in state.savedEntryIds.entries)
              if (entry.key != normalizedEntryKey) entry.key: entry.value,
          },
        ),
      );
    } catch (e, st) {
      if (isClosed) return;
      addError(e, st);
      emit(
        state.copyWith(
          status: TranslateStatus.failure,
          savingEntryKey: null,
          errorMessage: 'Failed to undo dictionary save',
        ),
      );
    }
  }

  static String? _nonEmpty(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
