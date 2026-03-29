import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';

void main() {
  late AppDatabase db;
  late FlashcardsDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = db.flashcardsDao;
  });

  tearDown(() => db.close());

  FlashcardsTableCompanion _card({
    String id = 'f1',
    String deckId = 'd1',
    String front = 'Front',
    String back = 'Back',
    String createdAt = '2026-01-01T00:00:00.000Z',
    String? nextReviewAt,
  }) => FlashcardsTableCompanion.insert(
    id: id,
    deckId: deckId,
    front: front,
    back: back,
    createdAt: createdAt,
    nextReviewAt: Value(nextReviewAt),
  );

  test('insert and retrieve flashcard', () async {
    await dao.insertFlashcard(_card());
    final cards = await dao.allFlashcards();
    expect(cards, hasLength(1));
    expect(cards.first.front, 'Front');
  });

  test('flashcardsByDeck filters correctly', () async {
    await dao.insertFlashcard(_card(id: 'f1', deckId: 'd1'));
    await dao.insertFlashcard(_card(id: 'f2', deckId: 'd2'));
    final result = await dao.flashcardsByDeck('d1');
    expect(result, hasLength(1));
  });

  test('dueFlashcards returns cards with null or past nextReviewAt', () async {
    await dao.insertFlashcard(_card(id: 'f1')); // null nextReviewAt → due
    await dao.insertFlashcard(
      _card(id: 'f2', nextReviewAt: '2026-01-01T00:00:00.000Z'),
    ); // past → due
    await dao.insertFlashcard(
      _card(id: 'f3', nextReviewAt: '2099-01-01T00:00:00.000Z'),
    ); // future → not due
    final due = await dao.dueFlashcards('2026-06-01T00:00:00.000Z');
    expect(due, hasLength(2));
  });

  test('insertReviewLog and retrieve by flashcard', () async {
    await dao.insertFlashcard(_card());
    await dao.insertReviewLog(
      ReviewLogsTableCompanion.insert(
        id: 'r1',
        itemId: 'f1',
        itemType: 'flashcard',
        rating: 'good',
        stateBefore: 'new',
        stabilityBefore: 0.0,
        difficultyBefore: 0.0,
        retrievabilityAtReview: 0.0,
        scheduledDays: 1,
        elapsedDays: 0,
        reviewedAt: '2026-01-01T00:00:00.000Z',
      ),
    );
    final logs = await dao.reviewLogsByItem('f1');
    expect(logs, hasLength(1));
    expect(logs.first.rating, 'good');
  });
}
