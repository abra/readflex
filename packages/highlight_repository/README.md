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
| `addImageAreaHighlight({sourceId, sourceType, pageIndex, x, y, width, height, note, color})` | Create image-page area highlight |
| `updateHighlight(highlight)`                                  | Replace a complete snapshot             |
| `updateHighlightColor(id, color)`                              | Atomically patch only the color         |
| `updateHighlightNote(id, note)`                                | Atomically patch/clear only the note    |
| `deleteHighlight(id)`                                         | Delete by id                           |
| `deleteHighlightsBySource(sourceId)`                          | Cascade delete when a source is removed|

The `cfiRange` field holds an EPUB CFI for books or a serialized
`readflex-html-position:` anchor for articles; it is not always an EPUB CFI.
Comic/image-page
highlights are anchored by a zero-based `pageIndex` plus normalized rectangle
coordinates. Both kinds share optional `note` and `HighlightColor`.

`addHighlight` accepts `replaceHighlightIds` from the reader's DOM containment
check. Saving a wider selection replaces fully absorbed text highlights and
their review rows in one transaction, scoped to the same source and source type.
Partial overlaps are not replacement candidates. An equal anchor and text among
those candidates updates the existing color instead of creating a duplicate;
its ID, note (unless explicitly supplied), metadata and review state survive.
Selecting or translating text alone never invokes this replacement path.

Editors should use the field-specific methods: one SQL UPDATE, no read/modify/
write of stale fields and no schema change. Patches preserve anchors, metadata,
and independent edits; a missing row raises `StorageException` instead of
silently reporting success or recreating a deleted highlight.

> The storage row also carries legacy `pageNumber` and `scrollOffset`
> columns for old rows and tests. Current reader selections primarily use
> `cfiRange`.

## Dependencies

- `domain_models` — `Highlight`, `HighlightColor`, `SourceType`, `StorageException`
- `local_storage` — `AppDatabase`, `HighlightsDao`
- `uuid`
