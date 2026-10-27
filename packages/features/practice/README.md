# practice

The Practice section, pushed above the Library: spaced review of saved words
and text highlights. The hub shows what is due today,
the Vocabulary and Highlights collections and each source's share; a full-screen
session reviews one card at a time. Before anything is saved the hub shows
the first-run frame alone, with no command: back leads to the Library, where
saving starts.

Scheduling itself is not here. `fsrs_repository` owns the due queue, stats
and rating previews over `review_scheduler`; `dictionary_repository` and
`highlight_repository` register a review row when content is saved. This
package only reads the queue and records ratings.

## Public API

```dart
class PracticeScreen extends StatelessWidget {
  const PracticeScreen({
    required FsrsRepository fsrsRepository,
    required DictionaryRepository dictionaryRepository,
    required HighlightRepository highlightRepository,
    required BookRepository bookRepository,
    required PreferencesService preferencesService,
    required PracticeStartReview onStartReview,
    required Future<void> Function() onWordsPressed,
    required Future<void> Function() onHighlightsPressed,
    ArticleRepository? articleRepository,
  });
}

class PracticeWordsScreen extends StatelessWidget { ... }
class PracticeHighlightsScreen extends StatelessWidget { ... }

class ReviewSessionScreen extends StatelessWidget {
  const ReviewSessionScreen({
    required FsrsRepository fsrsRepository,
    required DictionaryRepository dictionaryRepository,
    required HighlightRepository highlightRepository,
    required BookRepository bookRepository,
    required PreferencesService preferencesService,
    required Future<void> Function(String sourceId, String? cfiRange)
        onOpenInSource,
    ArticleRepository? articleRepository,
    String? sourceId,
    bool ahead = false,
  });
}
```

`PracticeStartReview` starts a session, optionally for one `sourceId` or
`ahead` of schedule, and completes when it closes. `PracticeOpenInSource`
opens a source in the reader at a CFI. `routing.dart` owns every destination:
Vocabulary, Highlights and the session are nested routes under `/practice`, the
session as a full-screen dialog page. The hub reloads after each of them
closes; there is no tab to return to. Nothing else is public;
tests reach cubits and `PracticeItem` through `src/` imports.

## Architecture

- `PracticeScreen` → `PracticeBloc`: review stats, the per-source summaries
  and the highlights setting. Every load first backfills review rows for text
  highlights saved before review tracking existed, so counts include them.
- `PracticeWordsScreen` → `PracticeWordsCubit`: every saved word newest
  first, search, All / Learning / Mastered, remove.
- `PracticeHighlightsScreen` → `PracticeHighlightsCubit`: every text
  highlight newest first, search, a colour filter, grouped by source in
  order of first appearance.
- `ReviewSessionScreen` → `ReviewSessionBloc`: the queue and one card at a
  time. Events are start, reveal, rate, remove and again.
- `PracticeItemLoader` turns review rows into `PracticeWordItem` /
  `PracticeHighlightItem` with one batch query per type, keeps the due order
  and drops rows whose content was deleted. `PracticeSourceIndex` names
  where items came from; a missing source leaves `sourceTitle` null.
- Views read only state and dispatch events or callbacks. The hub reloads
  after each pushed destination (Vocabulary, Highlights, a session) closes.

### Session rules

- The queue honours Profile: highlights only when `practiceReviewHighlights`
  is on; never-reviewed cards only up to `practiceNewCardsPerDay` less
  `ReviewStats.newReviewedToday`.
- At most 50 cards per session. A caught-up reader can review `ahead`: the
  20 cards due soonest across both types, never-reviewed cards last.
- Each rating is recorded through `FsrsRepository.recordReview` as it is
  given; a failed write ends the session in the failure state.
- Words are rated Again / Hard / Good with the interval each would give,
  from `previewIntervals`. Highlights are Keep (recorded as Good) or Show
  less (recorded as Easy). There is no Easy for words.
- Remove deletes the card's review row and drops it from the queue; a
  session emptied by removals ends as empty when nothing was rated.
- Cards rated Again are collected; the summary offers a second pass over
  them.

## Layout

- The hub, Vocabulary and Highlights share one app bar: the screen's name as the
  title and `AppBackButton` (the app's directional chevron, not Material's
  platform arrow) in the leading slot. The hub has no serif hero under it:
  the Today card is its headline, so a back arrow never floats above a
  heading.
- The hub floats Start review at the bottom where Library floats "+": one
  filled stadium (`PracticeStartButton`) on the capsule's soft shadow, with
  no capsule around it. It appears in the same frame as the content, at
  full size (`FloatingActionButtonAnimator.noAnimation`): Material's default
  would scale and turn it in on its own. When nothing is due the button
  offers Review ahead.
  An empty hub has no button: it is the shared `AppFirstRunState` (the
  practice glyph, Nothing to practice yet, no command), the same frame as
  the empty Library, centred in the space under the app bar and scrolling
  at large text. Back leads to the Library, where saving starts.
- `PracticeTodayCard` shows the due count large with its words/highlights
  split, then new today, the streak and totals in one muted line, in the
  outlined frame of the Library's Practice row.
- `PracticeSourceRow` shows a cover, title (the Library list's title role),
  counts and what is due; tapping it starts a session over that source.
- Word rows show the word, its meaning, the source title and when it is
  next due (`reviewDueLabel`: New, Due, or a rounded interval). Tapping opens
  `PracticeWordSheet` with the saved meaning, the sentence, Open in book and
  Remove.
- Highlight rows quote the passage on its colour (`practiceHighlightTint`)
  and open it in its source.
- The session has Close, the card's position and an overflow menu (Open in
  book, Remove from review) on one row with a thin progress line under it. A word card
  shows the word large with reading and part of speech and the sentence with
  the word in bold; the answer adds the meaning in context, the word's own
  meaning and the sentence translation. A highlight card shows the quote and
  its origin; the answer is the note, or that there is none.
- `reviewIntervalLabel` rounds intervals to one unit: minutes under an hour,
  then hours, days, weeks, months and years.

## Tests

- `test/review_session_bloc_test.dart` covers the empty queue, mixed queues
  with intervals, rating and Again collection, removal, the daily new-card
  limit and the highlights setting, source-scoped sessions and ahead.
- `test/practice_bloc_test.dart` covers the empty hub, per-source grouping,
  the highlight backfill and the highlights setting leaving the due count.
- `test/practice_words_cubit_test.dart` and
  `test/practice_highlights_cubit_test.dart` cover loading with titles and
  anchors, search and filters, removal and grouping.
- `test/practice_screens_test.dart` covers the hub, Vocabulary, Highlights and
  the session end to end with fakes, the app bar of each pushed screen
  (title, `AppBackButton`, localized Back, pop), plus 200% text at 320×568
  in every locale.
- `test/review_interval_label_test.dart` pins the rounding and due labels.
- Root goldens (`test/ui/practice_golden_test.dart`) cover `practice`,
  `practice-empty` and the `review-*` states.

## Not here

No Listen (text-to-speech) on word cards and no daily reminder: neither
platform service is shipped.

## Dependencies

- `fsrs_repository`, `dictionary_repository`, `highlight_repository`,
  `book_repository`, `article_repository` — queue, content and titles
- `preferences_service` — the session limits
- `toast_service` — `ToastAvoidArea`, so bottom toasts clear Start review
- `component_library` — theme tokens, `SearchField`, `AppChoiceControl`,
  `AppFilterChip`, `AppFirstRunState`, sheets
- `readflex_localizations` — copy
- `intl` — bidi detection, so words and quotes keep their own writing
  direction
