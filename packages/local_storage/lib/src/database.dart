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
import 'daos/review_items_dao.dart';
import 'tables/articles_table.dart';
import 'tables/books_table.dart';
import 'tables/dictionary_table.dart';
import 'tables/flashcards_table.dart';
import 'tables/highlights_table.dart';
import 'tables/review_items_table.dart';
import 'tables/review_logs_table.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    BooksTable,
    ArticlesTable,
    HighlightsTable,
    FlashcardsTable,
    DictionaryTable,
    ReviewItemsTable,
    ReviewLogsTable,
  ],
  daos: [
    ArticlesDao,
    BooksDao,
    HighlightsDao,
    FlashcardsDao,
    DictionaryDao,
    ReviewItemsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @visibleForTesting
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 9;

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
      if (from < 4) {
        // Normalize FSRS state out of per-entity tables into a single
        // review_items_table. Motivation: FSRS fields were duplicated across
        // flashcards / highlights / dictionary, each with its own schema and
        // its own mapper. A single table lets FsrsRepository operate
        // generically over any ReviewableType, enables cross-type queries
        // (due items, mastered items, logs) with a single join, and makes
        // adding new reviewable types a one-line change instead of a
        // migration per table.
        await customStatement('''
          CREATE TABLE IF NOT EXISTS review_items_table (
            item_id TEXT NOT NULL PRIMARY KEY,
            item_type TEXT NOT NULL,
            source_id TEXT,
            fsrs_state TEXT NOT NULL DEFAULT 'new',
            stability REAL NOT NULL DEFAULT 0.0,
            difficulty REAL NOT NULL DEFAULT 0.0,
            retrievability REAL NOT NULL DEFAULT 0.0,
            reps INTEGER NOT NULL DEFAULT 0,
            lapses INTEGER NOT NULL DEFAULT 0,
            last_review_at TEXT,
            next_review_at TEXT,
            scheduled_days INTEGER NOT NULL DEFAULT 0,
            elapsed_days INTEGER NOT NULL DEFAULT 0
          )
        ''');

        // Migrate existing FSRS data from flashcards.
        await customStatement('''
          INSERT OR IGNORE INTO review_items_table
            (item_id, item_type, source_id, fsrs_state, stability, difficulty,
             retrievability, reps, lapses, last_review_at, next_review_at,
             scheduled_days, elapsed_days)
          SELECT id, 'flashcard', deck_id, fsrs_state, stability, difficulty,
                 retrievability, reps, lapses, last_review_at, next_review_at,
                 scheduled_days, elapsed_days
          FROM flashcards_table
        ''');

        // Migrate from highlights.
        await customStatement('''
          INSERT OR IGNORE INTO review_items_table
            (item_id, item_type, source_id, fsrs_state, stability, difficulty,
             retrievability, reps, lapses, last_review_at, next_review_at,
             scheduled_days, elapsed_days)
          SELECT id, 'highlight', source_id, fsrs_state, stability, difficulty,
                 retrievability, reps, lapses, last_review_at, next_review_at,
                 scheduled_days, elapsed_days
          FROM highlights_table
        ''');

        // Migrate from dictionary.
        await customStatement('''
          INSERT OR IGNORE INTO review_items_table
            (item_id, item_type, source_id, fsrs_state, stability, difficulty,
             retrievability, reps, lapses, last_review_at, next_review_at,
             scheduled_days, elapsed_days)
          SELECT id, 'dictionary', source_id, fsrs_state, stability, difficulty,
                 retrievability, reps, lapses, last_review_at, next_review_at,
                 scheduled_days, elapsed_days
          FROM dictionary_table
        ''');

        // Drop FSRS columns from entity tables (SQLite 3.35+).
        for (final table in [
          'flashcards_table',
          'highlights_table',
          'dictionary_table',
        ]) {
          for (final col in [
            'fsrs_state',
            'stability',
            'difficulty',
            'retrievability',
            'reps',
            'lapses',
            'last_review_at',
            'next_review_at',
            'scheduled_days',
            'elapsed_days',
          ]) {
            await customStatement('ALTER TABLE $table DROP COLUMN $col');
          }
        }
      }
      if (from < 5) {
        // Extend articles_table with readability-derived metadata columns.
        // All new columns are nullable or defaulted so existing rows remain
        // valid without backfill.
        await customStatement(
          'ALTER TABLE articles_table ADD COLUMN byline TEXT',
        );
        await customStatement(
          'ALTER TABLE articles_table ADD COLUMN excerpt TEXT',
        );
        await customStatement(
          'ALTER TABLE articles_table ADD COLUMN published_time TEXT',
        );
        await customStatement(
          'ALTER TABLE articles_table ADD COLUMN lang TEXT',
        );
        await customStatement(
          'ALTER TABLE articles_table ADD COLUMN text_length INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (from < 6) {
        // Rebuild articles_table: cleanedHtml TEXT is replaced by contentPath
        // pointing to a file on disk, and coverImagePath is added for locally
        // cached covers. No real article data exists yet (articles were only
        // produced by the stub parser), so we drop and recreate instead of
        // carrying a conversion step.
        await customStatement('DROP TABLE IF EXISTS articles_table');
        await migrator.createTable(articlesTable);
      }
      if (from < 7) {
        // articles_table.contentPath / coverImagePath flip from absolute
        // paths to filenames only. ArticleRepository now resolves them
        // against the current articles/covers directories on every read,
        // so the DB survives iOS Documents-UUID changes between simulator
        // reinstalls. Same rationale as the v5→v6 rebuild: article data is
        // still dev-only, so a drop+recreate is cheaper than writing a
        // path-stripping migration.
        await customStatement('DROP TABLE IF EXISTS articles_table');
        await migrator.createTable(articlesTable);
      }
      if (from < 8) {
        // Add normalized reading_progress to articles, mirroring
        // books_table. Purely additive with a 0.0 default — no backfill
        // needed. See Article.readingProgress doc for why this is kept
        // separate from the existing current_scroll_offset column.
        await customStatement(
          'ALTER TABLE articles_table ADD COLUMN reading_progress REAL NOT NULL DEFAULT 0.0',
        );
      }
      if (from < 9) {
        // Reverse v8. `reading_progress` turned out to be a duplicate of
        // the existing `current_scroll_offset` — for articles the reader
        // already stores a normalized [0, 1] fraction in that column (see
        // ArticleContentView.onScrollFractionChanged), not a raw pixel
        // offset as the name implies. A second column holding the same
        // value was pure waste, so we drop it and let the library cover
        // read from `current_scroll_offset` directly. Books are unaffected
        // — they still have their own `reading_progress` column because
        // their restore key (`current_location`) is a different type.
        //
        // DROP COLUMN works on SQLite 3.35+. This ships both to users who
        // are upgrading straight from v7 (they never saw the column) and
        // to those who ran v8 once — idempotent either way since v8 runs
        // first in the same transaction when upgrading from <8.
        await customStatement(
          'ALTER TABLE articles_table DROP COLUMN reading_progress',
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
