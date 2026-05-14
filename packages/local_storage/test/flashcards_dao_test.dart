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

  FlashcardsTableCompanion makeCard({
    String id = 'f1',
    String deckId = 'd1',
    String front = 'Front',
    String back = 'Back',
    String createdAt = '2026-01-01T00:00:00.000Z',
  }) => FlashcardsTableCompanion.insert(
    id: id,
    deckId: deckId,
    front: front,
    back: back,
    createdAt: createdAt,
  );

  test('insert and retrieve flashcard', () async {
    await dao.insertFlashcard(makeCard());
    final cards = await dao.allFlashcards();
    expect(cards, hasLength(1));
    expect(cards.first.front, 'Front');
  });

  test('flashcardsByDeck filters correctly', () async {
    await dao.insertFlashcard(makeCard(id: 'f1', deckId: 'd1'));
    await dao.insertFlashcard(makeCard(id: 'f2', deckId: 'd2'));
    final result = await dao.flashcardsByDeck('d1');
    expect(result, hasLength(1));
  });

  test('flashcardCountByDeck counts only deck cards', () async {
    await dao.insertFlashcard(makeCard(id: 'f1', deckId: 'd1'));
    await dao.insertFlashcard(makeCard(id: 'f2', deckId: 'd1'));
    await dao.insertFlashcard(makeCard(id: 'f3', deckId: 'd2'));

    expect(await dao.flashcardCountByDeck('d1'), 2);
    expect(await dao.flashcardCountByDeck('missing'), 0);
  });
}
