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

## Architecture

- `DictionaryBloc` — three events:
  - `DictionaryLoadRequested` — fetches entries + mastered IDs in
    parallel on tab open and after deletions.
  - `DictionarySearchChanged` — debounced 300 ms; updates
    `searchQuery`, which feeds the `filteredEntries` getter on state.
  - `DictionaryEntryDeleted` — removes the entry and its FSRS review
    row, then reloads.
- `DictionaryState` — exposes `entries`, `searchQuery`, `masteredIds`,
  plus the derived `filteredEntries`, `masteredCount`, and
  `isMastered(id)` helpers consumed by the view.

## Dependencies

- `DictionaryRepository` — CRUD for saved words.
- `FsrsRepository` — returns mastered IDs for
  `ReviewableType.dictionary`, and clears the review row on delete.

## Relationship to other features

- Entries are **created** by the `translate` feature (save-to-dictionary
  button in the sheet).
- Entries are **reviewed** by the `practice` feature (full session) and
  `mini_review_sheet` (per-source session inside the reader).
- This feature is strictly a browser — no review UI, no FSRS rating.
