import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';
import 'package:translate/src/translate_cubit.dart';
import 'package:translation_service/translation_service.dart';

import 'helpers/fake_dictionary_repository.dart';
import 'helpers/fake_translation_service.dart';

void main() {
  late FakeTranslationService translationService;
  late FakeDictionaryRepository dictionaryRepository;

  setUp(() {
    translationService = FakeTranslationService();
    dictionaryRepository = FakeDictionaryRepository();
  });

  group('TranslateCubit', () {
    blocTest<TranslateCubit, TranslateState>(
      'initial state has idle status',
      build: () => TranslateCubit(
        translationService: translationService,
        dictionaryRepository: dictionaryRepository,
      ),
      verify: (cubit) {
        expect(cubit.state.status, TranslateStatus.idle);
        expect(cubit.state.translatedText, '');
      },
    );

    blocTest<TranslateCubit, TranslateState>(
      'translate emits translating then translated',
      build: () => TranslateCubit(
        translationService: translationService,
        dictionaryRepository: dictionaryRepository,
      ),
      act: (cubit) => cubit.translate(
        text: 'hello',
        fromLang: 'en',
        toLang: 'ru',
      ),
      expect: () => [
        const TranslateState(status: TranslateStatus.translating),
        const TranslateState(
          status: TranslateStatus.translated,
          translatedText: '[ru] hello',
          source: TranslationSource.platform,
        ),
      ],
    );

    blocTest<TranslateCubit, TranslateState>(
      'translate preserves usage examples from remote',
      build: () {
        translationService.resultOverride = const TranslationResult(
          originalText: 'hello',
          translatedText: 'привет',
          source: TranslationSource.remote,
          usageExamples: ['Hello, world!', 'Say hello'],
        );
        return TranslateCubit(
          translationService: translationService,
          dictionaryRepository: dictionaryRepository,
        );
      },
      act: (cubit) => cubit.translate(
        text: 'hello',
        fromLang: 'en',
        toLang: 'ru',
      ),
      expect: () => [
        const TranslateState(status: TranslateStatus.translating),
        const TranslateState(
          status: TranslateStatus.translated,
          translatedText: 'привет',
          source: TranslationSource.remote,
          usageExamples: ['Hello, world!', 'Say hello'],
        ),
      ],
    );

    blocTest<TranslateCubit, TranslateState>(
      'translate emits failure on error',
      build: () {
        translationService.shouldThrow = true;
        return TranslateCubit(
          translationService: translationService,
          dictionaryRepository: dictionaryRepository,
        );
      },
      act: (cubit) => cubit.translate(
        text: 'hello',
        fromLang: 'en',
        toLang: 'ru',
      ),
      expect: () => [
        const TranslateState(status: TranslateStatus.translating),
        const TranslateState(
          status: TranslateStatus.failure,
          errorMessage: 'Translation failed',
        ),
      ],
    );

    blocTest<TranslateCubit, TranslateState>(
      'saveToDictionary does nothing when translatedText is empty',
      build: () => TranslateCubit(
        translationService: translationService,
        dictionaryRepository: dictionaryRepository,
      ),
      act: (cubit) => cubit.saveToDictionary(word: 'hello'),
      expect: () => [],
      verify: (_) {
        expect(dictionaryRepository.entries, isEmpty);
      },
    );

    blocTest<TranslateCubit, TranslateState>(
      'saveToDictionary emits saving then saved',
      build: () => TranslateCubit(
        translationService: translationService,
        dictionaryRepository: dictionaryRepository,
      ),
      seed: () => const TranslateState(
        status: TranslateStatus.translated,
        translatedText: 'привет',
      ),
      act: (cubit) => cubit.saveToDictionary(
        word: 'hello',
        sourceId: 'book-1',
        sourceType: SourceType.book,
      ),
      expect: () => [
        const TranslateState(
          status: TranslateStatus.saving,
          translatedText: 'привет',
        ),
        const TranslateState(
          status: TranslateStatus.saved,
          translatedText: 'привет',
        ),
      ],
      verify: (_) {
        expect(dictionaryRepository.entries, hasLength(1));
        expect(dictionaryRepository.entries.first.word, 'hello');
        expect(dictionaryRepository.entries.first.translation, 'привет');
        expect(dictionaryRepository.entries.first.sourceId, 'book-1');
      },
    );

    blocTest<TranslateCubit, TranslateState>(
      'saveToDictionary emits failure on error',
      build: () {
        dictionaryRepository.shouldThrow = true;
        return TranslateCubit(
          translationService: translationService,
          dictionaryRepository: dictionaryRepository,
        );
      },
      seed: () => const TranslateState(
        status: TranslateStatus.translated,
        translatedText: 'привет',
      ),
      act: (cubit) => cubit.saveToDictionary(word: 'hello'),
      expect: () => [
        const TranslateState(
          status: TranslateStatus.saving,
          translatedText: 'привет',
        ),
        const TranslateState(
          status: TranslateStatus.failure,
          translatedText: 'привет',
          errorMessage: 'Failed to save to dictionary',
        ),
      ],
    );
  });
}
