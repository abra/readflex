# dictionary

Dictionary tab: browser for words and phrases the user has saved from the
translate sheet. Read-only list with search and per-entry expansion —
review of dictionary entries happens through the `practice` feature, not
here.

## Public API

| Symbol             | Kind              | Purpose                                        |
|--------------------|-------------------|------------------------------------------------|
| `DictionaryScreen` | `StatelessWidget` | The Dictionary tab at `/dictionary`            |

### DictionaryScreen

Props:

| Prop                   | Type                    | Purpose                                 |
|------------------------|-------------------------|-----------------------------------------|
| `dictionaryRepository` | `DictionaryRepository`  | Source of saved entries                 |
| `fsrsRepository`       | `FsrsRepository`        | Resolves per-entry "mastered" badges    |
| `bookRepository`       | `BookRepository?`       | Optional source title lookup for books  |
| `articleRepository`    | `ArticleRepository?`    | Optional source title lookup for articles |

## Architecture

- `DictionaryBloc` — primary events:
  - `DictionaryLoadRequested` — fetches entries + mastered IDs in
    parallel on tab open and after deletions.
  - `DictionarySearchChanged` — debounced 300 ms; updates
    `searchQuery`, which feeds the `filteredEntries` getter on state.
  - `DictionaryFilterChanged` — switches the all/words/phrases filter.
  - `DictionaryEntryAdded` — creates a manual entry and reloads.
  - `DictionaryEntryDeleted` — removes the entry and its FSRS review
    row, then reloads.
  - `DictionaryEntriesDeleted` — deletes a selected batch and continues
    past per-entry failures so the UI can show accurate feedback.
- `DictionaryState` — exposes `entries`, `searchQuery`, `masteredIds`,
  `filter`, source titles, and deletion effects, plus the derived
  `filteredEntries`, `masteredCount`, and `isMastered(id)` helpers consumed
  by the view.

The bloc subscribes to `DictionaryRepository.changes`. External writes, such as
saves from the reader translate sheet, reload the tab automatically. Writes
initiated by this bloc suppress that stream notification because their handlers
already perform a reload and emit the right delete toast/effect.

## Dependencies

- `DictionaryRepository` — CRUD for saved words.
- `FsrsRepository` — returns mastered IDs for
  `ReviewableType.dictionary`, and clears the review row on delete.
- `BookRepository` / `ArticleRepository` — optional title lookup for the
  source label shown on entries.

## Relationship to other features

- Entries are **created** by the `translate` feature (save-to-dictionary
  button in the sheet).
- Entries are **reviewed** by the `practice` feature (full session) and
  `mini_review_sheet` (per-source session inside the reader).
- This feature is strictly a browser — no review UI, no FSRS rating.
