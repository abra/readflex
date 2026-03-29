// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'highlights_dao.dart';

// ignore_for_file: type=lint
mixin _$HighlightsDaoMixin on DatabaseAccessor<AppDatabase> {
  $HighlightsTableTable get highlightsTable => attachedDatabase.highlightsTable;

  $ReviewLogsTableTable get reviewLogsTable => attachedDatabase.reviewLogsTable;

  HighlightsDaoManager get managers => HighlightsDaoManager(this);
}

class HighlightsDaoManager {
  final _$HighlightsDaoMixin _db;

  HighlightsDaoManager(this._db);

  $$HighlightsTableTableTableManager get highlightsTable =>
      $$HighlightsTableTableTableManager(
        _db.attachedDatabase,
        _db.highlightsTable,
      );

  $$ReviewLogsTableTableTableManager get reviewLogsTable =>
      $$ReviewLogsTableTableTableManager(
        _db.attachedDatabase,
        _db.reviewLogsTable,
      );
}
