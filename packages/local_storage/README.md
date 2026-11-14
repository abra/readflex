# local_storage

Single Drift database for the whole app. All tables, DAOs, schema, and
migrations live here. Repositories receive one `AppDatabase` instance
from the DI container and extract the DAO they need.

File on disk: `readflex.db` in the application documents directory, opened in
a background isolate with write-ahead logging and `synchronous = NORMAL`
(`configureAppDatabaseConnection`): a commit, such as a reading position
save, appends to `readflex.db-wal` without a per-commit fsync. A power loss can
drop recent commits; this setting does not provide full commit durability.
Anything that copies the
database must checkpoint first or copy the `-wal` file too.

---

## Public API

Barrel exports `AppDatabase` and every DAO:

| Symbol            | Kind       | Purpose                                                |
|-------------------|------------|--------------------------------------------------------|
| `AppDatabase`     | class      | The single Drift database (`@DriftDatabase`)           |
| `BooksDao`        | DAO        | CRUD for books                                         |
| `ArticlesDao`     | DAO        | CRUD for saved web articles                            |
| `CollectionsDao`  | DAO        | CRUD for collections and source memberships            |
| `HighlightsDao`   | DAO        | CRUD for highlights                                    |
| `FlashcardsDao`   | DAO        | CRUD for flashcards                                    |
| `DictionaryDao`   | DAO        | CRUD for dictionary entries                            |
| `ReviewItemsDao`  | DAO        | CRUD for the centralized FSRS `review_items_table`     |

Generated Drift data classes (`BooksTableData`, `HighlightsTableData`, …)
and companions are also reachable through the DAO exports.

`DictionaryDao` and `ReviewItemsDao` back saved words and spaced review
(`dictionary_repository`, `fsrs_repository`). `FlashcardsDao` is dormant: it
remains exported so existing databases keep migrating cleanly and the frozen
flashcard feature can be restored from history without a destructive schema
reset.

`ReviewItemsDao.reviewQueueStatus` reads the due count and earliest future
deadline in one SQL snapshot at a supplied UTC time. Separate aggregate
subqueries let the existing type/deadline index restrict each lookup. An
explicit set of types filters both values; an empty set returns an empty
queue. It reads no review history and requires no schema change.

`ReviewItemsDao.dueItems` and `dueItemsBySource` also accept sets of types and
FSRS states, applied before SQL pagination. `backfillTextHighlights` inserts only
missing text-highlight review rows in one SQL statement using the review table's item-ID
primary key. App composition awaits this compatibility repair once at startup;
screen loading performs no repair writes. Existing schedules remain unchanged.
`DictionaryDao.entryExists` and `HighlightsDao.textHighlightExists` select only
the ID so transactional review validation never loads translation or quotation
bodies.

`DictionaryDao.firstAnchorsByEntries` selects only the oldest anchor for each
requested entry, with insertion order breaking equal timestamps. It deduplicates
IDs and binds at most 500 per statement, below SQLite's 999-parameter baseline.
Vocabulary and review loading use this bounded lookup rather than individual
anchor reads; it uses the existing entry index and requires no schema change.

Schema v27 adds the indexed `dictionary_table.word_key`. `DictionaryDao`
normalizes both saved words and lookup terms with Dart's Unicode lowercase
conversion and trimming; insert and rename keep the key current. Migration
backfills existing words with the same function without changing their display
text, meanings, anchors or review state.

Schema v26 adds `dictionary_table.lemma`, `base_translation` and
`context_translation`: the dictionary form, the word's own meaning and the
sentence translation a saved word keeps beside its meaning in context.

Schema v25 adds `bookmarks_table.anchor_version`. The reader sets it when a
bookmark's CFI and quote come from a word on the bookmarked page, so they stay
valid after font, margin or column changes repaginate the chapter. Older rows
keep `NULL`: their CFI and quote may point to the middle of the chapter, and
readers navigate them by the visual page anchor as before.

Schema v24 rebuilds `articles_table` with `plain_text` as its last column.
SQLite reads a row's columns in order, so with the article text in the middle
the Library's metadata query walked every article's overflow pages to reach
`added_at` or `is_finished` (5.9ms instead of 1.4ms for 1000 articles of 16KB
on a warm cache, and the whole text from disk on a cold one). Keep long
columns last when adding new ones.

Schema v23 adds `books_table.comic_page_order_version` with a legacy default of
0. Only new CBZ imports use version 1; migration leaves saved page anchors and
annotation indices untouched. Source repositories remove collection memberships
in the same transaction as the book/article row.

---

## Tables

```
books_table              articles_table          highlights_table
flashcards_table         dictionary_table        review_items_table
review_logs_table        bookmarks_table         dictionary_anchors_table
collections_table        collection_sources_table
```

