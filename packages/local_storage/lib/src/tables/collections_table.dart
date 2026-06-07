import 'package:drift/drift.dart';

/// User-created source collections.
///
/// Automatic scopes (author, site/domain, etc.) are intentionally not stored
/// here: they are derived from source metadata at query time.
class CollectionsTable extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get createdAt => text()();

  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Many-to-many relation between manual collections and library source ids.
///
/// `sourceId` references either a book or an article id. There is no DB-level
/// foreign key because those ids live in separate tables.
class CollectionSourcesTable extends Table {
  TextColumn get collectionId => text().references(
    CollectionsTable,
    #id,
    onDelete: KeyAction.cascade,
  )();

  TextColumn get sourceId => text()();

  TextColumn get addedAt => text()();

  @override
  Set<Column> get primaryKey => {collectionId, sourceId};
}
