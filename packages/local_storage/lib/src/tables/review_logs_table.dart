import 'package:drift/drift.dart';

/// Append-only record of every FSRS review across all reviewable types.
/// Each row captures the rating plus a snapshot of the pre-review FSRS
/// state, used for analytics and parameter optimization. The current state
/// itself lives in `review_items_table`.
class ReviewLogsTable extends Table {
  TextColumn get id => text()();

  TextColumn get itemId => text()();

  TextColumn get itemType => text()(); // flashcard | highlight | dictionary
  TextColumn get rating => text()(); // again, hard, good, easy
  TextColumn get stateBefore => text()();

  RealColumn get stabilityBefore => real()();

  RealColumn get difficultyBefore => real()();

  RealColumn get retrievabilityAtReview => real()();

  IntColumn get scheduledDays => integer()();

  IntColumn get elapsedDays => integer()();

  IntColumn get reviewDurationMs => integer().nullable()();

  TextColumn get reviewedAt => text()(); // ISO 8601

  @override
  Set<Column> get primaryKey => {id};
}
