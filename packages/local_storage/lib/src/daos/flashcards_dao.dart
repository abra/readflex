import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/flashcards_table.dart';

part 'flashcards_dao.g.dart';

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

  Future<void> insertFlashcard(FlashcardsTableCompanion card) =>
      into(flashcardsTable).insert(card);

  Future<void> updateFlashcard(FlashcardsTableCompanion card) => (update(
    flashcardsTable,
  )..where((t) => t.id.equals(card.id.value))).write(card);

  Future<void> deleteFlashcard(String id) =>
      (delete(flashcardsTable)..where((t) => t.id.equals(id))).go();
}
