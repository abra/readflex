# highlight_repository

Domain repository for text highlights captured from books and articles.

Follows the standard repository pattern: receives `AppDatabase` via its
constructor and extracts `highlightsDao` internally. Storage exceptions are
wrapped into `StorageException` (from `domain_models`) before surfacing.

## Public API

| Method                                                        | Purpose                                |
|---------------------------------------------------------------|----------------------------------------|
| `getHighlights()`                                             | All highlights                         |
| `getHighlightsBySource(sourceId)`                             | Highlights from one book or article    |
| `getHighlightById(id)`                                        | Lookup by id                           |
| `getHighlightsByIds(ids)`                                     | Batch lookup                           |
| `addHighlight({sourceId, sourceType, text, note, cfiRange, pageNumber, scrollOffset, color})` | Create highlight |
| `updateHighlight(highlight)`                                  | Update fields                          |
| `deleteHighlight(id)`                                         | Delete by id                           |
| `deleteHighlightsBySource(sourceId)`                          | Cascade delete when a source is removed|

A highlight carries either `cfiRange` (books, via foliate-js) or
`scrollOffset` + `pageNumber` (articles), plus an optional `note` and a
`HighlightColor`.

## Review state

Highlights are reviewable (Readwise-style), but this repo does not track
FSRS state. Scheduling and review state live in `fsrs_repository` — one
centralized FSRS store for flashcards, highlights, and dictionary entries.

## Dependencies

- `domain_models` — `Highlight`, `HighlightColor`, `SourceType`, `StorageException`
- `local_storage` — `AppDatabase`, `HighlightsDao`
- `uuid`
