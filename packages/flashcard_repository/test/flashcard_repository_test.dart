import 'package:drift/native.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';

void main() {
  late AppDatabase db;
  late FlashcardRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FlashcardRepository(database: db);
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
}
