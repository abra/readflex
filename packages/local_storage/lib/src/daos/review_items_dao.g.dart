// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review_items_dao.dart';

// ignore_for_file: type=lint
mixin _$ReviewItemsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ReviewItemsTableTable get reviewItemsTable =>
      attachedDatabase.reviewItemsTable;

  $ReviewLogsTableTable get reviewLogsTable => attachedDatabase.reviewLogsTable;

  ReviewItemsDaoManager get managers => ReviewItemsDaoManager(this);
}

class ReviewItemsDaoManager {
  final _$ReviewItemsDaoMixin _db;

  ReviewItemsDaoManager(this._db);

  $$ReviewItemsTableTableTableManager get reviewItemsTable =>
      $$ReviewItemsTableTableTableManager(
        _db.attachedDatabase,
        _db.reviewItemsTable,
      );

  $$ReviewLogsTableTableTableManager get reviewLogsTable =>
      $$ReviewLogsTableTableTableManager(
        _db.attachedDatabase,
        _db.reviewLogsTable,
      );
}
