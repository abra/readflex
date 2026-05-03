# highlight_repository

Domain repository for text highlights captured from books.

Follows the standard repository pattern: receives `AppDatabase` via its
constructor and extracts `highlightsDao` internally. Storage exceptions are
wrapped into `StorageException` (from `domain_models`) before surfacing.

## Public API

| Method                                                        | Purpose                                |
|---------------------------------------------------------------|----------------------------------------|
| `getHighlights()`                                             | All highlights                         |
| `getHighlightsBySource(sourceId)`                             | Highlights from one book               |
| `getHighlightById(id)`                                        | Lookup by id                           |
| `getHighlightsByIds(ids)`                                     | Batch lookup                           |
| `addHighlight({sourceId, sourceType, text, note, cfiRange, color})` | Create highlight                 |
| `updateHighlight(highlight)`                                  | Update fields                          |
| `deleteHighlight(id)`                                         | Delete by id                           |
| `deleteHighlightsBySource(sourceId)`                          | Cascade delete when a source is removed|

A highlight is anchored by an EPUB `cfiRange` (via foliate-js), with an
optional `note` and a `HighlightColor`.

> The storage row also carries vestigial `pageNumber` and `scrollOffset`
> columns from the removed article reader. They are no longer written by
> the repository and will be dropped in a future schema migration.

## Review state

Highlights are reviewable (Readwise-style), but this repo does not track
FSRS state. Scheduling and review state live in `fsrs_repository` — one
centralized FSRS store for flashcards, highlights, and dictionary entries.

## Dependencies

- `domain_models` — `Highlight`, `HighlightColor`, `SourceType`, `StorageException`
- `local_storage` — `AppDatabase`, `HighlightsDao`
- `uuid`
