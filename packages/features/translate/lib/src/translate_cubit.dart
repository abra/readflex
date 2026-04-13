import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:translation_service/translation_service.dart';

part 'translate_state.dart';

class TranslateCubit extends Cubit<TranslateState> {
  TranslateCubit({
    required TranslationService translationService,
    required DictionaryRepository dictionaryRepository,
  }) : _translationService = translationService,
       _dictionaryRepository = dictionaryRepository,
       super(const TranslateState());

  final TranslationService _translationService;
  final DictionaryRepository _dictionaryRepository;

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
    } catch (e) {
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
      await _dictionaryRepository.addEntry(
        word: word,
        translation: state.translatedText,
        sourceId: sourceId,
        sourceType: sourceType,
        usageExamples: state.usageExamples,
      );
      emit(state.copyWith(status: TranslateStatus.saved));
    } catch (e) {
      emit(
        state.copyWith(
          status: TranslateStatus.failure,
          errorMessage: 'Failed to save to dictionary',
        ),
      );
    }
  }
}
