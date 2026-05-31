# fsrs_repository

Centralized FSRS review state for every reviewable thing in the app:
flashcards, highlights, and dictionary entries go through one repository
and one FSRS scheduler, not three.

## Why centralized

Each reviewable type owns its own content repository (`flashcard_repository`,
`highlight_repository`, `dictionary_repository`). None of them tracks review
state. `fsrs_repository` is the single store for `stability`, `difficulty`,
`dueAt`, and `reps` — indexed by `(itemId, itemType)` — plus the review log.

Consequences:

- Practice screens can ask one question — "what's due today?" — and get a
  mixed queue across types.
- Adding a new reviewable type (e.g. cloze cards) only needs a new
  `ReviewableType` enum value, not a new repository.
- The FSRS v6 algorithm is implemented once in `review_scheduler` and
  injected here, so tuning parameters is a one-line change.

## Tracking lifecycle

Features normally call `createReviewItem` when a flashcard, highlight, or
dictionary entry is saved so new items can appear in the due queue immediately.
`recordReview()` still implicitly creates the row if it is missing; that keeps
review flows resilient when old data, test fixtures, or future import paths
encounter content that was not pre-registered.

## Public API

| Method                                                        | Purpose                                          |
|---------------------------------------------------------------|--------------------------------------------------|
| `createReviewItem({itemId, itemType, sourceId})`              | Explicit creation (usually not needed)           |
| `deleteReviewItem(itemId)`                                    | Remove tracking when the content row is deleted  |
| `getReviewState(itemId)`                                      | FSRS state for one item                          |
| `getReviewStates(itemIds)`                                    | Batch FSRS state lookup                          |
| `getMasteredItemIds({type, limit, offset})`                   | IDs of items that reached the `review` phase     |
| `getDueItems({type, limit, offset})`                          | All items due now, mixed across types            |
| `getDueItemsBySource(sourceId, {type, limit, offset})`        | Due items from one source                        |
| `recordReview({itemId, itemType, rating, sourceId, reviewDurationMs})` | Apply a rating; returns updated FSRS state |

Follows the standard repository pattern: receives `AppDatabase` via its
constructor and extracts `reviewItemsDao` internally. Storage exceptions are
wrapped into `StorageException`.

## Dependencies

- `domain_models` — `ReviewItem`, `ReviewableType`, `Rating`, `FsrsCardData`
- `local_storage` — `AppDatabase`, `ReviewItemsDao`
- `review_scheduler` — pure-Dart FSRS v6 algorithm
