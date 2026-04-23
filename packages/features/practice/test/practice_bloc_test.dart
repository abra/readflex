import 'package:bloc_test/bloc_test.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/src/practice_bloc.dart';
import 'package:practice/src/practice_item.dart';

import 'helpers/fake_dictionary_repository.dart';
import 'helpers/fake_flashcard_repository.dart';
import 'helpers/fake_fsrs_repository.dart';
import 'helpers/fake_highlight_repository.dart';

final _card1 = Flashcard(
  id: 'f1',
  deckId: 'd1',
  front: 'Question 1',
  back: 'Answer 1',
  creationSource: CreationSource.manual,
  createdAt: DateTime(2026, 1, 1),
);

final _card2 = Flashcard(
  id: 'f2',
  deckId: 'd1',
  front: 'Question 2',
  back: 'Answer 2',
  creationSource: CreationSource.manual,
  createdAt: DateTime(2026, 1, 2),
);

final _highlight1 = Highlight(
  id: 'h1',
  sourceId: 's1',
  sourceType: SourceType.book,
  text: 'Important passage',
  createdAt: DateTime(2026, 1, 1),
);

final _dueCard1 = ReviewItem(
  itemId: 'f1',
  itemType: ReviewableType.flashcard,
  fsrs: const FsrsCardData(),
);

final _dueHighlight1 = ReviewItem(
  itemId: 'h1',
  itemType: ReviewableType.highlight,
  fsrs: const FsrsCardData(),
);

PracticeBloc _buildBloc({
  required FakeFsrsRepository fsrsRepository,
  required FakeFlashcardRepository flashcardRepository,
  required FakeHighlightRepository highlightRepository,
  required FakeDictionaryRepository dictionaryRepository,
}) => PracticeBloc(
  fsrsRepository: fsrsRepository,
  flashcardRepository: flashcardRepository,
  highlightRepository: highlightRepository,
  dictionaryRepository: dictionaryRepository,
);

void main() {
  group('PracticeBloc', () {
    late FakeFsrsRepository fsrsRepo;
    late FakeFlashcardRepository flashcardRepo;
    late FakeHighlightRepository highlightRepo;
    late FakeDictionaryRepository dictionaryRepo;

    setUp(() {
      fsrsRepo = FakeFsrsRepository();
      flashcardRepo = FakeFlashcardRepository();
      highlightRepo = FakeHighlightRepository();
      dictionaryRepo = FakeDictionaryRepository();
    });

    blocTest<PracticeBloc, PracticeState>(
      'emits reviewing with due cards and highlights',
      setUp: () {
        fsrsRepo.dueItems = [_dueCard1, _dueHighlight1];
        flashcardRepo.seed([_card1]);
        highlightRepo.seed([_highlight1]);
      },
      build: () => _buildBloc(
        fsrsRepository: fsrsRepo,
        flashcardRepository: flashcardRepo,
        highlightRepository: highlightRepo,
        dictionaryRepository: dictionaryRepo,
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
        fsrsRepository: fsrsRepo,
        flashcardRepository: flashcardRepo,
        highlightRepository: highlightRepo,
        dictionaryRepository: dictionaryRepo,
      ),
      act: (bloc) => bloc.add(const PracticeLoadRequested()),
      expect: () => [
        const PracticeState(status: PracticeStatus.loading),
        const PracticeState(status: PracticeStatus.empty),
      ],
    );

    blocTest<PracticeBloc, PracticeState>(
      'emits failure when load throws',
      setUp: () => fsrsRepo.shouldThrow = true,
      build: () => _buildBloc(
        fsrsRepository: fsrsRepo,
        flashcardRepository: flashcardRepo,
        highlightRepository: highlightRepo,
        dictionaryRepository: dictionaryRepo,
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
        fsrsRepository: fsrsRepo,
        flashcardRepository: flashcardRepo,
        highlightRepository: highlightRepo,
        dictionaryRepository: dictionaryRepo,
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
      build: () => _buildBloc(
        fsrsRepository: fsrsRepo,
        flashcardRepository: flashcardRepo,
        highlightRepository: highlightRepo,
        dictionaryRepository: dictionaryRepo,
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
        expect(fsrsRepo.reviews, hasLength(1));
        expect(fsrsRepo.reviews.first.rating, Rating.good);
      },
    );

    blocTest<PracticeBloc, PracticeState>(
      'rating last card emits completed',
      build: () => _buildBloc(
        fsrsRepository: fsrsRepo,
        flashcardRepository: flashcardRepo,
        highlightRepository: highlightRepo,
        dictionaryRepository: dictionaryRepo,
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
        fsrsRepository: fsrsRepo,
        flashcardRepository: flashcardRepo,
        highlightRepository: highlightRepo,
        dictionaryRepository: dictionaryRepo,
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
        fsrsRepository: fsrsRepo,
        flashcardRepository: flashcardRepo,
        highlightRepository: highlightRepo,
        dictionaryRepository: dictionaryRepo,
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
      setUp: () => fsrsRepo.shouldThrow = true,
      build: () => _buildBloc(
        fsrsRepository: fsrsRepo,
        flashcardRepository: flashcardRepo,
        highlightRepository: highlightRepo,
        dictionaryRepository: dictionaryRepo,
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

  group('PracticeBloc pagination', () {
    late FakeFsrsRepository fsrsRepository;
    late FakeFlashcardRepository flashcardRepository;
    late FakeHighlightRepository highlightRepository;
    late FakeDictionaryRepository dictionaryRepository;

    setUp(() {
      fsrsRepository = FakeFsrsRepository();
      flashcardRepository = FakeFlashcardRepository();
      highlightRepository = FakeHighlightRepository();
      dictionaryRepository = FakeDictionaryRepository();
    });

    blocTest<PracticeBloc, PracticeState>(
      'passes a limit to getDueItems (guards against OOM on large decks)',
      build: () => _buildBloc(
        fsrsRepository: fsrsRepository,
        flashcardRepository: flashcardRepository,
        highlightRepository: highlightRepository,
        dictionaryRepository: dictionaryRepository,
      ),
      act: (bloc) => bloc.add(const PracticeLoadRequested()),
      verify: (_) {
        expect(fsrsRepository.lastDueLimitPassed, isNotNull);
      },
    );
  });
}
