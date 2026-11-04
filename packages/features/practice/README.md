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
closes; there is no tab to return to. The entry library exports the four screen
files and their public callback typedefs and row widgets; cubits and
`PracticeItem` are accessed through `src/` imports in tests.

On iOS and macOS the session uses a short fade (`AppMotion.short`), skipped
with reduced motion. Sliding its full-screen background down leaves a moving
edge over Review ahead when returning to the hub. Other platforms retain the
theme's page transition; the session stays a full-screen dialog.

## Settings

The hub's app bar ends with Practice settings (`AppIcons.settings`), a sheet
built like Library's Display sheet (`ActionBottomSheetLayout.scrollable`,
`AppSettingsSection`, `AppChoiceControl`): new cards a day (10 / 20 / 40),
what a session reviews (Vocabulary only / With highlights) and the memory
target (Lighter / Balanced / Stronger: FSRS desired retention 0.8 / 0.9 /
0.95, `PracticeMemoryTarget`). `PracticeSettingsCubit` shows each choice at
once and writes it to `PreferencesService`. An update error rolls the choice
back; disk-save failures are logged by the service and keep the in-memory
choice for the current session. On restart, preferences return to the last
successfully saved snapshot. A stored value the sheet does not offer shows as
its nearest choice (`practice_settings_presets.dart`) and is rewritten only when
the user picks one. The hub reloads when the sheet closes, since the
highlights setting changes what counts as due; the Library's due count
follows the same setting.

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
  `PracticeHighlightItem` with one content query per type and a separate
  anchor lookup for each saved word, keeps the due order and drops rows whose
  content was deleted. `PracticeSourceIndex` names
  where items came from; a missing source leaves `sourceTitle` null.
- Views read only state and dispatch events or callbacks. `PracticeScreen`
  owns the settings-sheet callback, so its view never receives a service.
  The hub reloads
  after each pushed destination (Vocabulary, Highlights, a session) closes.

### Session rules

- The queue honours Practice settings: highlights only when
  `practiceReviewHighlights` is on; never-reviewed cards only up to
  `practiceNewCardsPerDay` less `ReviewStats.newReviewedToday`; every
  preview and rating in a session schedules at the memory target
  (`practiceDesiredRetention`) read when the session starts.
- At most 50 cards per session. A caught-up reader can review `ahead`: the
  20 cards due soonest across both types, never-reviewed cards last.
- Each rating is recorded through `FsrsRepository.recordReview` as it is
  given; a failed write ends the session in the failure state.
- Words are rated Again / Hard / Good with the interval each would give,
  from `previewIntervals`. Highlights are Keep (recorded as Good) or Show
  less (recorded as Easy). There is no Easy for words.
- Remove deletes the card's review row and drops it from the queue; the saved
  word or highlight remains. A session emptied by removals ends as empty when
  nothing was rated. The legacy-highlight backfill currently registers text
  highlights without a review row again on a later load; removal is not a
  persistent opt-out for highlights.
- Cards rated Again are collected; the summary offers a second pass over
  them.

## Layout

- The hub, Vocabulary and Highlights use `PracticePageHeader`: the directional
  `AppBackButton`, a semantic heading and optional settings action, aligned
  with the shared `AppContentFrame` (maximum 1200dp). Vocabulary and Highlights
  keep their search and lists within 960dp; the Vocabulary toolbar puts search
  and filters alongside each other when space and text size allow it.
- On phones the hub floats Start review at the bottom where Library floats "+": one
  filled stadium (`PracticeStartButton`) on the capsule's soft shadow, with
  no capsule around it. It appears in the same frame as the content, at
  full size (`FloatingActionButtonAnimator.noAnimation`): Material's default
  would scale and turn it in on its own. When nothing is due the button
  offers Review ahead.
  An empty hub has no button: it is the shared `AppFirstRunState` (the
  practice glyph, Nothing to practice yet, no command), the same frame as
  the empty Library, centred in the space under the app bar and scrolling
  at large text. Back leads to the Library, where saving starts.
- At widths of at least 840dp and heights of at least 480dp, the populated hub
  places the due overview and its review command beside the collections and
  source list. Each side scrolls independently. Text above 150% returns to one
  column, at most 720dp wide, so translated labels retain usable space. RTL
  mirrors the columns. The embedded command follows the due count, ahead of
  supporting statistics.
  The source list alone owns primary keyboard/status-bar scrolling; the due
  overview uses its own scroll position. The Vocabulary toolbar keeps its
  search editor mounted when its axis changes, retaining query and focus.
  A feature-local `PageStorageKey` retains the source-list offset across the
  one-column/two-column reparenting without changing its automation key.
- `PracticeTodayCard` shows the due count large with its words/highlights
  split and new today, then streak and totals below a divider. These supporting
  labels wrap independently inside the quiet surface, including at large text.
