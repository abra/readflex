import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:translate/src/translate_cubit.dart';
import 'package:translation_service/translation_service.dart';

import 'helpers/fake_dictionary_repository.dart';
import 'helpers/fake_fsrs_repository.dart';
import 'helpers/fake_translation_service.dart';

void main() {
  late FakeTranslationService translationService;
  late FakeDictionaryRepository dictionaryRepository;
  late FakeFsrsRepository fsrsRepository;

  setUp(() {
    translationService = FakeTranslationService();
    dictionaryRepository = FakeDictionaryRepository();
    fsrsRepository = FakeFsrsRepository();
  });

  group('TranslateCubit', () {
    blocTest<TranslateCubit, TranslateState>(
      'initial state has idle status',
      build: () => TranslateCubit(
        translationService: translationService,
        dictionaryRepository: dictionaryRepository,
        fsrsRepository: fsrsRepository,
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
        fsrsRepository: fsrsRepository,
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
          fsrsRepository: fsrsRepository,
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
          fsrsRepository: fsrsRepository,
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
        fsrsRepository: fsrsRepository,
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
        fsrsRepository: fsrsRepository,
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
      'saveToDictionary registers a review item via FSRS',
      build: () => TranslateCubit(
        translationService: translationService,
        dictionaryRepository: dictionaryRepository,
        fsrsRepository: fsrsRepository,
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
      verify: (_) {
        expect(fsrsRepository.created, hasLength(1));
        final registered = fsrsRepository.created.first;
        expect(registered.itemId, dictionaryRepository.entries.first.id);
        expect(registered.itemType, ReviewableType.dictionary);
        expect(registered.sourceId, 'book-1');
      },
    );

    blocTest<TranslateCubit, TranslateState>(
      'saveToDictionary still reports saved if FSRS registration fails',
      build: () {
        fsrsRepository.shouldThrow = true;
        return TranslateCubit(
          translationService: translationService,
          dictionaryRepository: dictionaryRepository,
          fsrsRepository: fsrsRepository,
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
          status: TranslateStatus.saved,
          translatedText: 'привет',
        ),
      ],
      errors: () => [isA<StorageException>()],
      verify: (_) {
        expect(dictionaryRepository.entries, hasLength(1));
      },
    );

    blocTest<TranslateCubit, TranslateState>(
      'saveToDictionary emits failure on error',
      build: () {
        dictionaryRepository.shouldThrow = true;
        return TranslateCubit(
          translationService: translationService,
          dictionaryRepository: dictionaryRepository,
          fsrsRepository: fsrsRepository,
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

    // Race-protection: the user can dismiss the bottom sheet while the
    // network call is still in flight. Without an `isClosed` guard, the
    // post-await `emit` would throw StateError (Cubit is closed) and
    // crash the bloc framework with "Bad state: Cannot emit new states
    // after calling close".
    test(
      'translate: post-await emit is skipped when cubit closes mid-call',
      () async {
        translationService.awaitGate = Completer<void>();
        final cubit = TranslateCubit(
          translationService: translationService,
          dictionaryRepository: dictionaryRepository,
          fsrsRepository: fsrsRepository,
        );

        // Kick off translate without awaiting — fake service is now
        // blocked on the gate.
        unawaited(
          cubit.translate(text: 'hello', fromLang: 'en', toLang: 'ru'),
        );
        // Pump microtasks so the synchronous "emit translating" lands.
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.status, TranslateStatus.translating);

        // Tear the cubit down while translate awaits. Then release the
        // gate so the await resolves AFTER close.
        await cubit.close();
        translationService.awaitGate!.complete();
        await Future<void>.delayed(Duration.zero);

        // Reaching this line without StateError is the assertion: the
        // guard intercepted the post-await emit. State is the last one
        // we observed — close() doesn't roll it back.
        expect(cubit.isClosed, isTrue);
        expect(cubit.state.status, TranslateStatus.translating);
      },
    );

    test(
      'saveToDictionary: post-await emit is skipped when cubit closes mid-call',
      () async {
        final cubit = TranslateCubit(
          translationService: translationService,
          dictionaryRepository: dictionaryRepository,
          fsrsRepository: fsrsRepository,
        );
        // Drive a successful translate first so saveToDictionary has
        // non-empty translatedText to work with.
        await cubit.translate(
          text: 'hello',
          fromLang: 'en',
          toLang: 'ru',
        );
        expect(cubit.state.translatedText, isNotEmpty);

        // Now gate the dictionary write, fire saveToDictionary, close
        // the cubit while it awaits, release the gate.
        dictionaryRepository.awaitGate = Completer<void>();
        unawaited(cubit.saveToDictionary(word: 'hello'));
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.status, TranslateStatus.saving);

        await cubit.close();
        dictionaryRepository.awaitGate!.complete();
        await Future<void>.delayed(Duration.zero);

        expect(cubit.isClosed, isTrue);
        expect(cubit.state.status, TranslateStatus.saving);
      },
    );
  });
}
