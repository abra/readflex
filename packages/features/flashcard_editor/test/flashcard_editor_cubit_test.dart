import 'package:bloc_test/bloc_test.dart';
import 'package:flashcard_editor/src/flashcard_editor_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

import 'helpers/fake_flashcard_repository.dart';

void main() {
  late FakeFlashcardRepository repository;

  setUp(() {
    repository = FakeFlashcardRepository();
  });

  group('FlashcardEditorCubit', () {
    blocTest<FlashcardEditorCubit, FlashcardEditorState>(
      'initial state has idle status and empty fields',
      build: () => FlashcardEditorCubit(flashcardRepository: repository),
      verify: (cubit) {
        expect(cubit.state.status, FlashcardEditorStatus.idle);
        expect(cubit.state.front, '');
        expect(cubit.state.back, '');
        expect(cubit.state.hint, '');
        expect(cubit.state.canSave, isFalse);
      },
    );

    blocTest<FlashcardEditorCubit, FlashcardEditorState>(
      'setFront emits state with new front',
      build: () => FlashcardEditorCubit(flashcardRepository: repository),
      act: (cubit) => cubit.setFront('What is X?'),
      expect: () => [
        const FlashcardEditorState(front: 'What is X?'),
      ],
    );

    blocTest<FlashcardEditorCubit, FlashcardEditorState>(
      'setBack emits state with new back',
      build: () => FlashcardEditorCubit(flashcardRepository: repository),
      act: (cubit) => cubit.setBack('Answer'),
      expect: () => [
        const FlashcardEditorState(back: 'Answer'),
      ],
    );

    blocTest<FlashcardEditorCubit, FlashcardEditorState>(
      'setHint emits state with new hint',
      build: () => FlashcardEditorCubit(flashcardRepository: repository),
      act: (cubit) => cubit.setHint('Think about...'),
      expect: () => [
        const FlashcardEditorState(hint: 'Think about...'),
      ],
    );

    blocTest<FlashcardEditorCubit, FlashcardEditorState>(
      'canSave is true when front and back are non-empty',
      build: () => FlashcardEditorCubit(flashcardRepository: repository),
      seed: () => const FlashcardEditorState(
        front: 'Q',
        back: 'A',
      ),
      verify: (cubit) {
        expect(cubit.state.canSave, isTrue);
      },
    );

    blocTest<FlashcardEditorCubit, FlashcardEditorState>(
      'save does nothing when canSave is false',
      build: () => FlashcardEditorCubit(flashcardRepository: repository),
      act: (cubit) => cubit.save(
        sourceId: 'book-1',
        sourceType: SourceType.book,
      ),
      expect: () => [],
      verify: (_) {
        expect(repository.flashcards, isEmpty);
      },
    );

    blocTest<FlashcardEditorCubit, FlashcardEditorState>(
      'save emits saving then success',
      build: () => FlashcardEditorCubit(flashcardRepository: repository),
      seed: () => const FlashcardEditorState(front: 'Q', back: 'A'),
      act: (cubit) => cubit.save(
        sourceId: 'book-1',
        sourceType: SourceType.book,
      ),
      expect: () => [
        const FlashcardEditorState(
          front: 'Q',
          back: 'A',
          status: FlashcardEditorStatus.saving,
        ),
        const FlashcardEditorState(
          front: 'Q',
          back: 'A',
          status: FlashcardEditorStatus.success,
        ),
      ],
      verify: (_) {
        expect(repository.flashcards, hasLength(1));
        expect(repository.flashcards.first.front, 'Q');
        expect(repository.flashcards.first.back, 'A');
        expect(repository.flashcards.first.deckId, 'book-1');
      },
    );

    blocTest<FlashcardEditorCubit, FlashcardEditorState>(
      'save passes hint when non-empty',
      build: () => FlashcardEditorCubit(flashcardRepository: repository),
      seed: () => const FlashcardEditorState(
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

    blocTest<FlashcardEditorCubit, FlashcardEditorState>(
      'save passes null hint when empty',
      build: () => FlashcardEditorCubit(flashcardRepository: repository),
      seed: () => const FlashcardEditorState(front: 'Q', back: 'A'),
      act: (cubit) => cubit.save(
        sourceId: 'book-1',
        sourceType: SourceType.book,
      ),
      verify: (_) {
        expect(repository.flashcards.first.hint, isNull);
      },
    );

    blocTest<FlashcardEditorCubit, FlashcardEditorState>(
      'save emits saving then failure on error',
      build: () {
        repository.shouldThrow = true;
        return FlashcardEditorCubit(flashcardRepository: repository);
      },
      seed: () => const FlashcardEditorState(front: 'Q', back: 'A'),
      act: (cubit) => cubit.save(
        sourceId: 'book-1',
        sourceType: SourceType.book,
      ),
      expect: () => [
        const FlashcardEditorState(
          front: 'Q',
          back: 'A',
          status: FlashcardEditorStatus.saving,
        ),
        const FlashcardEditorState(
          front: 'Q',
          back: 'A',
          status: FlashcardEditorStatus.failure,
        ),
      ],
    );
  });
}
