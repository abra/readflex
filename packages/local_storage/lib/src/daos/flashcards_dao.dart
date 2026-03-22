import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/flashcards_table.dart';
import '../tables/review_logs_table.dart';

part 'flashcards_dao.g.dart';

@DriftAccessor(tables: [FlashcardsTable, ReviewLogsTable])
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

  Future<List<FlashcardsTableData>> dueFlashcards(String now) =>
      (select(flashcardsTable)
            ..where(
              (t) =>
                  t.nextReviewAt.isNull() |
                  t.nextReviewAt.isSmallerOrEqual(Variable(now)),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.nextReviewAt)]))
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

  // Review logs

  Future<void> insertReviewLog(ReviewLogsTableCompanion log) =>
      into(reviewLogsTable).insert(log);

  Future<List<ReviewLogsTableData>> reviewLogsByFlashcard(String flashcardId) =>
      (select(reviewLogsTable)
            ..where((t) => t.flashcardId.equals(flashcardId))
            ..orderBy([(t) => OrderingTerm.desc(t.reviewedAt)]))
          .get();
}
