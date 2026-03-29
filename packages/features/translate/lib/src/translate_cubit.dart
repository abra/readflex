import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:translation_service/translation_service.dart';

enum TranslateStatus { idle, translating, translated, saving, saved, failure }

final class TranslateState extends Equatable {
  const TranslateState({
    this.status = TranslateStatus.idle,
    this.translatedText = '',
    this.source = TranslationSource.platform,
    this.usageExamples = const [],
    this.errorMessage,
  });

  final TranslateStatus status;
  final String translatedText;
  final TranslationSource source;
  final List<String> usageExamples;
  final String? errorMessage;

  TranslateState copyWith({
    TranslateStatus? status,
    String? translatedText,
    TranslationSource? source,
    List<String>? usageExamples,
    String? errorMessage,
  }) => TranslateState(
    status: status ?? this.status,
    translatedText: translatedText ?? this.translatedText,
    source: source ?? this.source,
    usageExamples: usageExamples ?? this.usageExamples,
    errorMessage: errorMessage,
  );

  @override
  List<Object?> get props => [
    status,
    translatedText,
    source,
    usageExamples,
    errorMessage,
  ];
}

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
