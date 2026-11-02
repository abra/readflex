# dictionary_repository

Domain repository for dictionary entries — saved words, phrases, and idioms
captured from the reader or added manually.

Follows the standard repository pattern: receives `AppDatabase` via its
constructor and extracts `dictionaryDao` internally. Storage exceptions are
wrapped into `StorageException` (from `domain_models`) before surfacing.

## Public API

| Method                                      | Purpose                                       |
|---------------------------------------------|-----------------------------------------------|
| `getEntries()`                              | All entries ordered by added date             |
| `getEntriesBySource(sourceId)`              | Entries belonging to a source                 |
| `getEntryById(id)`                          | Lookup by id                                  |
| `getEntriesByIds(ids)`                      | Batch lookup                                  |
| `getEntryCountBySource(sourceId)`           | Count entries saved from one source           |
| `getAnchorsBySource(sourceId)` / `getAnchorsByEntry(entryId)` | Source locations for saved entries |
| `addEntry({word, translation, lemma, baseTranslation, contextTranslation, pronunciation, partOfSpeech, context, sourceId, sourceType, usageExamples, anchor…})` | Create entry and its review row |
| `addAnchor({entryId, sourceId, sourceType, text, cfiRange, ...})` | Attach another source location to an entry |
| `deleteAnchorsBySource(sourceId)`           | Remove source locations while retaining entries |
| `findEntry(word, {sourceId})`              | Newest entry for a word, case-insensitive  |
| `getEntryCount()`                           | Every saved word                              |
| `updateEntry(entry)`                        | Update fields                                 |
| `deleteEntry(id)`                           | Delete entry                                  |
| `changes`                                   | Broadcast stream after entry or anchor mutations |
| `dispose()`                                 | Close the repository change stream            |

Entries carry optional `sourceId` + `sourceType` so they can be filtered by
the reading session that produced them (see `features/practice`).

`findEntry` uses an indexed Unicode lowercase key maintained by `DictionaryDao`
on insert and word edits. It recognizes capitalized Cyrillic and accented words,
keeps the original spelling, and returns the newest match within the optional
source scope. Schema v27 backfills keys for already saved entries.

`changes` exists for cross-feature freshness. For example, the translate sheet
can save an entry while Practice's Vocabulary list is already mounted; the list listens
to this stream and reloads without depending on the translate feature.

`addEntry` stores its optional source anchor in the same transaction as the
entry and review row when source id/type, anchor text and CFI are present.
Anchors live separately from entries so deleting a source can remove its
underlines while retaining saved words.

## Review state

Dictionary entries are reviewable, but this repo does not track FSRS state.
Scheduling and review state live in `fsrs_repository`, one centralized FSRS
store for highlights and dictionary entries. `addEntry` registers the review
row in the same transaction (insert-or-ignore, so re-saving never resets
scheduling) and `deleteEntry` removes it, so due-item queries cannot surface
removed dictionary entries.

## Dependencies

- `domain_models` — `DictionaryEntry`, `SourceType`, `StorageException`
- `local_storage` — `AppDatabase`, `DictionaryDao`
- `uuid`
