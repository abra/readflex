import 'package:drift/drift.dart';

/// Stores FSRS review state for all reviewable items
/// (flashcards, highlights, dictionary entries).
class ReviewItemsTable extends Table {
  TextColumn get itemId => text()();

  TextColumn get itemType => text()(); // flashcard | highlight | dictionary
  TextColumn get sourceId =>
      text().nullable()(); // denormalized for due-by-source queries

  // FSRS card data
  TextColumn get fsrsState => text().withDefault(const Constant('new'))();

  RealColumn get stability => real().withDefault(const Constant(0.0))();

  RealColumn get difficulty => real().withDefault(const Constant(0.0))();

  RealColumn get retrievability => real().withDefault(const Constant(0.0))();

  IntColumn get reps => integer().withDefault(const Constant(0))();

  IntColumn get lapses => integer().withDefault(const Constant(0))();

  TextColumn get lastReviewAt => text().nullable()(); // ISO 8601
  TextColumn get nextReviewAt => text().nullable()(); // ISO 8601
  IntColumn get scheduledDays => integer().withDefault(const Constant(0))();

  IntColumn get elapsedDays => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {itemId};
}
