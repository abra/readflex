import 'package:bloc_test/bloc_test.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flashcard/src/flashcard_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_flashcard_repository.dart';

void main() {
  late FakeFlashcardRepository repository;

  setUp(() {
    repository = FakeFlashcardRepository();
  });

  group('FlashcardCubit', () {
    blocTest<FlashcardCubit, FlashcardState>(
      'initial state has idle status and empty fields',
      build: () => FlashcardCubit(flashcardRepository: repository),
      verify: (cubit) {
        expect(cubit.state.status, FlashcardStatus.idle);
        expect(cubit.state.front, '');
        expect(cubit.state.back, '');
        expect(cubit.state.hint, '');
        expect(cubit.state.canSave, isFalse);
      },
    );

    blocTest<FlashcardCubit, FlashcardState>(
      'setFront emits state with new front',
      build: () => FlashcardCubit(flashcardRepository: repository),
      act: (cubit) => cubit.setFront('What is X?'),
      expect: () => [
        const FlashcardState(front: 'What is X?'),
      ],
    );

    blocTest<FlashcardCubit, FlashcardState>(
      'setBack emits state with new back',
      build: () => FlashcardCubit(flashcardRepository: repository),
      act: (cubit) => cubit.setBack('Answer'),
      expect: () => [
        const FlashcardState(back: 'Answer'),
      ],
    );

    blocTest<FlashcardCubit, FlashcardState>(
      'setHint emits state with new hint',
      build: () => FlashcardCubit(flashcardRepository: repository),
      act: (cubit) => cubit.setHint('Think about...'),
      expect: () => [
        const FlashcardState(hint: 'Think about...'),
      ],
    );

    blocTest<FlashcardCubit, FlashcardState>(
      'canSave is true when front and back are non-empty',
      build: () => FlashcardCubit(flashcardRepository: repository),
      seed: () => const FlashcardState(
        front: 'Q',
        back: 'A',
      ),
      verify: (cubit) {
        expect(cubit.state.canSave, isTrue);
      },
    );

    blocTest<FlashcardCubit, FlashcardState>(
      'save does nothing when canSave is false',
      build: () => FlashcardCubit(flashcardRepository: repository),
      act: (cubit) => cubit.save(
        sourceId: 'book-1',
        sourceType: SourceType.book,
      ),
      expect: () => [],
      verify: (_) {
        expect(repository.flashcards, isEmpty);
      },
    );

    blocTest<FlashcardCubit, FlashcardState>(
      'save emits saving then success',
      build: () => FlashcardCubit(flashcardRepository: repository),
      seed: () => const FlashcardState(front: 'Q', back: 'A'),
      act: (cubit) => cubit.save(
        sourceId: 'book-1',
        sourceType: SourceType.book,
      ),
      expect: () => [
        const FlashcardState(
          front: 'Q',
          back: 'A',
          status: FlashcardStatus.saving,
        ),
        const FlashcardState(
          front: 'Q',
          back: 'A',
          status: FlashcardStatus.success,
        ),
      ],
      verify: (_) {
        expect(repository.flashcards, hasLength(1));
        expect(repository.flashcards.first.front, 'Q');
        expect(repository.flashcards.first.back, 'A');
        expect(repository.flashcards.first.deckId, 'book-1');
      },
    );

    blocTest<FlashcardCubit, FlashcardState>(
      'save passes hint when non-empty',
      build: () => FlashcardCubit(flashcardRepository: repository),
      seed: () => const FlashcardState(
        front: 'Q',
        back: 'A',
        hint: 'Hint',
      ),
      act: (cubit) => cubit.save(
        sourceId: 'book-1',
        sourceType: SourceType.book,
      ),
      verify: (_) {
        expect(repository.flashcards.first.hint, 'Hint');
      },
    );

    blocTest<FlashcardCubit, FlashcardState>(
      'save passes null hint when empty',
      build: () => FlashcardCubit(flashcardRepository: repository),
      seed: () => const FlashcardState(front: 'Q', back: 'A'),
      act: (cubit) => cubit.save(
        sourceId: 'book-1',
        sourceType: SourceType.book,
      ),
      verify: (_) {
        expect(repository.flashcards.first.hint, isNull);
      },
    );

    blocTest<FlashcardCubit, FlashcardState>(
      'save emits saving then failure on error',
      build: () {
        repository.shouldThrow = true;
        return FlashcardCubit(flashcardRepository: repository);
      },
      seed: () => const FlashcardState(front: 'Q', back: 'A'),
      act: (cubit) => cubit.save(
        sourceId: 'book-1',
        sourceType: SourceType.book,
      ),
      expect: () => [
        const FlashcardState(
          front: 'Q',
          back: 'A',
          status: FlashcardStatus.saving,
        ),
        const FlashcardState(
          front: 'Q',
          back: 'A',
          status: FlashcardStatus.failure,
        ),
      ],
    );
  });
}
