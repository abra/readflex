import 'package:drift/drift.dart';

class DictionaryEntriesTable extends Table {
  TextColumn get id => text()();

  TextColumn get word => text()();

  TextColumn get translation => text()();

  TextColumn get context => text().nullable()();

  TextColumn get sourceId => text().nullable()();

  TextColumn get sourceType => text().nullable()(); // book | article
  TextColumn get usageExamples => text().nullable()(); // JSON-encoded list
  TextColumn get addedAt => text()(); // ISO 8601

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
  Set<Column> get primaryKey => {id};
}
