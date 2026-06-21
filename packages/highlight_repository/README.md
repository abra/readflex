# highlight_repository

Domain repository for highlights captured from reading sources.

Follows the standard repository pattern: receives `AppDatabase` via its
constructor and extracts `highlightsDao` internally. Storage exceptions are
wrapped into `StorageException` (from `domain_models`) before surfacing.

## Public API

| Method                                                        | Purpose                                |
|---------------------------------------------------------------|----------------------------------------|
| `getHighlights()`                                             | All highlights                         |
| `getHighlightsBySource(sourceId)`                             | Highlights from one source             |
| `getHighlightById(id)`                                        | Lookup by id                           |
| `getHighlightsByIds(ids)`                                     | Batch lookup                           |
| `addHighlight({sourceId, sourceType, text, note, cfiRange, color})` | Create text highlight            |
| `addImageAreaHighlight({sourceId, sourceType, pageIndex, x, y, width, height, color})` | Create image-page area highlight |
| `updateHighlight(highlight)`                                  | Update fields                          |
| `deleteHighlight(id)`                                         | Delete by id                           |
| `deleteHighlightsBySource(sourceId)`                          | Cascade delete when a source is removed|

Text highlights are anchored by `cfiRange` (via foliate-js). Comic/image-page
highlights are anchored by a zero-based `pageIndex` plus normalized rectangle
coordinates. Both kinds share optional `note` and `HighlightColor`.

> The storage row also carries legacy `pageNumber` and `scrollOffset`
> columns for old rows and tests. Current reader selections primarily use
> `cfiRange`.

## Dependencies

- `domain_models` — `Highlight`, `HighlightColor`, `SourceType`, `StorageException`
- `local_storage` — `AppDatabase`, `HighlightsDao`
- `uuid`
