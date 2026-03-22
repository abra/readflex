import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice_feature/src/practice_bloc.dart';
import 'package:shared/shared.dart';

import 'helpers/fake_flashcard_repository.dart';

final _card1 = Flashcard(
  id: 'f1',
  deckId: 'd1',
  front: 'Question 1',
  back: 'Answer 1',
  creationSource: CreationSource.manual,
  createdAt: DateTime(2026, 1, 1),
  fsrs: const FsrsCardData(),
);

final _card2 = Flashcard(
  id: 'f2',
  deckId: 'd1',
  front: 'Question 2',
  back: 'Answer 2',
  creationSource: CreationSource.manual,
  createdAt: DateTime(2026, 1, 2),
  fsrs: const FsrsCardData(),
);

void main() {
  group('PracticeBloc', () {
    late FakeFlashcardRepository repository;

    setUp(() {
      repository = FakeFlashcardRepository();
    });

    blocTest<PracticeBloc, PracticeState>(
      'emits reviewing with due cards',
      setUp: () => repository.dueCards = [_card1, _card2],
      build: () => PracticeBloc(flashcardRepository: repository),
      act: (bloc) => bloc.add(const PracticeLoadRequested()),
      expect: () => [
        const PracticeState(status: PracticeStatus.loading),
        PracticeState(
          status: PracticeStatus.reviewing,
          dueCards: [_card1, _card2],
          currentIndex: 0,
        ),
      ],
    );

    blocTest<PracticeBloc, PracticeState>(
      'emits empty when no due cards',
      build: () => PracticeBloc(flashcardRepository: repository),
      act: (bloc) => bloc.add(const PracticeLoadRequested()),
      expect: () => [
        const PracticeState(status: PracticeStatus.loading),
        const PracticeState(status: PracticeStatus.empty),
      ],
    );

    blocTest<PracticeBloc, PracticeState>(
      'emits failure when load throws',
      setUp: () => repository.shouldThrow = true,
      build: () => PracticeBloc(flashcardRepository: repository),
      act: (bloc) => bloc.add(const PracticeLoadRequested()),
      expect: () => [
        const PracticeState(status: PracticeStatus.loading),
        const PracticeState(status: PracticeStatus.failure),
      ],
    );

    blocTest<PracticeBloc, PracticeState>(
      'reveal sets isRevealed to true',
      build: () => PracticeBloc(flashcardRepository: repository),
      seed: () => PracticeState(
        status: PracticeStatus.reviewing,
        dueCards: [_card1],
      ),
      act: (bloc) => bloc.add(const PracticeCardRevealed()),
      expect: () => [
        PracticeState(
          status: PracticeStatus.reviewing,
          dueCards: [_card1],
          isRevealed: true,
        ),
      ],
    );

    blocTest<PracticeBloc, PracticeState>(
      'rating advances to next card',
      setUp: () => repository.dueCards = [_card1, _card2],
      build: () => PracticeBloc(flashcardRepository: repository),
      seed: () => PracticeState(
        status: PracticeStatus.reviewing,
        dueCards: [_card1, _card2],
        currentIndex: 0,
        isRevealed: true,
      ),
      act: (bloc) => bloc.add(const PracticeCardRated(Rating.good)),
      expect: () => [
        PracticeState(
          status: PracticeStatus.reviewing,
          dueCards: [_card1, _card2],
          currentIndex: 1,
        ),
      ],
      verify: (_) {
        expect(repository.reviews, hasLength(1));
        expect(repository.reviews.first.rating, Rating.good);
      },
    );

    blocTest<PracticeBloc, PracticeState>(
      'rating last card emits completed',
      build: () => PracticeBloc(flashcardRepository: repository),
      seed: () => PracticeState(
        status: PracticeStatus.reviewing,
        dueCards: [_card1],
        currentIndex: 0,
        isRevealed: true,
      ),
      act: (bloc) => bloc.add(const PracticeCardRated(Rating.easy)),
      expect: () => [
        PracticeState(
          status: PracticeStatus.completed,
          dueCards: [_card1],
          currentIndex: 0,
          isRevealed: true,
        ),
      ],
    );

    blocTest<PracticeBloc, PracticeState>(
      'rating emits failure when repository throws',
      setUp: () => repository.shouldThrow = true,
      build: () => PracticeBloc(flashcardRepository: repository),
      seed: () => PracticeState(
        status: PracticeStatus.reviewing,
        dueCards: [_card1],
        currentIndex: 0,
        isRevealed: true,
      ),
      act: (bloc) => bloc.add(const PracticeCardRated(Rating.good)),
      expect: () => [
        PracticeState(
          status: PracticeStatus.failure,
          dueCards: [_card1],
          currentIndex: 0,
          isRevealed: true,
        ),
      ],
    );
  });

  group('PracticeState', () {
    test('currentCard returns card at currentIndex', () {
      final state = PracticeState(
        dueCards: [_card1, _card2],
        currentIndex: 1,
      );
      expect(state.currentCard, _card2);
    });

    test('currentCard returns null when index out of range', () {
      final state = PracticeState(
        dueCards: [_card1],
        currentIndex: 1,
      );
      expect(state.currentCard, isNull);
    });

    test('remaining counts cards left', () {
      final state = PracticeState(
        dueCards: [_card1, _card2],
        currentIndex: 1,
      );
      expect(state.remaining, 1);
      expect(state.reviewed, 1);
    });
  });
}
