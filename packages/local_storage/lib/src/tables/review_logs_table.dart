import 'package:drift/drift.dart';

class ReviewLogsTable extends Table {
  TextColumn get id => text()();
  TextColumn get flashcardId => text()();
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
