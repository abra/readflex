import 'package:drift/drift.dart';

/// Drift schema for text highlights captured in the reader. [sourceId] +
/// [sourceType] identify the book or article; position is stored as either
/// an EPUB [cfiRange] (books) or a [scrollOffset] / [pageNumber] (articles).
/// FSRS review state lives separately in `review_items_table`.
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

  @override
  Set<Column> get primaryKey => {id};
}
