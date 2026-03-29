import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/articles_dao.dart';
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
    DictionaryTable,
    ReviewLogsTable,
  ],
  daos: [ArticlesDao, BooksDao, HighlightsDao, FlashcardsDao, DictionaryDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @visibleForTesting
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        // Add FSRS columns to highlights
        await customStatement(
          'ALTER TABLE highlights_table ADD COLUMN fsrs_state TEXT NOT NULL DEFAULT \'new\'',
        );
        await customStatement(
          'ALTER TABLE highlights_table ADD COLUMN stability REAL NOT NULL DEFAULT 0.0',
        );
        await customStatement(
          'ALTER TABLE highlights_table ADD COLUMN difficulty REAL NOT NULL DEFAULT 0.0',
        );
        await customStatement(
          'ALTER TABLE highlights_table ADD COLUMN retrievability REAL NOT NULL DEFAULT 0.0',
        );
        await customStatement(
          'ALTER TABLE highlights_table ADD COLUMN reps INTEGER NOT NULL DEFAULT 0',
        );
        await customStatement(
          'ALTER TABLE highlights_table ADD COLUMN lapses INTEGER NOT NULL DEFAULT 0',
        );
        await customStatement(
          'ALTER TABLE highlights_table ADD COLUMN last_review_at TEXT',
        );
        await customStatement(
          'ALTER TABLE highlights_table ADD COLUMN next_review_at TEXT',
        );
        await customStatement(
          'ALTER TABLE highlights_table ADD COLUMN scheduled_days INTEGER NOT NULL DEFAULT 0',
        );
        await customStatement(
          'ALTER TABLE highlights_table ADD COLUMN elapsed_days INTEGER NOT NULL DEFAULT 0',
        );

        // Add FSRS columns to dictionary_entries
        await customStatement(
          'ALTER TABLE dictionary_entries_table ADD COLUMN fsrs_state TEXT NOT NULL DEFAULT \'new\'',
        );
        await customStatement(
          'ALTER TABLE dictionary_entries_table ADD COLUMN stability REAL NOT NULL DEFAULT 0.0',
        );
        await customStatement(
          'ALTER TABLE dictionary_entries_table ADD COLUMN difficulty REAL NOT NULL DEFAULT 0.0',
        );
        await customStatement(
          'ALTER TABLE dictionary_entries_table ADD COLUMN retrievability REAL NOT NULL DEFAULT 0.0',
        );
        await customStatement(
          'ALTER TABLE dictionary_entries_table ADD COLUMN reps INTEGER NOT NULL DEFAULT 0',
        );
        await customStatement(
          'ALTER TABLE dictionary_entries_table ADD COLUMN lapses INTEGER NOT NULL DEFAULT 0',
        );
        await customStatement(
          'ALTER TABLE dictionary_entries_table ADD COLUMN last_review_at TEXT',
        );
        await customStatement(
          'ALTER TABLE dictionary_entries_table ADD COLUMN next_review_at TEXT',
        );
        await customStatement(
          'ALTER TABLE dictionary_entries_table ADD COLUMN scheduled_days INTEGER NOT NULL DEFAULT 0',
        );
        await customStatement(
          'ALTER TABLE dictionary_entries_table ADD COLUMN elapsed_days INTEGER NOT NULL DEFAULT 0',
        );

        // Update review_logs: rename flashcard_id → item_id, add item_type
        await customStatement(
          'ALTER TABLE review_logs_table RENAME COLUMN flashcard_id TO item_id',
        );
        await customStatement(
          'ALTER TABLE review_logs_table ADD COLUMN item_type TEXT NOT NULL DEFAULT \'flashcard\'',
        );
      }
      if (from < 3) {
        await customStatement(
          'ALTER TABLE dictionary_entries_table RENAME TO dictionary_table',
        );
      }
    },
  );
}

LazyDatabase _openConnection() => LazyDatabase(() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, 'readflex.db'));
  return NativeDatabase.createInBackground(file);
});
