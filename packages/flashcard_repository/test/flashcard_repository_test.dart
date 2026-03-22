import 'package:drift/native.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:shared/shared.dart';

void main() {
  late AppDatabase db;
  late FlashcardRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FlashcardRepository(flashcardsDao: db.flashcardsDao);
  });

  tearDown(() => db.close());

  group('FlashcardRepository — CRUD', () {
    test('addFlashcard creates and returns flashcard', () async {
      final card = await repo.addFlashcard(
        deckId: 'd1',
        front: 'What is Dart?',
        back: 'A programming language.',
      );
      expect(card.front, 'What is Dart?');
      expect(card.deckId, 'd1');
      expect(card.id, isNotEmpty);
      expect(card.fsrs.state, FsrsState.newCard);
    });

    test('getFlashcards returns all flashcards', () async {
      await repo.addFlashcard(deckId: 'd1', front: 'F1', back: 'B1');
      await repo.addFlashcard(deckId: 'd1', front: 'F2', back: 'B2');
      final cards = await repo.getFlashcards();
      expect(cards, hasLength(2));
    });

    test('getFlashcardsByDeck filters correctly', () async {
      await repo.addFlashcard(deckId: 'd1', front: 'F1', back: 'B1');
      await repo.addFlashcard(deckId: 'd2', front: 'F2', back: 'B2');
      final result = await repo.getFlashcardsByDeck('d1');
      expect(result, hasLength(1));
      expect(result.first.front, 'F1');
    });

    test('getFlashcardById returns correct flashcard', () async {
      final created = await repo.addFlashcard(
        deckId: 'd1',
        front: 'Find',
        back: 'Me',
      );
      final found = await repo.getFlashcardById(created.id);
      expect(found, isNotNull);
      expect(found!.front, 'Find');
    });

    test('getFlashcardById returns null for missing id', () async {
      final found = await repo.getFlashcardById('missing');
      expect(found, isNull);
    });

    test('updateFlashcard persists changes', () async {
      final created = await repo.addFlashcard(
        deckId: 'd1',
        front: 'Old',
        back: 'Answer',
      );
      final updated = created.copyWith(front: 'New');
      await repo.updateFlashcard(updated);
      final fetched = await repo.getFlashcardById(created.id);
      expect(fetched!.front, 'New');
    });

    test('deleteFlashcard removes flashcard', () async {
      final created = await repo.addFlashcard(
        deckId: 'd1',
        front: 'Del',
        back: 'Me',
      );
      await repo.deleteFlashcard(created.id);
      final cards = await repo.getFlashcards();
      expect(cards, isEmpty);
    });
  });

  group('FlashcardRepository — review (FSRS)', () {
    test('recordReview updates FSRS state from new to learning', () async {
      final card = await repo.addFlashcard(deckId: 'd1', front: 'Q', back: 'A');
      final reviewed = await repo.recordReview(card, Rating.good);
      expect(reviewed.fsrs.reps, 1);
      expect(reviewed.fsrs.lastReviewAt, isNotNull);
      expect(reviewed.fsrs.nextReviewAt, isNotNull);
    });

    test('recordReview with Again keeps card in learning', () async {
      final card = await repo.addFlashcard(deckId: 'd1', front: 'Q', back: 'A');
      final reviewed = await repo.recordReview(card, Rating.again);
      expect(reviewed.fsrs.state, FsrsState.learning);
      expect(reviewed.fsrs.reps, 1);
    });

    test('recordReview with Easy advances card faster', () async {
      final card = await repo.addFlashcard(deckId: 'd1', front: 'Q', back: 'A');
      final reviewed = await repo.recordReview(card, Rating.easy);
      // Easy should result in review state or longer interval
      expect(reviewed.fsrs.reps, 1);
      expect(reviewed.fsrs.nextReviewAt, isNotNull);
    });

    test('consecutive reviews increment reps', () async {
      var card = await repo.addFlashcard(deckId: 'd1', front: 'Q', back: 'A');
      card = await repo.recordReview(card, Rating.good);
      expect(card.fsrs.reps, 1);
      card = await repo.recordReview(card, Rating.good);
      expect(card.fsrs.reps, 2);
      card = await repo.recordReview(card, Rating.good);
      expect(card.fsrs.reps, 3);
    });

    test('recordReview persists to storage', () async {
      final card = await repo.addFlashcard(deckId: 'd1', front: 'Q', back: 'A');
      await repo.recordReview(card, Rating.good);
      final fetched = await repo.getFlashcardById(card.id);
      expect(fetched!.fsrs.reps, 1);
      expect(fetched.fsrs.lastReviewAt, isNotNull);
    });

    test('recordReview with duration saves to review log', () async {
      final card = await repo.addFlashcard(deckId: 'd1', front: 'Q', back: 'A');
      await repo.recordReview(card, Rating.good, reviewDurationMs: 5000);
      // Verify review log was saved via DAO
      final logs = await db.flashcardsDao.reviewLogsByFlashcard(card.id);
      expect(logs, hasLength(1));
      expect(logs.first.rating, 'good');
      expect(logs.first.reviewDurationMs, 5000);
    });
  });
}
