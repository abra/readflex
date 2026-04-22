# review_scheduler

Pure-Dart FSRS v6 scheduling computation. Given an item's current FSRS
state and a user rating, returns the next FSRS state plus a review log
entry. Nothing else — no Flutter, no storage, no I/O.

Thin wrapper around the [`fsrs`](https://pub.dev/packages/fsrs) package
that speaks `domain_models` types (`FsrsCardData`, `Rating`,
`ReviewableType`, `ReviewLog`) instead of raw `fsrs.Card` / `fsrs.Rating`.

---

## Public API

| Symbol            | Kind       | Purpose                                     |
|-------------------|------------|---------------------------------------------|
| `ReviewScheduler` | class      | Computes `ReviewResult` from a rating       |
| `ReviewResult`    | data class | Updated `FsrsCardData` + `ReviewLog` to persist |

### ReviewScheduler.computeReview

```dart
ReviewResult computeReview({
  required String itemId,
  required ReviewableType itemType,
  required FsrsCardData currentFsrs,
  required Rating rating,
  int? reviewDurationMs,
});
```

The result is a pure value — callers decide how to persist it.

---

## Example: used by FsrsRepository

```dart
// packages/fsrs_repository/lib/src/fsrs_repository.dart
final result = _scheduler.computeReview(
  itemId: itemId,
  itemType: itemType,
  currentFsrs: current.fsrs,
  rating: rating,
);

await _dao.updateItem(result.fsrs.toCompanion(itemId, itemType));
await _dao.insertLog(result.log.toCompanion());
```

`computeReview` is deterministic given the inputs; pass a custom
`fsrs.Scheduler` to the constructor for tests that need a fixed clock
or overridden parameters.

---

## Where it fits

```
review_scheduler → domain_models, fsrs, uuid
        ▲
        │
        └── fsrs_repository   (sole consumer)
```

Repositories delegate pure scheduling here, then persist the results
through their own DAO. Feature packages never import this package
directly — they go through `FsrsRepository`.

---

## Rules

- Pure Dart. No Flutter, no database, no async I/O.
- Inputs and outputs are `domain_models` types. The `fsrs.*` package
  stays fully encapsulated — mapping helpers are private.
- Deterministic: given the same `currentFsrs` and `rating` at the same
  `DateTime.now()`, `computeReview` must return the same result.
- `ReviewLog.id` is generated here with `uuid`; persistence decides
  whether to use it or assign its own.
