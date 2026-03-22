import 'package:drift/drift.dart';

class FlashcardsTable extends Table {
  TextColumn get id => text()();

  TextColumn get deckId => text()();

  TextColumn get front => text()();

  TextColumn get back => text()();

  TextColumn get hint => text().nullable()();

  TextColumn get sourceHighlightId => text().nullable()();

  TextColumn get creationSource => text().withDefault(
    const Constant('manual'),
  )(); // manual, aiHighlight, aiSelection
  TextColumn get createdAt => text()(); // ISO 8601

  // FSRS card data (embedded)
  TextColumn get fsrsState => text().withDefault(
    const Constant('new'),
  )(); // new, learning, review, relearning
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
  Set<Column> get primaryKey => {id};
}
