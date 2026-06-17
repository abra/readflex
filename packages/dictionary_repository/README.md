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
| `addEntry({word, translation, pronunciation, partOfSpeech, context, sourceId, sourceType, usageExamples})` | Create entry |
| `updateEntry(entry)`                        | Update fields                                 |
| `deleteEntry(id)`                           | Delete entry                                  |
| `changes`                                   | Broadcast stream after add/update/delete      |
| `dispose()`                                 | Close the repository change stream            |

Entries carry optional `sourceId` + `sourceType` so they can be filtered by
the reading session that produced them (see `features/practice`).

`changes` exists for cross-feature freshness. For example, the translate sheet
can save an entry while the Dictionary tab is already mounted; the tab listens
to this stream and reloads without depending on the translate feature.

## Review state

Dictionary entries are reviewable, but this repo does not track FSRS state.
Scheduling and review state live in `fsrs_repository` — one centralized FSRS
store for flashcards, highlights, and dictionary entries. Deleting an entry here
also deletes its FSRS review row in one database transaction so due-item queries
cannot surface removed dictionary entries.

## Dependencies

- `domain_models` — `DictionaryEntry`, `SourceType`, `StorageException`
- `local_storage` — `AppDatabase`, `DictionaryDao`
- `uuid`
