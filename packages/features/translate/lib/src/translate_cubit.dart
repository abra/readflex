import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:translation_service/translation_service.dart';

part 'translate_state.dart';

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
  }) async {
    emit(state.copyWith(status: TranslateStatus.translating));

    try {
      final result = await _translationService.translate(
        text,
        fromLang: fromLang,
        toLang: toLang,
      );
      emit(
        state.copyWith(
          status: TranslateStatus.translated,
          translatedText: result.translatedText,
          source: result.source,
          usageExamples: result.usageExamples,
        ),
      );
    } catch (e, st) {
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
    String? sourceId,
    SourceType? sourceType,
  }) async {
    if (state.translatedText.isEmpty) return;

    emit(state.copyWith(status: TranslateStatus.saving));

    try {
      final entry = await _dictionaryRepository.addEntry(
        word: word,
        translation: state.translatedText,
        sourceId: sourceId,
        sourceType: sourceType,
        usageExamples: state.usageExamples,
      );
      try {
        await _fsrsRepository.createReviewItem(
          itemId: entry.id,
          itemType: ReviewableType.dictionary,
          sourceId: sourceId,
        );
      } catch (e, st) {
        // Non-fatal: entry is saved; missing FSRS row just means it won't
        // appear in review queue until next manual registration.
        addError(e, st);
      }
      emit(state.copyWith(status: TranslateStatus.saved));
    } catch (e, st) {
      addError(e, st);
      emit(
        state.copyWith(
          status: TranslateStatus.failure,
          errorMessage: 'Failed to save to dictionary',
        ),
      );
    }
  }
}
