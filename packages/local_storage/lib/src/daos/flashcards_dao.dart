import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/flashcards_table.dart';

part 'flashcards_dao.g.dart';

/// CRUD access to [FlashcardsTable] with a by-deck filter and a batch
/// by-ids lookup used by the practice feature. Consumed by
/// `FlashcardRepository`, which wraps errors in `StorageException`.
@DriftAccessor(tables: [FlashcardsTable])
class FlashcardsDao extends DatabaseAccessor<AppDatabase>
    with _$FlashcardsDaoMixin {
  FlashcardsDao(super.db);

  Future<List<FlashcardsTableData>> allFlashcards() => (select(
    flashcardsTable,
  )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();

  Future<List<FlashcardsTableData>> flashcardsByDeck(String deckId) =>
      (select(flashcardsTable)
            ..where((t) => t.deckId.equals(deckId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Future<FlashcardsTableData?> flashcardById(String id) => (select(
    flashcardsTable,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<FlashcardsTableData>> flashcardsByIds(List<String> ids) =>
      (select(flashcardsTable)..where((t) => t.id.isIn(ids))).get();

  Future<void> insertFlashcard(FlashcardsTableCompanion card) =>
      into(flashcardsTable).insert(card);

  Future<void> updateFlashcard(FlashcardsTableCompanion card) => (update(
    flashcardsTable,
  )..where((t) => t.id.equals(card.id.value))).write(card);

  Future<void> deleteFlashcard(String id) =>
      (delete(flashcardsTable)..where((t) => t.id.equals(id))).go();

  /// Bulk-removes every flashcard tied to [deckId]. Used when the parent
  /// book is deleted so cards don't outlive their deck.
  Future<void> deleteFlashcardsByDeck(String deckId) =>
      (delete(flashcardsTable)..where((t) => t.deckId.equals(deckId))).go();
}
