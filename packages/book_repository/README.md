# book_repository

Domain repository for reading sources. Wraps `BooksDao` from `local_storage`,
owns on-disk storage of book/comic files (epub, fb2, mobi, pdf, azw3, cbz)
and cover images, and stores source-scoped bookmarks.

Follows the standard repository pattern: receives `AppDatabase` via its
constructor and extracts `booksDao` internally. Storage exceptions are
wrapped into `StorageException` (from `domain_models`) before surfacing.

## On-disk layout

Each book lives in its own directory under the `booksDirectory` passed at
construction. The DB row stores only filenames (`book.epub`, `cover.jpeg`);
this repo resolves them against the per-book directory on every read, so the
data survives iOS Documents-UUID changes.

New CBZ imports store `comicPageOrderVersion: 1`: the reader ignores macOS
metadata entries, accepts image extensions case-insensitively and sorts numeric
filename parts naturally. Existing rows retain version 0 and their original
page indices so CFI, bookmarks and image highlights do not silently move.
Reading an old comic does not migrate or repair its page order.

```
books/<uuid>/
  book.<ext>    — the source file (epub, fb2, mobi, pdf, azw3, cbz)
  cover.<ext>   — extracted cover image (if available)
```

Read paths returned on domain `Book` objects are absolute (resolved against
the current `booksDirectory`). On update, paths are stripped back to
filenames before being written to the DB.

## Public API

| Method                              | Purpose                                       |
|-------------------------------------|-----------------------------------------------|
| `getBooks({limit, offset})`         | List books ordered by most-recently opened, then added date |
| `getBookById(id)`                   | Lookup by id, returns null if missing         |
| `addBook({sourceFile, title, format, author, coverData, ...})` | Copy file in, save cover, insert row |
| `updateBook(book)`                  | Update metadata + reading position            |
| `updateReadingPosition(id, {cfi, progress})` | Update only CFI/progress without replacing metadata |
| `markOpened(id, openedAt)`          | Update only the last-opened timestamp |
| `getBookmarksBySource(sourceId)`    | List saved positions for a source in reading order |
| `addBookmark({sourceId, cfi, content, progress, anchorExact, anchorSectionPage, ...})` | Save a source position, idempotent by visual/text anchor when present |
| `deleteBookmarkById(sourceId, bookmarkId)` | Remove one saved bookmark precisely |
| `restoreBookmark(bookmark)` | Restore the original identity/date/full anchor, or return an existing bookmark at that anchor |
| `deleteBookmarkBySourceAndCfi(sourceId, cfi)` | Legacy fallback removal by CFI |
| `deleteBook(id, {scope})`           | Delete row + remove per-book directory; optionally preserve learning data |

Cover bytes (`coverData`) are typically produced upstream by
`reader_webview`'s `BookMetadataExtractor`.

Bookmark restoration checks source existence, detects an already recreated
anchor and inserts in one transaction. It never recreates a deleted book/article
or replaces a newer bookmark at the same location. The reader owns the temporary
Undo state; no schema migration or persistent deletion queue is required.

Reader writes use partial Drift companions, not a previously read `Book`
snapshot. Concurrent metadata/finished-state edits survive position saves.
Both partial updates are no-ops if the row has already been deleted; they do
not recreate a source. Callers retain responsibility for ordering position
writes and awaiting them on close.

Deletion removes collection memberships inside the source transaction, including
the `keepLearningData` mode. Filesystem cleanup runs only after commit.
Progress-reporting imports use `IOSink.addStream` to propagate backpressure;
imports without a progress callback retain the native `File.copy` path.

## Dependencies

- `domain_models` — `Book`, `BookFormat`, `StorageException`
- `local_storage` — `AppDatabase`, `BooksDao`
- `path`, `uuid`
