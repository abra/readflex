// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flashcards_dao.dart';

// ignore_for_file: type=lint
mixin _$FlashcardsDaoMixin on DatabaseAccessor<AppDatabase> {
  $FlashcardsTableTable get flashcardsTable => attachedDatabase.flashcardsTable;
  $ReviewLogsTableTable get reviewLogsTable => attachedDatabase.reviewLogsTable;
  FlashcardsDaoManager get managers => FlashcardsDaoManager(this);
}

class FlashcardsDaoManager {
  final _$FlashcardsDaoMixin _db;
  FlashcardsDaoManager(this._db);
  $$FlashcardsTableTableTableManager get flashcardsTable =>
      $$FlashcardsTableTableTableManager(
        _db.attachedDatabase,
        _db.flashcardsTable,
      );
  $$ReviewLogsTableTableTableManager get reviewLogsTable =>
      $$ReviewLogsTableTableTableManager(
        _db.attachedDatabase,
        _db.reviewLogsTable,
      );
}
