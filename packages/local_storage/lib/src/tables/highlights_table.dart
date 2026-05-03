import 'package:drift/drift.dart';

/// Drift schema for text highlights captured in the reader. [sourceId] +
/// [sourceType] identify the book; position is stored as an EPUB
/// [cfiRange]. FSRS review state lives separately in
/// `review_items_table`.
///
/// [pageNumber] and [scrollOffset] are vestigial columns from the removed
/// article reader; new rows write `null`. They will be dropped in a
/// future schema migration once their absence is confirmed across all
/// existing installs.
class HighlightsTable extends Table {
  TextColumn get id => text()();

  TextColumn get sourceId => text()();

  TextColumn get sourceType => text()(); // always 'book' (legacy SourceType column)
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