- `PracticeSourceRow` shows a cover, title (the Library list's title role),
  counts and what is due; tapping it starts a session over that source. Source
  chevrons align with Collections and follow the layout direction. Source
  and highlight lists build visible rows lazily.
- Word rows show the word, its meaning, the source title and the stored FSRS
  review date and time (`reviewDueLabel` in `review_due_label.dart`). The date
  uses the current locale and local time zone; the clock follows the 12/24-hour
  preference. Muted `bodySmall` metadata puts the schedule on a separate,
  wrapping line so a long source title cannot hide it. Items without a
  timestamp keep New or Due rather than inventing a date. The word and meaning
  each keep their own reading direction. Tapping opens
  `PracticeWordSheet` with the saved meaning, the sentence, Open in book and
  Remove, plus the same review timestamp. Details scroll above pinned actions,
  with one shared content gutter.
- Highlight rows quote the passage on its colour (`practiceHighlightTint`)
  and open it in its source. Their chapter and review timestamp use the same
  separate metadata lines as word rows.
- Composite source, word and highlight rows and rating buttons expose one
  labelled, enabled semantics node with their tap action and metadata. Their
  replacement semantics keep assistive activation available.
- The session has Close, the card's position and an overflow menu (Open in
  book, Remove from review) on one row with a thin progress line under it. A word card
  shows the word large with reading and part of speech and the sentence with
  the word in bold; the answer adds the meaning in context, the word's own
  meaning and the sentence translation. A highlight card shows the quote and
  its origin; the answer is the note, or that there is none.
- The session workspace is at most 960dp wide. A vertically centred study
  surface and the bottom controls share a 640dp reading measure; a long answer
  scrolls without moving the controls. Word ratings stack at narrow widths or
  large text instead of clipping their labels. The completion surface is at
  most 480dp and scrolls when needed, with Done in the same quiet panel.
- A word heading fits its longest unbreakable piece with `appFitLongestWord`,
  at the current locale, direction and text scale. It stays at least as large
  as `titleLarge`; unusually long words can wrap at that floor. The full text
  and heading semantics remain, and the context keeps normal body scaling.
- Medium windows (at least 600×480dp) use the existing 15sp roles for rating
  intervals, the session position, the Today label and due breakdown, and each
  source's due label. Summary counts already use 15sp. Narrow windows keep
  their compact roles; supporting statistics and source metadata stay small.
  Accessibility text scaling still applies to every role.
- Rating previews keep `reviewIntervalLabel`, which rounds intervals to one
  unit: minutes under an hour, then hours, days, weeks, months and years.
  Displaying a stored timestamp does not change FSRS scheduling.

## Tests

- `test/review_session_bloc_test.dart` covers the empty queue, mixed queues
  with intervals, rating and Again collection, removal, the daily new-card
  limit and the highlights setting, source-scoped sessions and ahead.
- `test/practice_bloc_test.dart` covers the empty hub, per-source grouping,
  the highlight backfill and the highlights setting leaving the due count.
- `test/practice_words_cubit_test.dart` and
  `test/practice_highlights_cubit_test.dart` cover loading with titles and
  anchors, search and filters, removal and grouping.
- `test/practice_settings_cubit_test.dart` covers the presets, each choice's
  update, no-op choices and roll-back when the preferences service throws.
  That fake throws from `update`; it does not exercise the real service's
  non-fatal disk-save failure path.
- `test/practice_screens_test.dart` covers the hub, Vocabulary, Highlights and
  the session end to end with fakes, the app bar of each pushed screen
  (title, `AppBackButton`, localized Back, pop), plus 200% text at 320×568
  in every locale. It also checks tablet columns and RTL, focused session and
  summary widths, reachable phone RTL ratings, lazy long highlight lists and
  scrollable word details with pinned commands, plus tap semantics on composite
  controls. These are widget geometry and
  interaction checks; they do not establish native accessibility or FPS.
- `test/review_interval_label_test.dart` pins rating-interval rounding.
- `test/practice_review_schedule_test.dart` covers full review timestamps,
  metadata semantics, long sources, large text and phone RTL in word and
  highlight rows and word details. Root
  `test/ui/practice_schedule_golden_test.dart` captures these surfaces on
  phones and tablets.
- `test/review_word_card_test.dart` uses the shipped Literata font to keep
  `reading` whole and legible at 320dp/200%, before and after revealing its
  answer, while context text retains accessibility scaling.
- `test/practice_tablet_controls_test.dart` checks these control roles with
  the app fonts and multilingual golden-test fallbacks: 800×1280 and 1280×800,
  all ten locales at 200%, compact phone defaults, text/tap/semantics bounds,
  and exact pointer and assistive activation callbacks.
- Root goldens (`test/ui/practice_golden_test.dart`) cover `practice`,
  `practice-empty` and the `review-*` states.
- `test/ui/practice_review_transition_test.dart` checks intermediate frames
  while closing a completed session and the refreshed hub after returning.

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
- `intl` — localized review dates and bidi detection, so words and quotes keep
  their own writing direction
