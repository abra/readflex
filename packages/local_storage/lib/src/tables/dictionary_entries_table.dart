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

  @override
  Set<Column> get primaryKey => {id};
}
