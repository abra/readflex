import 'package:drift/drift.dart';

/// Source-specific text anchors for saved dictionary entries.
///
/// Dictionary entries can outlive their source, so anchors live in a separate
/// table and are removed when a source is deleted or detached.
class DictionaryAnchorsTable extends Table {
  TextColumn get id => text()();

  TextColumn get entryId => text()();

  TextColumn get sourceId => text()();

  TextColumn get sourceType => text()();

  TextColumn get anchorText => text().named('text')();

  TextColumn get context => text().nullable()();

  TextColumn get cfiRange => text()();

  TextColumn get kind => text()();

  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}
