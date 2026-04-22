# book_repository

Domain repository for books. Wraps `BooksDao` from `local_storage` and owns
on-disk storage of book files (epub, fb2, mobi, pdf) and cover images.

Follows the standard repository pattern: receives `AppDatabase` via its
constructor and extracts `booksDao` internally. Storage exceptions are
wrapped into `StorageException` (from `domain_models`) before surfacing.

## On-disk layout

Each book lives in its own directory under the `booksDirectory` passed at
construction. The DB row stores only filenames (`book.epub`, `cover.jpeg`);
this repo resolves them against the per-book directory on every read, so the
data survives iOS Documents-UUID changes.

```
books/<uuid>/
  book.<ext>    — the book file (epub, fb2, mobi, pdf)
  cover.<ext>   — extracted cover image (if available)
```

Read paths returned on domain `Book` objects are absolute (resolved against
the current `booksDirectory`). On update, paths are stripped back to
filenames before being written to the DB.

## Public API

| Method                              | Purpose                                       |
|-------------------------------------|-----------------------------------------------|
| `getBooks({limit, offset})`         | List books ordered by added date              |
| `getBookById(id)`                   | Lookup by id, returns null if missing         |
| `addBook({sourceFile, title, format, author, coverData, ...})` | Copy file in, save cover, insert row |
| `updateBook(book)`                  | Update metadata + reading position            |
| `deleteBook(id)`                    | Delete row + remove per-book directory        |

Cover bytes (`coverData`) are typically produced upstream by
`reader_webview`'s `BookMetadataExtractor`.

## Dependencies

- `domain_models` — `Book`, `BookFormat`, `StorageException`
- `local_storage` — `AppDatabase`, `BooksDao`
- `path`, `uuid`
