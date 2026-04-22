# practice

Spaced-repetition review sessions over every reviewable type: flashcards,
highlights, and dictionary entries. Hosts both the global Practice tab
and the in-reader mini-review sheet.

## Public API

| Symbol                    | Kind              | Purpose                                                         |
|---------------------------|-------------------|-----------------------------------------------------------------|
| `PracticeScreen`          | `StatelessWidget` | Practice tab at `/practice` — all due items across the app      |
| `showMiniReviewSheet(…)`  | function          | Bottom sheet used by the reader for due items from one source   |

### PracticeScreen

Props (all repositories, passed from the DI container):

| Prop                   | Type                    |
|------------------------|-------------------------|
| `fsrsRepository`       | `FsrsRepository`        |
| `flashcardRepository`  | `FlashcardRepository`   |
| `highlightRepository`  | `HighlightRepository`   |
| `dictionaryRepository` | `DictionaryRepository`  |

### showMiniReviewSheet

```dart
void showMiniReviewSheet(
  BuildContext context, {
  required String sourceId, // book or article ID
  required FsrsRepository fsrsRepository,
  required FlashcardRepository flashcardRepository,
  required HighlightRepository highlightRepository,
  required DictionaryRepository dictionaryRepository,
});
```

## Architecture

Two BLoCs, shared state model (`PracticeItem`, `RatingButtons`, card
views):

- `PracticeBloc` — full session. Loads up to 50 due items via
  `fsrsRepository.getDueItems(limit:)`, resolves them into
  `PracticeItem`s with parallel batch queries, then walks the user
  through reveal → rate → next. Status flow:
  `initial → loading → reviewing → completed` (with `empty` and
  `failure` branches).
- `MiniReviewCubit` — same reveal/rate/advance loop, but scoped to one
  source via `fsrsRepository.getDueItemsBySource(sourceId)`. Lives in
  this package (the reader does not import practice internals — it calls
  `showMiniReviewSheet` through a callback wired at the composition
  root). Status flow:
  `loading → reviewing → completed` (with `empty` and `failure`).

Both submit ratings with `fsrsRepository.recordReview(…)`, which runs
the FSRS v6 scheduler and updates the review row.

## Dependencies

- `FsrsRepository` — due-queue queries + review recording.
- `FlashcardRepository`, `HighlightRepository`, `DictionaryRepository` —
  batch fetch (`…ByIds`) of the actual entities referenced by each
  `ReviewItem`. Items deleted between scheduling and resolution are
  skipped silently.

## Notes

- The full Practice tab UI is currently a `Placeholder`; the bloc and
  card layouts are wired and tested, the screen chrome is not yet
  finalized.
- `review_card_views.dart` is shared between the tab and the mini sheet
  — flashcard / highlight / dictionary cards render identically in both
  surfaces.
