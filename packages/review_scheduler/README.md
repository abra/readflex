# review_scheduler

Pure-Dart FSRS v6 scheduling over the `fsrs` package, shared by every
reviewable item type (saved words, highlights).

- `computeReview(...)` returns the next `FsrsCardData` plus a `ReviewLog`;
  `fsrs_repository` persists both.
- `previewIntervals(current)` returns how far each `Rating` would postpone
  the next review, for the labels under the rating buttons.
- The scheduler runs one learning step and one relearning step (10 minutes)
  because Readflex does not persist the FSRS learning step: a card rated
  Good graduates to review immediately.
- `clock` is injectable for tests; every timestamp is UTC.
