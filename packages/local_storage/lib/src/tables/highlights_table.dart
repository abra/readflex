import 'package:drift/drift.dart';

/// Drift schema for text highlights captured in the reader. [sourceId] +
/// [sourceType] identify the reading source; position is stored as an EPUB
/// [cfiRange]. FSRS review state lives separately in
/// `review_items_table`.
///
/// [pageNumber] and [scrollOffset] are legacy positional columns kept for old
/// rows and tests. Current reader selections are anchored by [cfiRange], with
/// [progress] and [chapterTitle] providing drawer-friendly location labels.
class HighlightsTable extends Table {
  TextColumn get id => text()();

  TextColumn get sourceId => text()();

  TextColumn get sourceType => text()(); // SourceType storage key.
  TextColumn get highlightText => text()();

  TextColumn get note => text().nullable()();

  TextColumn get cfiRange => text().nullable()();

  IntColumn get pageNumber => integer().nullable()();

  RealColumn get scrollOffset => real().nullable()();

  RealColumn get progress => real().nullable()();

  TextColumn get chapterTitle => text().nullable()();

  TextColumn get color => text().withDefault(
    const Constant('yellow'),
  )(); // yellow, green, blue, pink, purple
  TextColumn get createdAt => text()(); // ISO 8601

  @override
  Set<Column> get primaryKey => {id};
}
