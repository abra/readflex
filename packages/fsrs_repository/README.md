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
- A new reviewable type reuses the scheduler and review tables. It also needs
  content save/delete registration, storage enum handling, and Practice queue
  hydration and presentation; adding a `ReviewableType` value alone is not enough.
- The FSRS v6 algorithm lives once in `review_scheduler`.

## Tracking lifecycle

Content repositories register a review row inside the same transaction that
saves the content (`DictionaryRepository.addEntry`,
`HighlightRepository.addHighlight` for new text highlights) and delete it with
the content. Composition awaits `backfillTextHighlights` once during app
initialization to register legacy text highlights. One SQL insert selects only
missing IDs and source IDs; it neither loads quotations into Dart nor rewrites
existing schedules. Practice loads and session loads do not run this repair.
`ensureReviewItems` remains available for explicit batch registration.

`recordReview` checks that the saved word or text highlight still exists and is
not excluded inside the same transaction as reading its schedule, updating it
and appending the review log. A late rating for deleted or excluded content
throws `NotFoundException` and writes nothing; Practice skips that unavailable
item without counting a review.
Valid content with missing tracking can still be registered by its first rating.
The dormant `flashcard` type retains its historical registration behavior.

Current Practice sessions load saved words and text highlights. The legacy
`flashcard` enum and stored rows remain for database compatibility; image-area
highlights do not enter the review queue. Content IDs are globally unique
because the review table is keyed by `itemId`, not by type plus ID.

`excludeReviewItem` persists `isExcluded` on the existing review row without
changing its schedule or history. Active state lookups, queues (including Review
ahead), counts and deadlines omit excluded rows. Backfill and insert-or-ignore
registration leave them excluded after restart. Deleting and undoing a highlight
preserves the exclusion with its review snapshot. Excluding missing tracking is
a no-op, so a stale removal cannot recreate deleted content.

`deleteReviewItem` remains physical tracking deletion for cleanup. It does not
express user exclusion. Earlier removals that physically deleted tracking cannot
be distinguished from legacy content that was never registered.

Removing review tracking or deleting content does not erase append-only review
logs. Activity totals can therefore include reviews of content that is no
longer saved; current due/total/mastered counts come from review items instead.

## Public API

| Method | Purpose |
|--------|---------|
| `createReviewItem({itemId, itemType, sourceId})` | Explicit creation |
| `ensureReviewItems(items)` | Insert-or-ignore backfill |
| `backfillTextHighlights()` | Missing-only legacy text-highlight repair, awaited by app initialization |
| `excludeReviewItem(itemId)` | Persist user exclusion while retaining scheduling/history |
| `deleteReviewItem(itemId)` | Physically remove tracking |
| `getReviewState(itemId)` / `getReviewStates(ids)` | Active FSRS state lookup; excluded items are omitted |
| `getReviewItems(type)` | Every active tracked item of a type |
| `getMasteredItemIds({type})` | Items that reached the `review` phase |
| `getDueItems({type, types, states, limit, offset})` | Due now, oldest due first; type and state selection happen before pagination |
| `getDueItemsBySource(sourceId, {type, types, states, limit, offset})` | Due items from one source, with the same filtering rules |
| `getDueItemCount({type})` | Due count |
| `getReviewQueueStatus({types})` | Due count and earliest future deadline in one query, without review history; `null` types means all, an empty set means none |
| `getStats()` | `ReviewStats`: due/total/mastered per type, today, 7 days, streak, counted in study days (`studyDay`) |
| `previewIntervals(current, {desiredRetention})` | Interval per rating for the button labels |
| `recordReview({itemId, itemType, rating, sourceId, reviewDurationMs, desiredRetention})` | Apply a rating at the reader's memory target |
| `studyDay` | The 04:00 day boundary the schedule and the counts follow |

Receives `AppDatabase` and an optional `clock` (tests). Storage errors are
wrapped in `StorageException`.
The due-query filters `type` and `types` are mutually exclusive (`ArgumentError`
if combined); null includes all stored types and an empty set includes none.
The optional `states` filter follows the same null/empty semantics and lets
Practice bound new and already-reviewed candidates separately, so exhausted
new-card allowances cannot hide due learning/review/relearning items.
