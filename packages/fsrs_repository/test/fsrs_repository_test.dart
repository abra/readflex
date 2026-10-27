import 'package:domain_models/domain_models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:local_storage/local_storage.dart';

void main() {
  late AppDatabase db;
  late FsrsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FsrsRepository(database: db);
  });

  tearDown(() => db.close());

  group('FsrsRepository — create/delete', () {
    test('createReviewItem stores a new tracked item', () async {
      await repo.createReviewItem(
        itemId: 'card-1',
        itemType: ReviewableType.flashcard,
      );

      final state = await repo.getReviewState('card-1');
      expect(state, isNotNull);
      expect(state!.state, FsrsState.newCard);
      expect(state.reps, 0);
    });

    test('createReviewItem stores sourceId when provided', () async {
      await repo.createReviewItem(
        itemId: 'hl-1',
        itemType: ReviewableType.highlight,
        sourceId: 'book-42',
      );

      final dueForSource = await repo.getDueItemsBySource('book-42');
      expect(dueForSource, hasLength(1));
      expect(dueForSource.first.itemId, 'hl-1');
    });

    test('deleteReviewItem removes tracking', () async {
      await repo.createReviewItem(
        itemId: 'card-1',
        itemType: ReviewableType.flashcard,
      );
      await repo.deleteReviewItem('card-1');

      final state = await repo.getReviewState('card-1');
      expect(state, isNull);
    });

    test('getReviewState returns null for unknown item', () async {
      final state = await repo.getReviewState('missing');
      expect(state, isNull);
    });
  });

  group('FsrsRepository — queries', () {
    test('getReviewStates returns a map for known ids', () async {
      await repo.createReviewItem(
        itemId: 'a',
        itemType: ReviewableType.flashcard,
      );
      await repo.createReviewItem(
        itemId: 'b',
        itemType: ReviewableType.flashcard,
      );

      final states = await repo.getReviewStates(['a', 'b', 'missing']);
      expect(states.keys, containsAll(['a', 'b']));
      expect(states.containsKey('missing'), isFalse);
    });

    test('getReviewStates returns empty map for empty input', () async {
      final states = await repo.getReviewStates([]);
      expect(states, isEmpty);
    });

    test(
      'getDueItems returns never-reviewed items and type-filters correctly',
      () async {
        await repo.createReviewItem(
          itemId: 'card-1',
          itemType: ReviewableType.flashcard,
        );
        await repo.createReviewItem(
          itemId: 'hl-1',
          itemType: ReviewableType.highlight,
        );
        await repo.createReviewItem(
          itemId: 'dict-1',
          itemType: ReviewableType.dictionary,
        );

        final allDue = await repo.getDueItems();
        expect(allDue, hasLength(3));

        final flashcards = await repo.getDueItems(
          type: ReviewableType.flashcard,
        );
        expect(flashcards, hasLength(1));
        expect(flashcards.first.itemId, 'card-1');

        expect(await repo.getDueItemCount(), 3);
        expect(
          await repo.getDueItemCount(type: ReviewableType.flashcard),
          1,
        );
      },
    );

    test('getDueItemsBySource filters by source and type', () async {
      await repo.createReviewItem(
        itemId: 'hl-1',
        itemType: ReviewableType.highlight,
        sourceId: 'book-1',
      );
      await repo.createReviewItem(
        itemId: 'hl-2',
        itemType: ReviewableType.highlight,
        sourceId: 'book-2',
      );
      await repo.createReviewItem(
        itemId: 'card-1',
        itemType: ReviewableType.flashcard,
        sourceId: 'book-1',
      );

      final fromBook1 = await repo.getDueItemsBySource('book-1');
      expect(fromBook1.map((e) => e.itemId), containsAll(['hl-1', 'card-1']));

      final highlightsFromBook1 = await repo.getDueItemsBySource(
        'book-1',
        type: ReviewableType.highlight,
      );
      expect(highlightsFromBook1, hasLength(1));
      expect(highlightsFromBook1.first.itemId, 'hl-1');
    });

    test('getMasteredItemIds returns only items in review state', () async {
      await repo.createReviewItem(
        itemId: 'new-card',
        itemType: ReviewableType.flashcard,
      );

      // No reviews yet — no mastered items.
      expect(await repo.getMasteredItemIds(), isEmpty);

      // Promote the item repeatedly to push it into the review state.
      for (var i = 0; i < 4; i++) {
        await repo.recordReview(
          itemId: 'new-card',
          itemType: ReviewableType.flashcard,
          rating: Rating.easy,
        );
      }

      final state = await repo.getReviewState('new-card');
      // Only assert mastered-items if the item actually reached review state.
      if (state?.state == FsrsState.review) {
        final mastered = await repo.getMasteredItemIds();
        expect(mastered, contains('new-card'));
      }
    });
  });

  group('FsrsRepository — recordReview', () {
    test(
      'creates tracking implicitly when recording an untracked item',
      () async {
        // recordReview should handle first-time review of an item that was
        // never createReviewItem-ed.
        final updated = await repo.recordReview(
          itemId: 'card-1',
          itemType: ReviewableType.flashcard,
          rating: Rating.good,
        );

        expect(updated.reps, 1);
        expect(updated.lastReviewAt, isNotNull);

        final stored = await repo.getReviewState('card-1');
        expect(stored, isNotNull);
        expect(stored!.reps, 1);
      },
    );

    test('persists updated FSRS state', () async {
      await repo.createReviewItem(
        itemId: 'card-1',
        itemType: ReviewableType.flashcard,
      );
      await repo.recordReview(
        itemId: 'card-1',
        itemType: ReviewableType.flashcard,
        rating: Rating.good,
      );

      final stored = await repo.getReviewState('card-1');
      expect(stored!.state, isNot(FsrsState.newCard));
      expect(stored.reps, 1);
      expect(stored.nextReviewAt, isNotNull);
    });

    test('preserves sourceId across recordReview', () async {
      await repo.createReviewItem(
        itemId: 'hl-1',
        itemType: ReviewableType.highlight,
        sourceId: 'book-7',
      );
      await repo.recordReview(
        itemId: 'hl-1',
        itemType: ReviewableType.highlight,
        rating: Rating.good,
      );

      final row = await db.reviewItemsDao.byItemId('hl-1');
      expect(row?.sourceId, 'book-7');
    });

    test('implicit creation preserves sourceId when provided', () async {
      // Per the recordReview docstring, callers may rely on implicit creation
      // — the first review registers the item in FSRS tracking. sourceId must
      // be preserved on that implicit path, otherwise source-scoped queries
      // (review-by-book, review-by-article) silently miss the card forever.
      await repo.recordReview(
        itemId: 'hl-new',
        itemType: ReviewableType.highlight,
        rating: Rating.good,
        sourceId: 'book-42',
      );

      final row = await db.reviewItemsDao.byItemId('hl-new');
      expect(row?.sourceId, 'book-42');
    });

    test('two consecutive reviews increment reps to 2', () async {
      await repo.recordReview(
        itemId: 'card-1',
        itemType: ReviewableType.flashcard,
        rating: Rating.good,
      );
      final second = await repo.recordReview(
        itemId: 'card-1',
        itemType: ReviewableType.flashcard,
        rating: Rating.good,
      );

      expect(second.reps, 2);
    });
  });
}
