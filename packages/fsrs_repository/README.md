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

## Implicit tracking

`recordReview()` implicitly creates a `ReviewItem` on the first review.
Callers don't need to call `createReviewItem` when saving a highlight or
dictionary word — the item enters FSRS tracking only once the user actually
reviews it. Items that are never reviewed take zero rows in the review table.

## Public API

| Method                                                        | Purpose                                          |
|---------------------------------------------------------------|--------------------------------------------------|
| `createReviewItem({itemId, itemType, sourceId})`              | Explicit creation (usually not needed)           |
| `deleteReviewItem(itemId)`                                    | Remove tracking when the content row is deleted  |
| `getReviewState(itemId)`                                      | FSRS state for one item                          |
| `getReviewStates(itemIds)`                                    | Batch FSRS state lookup                          |
| `getMasteredItemIds({type, limit, offset})`                   | IDs of items that reached the `review` phase     |
| `getDueItems({type, limit, offset})`                          | All items due now, mixed across types            |
| `getDueItemsBySource(sourceId, {type, limit, offset})`        | Due items from one book/article                  |
| `recordReview({itemId, itemType, rating, sourceId, reviewDurationMs})` | Apply a rating; returns updated FSRS state |

Follows the standard repository pattern: receives `AppDatabase` via its
constructor and extracts `reviewItemsDao` internally. Storage exceptions are
wrapped into `StorageException`.

## Dependencies

- `domain_models` — `ReviewItem`, `ReviewableType`, `Rating`, `FsrsCardData`
- `local_storage` — `AppDatabase`, `ReviewItemsDao`
- `review_scheduler` — pure-Dart FSRS v6 algorithm
