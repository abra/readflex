import 'package:drift/drift.dart';

class HighlightsTable extends Table {
  TextColumn get id => text()();

  TextColumn get sourceId => text()();

  TextColumn get sourceType => text()(); // book | article
  TextColumn get highlightText => text()();

  TextColumn get note => text().nullable()();

  TextColumn get cfiRange => text().nullable()();

  IntColumn get pageNumber => integer().nullable()();

  RealColumn get scrollOffset => real().nullable()();

  TextColumn get color => text().withDefault(
    const Constant('yellow'),
  )(); // yellow, green, blue, pink, purple
  TextColumn get createdAt => text()(); // ISO 8601

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
