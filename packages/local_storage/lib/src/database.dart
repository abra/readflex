import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/books_dao.dart';
import 'daos/dictionary_dao.dart';
import 'daos/flashcards_dao.dart';
import 'daos/highlights_dao.dart';
import 'tables/articles_table.dart';
import 'tables/books_table.dart';
import 'tables/dictionary_entries_table.dart';
import 'tables/flashcards_table.dart';
import 'tables/highlights_table.dart';
import 'tables/review_logs_table.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    BooksTable,
    ArticlesTable,
    HighlightsTable,
    FlashcardsTable,
    DictionaryEntriesTable,
    ReviewLogsTable,
  ],
  daos: [BooksDao, HighlightsDao, FlashcardsDao, DictionaryDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @visibleForTesting
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() => LazyDatabase(() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, 'readflex.db'));
  return NativeDatabase.createInBackground(file);
});
