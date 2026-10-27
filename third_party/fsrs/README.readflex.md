# fsrs — Readflex patch

Vendored from `fsrs` 2.0.1 (open-spaced-repetition/dart-fsrs, MIT), the Dart
port of py-fsrs, so `review_scheduler` can hold it to the reference
implementation. Upstream structure, style and tests are kept; `example/` is
left out.

## Patches (both in lib/fsrs.dart, marked `Readflex:`)

1. `Scheduler._nextDifficulty`: the mean-reversion target is the
   **unclamped** initial difficulty of Easy, `w4 − e^(3·w5) + 1`, as py-fsrs
   (`_initial_difficulty(rating=Easy, clamp=False)`) and fsrs-rs compute it.
   Upstream reuses `_initialDifficulty`, which clamps to [1, 10]; with the
   default parameters that target is −4.77, clamped to 1, so every
   difficulty after the first review came out 0.00577 too high and the
   drift compounded through mean reversion.
2. `Scheduler._shortTermStability`: the same-day stability multiplier is
   floored at 1 for Hard as well as Good and Easy (py-fsrs 6.3:
   `if rating in (Hard, Good, Easy)`; fsrs-rs: `rating > 1`). Upstream
   floors only Good and Easy, so a Hard within a day of the last review
   shrank stability by up to 40 % and shortened every interval after it.

## Rechecking on update

`packages/review_scheduler/test/fsrs6_reference_test.dart` replays 118
py-fsrs histories (`test/fixtures/fsrs6_reference.json`, written by
`fsrs6_reference.py` from a py-fsrs checkout) through this package and
compares stability, difficulty, intervals and retrievability to nine
significant digits. After updating the vendored copy, reapply the patch
unless upstream has fixed it, and run that test; regenerate the fixture
from a newer py-fsrs only when the algorithm version changes.
