# review_scheduler

Pure-Dart FSRS-6 scheduling over the vendored `fsrs` package
(`third_party/fsrs`, held to py-fsrs by `test/fsrs6_reference_test.dart`),
shared by every reviewable item type (saved words, highlights).

- `computeReview(...)` returns the next `FsrsCardData` plus a `ReviewLog`;
  `fsrs_repository` persists both.
- `previewIntervals(current)` returns how far each `Rating` would postpone
  the next review, for the labels under the rating buttons: whole days for a
  card going to review, minutes for a learning step. It equals what
  `computeReview` records.
- `desiredRetention` comes with each call (the reader's memory target from
  preferences, 0.7–0.97, `clampDesiredRetention`); the package scheduler for
  each value is kept.
- Days are `StudyDay`s: a day starts at 04:00 local time, so a review after
  midnight belongs to the evening's day, and a card due in N days comes due
  when that study day starts. The package counts calendar days between two
  instants, so it is handed a last-review instant exactly that many whole
  days before now.
- The scheduler runs one learning step and one relearning step (10 minutes)
  because Readflex does not persist the FSRS learning step: a card rated
  Good graduates to review immediately. Hard on a new card waits 15 minutes.
- Day-level intervals are at least one day, grow with the rating (Hard below
  Good below Easy) and never pass `maximumIntervalDays` (365; the model's
  own cap is 100 years). Fuzzing is off.
- `clock` is injectable for tests; every stored timestamp is UTC.

## Tests

- `test/fsrs6_reference_test.dart` replays 118 py-fsrs histories
  (`test/fixtures/fsrs6_reference.json`, written by `fsrs6_reference.py`)
  through the package: stability, difficulty, intervals and retrievability
  to nine significant digits. It found two upstream deviations, patched in
  `third_party/fsrs` (see its `README.readflex.md`).
- `test/study_day_test.dart` pins the 04:00 boundary and the day arithmetic.
- `test/review_scheduler_intervals_test.dart` covers study days in the
  schedule, the ordering and the cap of intervals, the retention and the
  previews; `test/review_scheduler_test.dart` the card bookkeeping.
