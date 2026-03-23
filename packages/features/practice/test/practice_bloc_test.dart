import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice_feature/src/practice_bloc.dart';
import 'package:shared/shared.dart';

import 'helpers/fake_flashcard_repository.dart';
import 'helpers/fake_highlight_repository.dart';

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

final _highlight1 = Highlight(
  id: 'h1',
  sourceId: 's1',
  sourceType: SourceType.book,
  text: 'Important passage',
  createdAt: DateTime(2026, 1, 1),
);

PracticeBloc _buildBloc({
  required FakeFlashcardRepository flashcardRepository,
  required FakeHighlightRepository highlightRepository,
}) => PracticeBloc(
  flashcardRepository: flashcardRepository,
  highlightRepository: highlightRepository,
);

void main() {
  group('PracticeBloc', () {
    late FakeFlashcardRepository flashcardRepo;
    late FakeHighlightRepository highlightRepo;

    setUp(() {
      flashcardRepo = FakeFlashcardRepository();
      highlightRepo = FakeHighlightRepository();
    });

    blocTest<PracticeBloc, PracticeState>(
      'emits reviewing with due cards and highlights',
      setUp: () {
        flashcardRepo.dueCards = [_card1];
        highlightRepo.highlights = [_highlight1];
      },
      build: () => _buildBloc(
        flashcardRepository: flashcardRepo,
        highlightRepository: highlightRepo,
      ),
      act: (bloc) => bloc.add(const PracticeLoadRequested()),
      expect: () => [
        const PracticeState(status: PracticeStatus.loading),
        PracticeState(
          status: PracticeStatus.reviewing,
          items: [
            FlashcardItem(_card1),
            HighlightItem(_highlight1),
          ],
          currentIndex: 0,
        ),
      ],
    );

    blocTest<PracticeBloc, PracticeState>(
      'emits empty when no items',
      build: () => _buildBloc(
        flashcardRepository: flashcardRepo,
        highlightRepository: highlightRepo,
      ),
      act: (bloc) => bloc.add(const PracticeLoadRequested()),
      expect: () => [
        const PracticeState(status: PracticeStatus.loading),
        const PracticeState(status: PracticeStatus.empty),
      ],
    );

    blocTest<PracticeBloc, PracticeState>(
      'emits failure when load throws',
      setUp: () => flashcardRepo.shouldThrow = true,
      build: () => _buildBloc(
        flashcardRepository: flashcardRepo,
        highlightRepository: highlightRepo,
      ),
      act: (bloc) => bloc.add(const PracticeLoadRequested()),
      expect: () => [
        const PracticeState(status: PracticeStatus.loading),
        const PracticeState(status: PracticeStatus.failure),
      ],
    );

    blocTest<PracticeBloc, PracticeState>(
      'reveal sets isRevealed to true',
      build: () => _buildBloc(
        flashcardRepository: flashcardRepo,
        highlightRepository: highlightRepo,
      ),
      seed: () => PracticeState(
        status: PracticeStatus.reviewing,
        items: [FlashcardItem(_card1)],
      ),
      act: (bloc) => bloc.add(const PracticeCardRevealed()),
      expect: () => [
        PracticeState(
          status: PracticeStatus.reviewing,
          items: [FlashcardItem(_card1)],
          isRevealed: true,
        ),
      ],
    );

    blocTest<PracticeBloc, PracticeState>(
      'rating advances to next item',
      setUp: () => flashcardRepo.dueCards = [_card1, _card2],
      build: () => _buildBloc(
        flashcardRepository: flashcardRepo,
        highlightRepository: highlightRepo,
      ),
      seed: () => PracticeState(
        status: PracticeStatus.reviewing,
        items: [FlashcardItem(_card1), FlashcardItem(_card2)],
        currentIndex: 0,
        isRevealed: true,
      ),
      act: (bloc) => bloc.add(const PracticeCardRated(Rating.good)),
      expect: () => [
        PracticeState(
          status: PracticeStatus.reviewing,
          items: [FlashcardItem(_card1), FlashcardItem(_card2)],
          currentIndex: 1,
        ),
      ],
      verify: (_) {
        expect(flashcardRepo.reviews, hasLength(1));
        expect(flashcardRepo.reviews.first.rating, Rating.good);
      },
    );

    blocTest<PracticeBloc, PracticeState>(
      'rating last card emits completed',
      build: () => _buildBloc(
        flashcardRepository: flashcardRepo,
        highlightRepository: highlightRepo,
      ),
      seed: () => PracticeState(
        status: PracticeStatus.reviewing,
        items: [FlashcardItem(_card1)],
        currentIndex: 0,
        isRevealed: true,
      ),
      act: (bloc) => bloc.add(const PracticeCardRated(Rating.easy)),
      expect: () => [
        PracticeState(
          status: PracticeStatus.completed,
          items: [FlashcardItem(_card1)],
          currentIndex: 0,
          isRevealed: true,
        ),
      ],
    );

    blocTest<PracticeBloc, PracticeState>(
      'PracticeItemNext advances past highlight',
      build: () => _buildBloc(
        flashcardRepository: flashcardRepo,
        highlightRepository: highlightRepo,
      ),
      seed: () => PracticeState(
        status: PracticeStatus.reviewing,
        items: [HighlightItem(_highlight1), FlashcardItem(_card1)],
        currentIndex: 0,
      ),
      act: (bloc) => bloc.add(const PracticeItemNext()),
      expect: () => [
        PracticeState(
          status: PracticeStatus.reviewing,
          items: [HighlightItem(_highlight1), FlashcardItem(_card1)],
          currentIndex: 1,
        ),
      ],
    );

    blocTest<PracticeBloc, PracticeState>(
      'PracticeItemNext on last item emits completed',
      build: () => _buildBloc(
        flashcardRepository: flashcardRepo,
        highlightRepository: highlightRepo,
      ),
      seed: () => PracticeState(
        status: PracticeStatus.reviewing,
        items: [HighlightItem(_highlight1)],
        currentIndex: 0,
      ),
      act: (bloc) => bloc.add(const PracticeItemNext()),
      expect: () => [
        PracticeState(
          status: PracticeStatus.completed,
          items: [HighlightItem(_highlight1)],
          currentIndex: 0,
        ),
      ],
    );

    blocTest<PracticeBloc, PracticeState>(
      'rating emits failure when repository throws',
      setUp: () => flashcardRepo.shouldThrow = true,
      build: () => _buildBloc(
        flashcardRepository: flashcardRepo,
        highlightRepository: highlightRepo,
      ),
      seed: () => PracticeState(
        status: PracticeStatus.reviewing,
        items: [FlashcardItem(_card1)],
        currentIndex: 0,
        isRevealed: true,
      ),
      act: (bloc) => bloc.add(const PracticeCardRated(Rating.good)),
      expect: () => [
        PracticeState(
          status: PracticeStatus.failure,
          items: [FlashcardItem(_card1)],
          currentIndex: 0,
          isRevealed: true,
        ),
      ],
    );
  });

  group('PracticeState', () {
    test('currentItem returns item at currentIndex', () {
      final state = PracticeState(
        items: [FlashcardItem(_card1), HighlightItem(_highlight1)],
        currentIndex: 1,
      );
      expect(state.currentItem, HighlightItem(_highlight1));
    });

    test('currentCard returns flashcard for FlashcardItem', () {
      final state = PracticeState(
        items: [FlashcardItem(_card1)],
        currentIndex: 0,
      );
      expect(state.currentCard, _card1);
    });

    test('currentCard returns null for HighlightItem', () {
      final state = PracticeState(
        items: [HighlightItem(_highlight1)],
        currentIndex: 0,
      );
      expect(state.currentCard, isNull);
    });

    test('currentItem returns null when index out of range', () {
      final state = PracticeState(
        items: [FlashcardItem(_card1)],
        currentIndex: 1,
      );
      expect(state.currentItem, isNull);
    });

    test('remaining counts items left', () {
      final state = PracticeState(
        items: [FlashcardItem(_card1), HighlightItem(_highlight1)],
        currentIndex: 1,
      );
      expect(state.remaining, 1);
      expect(state.reviewed, 1);
    });
  });
}
