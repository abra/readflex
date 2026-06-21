# local_storage

Single Drift database for the whole app. All tables, DAOs, schema, and
migrations live here. Repositories receive one `AppDatabase` instance
from the DI container and extract the DAO they need.

File on disk: `readflex.db` in the application documents directory.

---

## Public API

Barrel exports `AppDatabase` and every DAO:

| Symbol            | Kind       | Purpose                                                |
|-------------------|------------|--------------------------------------------------------|
| `AppDatabase`     | class      | The single Drift database (`@DriftDatabase`)           |
| `BooksDao`        | DAO        | CRUD for books                                         |
| `ArticlesDao`     | DAO        | CRUD for saved web articles                            |
| `HighlightsDao`   | DAO        | CRUD for highlights                                    |
| `FlashcardsDao`   | DAO        | CRUD for flashcards                                    |
| `DictionaryDao`   | DAO        | CRUD for dictionary entries                            |
| `ReviewItemsDao`  | DAO        | CRUD for the centralized FSRS `review_items_table`     |

Generated Drift data classes (`BooksTableData`, `HighlightsTableData`, …)
and companions are also reachable through the DAO exports.

`FlashcardsDao`, `DictionaryDao`, and `ReviewItemsDao` are dormant in the
current app surface. They remain exported so existing databases keep migrating
cleanly and the frozen learning features can be restored from history without a
destructive schema reset.

---

## Tables

```
books_table              articles_table          highlights_table
flashcards_table         dictionary_table        review_items_table
review_logs_table        bookmarks_table
```

All FSRS state (stability, difficulty, due date, reps, lapses) is
centralized in `review_items_table`, keyed by `(item_id, item_type)`.
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

`articles_table` stores saved web-article metadata and reader state. Heavy
article payloads stay on disk under `articles/<id>/`; the row stores local
filenames/paths plus extracted metadata such as language, author, site, CFI,
and reading progress. Older migrations still contain the historical
article-table removal step from v13; v18 creates the current article schema.

## Migrations

Schema version is bumped on every change. `MigrationStrategy.onUpgrade`
in `database.dart` handles each step with `ALTER TABLE` / `CREATE
TABLE` statements. Indexes are rebuilt via `_createIndexes()` at
`onCreate` and whenever a migration touches query paths.

---

## Usage

Repositories receive `AppDatabase` and extract their DAO:

```dart
class BookRepository {
  BookRepository({required AppDatabase database})
      : _dao = database.booksDao;

  final BooksDao _dao;

  Future<List<Book>> allBooks() async {
    try {
      final rows = await _dao.allBooks();
      return rows.map((r) => r.toDomain()).toList();
    } on Exception catch (e) {
      throw StorageException(cause: e);
    }
  }
}
```

The DI container constructs `AppDatabase` once and hands it to every
repository:

```dart
// composition.dart
final database = AppDatabase();
return DependenciesContainer(
  bookRepository: BookRepository(database: database),
  highlightRepository: HighlightRepository(database: database),
  // ...
);
```

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
local_storage → drift, sqlite3_flutter_libs, path_provider, path
        ▲
        │
        └── article_repository, book_repository, highlight_repository
```

No feature package ever imports `local_storage` directly — features go
through a repository.

---

## Rules

- One database, one file, one schema version. Never spin up a second
  `AppDatabase` instance at runtime.
- Tables stay here. Domain types stay in `domain_models`. Mapping lives
  in the repository that owns the domain concept.
- Every schema change bumps `schemaVersion` and adds an `if (from < N)`
  branch. Never edit a past migration.
- Hot-path queries get a matching index in `_createIndexes()` or beside the
  custom table setup that owns them.
