# fsrs_repository

Centralized FSRS review state for every reviewable thing in the app: saved
words (`dictionary`) and text highlights go through one repository and one
scheduler.

## Why centralized

Each reviewable type owns its own content repository
(`dictionary_repository`, `highlight_repository`). None of them tracks review
state. `fsrs_repository` is the single store for `stability`, `difficulty`,
`nextReviewAt` and `reps`, indexed by `itemId`, plus the review log.

- Practice asks one question, "what's due?", and gets a mixed queue.
- A new reviewable type only needs a new `ReviewableType` value.
- The FSRS v6 algorithm lives once in `review_scheduler`.

## Tracking lifecycle

Content repositories register a review row inside the same transaction that
saves the content (`DictionaryRepository.addEntry`,
`HighlightRepository.addHighlight` for new text highlights) and delete it with
the content. `ensureReviewItems` backfills rows for content saved before
tracking existed; `recordReview` still creates a missing row implicitly.

## Public API

| Method | Purpose |
|--------|---------|
| `createReviewItem({itemId, itemType, sourceId})` | Explicit creation |
| `ensureReviewItems(items)` | Insert-or-ignore backfill |
| `deleteReviewItem(itemId)` | Remove tracking |
| `getReviewState(itemId)` / `getReviewStates(ids)` | FSRS state lookup |
| `getReviewItems(type)` | Every tracked item of a type |
| `getMasteredItemIds({type})` | Items that reached the `review` phase |
| `getDueItems({type, limit, offset})` | Due now, oldest due first |
| `getDueItemsBySource(sourceId, {type})` | Due items from one source |
| `getDueItemCount({type})` | Due count |
| `getStats()` | `ReviewStats`: due/total/mastered per type, today, 7 days, streak |
| `previewIntervals(current)` | Interval per rating for the button labels |
| `recordReview({itemId, itemType, rating, sourceId, reviewDurationMs})` | Apply a rating |

Receives `AppDatabase` and an optional `clock` (tests). Storage errors are
wrapped in `StorageException`.
