import 'package:bloc_test/bloc_test.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/src/mini_review_cubit.dart';
import 'package:practice/src/practice_bloc.dart';

import 'helpers/fake_dictionary_repository.dart';
import 'helpers/fake_flashcard_repository.dart';
import 'helpers/fake_fsrs_repository.dart';
import 'helpers/fake_highlight_repository.dart';

final _flashcard = Flashcard(
  id: 'f1',
  deckId: 'book-1',
  front: 'Front',
  back: 'Back',
  createdAt: DateTime(2026, 1, 1),
);

final _highlight = Highlight(
  id: 'h1',
  sourceId: 'book-1',
  sourceType: SourceType.book,
  text: 'Important text',
  createdAt: DateTime(2026, 1, 2),
);

final _entry = DictionaryEntry(
  id: 'd1',
  word: 'hello',
  translation: 'привет',
  sourceType: SourceType.book,
  addedAt: DateTime(2026, 1, 3),
);

void main() {
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

  MiniReviewCubit buildCubit() => MiniReviewCubit(
    fsrsRepository: fsrsRepository,
    flashcardRepository: flashcardRepository,
    highlightRepository: highlightRepository,
    dictionaryRepository: dictionaryRepository,
  );

  group('MiniReviewCubit.load()', () {
    blocTest<MiniReviewCubit, MiniReviewState>(
      'emits empty when no due items',
      build: buildCubit,
      act: (cubit) => cubit.load('book-1'),
      expect: () => [
        const MiniReviewState(status: MiniReviewStatus.loading),
        const MiniReviewState(status: MiniReviewStatus.empty, items: []),
      ],
    );

    blocTest<MiniReviewCubit, MiniReviewState>(
      'emits reviewing with flashcard items',
      setUp: () {
        fsrsRepository.dueItemsBySource['book-1'] = [
          const ReviewItem(
            itemId: 'f1',
            itemType: ReviewableType.flashcard,
            fsrs: FsrsCardData(),
          ),
        ];
        flashcardRepository.seed([_flashcard]);
      },
      build: buildCubit,
      act: (cubit) => cubit.load('book-1'),
      expect: () => [
        const MiniReviewState(status: MiniReviewStatus.loading),
        isA<MiniReviewState>()
            .having((s) => s.status, 'status', MiniReviewStatus.reviewing)
            .having((s) => s.items.length, 'items.length', 1)
            .having((s) => s.currentIndex, 'currentIndex', 0)
            .having((s) => s.isRevealed, 'isRevealed', false),
      ],
    );

    blocTest<MiniReviewCubit, MiniReviewState>(
      'loads mixed item types',
      setUp: () {
        fsrsRepository.dueItemsBySource['book-1'] = [
          const ReviewItem(
            itemId: 'f1',
            itemType: ReviewableType.flashcard,
            fsrs: FsrsCardData(),
          ),
          const ReviewItem(
            itemId: 'h1',
            itemType: ReviewableType.highlight,
            fsrs: FsrsCardData(),
          ),
          const ReviewItem(
            itemId: 'd1',
            itemType: ReviewableType.dictionary,
            fsrs: FsrsCardData(),
          ),
        ];
        flashcardRepository.seed([_flashcard]);
        highlightRepository.seed([_highlight]);
        dictionaryRepository.seed([_entry]);
      },
      build: buildCubit,
      act: (cubit) => cubit.load('book-1'),
      expect: () => [
        const MiniReviewState(status: MiniReviewStatus.loading),
        isA<MiniReviewState>()
            .having((s) => s.status, 'status', MiniReviewStatus.reviewing)
            .having((s) => s.items.length, 'items.length', 3),
      ],
    );

    blocTest<MiniReviewCubit, MiniReviewState>(
      'skips items not found in repositories',
      setUp: () {
        fsrsRepository.dueItemsBySource['book-1'] = [
          const ReviewItem(
            itemId: 'missing',
            itemType: ReviewableType.flashcard,
            fsrs: FsrsCardData(),
          ),
        ];
      },
      build: buildCubit,
      act: (cubit) => cubit.load('book-1'),
      expect: () => [
        const MiniReviewState(status: MiniReviewStatus.loading),
        const MiniReviewState(status: MiniReviewStatus.empty, items: []),
      ],
    );

    blocTest<MiniReviewCubit, MiniReviewState>(
      'emits failure when fsrs repository throws',
      setUp: () => fsrsRepository.shouldThrow = true,
      build: buildCubit,
      act: (cubit) => cubit.load('book-1'),
      errors: () => [isA<StorageException>()],
      expect: () => [
        const MiniReviewState(status: MiniReviewStatus.loading),
        const MiniReviewState(status: MiniReviewStatus.failure),
      ],
    );
  });

  group('MiniReviewCubit.reveal()', () {
    blocTest<MiniReviewCubit, MiniReviewState>(
      'sets isRevealed to true',
      build: buildCubit,
      seed: () => MiniReviewState(
        status: MiniReviewStatus.reviewing,
        items: [PracticeItem.flashcard(_flashcard)],
      ),
      act: (cubit) => cubit.reveal(),
      expect: () => [
        isA<MiniReviewState>().having((s) => s.isRevealed, 'isRevealed', true),
      ],
    );
  });

  group('MiniReviewCubit.rate()', () {
    blocTest<MiniReviewCubit, MiniReviewState>(
      'advances to next item after rating',
      setUp: () {
        flashcardRepository.seed([_flashcard]);
        highlightRepository.seed([_highlight]);
      },
      build: buildCubit,
      seed: () => MiniReviewState(
        status: MiniReviewStatus.reviewing,
        items: [
          PracticeItem.flashcard(_flashcard),
          PracticeItem.highlight(_highlight),
        ],
      ),
      act: (cubit) => cubit.rate(Rating.good),
      expect: () => [
        isA<MiniReviewState>()
            .having((s) => s.currentIndex, 'currentIndex', 1)
            .having((s) => s.isRevealed, 'isRevealed', false),
      ],
      verify: (cubit) {
        expect(fsrsRepository.reviews, hasLength(1));
        expect(fsrsRepository.reviews.first.rating, Rating.good);
      },
    );

    blocTest<MiniReviewCubit, MiniReviewState>(
      'emits completed after rating last item',
      build: buildCubit,
      seed: () => MiniReviewState(
        status: MiniReviewStatus.reviewing,
        items: [PracticeItem.flashcard(_flashcard)],
        currentIndex: 0,
      ),
      act: (cubit) => cubit.rate(Rating.easy),
      expect: () => [
        isA<MiniReviewState>().having(
          (s) => s.status,
          'status',
          MiniReviewStatus.completed,
        ),
      ],
    );

    blocTest<MiniReviewCubit, MiniReviewState>(
      'emits failure when recording review throws',
      setUp: () => fsrsRepository.shouldThrow = true,
      build: buildCubit,
      seed: () => MiniReviewState(
        status: MiniReviewStatus.reviewing,
        items: [PracticeItem.flashcard(_flashcard)],
      ),
      act: (cubit) => cubit.rate(Rating.good),
      errors: () => [isA<StorageException>()],
      expect: () => [
        MiniReviewState(
          status: MiniReviewStatus.failure,
          items: [FlashcardItem(_flashcard)],
        ),
      ],
    );
  });

  group('MiniReviewState', () {
    test('currentItem returns item at currentIndex', () {
      final state = MiniReviewState(
        status: MiniReviewStatus.reviewing,
        items: [
          PracticeItem.flashcard(_flashcard),
          PracticeItem.highlight(_highlight),
        ],
        currentIndex: 1,
      );
      expect(state.currentItem, isA<HighlightItem>());
    });

    test('currentItem returns null when index is out of bounds', () {
      const state = MiniReviewState(
        status: MiniReviewStatus.reviewing,
        currentIndex: 5,
      );
      expect(state.currentItem, isNull);
    });

    test('remaining and reviewed track progress', () {
      final state = MiniReviewState(
        status: MiniReviewStatus.reviewing,
        items: [
          PracticeItem.flashcard(_flashcard),
          PracticeItem.highlight(_highlight),
          PracticeItem.dictionary(_entry),
        ],
        currentIndex: 1,
      );
      expect(state.remaining, 2);
      expect(state.reviewed, 1);
    });
  });
}
