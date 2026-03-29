// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dictionary_dao.dart';

// ignore_for_file: type=lint
mixin _$DictionaryDaoMixin on DatabaseAccessor<AppDatabase> {
  $DictionaryTableTable get dictionaryTable => attachedDatabase.dictionaryTable;

  $ReviewLogsTableTable get reviewLogsTable => attachedDatabase.reviewLogsTable;

  DictionaryDaoManager get managers => DictionaryDaoManager(this);
}

class DictionaryDaoManager {
  final _$DictionaryDaoMixin _db;

  DictionaryDaoManager(this._db);

  $$DictionaryTableTableTableManager get dictionaryTable =>
      $$DictionaryTableTableTableManager(
        _db.attachedDatabase,
        _db.dictionaryTable,
      );

  $$ReviewLogsTableTableTableManager get reviewLogsTable =>
      $$ReviewLogsTableTableTableManager(
        _db.attachedDatabase,
        _db.reviewLogsTable,
      );
}
