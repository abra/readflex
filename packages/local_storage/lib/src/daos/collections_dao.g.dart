// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collections_dao.dart';

// ignore_for_file: type=lint
mixin _$CollectionsDaoMixin on DatabaseAccessor<AppDatabase> {
  $CollectionsTableTable get collectionsTable =>
      attachedDatabase.collectionsTable;
  $CollectionSourcesTableTable get collectionSourcesTable =>
      attachedDatabase.collectionSourcesTable;
  CollectionsDaoManager get managers => CollectionsDaoManager(this);
}

class CollectionsDaoManager {
  final _$CollectionsDaoMixin _db;
  CollectionsDaoManager(this._db);
  $$CollectionsTableTableTableManager get collectionsTable =>
      $$CollectionsTableTableTableManager(
        _db.attachedDatabase,
        _db.collectionsTable,
      );
  $$CollectionSourcesTableTableTableManager get collectionSourcesTable =>
      $$CollectionSourcesTableTableTableManager(
        _db.attachedDatabase,
        _db.collectionSourcesTable,
      );
}
