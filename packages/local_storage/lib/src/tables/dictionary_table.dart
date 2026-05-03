import 'package:drift/drift.dart';

/// Drift schema for saved dictionary entries (words / phrases / idioms).
/// Optional [sourceId] + [sourceType] link the entry back to the book it
/// was captured from; [usageExamples] is a JSON-encoded list of strings.
/// FSRS review state lives separately in `review_items_table`.
class DictionaryTable extends Table {
  TextColumn get id => text()();

  TextColumn get word => text()();

  TextColumn get translation => text()();

  TextColumn get pronunciation => text().nullable()();

  TextColumn get partOfSpeech => text().nullable()();

  TextColumn get context => text().nullable()();

  TextColumn get sourceId => text().nullable()();

  TextColumn get sourceType => text().nullable()(); // 'book' or null (legacy SourceType column)
  TextColumn get usageExamples => text().nullable()(); // JSON-encoded list
  TextColumn get addedAt => text()(); // ISO 8601

  @override
  Set<Column> get primaryKey => {id};
}