All FSRS state (stability, difficulty, due date, reps, lapses) is
centralized in `review_items_table`, keyed by `item_id`, with `item_type`
identifying the content kind. Reviewable content IDs must be globally unique.
Entity tables (flashcards/highlights/dictionary) hold only domain
fields; nothing reviewable is duplicated across tables. This was the
v3→v4 migration — see the comment in `database.dart`.

`highlights_table` stores both text and image-page highlights. Text highlights
use `cfi_range`; image-page highlights use `kind = imageArea`,
`image_page_index`, and normalized rectangle columns. Repositories expose this
as one `Highlight` domain model with `HighlightKind`.

`bookmarks_table` is a small custom-SQL table owned by `BookRepository`
rather than a generated DAO because bookmark operations are source-scoped and
do not need cross-feature query composition yet. It stores both the navigation
CFI plus optional text and visual-page anchor fields so readers can
distinguish pages when a book format reports coarse section-level CFI values.

`articles_table` stores saved web-article metadata, reader state and the complete
extracted `plain_text`. Structured JSON, generated reader HTML and images live
on disk under `articles/<id>/`; the row stores their filenames/paths plus
language, author, site, CFI and reading progress. Metadata-only Library queries
exclude `plain_text`; full article reads include it. Upgrades from the historical
v5-v12 article schemas migrate rows directly into the current table. Inline v5
HTML, v6 absolute paths, and later filename-only layouts are copied into the
current per-article directory instead of being deleted.

`collections_table` stores manual collection metadata;
`collection_sources_table` stores manual and protected favourites membership.
Smart author/site collections are derived by the Library feature and are not
persisted. `dictionary_anchors_table` stores source-specific text anchors for
saved words. `DictionaryDao` removes those anchors when their entry is deleted
or their source is deleted or detached; the saved word may outlive its source.

## Migrations

Schema version is bumped on every change. `MigrationStrategy.onUpgrade`
in `database.dart` handles each step with `ALTER TABLE` / `CREATE
TABLE` statements. Indexes are rebuilt via `_createIndexes()` at
`onCreate` and whenever a migration touches query paths.

Migration tests open file-backed SQLite fixtures at representative historical
versions. Any change to an upgrade path must preserve those fixtures and add a
new one when a schema shape changes.

---

## Usage

Repositories receive `AppDatabase` and extract their DAO:

`BookRepository` calls `database.booksDao.allBooks()` and maps each row with
`toDomainModel(booksDir: ...)`, resolving filenames against its managed book
directory. It wraps storage failures in `StorageException`.

Composition constructs `AppDatabase` once and hands it to repositories. The
essential setup is:

```dart
// composition.dart
final database = AppDatabase();
final bookRepository = BookRepository(
  database: database,
  booksDirectory: booksDir, // App documents/books directory from composition.
);
final highlightRepository = HighlightRepository(database: database);
```

The application's resource disposer owns `database.close`; individual
repositories must not close this shared database.

Tests use `AppDatabase.forTesting(NativeDatabase.memory())` with an
in-memory executor.

---

## Responsibilities

**`local_storage` owns:**
- Schema (table definitions)
- Migrations (`onCreate`, `onUpgrade`)
- Indexes
- Raw CRUD via DAOs
- Generated Drift data classes

**Repositories own:**
- Domain logic
- Storage ↔ domain mappers (extension methods in `mappers/`)
- Wrapping storage errors into `StorageException` / `NotFoundException`

---

## Where it fits

```
local_storage → flutter, drift, sqlite3, sqlite3_flutter_libs, path_provider, path
        ▲
        │
        └── article_repository, book_repository, collection_repository,
            dictionary_repository, fsrs_repository, highlight_repository
```

No feature package ever imports `local_storage` directly — features go
through a repository.

---

## Code generation

Dependencies and generator versions are pinned by the repository's shared
workspace lockfile. `drift_dev` stays on the locked runtime's 2.34 API family;
update the runtime and generator together. Workspace tests guard this pairing,
since a newer generator can reference manager APIs absent from an older runtime.
After editing tables or DAOs, run from this package:

```sh
fvm dart run build_runner build
```

Generation stays scoped to `local_storage`; the experimental multi-package
`--workspace` builder mode is not required. Review generated Dart changes with
the schema/migration change, then run this package's tests. A normal checkout
already contains the generated files and does not need regeneration to run.

## Rules

- One database, one file, one schema version. Never spin up a second
  `AppDatabase` instance at runtime.
- Tables stay here. Domain types stay in `domain_models`. Mapping lives
  in the repository that owns the domain concept.
- Every current-schema change bumps `schemaVersion` and adds an
  `if (from < N)` branch. Historical migration behavior may be corrected only
  to prevent data loss, with file-backed tests for every affected source shape.
- Hot-path queries get a matching index in `_createIndexes()` or beside the
  custom table setup that owns them.
