// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dictionary_dao.dart';

// ignore_for_file: type=lint
mixin _$DictionaryDaoMixin on DatabaseAccessor<AppDatabase> {
  $DictionaryEntriesTableTable get dictionaryEntriesTable =>
      attachedDatabase.dictionaryEntriesTable;

  DictionaryDaoManager get managers => DictionaryDaoManager(this);
}

class DictionaryDaoManager {
  final _$DictionaryDaoMixin _db;

  DictionaryDaoManager(this._db);

  $$DictionaryEntriesTableTableTableManager get dictionaryEntriesTable =>
      $$DictionaryEntriesTableTableTableManager(
        _db.attachedDatabase,
        _db.dictionaryEntriesTable,
      );
}
