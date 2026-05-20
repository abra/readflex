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

/// Single Drift-generated SQLite database (`readflex.db`) holding every
/// table and DAO the app uses. Repositories receive an [AppDatabase] via DI
/// and extract the DAO they need — there are no per-feature databases.
///
/// Schema version lives in [schemaVersion]; all forward migrations are in
/// [migration]. Use [AppDatabase.forTesting] with an in-memory executor to
/// exercise schema + migrations without touching the real app documents
/// directory.
@DriftDatabase(
  tables: [
    ArticlesTable,
    BooksTable,
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
  int get schemaVersion => 18;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createBookmarksTable();
      await _createArticlesIndexes();
      await _createIndexes();
    },
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
        // Rebuild articles_table: cleanedHtml TEXT was replaced by
        // contentPath pointing to a file on disk. Now obsolete (articles
        // are removed in v13), but kept for upgrade fidelity from v5.
        await customStatement('DROP TABLE IF EXISTS articles_table');
        await customStatement('''
          CREATE TABLE articles_table (
            id TEXT NOT NULL PRIMARY KEY,
            title TEXT NOT NULL,
            site_name TEXT,
            url TEXT NOT NULL,
            content_path TEXT NOT NULL,
            cover_image_url TEXT,
            cover_image_path TEXT,
            byline TEXT,
            excerpt TEXT,
            published_time TEXT,
            lang TEXT,
            text_length INTEGER NOT NULL DEFAULT 0,
            estimated_word_count INTEGER NOT NULL DEFAULT 0,
            current_scroll_offset REAL NOT NULL DEFAULT 0.0,
            added_at TEXT NOT NULL,
            last_opened_at TEXT,
            is_finished INTEGER NOT NULL DEFAULT 0
          )
        ''');
      }
      if (from < 7) {
        // articles_table.contentPath / coverImagePath flipped from absolute
        // paths to filenames only. Now obsolete (v13 drops the table).
        await customStatement('DROP TABLE IF EXISTS articles_table');
        await customStatement('''
          CREATE TABLE articles_table (
            id TEXT NOT NULL PRIMARY KEY,
            title TEXT NOT NULL,
            site_name TEXT,
            url TEXT NOT NULL,
            content_path TEXT NOT NULL,
            cover_image_url TEXT,
            cover_image_path TEXT,
            byline TEXT,
            excerpt TEXT,
            published_time TEXT,
            lang TEXT,
            text_length INTEGER NOT NULL DEFAULT 0,
            estimated_word_count INTEGER NOT NULL DEFAULT 0,
            current_scroll_offset REAL NOT NULL DEFAULT 0.0,
            added_at TEXT NOT NULL,
            last_opened_at TEXT,
            is_finished INTEGER NOT NULL DEFAULT 0
          )
        ''');
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
      if (from < 11) {
        // Single index-creation pass. Earlier the same call lived under
        // both `<10` and `<11` guards, so any user upgrading from <10
        // ran it twice. Statements are CREATE INDEX IF NOT EXISTS so
        // the duplicate was idempotent, but the doubled DDL roundtrip
        // and the inverted ordering (the `<9` block sat between the
        // two `_createIndexes` calls) were maintenance landmines.
        await _createIndexes();
      }
      if (from < 12) {
        // Articles used to render through foliate-js with a CFI restore
        // column. Obsolete in v13 but kept here so that upgrades from
        // <12 still execute the historical schema before v13 drops it.
        await customStatement(
          'ALTER TABLE articles_table ADD COLUMN current_cfi TEXT',
        );
      }
      if (from < 13) {
        // Articles feature removed. Drop the table entirely; safe to
        // skip if the user never had article data (e.g. clean install
        // that goes through onCreate instead).
        await customStatement('DROP TABLE IF EXISTS articles_table');
      }
      if (from < 14) {
        // The `txt` format was dropped from BookFormat (foliate-js
        // can't render plain text). Any pre-existing rows with that
        // value would be silently mapped to `epub` by BookFormat.from
        // on read and then fail to open. Drop them so the user sees
        // a clean library instead of a broken row they can't delete.
        await customStatement(
          "DELETE FROM books_table WHERE format = 'txt'",
        );
      }
      if (from < 15) {
        await _createBookmarksTable();
      }
      if (from < 16) {
        await _migrateBookmarksToTextAnchors();
      }
      if (from < 17) {
        await _addBookmarkVisualPageAnchors();
      }
      if (from < 18) {
        await _createArticlesTable();
      }
    },
  );

  Future<void> _createArticlesTable() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS articles_table (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL,
        url TEXT NOT NULL,
        resolved_url TEXT,
        canonical_url TEXT,
        author TEXT,
        site_name TEXT,
        hostname TEXT,
        description TEXT,
        image_url TEXT,
        cover_image_path TEXT,
        language TEXT,
        content_path TEXT NOT NULL,
        plain_text TEXT NOT NULL DEFAULT '',
        text_length INTEGER NOT NULL DEFAULT 0,
        estimated_word_count INTEGER NOT NULL DEFAULT 0,
        current_cfi TEXT,
        reading_progress REAL NOT NULL DEFAULT 0.0,
        added_at TEXT NOT NULL,
        last_opened_at TEXT,
        is_finished INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await _createArticlesIndexes();
  }

  Future<void> _createArticlesIndexes() async {
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_articles_last_opened
      ON articles_table (last_opened_at, added_at)
    ''');
  }

  Future<void> _createBookmarksTable() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS bookmarks_table (
        id TEXT NOT NULL PRIMARY KEY,
        source_id TEXT NOT NULL,
        source_type TEXT NOT NULL,
        cfi TEXT NOT NULL,
        content TEXT NOT NULL,
        progress REAL NOT NULL DEFAULT 0.0,
        chapter_title TEXT,
        anchor_exact TEXT,
        anchor_prefix TEXT,
        anchor_suffix TEXT,
        anchor_section_index INTEGER,
        anchor_section_page INTEGER,
        created_at TEXT NOT NULL
      )
    ''');
    await _createBookmarksIndexes();
  }

  Future<void> _migrateBookmarksToTextAnchors() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS bookmarks_table_v16 (
        id TEXT NOT NULL PRIMARY KEY,
        source_id TEXT NOT NULL,
        source_type TEXT NOT NULL,
        cfi TEXT NOT NULL,
        content TEXT NOT NULL,
        progress REAL NOT NULL DEFAULT 0.0,
        chapter_title TEXT,
        anchor_exact TEXT,
        anchor_prefix TEXT,
        anchor_suffix TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await customStatement('''
      INSERT OR IGNORE INTO bookmarks_table_v16
        (id, source_id, source_type, cfi, content, progress, chapter_title,
         anchor_exact, anchor_prefix, anchor_suffix, created_at)
      SELECT id, source_id, source_type, cfi, content, progress, chapter_title,
             NULL, NULL, NULL, created_at
      FROM bookmarks_table
    ''');
    await customStatement('DROP TABLE IF EXISTS bookmarks_table');
    await customStatement(
      'ALTER TABLE bookmarks_table_v16 RENAME TO bookmarks_table',
    );
    await _createBookmarksIndexes();
  }

  Future<void> _addBookmarkVisualPageAnchors() async {
    await customStatement(
      'ALTER TABLE bookmarks_table ADD COLUMN anchor_section_index INTEGER',
    );
    await customStatement(
      'ALTER TABLE bookmarks_table ADD COLUMN anchor_section_page INTEGER',
    );
  }

  Future<void> _createBookmarksIndexes() async {
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_bookmarks_source_progress
      ON bookmarks_table (source_id, progress)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_bookmarks_source_cfi
      ON bookmarks_table (source_id, cfi)
    ''');
  }

  Future<void> _createIndexes() async {
    // Composite indexes for the hot-path review_items queries:
    // dueItemsBySource(sourceId, nextReviewAt) and dueItems(itemType, nextReviewAt).
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_review_items_source_next
      ON review_items_table (source_id, next_review_at)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_review_items_type_next
      ON review_items_table (item_type, next_review_at)
    ''');
    // FK lookup indexes — highlightsBySource / flashcardsByDeck / entriesBySource
    // scan these columns on every source/deck filter.
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_highlights_source
      ON highlights_table (source_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_flashcards_deck
      ON flashcards_table (deck_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_dictionary_source
      ON dictionary_table (source_id)
    ''');
  }
}

LazyDatabase _openConnection() => LazyDatabase(() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, 'readflex.db'));
  return NativeDatabase.createInBackground(file);
});
