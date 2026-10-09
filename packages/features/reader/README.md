# reader

Full-screen reader for books, comics, and saved articles. The single route
(`/reader/:sourceId`) hosts the WebView-based reading surface, bottom action
chrome, and a text-selection context panel populated by pluggable
`TextAction`s.

## Public API

```dart
class ReaderScreen extends StatelessWidget {
  ReaderScreen({
    required String sourceId,
    required Uri serverBaseUri,                    // token-scoped localhost URI
    required BookRepository bookRepository,
    ArticleRepository? articleRepository,
    required HighlightRepository highlightRepository,
    required PreferencesService preferencesService,
    required ScreenControlService screenControlService,
    required List<TextAction> textActions,         // plug-in actions
    List<String> initialSearchHistory = const [],
    Book? initialSource,
    ValueChanged<List<String>>? onSearchHistoryChanged,
    VoidCallback? onSourceOpened,
    void Function(String url, String title)? onArticleTitlePressed,
    ValueChanged<String>? onExternalLink,
  });
}
```

`sourceId` resolves first through `BookRepository.getBookById`; when an
`ArticleRepository` is provided, saved articles are loaded as article sources
and opened from `Article.contentHtmlPath`. Internally `ReaderBloc` maps both
books and articles to a source-neutral `ReaderDocument`, so article HTML is not
modeled as an EPUB. `initialSource` lets the route avoid a loading flash
when a book source was already loaded by the previous route. For articles,
`onArticleTitlePressed` lets the composition root open the original article URL
from the top reader chrome without coupling the reader package to
`url_launcher`.
`onExternalLink` separately forwards book links to the app shell's validated
HTTP(S) launcher.

## TextAction plugin system

The reader does not depend on sibling action implementations or translation/
dictionary services. New text-highlight creation is delegated through TextAction;
saved-highlight edits and image highlights use its injected repository.
Callers assemble a `List<TextAction>` (from `shared/`) in the composition root
(`routing.dart`) and pass it in. On text selection the context panel renders
actions in a two-row popup: highlight colors and Highlight are above the
general Copy, Translate, and Define commands. Active feature implementations
are supplied by sibling packages such as `highlight`, `translate`, and
`dictionary`; the UI-only `CopyTextAction` remains in Reader.
The popup captures input only inside its visible controls, leaving the WebView
selection handles interactive so the selected range can be resized in place.
The saved-highlight popup (`ReaderSavedHighlightPopup`) is different: its
full-screen barrier exists only while the popup is open and is opaque, so the
dismissing tap never also toggles chrome or turns the page.
All three popups (text selection, image-area selection, saved highlight) clamp
horizontally inside the safe area plus a 16dp inset, so landscape cutouts
never cover them; their width is sized from the safe width.
Each action starts resolving the current WebView range on pointer down, before
focus can collapse the native WebKit selection, and awaits that same snapshot
on execution. The reader runtime also retains the latest changed range as a
fallback, so expanding a word into a paragraph cannot send the initial word to
Copy, Translate, Define, or Highlight.
Before Translate or Define presents another surface, the driver dismisses the
selection popup, waits for that frame to finish, and then executes the action
from its stable context. This prevents a context menu from remaining visible
behind a modal or native dictionary surface without losing the captured range.

`ReaderHighlightControls` is a presentation-only leaf: 48px swatches expose
their selected/enabled states, and only the palette scrolls when the popup is
narrow. Save/edit/delete commands stay visible. Its callbacks preserve the
existing preview/explicit-save contract and pointer-down selection capture.
`ReaderSearchResultTile` respects the system text scaler for both its chapter
label and highlighted excerpt, while retaining document direction and the
three-line excerpt limit. Neither leaf owns repositories or WebView lifecycle.

Appearance uses `ActionBottomSheetLayout.scrollable`, the same shell as Display,
Language and the text-action result sheets. `AppSettingsSection` and
`AppChoiceControl` share settings typography, spacing and selection states.
Theme swatches retain the preset's page colors for the localized sample
(`readerAppearanceSample`); each swatch is an ink tile with a 48dp target,
`Semantics(button, selected)` and the shared `selectedControlBackground/
Foreground` pair behind the active sample and label. Each swatch keeps a 4dp
ink inset around its sample, so the sheet body gutter is reduced by that inset
for the swatch grid only (`_swatchInkInset`): sample borders, the "Theme"
label, the Font row and the setting rows all sit on the 24dp gutter while the
ink tiles bleed 4dp past it. Font options use the same fill-plus-check
selection as the Language sheet, without an extra border, and the same 8dp
option inset: the Font sheet body gives those 8dp back so option text and the
check glyph land on 24dp. The Font row shows the active typeface and
opens a sample picker inside the same route. Appearance's content determines
both steps' height; the picker scrolls only when its samples need more space.
Selection applies immediately through `ReaderAppearanceCubit` and stays in the
picker. Back returns to Appearance; Close or a scrim tap dismisses the whole
flow. The hidden step cannot receive input, focus or accessibility actions.
Font samples are localized and use their actual bundled typefaces.
Font size steps between a small and a large Literata "A" (14/22sp, following
text scale until the large one fills its 48dp target); the percentage between
them is a muted caption, accented while the source overrides it, and tapping
it resets that override. Line spacing and Page margins are icon-only presets
(`reader_layout_presets.dart`) drawn by `ReaderLineSpacingGlyph` and
`ReaderMarginsGlyph`: Compact 1.4 / Normal 1.6 / Relaxed 1.8 line height and
Narrow 4 / Medium 8 / Wide 12% side margin, where Normal and Medium are the
defaults. A stored value between presets shows the nearest one (a midpoint
shows the default) and is not rewritten; tapping a preset, including the one
shown as nearest, commits its exact value through the existing preview/commit
calls. The glyph segments are icon-only `AppChoiceControl`s with
`AppChoiceOption.glyph` and `reselectable`, so tapping the preset shown as the
nearest match applies its exact value. Alignment offers labeled Normal (start)
and Justified choices; a legacy stored `end` reads back as start. Page turn (books only)
offers labeled Horizontal and Vertical paging. The three compact controls
share one width that grows with text scale and trail their label, moving below
it for large text in a narrow sheet. The labeled choices always span the
gutters below their label (16dp above the label, 8dp to the control), where
`AppChoiceControl` reflows long translations instead of truncating them. Large
text uses a tooltip-labeled Reset icon. Controls keep
their narrow `context.select` subscriptions and existing preview/commit/reset
callbacks; scrolling the sheet does not recreate the reading WebView.
`test/reader_appearance_layout_test.dart` checks gutters in LTR/RTL, en/ru/de
fit and 2x text at 320dp with the bundled faces.
Root goldens cover portrait, landscape, 2x text and RTL, including access to
the final page-turn control and font sample. Native reader flows check equal
step heights, manual return, DOM style updates,
persistence across reopening and reset to inherited settings.

```dart
abstract class TextAction {
  String get label;
  IconData get icon;
  Future<void> onExecute(BuildContext context, TextSelectionContext selection);
}
```

## Architecture — independent units of state

| Unit                          | Responsibility                                                             |
|-------------------------------|----------------------------------------------------------------------------|
| `ReaderBloc`                  | Content: load source document + highlights/bookmarks, debounced position save (500ms) |
| `ReaderUiCubit`               | Chrome, drawer, appearance-sheet and search-highlight UI state             |
| `ReaderSearchCubit`           | Search debounce, streamed results, recent queries, active match and return anchor |
| `ReaderSelectionCubit`        | Current text selection (text + `cfiRange`) and adjustment phase             |
| `ReaderImageSelectionCubit`   | Current image-page area selection for comics/fixed-layout pages            |
| `ReaderImageHighlightCubit`   | Persists image-page highlights with optional notes, then `ReaderBloc` refreshes annotations |
| `ReaderAppearanceCubit`       | Per-source reader appearance overrides over global preferences             |
| `ReaderBrightnessCubit`       | System/custom reader brightness state and active window override lifecycle |
| `ReaderComicThumbnailCubit`   | UI-only bounded preview queue/cache, owned by the visible Pages or Highlights tab |

### Contents and Saved Passages

Highlights combine the existing text query with an optional color filter. The
list caches that projection until its inputs change; reading-position updates
do not refilter it. Quotes/notes expand in place without re-extracting content.
Text and image rows share one interaction: tap the entry to navigate by its
stored anchor. Neither has standalone copy/arrow buttons or a reserved action
footer. A text row paints its highlight colour under the quote itself
(`ReaderHighlightQuoteText`: a `TextSpan` background that wraps line by line,
no start rule), then the note on its own row behind a 16dp pencil mark in
`bodySmall` (`ReaderHighlightNoteRow`), then a footer with the location at the
start and Read more / Show less at the end of the same row
(`ReaderHighlightFooter`). The fill is the reader theme's highlight colour at
the page's own highlight opacity, premixed over the drawer surface
(`readerHighlightQuoteBackground`); because reader and app themes are chosen
independently, it fades toward the surface until the quote keeps 4.5:1 (a
dark theme's deep yellow on a light drawer is lightened, not dropped), and
results are memoized per colour pair. Text copying remains available in the
reader's selection menu. A missing anchor disables navigation, not reading or
expansion. Text rows retain document direction, and row semantics announce the
navigation action. The quote follows the document direction; the note row
(mark and text) follows the note's own bidi direction, independent of the UI
and book; the footer follows the app locale, with the location aligned to the
app's leading edge while keeping the book's base direction. Legacy page-only
labels are localized in presentation; filtering accepts both the displayed
page label and the legacy English term. Locale changes invalidate the filtered
projection, while unrelated reading-position updates do not.

`ReaderHighlightNoteSheet` owns only the draft and discard confirmation. Saved
image-area highlights can add a previously skipped note, edit it, or save an
empty value to clear it. A null result cancels; a result containing a null note
explicitly clears/skips. `ReaderBloc` persists the patch through the existing
repository method. Editing a saved note shows one full-width Save command,
enabled only once the note changed; leaving is the header Close. A new
highlight keeps the Skip/Save pair because Skip keeps the highlight without a
note, a different outcome from Close. Close/system Back protect dirty text
through the Keep editing/Discard confirmation; scrim/drag dismissal is
disabled. Confirmation retains the draft field and its geometry.

Image-area rows instead show a cropped preview on the gutter, the localized
page number as their primary line with the same highlight fill under it, and
an optional expandable note row (pencil mark, `bodySmall`, three lines) whose
Read more sits at the end of its own footer row. Comic "chapter titles"
are archive file names, so they are never surfaced: the bottom chrome header
shows only the page counter for CBZ, image-area selections are saved without a
chapter title, comic bookmarks store none, and image rows ignore any stored
one. The TOC model itself is untouched (the Pages grid is unaffected).
Tapping the row opens
the saved page with its existing area annotations; it does not automatically
zoom or change the selection. Image rows have no clipboard or arrow action and
do not expose the stored `Page highlight` placeholder. Missing preview data does
not disable page navigation. CBZ thumbnails reuse the page preview pipeline;
other image-page formats keep a static placeholder without retrying an
unsupported thumbnail request. Note expansion and color filters survive tab
switches, independently of the shorter-lived thumbnail cache.
Titles/notes use their own text direction; page labels and row layout follow
the app locale, so Latin filenames/notes remain readable in an RTL interface.
Chapter rows indent with `EdgeInsetsDirectional` (app locale) while the chapter
text keeps the book direction. After the indent every row reserves the same
16dp mark slot plus 8dp, centred on the title's first line, so titles of one
level align: chapters before the active one are read (muted title, 16dp check,
semantics value `readerChapterRead`), the active chapter shows a dot in the
selected foreground, later chapters and the parts containing the active
chapter stay plain (`readerTocReadingStates`, cached per items/active index).
Each row ends on the 16dp gutter with its start position as a muted
`bodySmall` label in tabular figures, baseline-aligned with the title: the
estimated start page (announced as "Page N"; the renderer's page 0 reads 1),
else the whole start percent, else nothing. On the active row the label takes
the selected foreground, since the dark selected fill is tonal. Active chapter,
active search result and
bookmark rows share the plain `ListTile(selected:)` fill, drawn edge to edge
with an explicit rectangular shape: the app-wide 16dp tile radius is for inset
rows and must not bleed into full-bleed panel rows. The highlight color
filter strip starts on the 16dp gutter like the search field above it, with
8dp above and below its 48dp targets; its "All" entry is an `AppFilterChip`
with a visible selected state and the swatches beside it paint 32dp circles
(`ReaderHighlightColorButton(size:)`), while the selection popups keep 24dp.
Highlight rows own both 16dp gutters inside the body so Read more / Show less
(`ReaderHighlightExpandButton`, `AppButtonLabel`) ends its label on the
trailing gutter with the themed 16dp button padding and lets the ink and 48dp
target extend to the drawer edge; quote, note and location text keep their 16dp
edges. Beside a location the button is bounded to half the row, so a long or
2x label wraps inside it instead of overflowing.
Empty tabs render `EmptyState(compact: true)`, scrollable when a short sheet
leaves it less room than it needs.

Contents is an `AppInlineSheet` (component_library) in the reader's stack, not
a route. It opens at 60% of the height below the status bar, so the title, tabs
and search field land mid-screen and the current chapter is under the thumb;
the page stays visible, dimmed, above it. Dragging the header or scrolling a
list forward grows it to just below the status bar; a downward fling, pulling a
list past its top, the scrim, Close and System Back step it down or close it.
Landscape phones and large text open it at full. Hidden, it stays mounted
offstage, so each tab's search text and scroll offset survive; opening reveals
the active chapter in the list only (`ScrollPosition.ensureVisible`), never by
scrolling the sheet itself.

Deleting a bookmark persists immediately and atomically replaces its row with
an Undo state. Undo restores the original ID, date and complete anchor. It is
available per row until Contents closes, not on an expiring toast. Multiple
deletions can be restored independently; errors retain a retryable row. Delete,
restore, normal bookmark toggles and dismissal share the existing serialized
bookmark event bucket. Closing during deletion clears Undo after that write.
Bookmark rows show only their text (`bodyMedium`, two lines) and location
(`bodySmall`, muted) on the 16dp gutters, with no leading icon or trailing
button. Deleting is an end-to-start swipe (`ReaderSwipeToDelete`, a
`Dismissible` like the Library list) that reveals a full-bleed error fill with
the trash glyph on the trailing gutter and the localized "Delete bookmark"
before it; because a swipe is unreachable with a screen reader, every row also
carries the same delete as a `CustomSemanticsAction`. A completed swipe
dispatches the existing `ReaderBookmarkDeleted` and springs back; the Undo row
then replaces it in place, while a failed or queued write leaves an ordinary
row (with its retryable error). Swipe keys are the bookmark id. Only the
removed row has a trailing control, its `AppIcons.undo` button: 48dp target,
20dp glyph on the gutter, localized tooltip. Only the row whose write is in
flight disables its own action; the serialized event bucket orders the rest.
Inside the Contents `TabBarView` a horizontal drag that starts on a bookmark
row belongs to the row, so tab paging works from the tab bar or outside the
rows.
Oversized Contents tab labels scroll horizontally rather than overlapping;
the scrolling bar is inset 8dp so the first glyph lands on the 16dp gutter.

Deleting a highlight from the saved-highlight popup follows the same model
(`highlightEdits` in `ReaderState`): the page annotation disappears and the
existing toast shows, while the Highlights tab keeps the row muted as
"Highlight removed" with an icon-only Undo until Contents closes
(`ReaderHighlightUndoDismissed` purges it). There is no restore API, so Undo
re-adds the highlight through the repository (`addHighlight` /
`addImageAreaHighlight`) and then writes back the original `createdAt`; the
restored highlight has a new id but returns to its former list position and
the page overlay refreshes from the repository. Restore failures keep the row
with Undo. Removed rows neither navigate nor expand; image rows keep their
preview.

CBZ Contents replaces Chapters with a Pages grid, initially revealing the saved
page. The grid keeps the 16dp drawer gutter on every side (plus the bottom
system inset) with 12dp between tiles. Page order follows the book's
progression direction independently of the app locale. Captions and controls still use the app locale. Only the visible
Pages or Highlights tab owns `ReaderComicThumbnailCubit`; its callback is supplied by the reader
host, and the View receives no repository or WebView controller. One preview is
decoded at a time. Offscreen queued requests are discarded; a 24-entry LRU retains
at most 96 KiB encoded bytes per preview. Per-tile selectors avoid rebuilding the
grid/list for each response. Multiple highlights on one page share the encoded
bytes and Flutter image-cache key; their normalized crops are painted without
allocating separate cropped bitmaps or decoding the archive again. Per-page
consumer counts prevent a disappearing row from cancelling another visible
area's request. Visible comic lists/grids use zero cache extent, so offscreen
rows do not start preview work; text lists keep their normal prefetch.
Closing/changing tabs evicts owned Flutter image-cache
entries and ignores late responses. Failure keeps page navigation available and
offers Retry. There is no startup thumbnail generation or whole-archive decode.
The JS/WebView side's limits are documented in `reader_webview/README.md`.
Tests cover shared-page leases, cancellation/retry, crop pixels/aspect ratio,
long notes and missing anchors. `test/ui/comic_highlights_golden_test.dart` checks
the real drawer with 100 saved areas across phone themes, large text, landscape
and phone RTL; `integration_test/comic_highlights_test.dart` checks native CBZ
thumbnails and row navigation on iOS/Android. These are not device FPS tests.

`ReaderSearchCubit` debounces typing by 300ms and batches incoming results and
progress at 16ms intervals. A done event or stream close flushes immediately;
published result lists remain immutable snapshots. Reset, query replacement,
terminal error, and close discard pending updates and reject late events.
Synchronous renderer failures and stream errors become recoverable error state.
Stress tests bound emissions and cumulative published entries for bursts; the
benchmark under `benchmarks/` measures 1k/5k/20k-result workloads separately from
device frame performance. Continuous streams still publish cumulative snapshots,
so the burst benchmark is not a claim of constant work for every stream shape.

Search is the same inline sheet, with the input above the lazy results list.
While typing, the sheet sits on the keyboard, so the field and recent queries
stay near the thumb; after a search it rests at 60% over the page. Closing the
sheet preserves the
query, result snapshot, list offset and in-progress search; reopening a populated
query neither focuses the input nor repeats the document scan.
Search failures render the shared `ErrorState` with a filled Retry for the same
query, without adding a duplicate history entry; retry is ignored while a
search is already loading. The prompt and "no results" placeholders are
`EmptyState(compact: true)`, the same primitive the Contents drawer tabs use.

Selecting a result starts a navigation session with previous/next match controls
and a return-to-reading action. The return anchor is captured before opening the
panel (before native keyboard resizing), retained across query changes, and
cleared only when the session ends. Books restore their CFI; articles restore
scroll progress rather than re-centering the nearest sentence. Navigation controls
overlay the existing WebView: opening/closing them never changes its height or
repaginates the document. The reader sends only the covered height fraction to
the renderer. If the active match lies behind the panel, an amber edge marker
projects its horizontal position just above the panel; fully visible matches
and matches on other pages have no marker. The search drawer hides this marker.
Ending search,
opening contents/appearance or seeking the progress slider clears the session.
System Back (and the iOS edge swipe) dismisses the topmost overlay only:
`ReaderBackGuard` resolves `readerBackTargetFor` (search panel, then Contents
drawer, then the saved-highlight popup, then match navigation) and lets the
route pop only when nothing is layered over the page. Appearance and note
sheets are modal routes and are popped by the navigator before the reader is
consulted. Reopening the panel during match navigation scrolls the active
result into view (an off-screen builder tile is approached in up to three
extrapolated passes before the list's own `ScrollPosition.ensureVisible`
aligns it, leaving the sheet where it is); the field
uses `TextInputAction.search`. Widget tests cover keyboard/large-text layouts and preserved
state; native tests exercise navigation and return in the actual renderer.
Navigation buttons are unfilled with 48dp tap targets. Widget and golden tests
cover icon/text spacing, both themes, RTL and large text, including held presses.
Search content uses a 16 logical-pixel horizontal inset inside the safe area:
the header, field, recent queries, result count and excerpts share this inset.
Close is an `AppPlainIconButton` with the default 20dp glyph, its edge aligned
to the field. Its 48dp target extends into the gutter
(`readerDrawerActionEndPadding`) and stays inside the safe area, including
RTL. Recent queries keep their leading clock (it separates history from
results) and have no trailing control: removal is the same end-to-start swipe
and custom semantics action as bookmark rows (`ReaderSwipeToDelete`, labelled
"Remove from history"), and the row collapses with `AppMotion.short` (removed
without resizing under reduced motion). Result and history lists pad their bottom with
`readerDrawerListBottomPadding` (keyboard + system inset + 16dp), the same
formula as the Contents lists; inside the sheet the keyboard inset reads as
zero because the sheet itself sits on the keyboard.
The bottom match-navigation bar's Close target extends into the trailing
gutter so its glyph ends on the 16dp line shared with the return row's
percentage.
The swipe fill uses the shared trash icon; Close and field clearing keep the
cross. Removing a history entry does not run a search or close the panel.
Geometry tests and search goldens cover narrow/wide layouts, large text, RTL,
long queries and asymmetric landscape safe-area padding.
Icon controls are `AppPlainIconButton`s with circular feedback. The query and
return actions are themed `TextButton`s (padding only), so press feedback is
the theme's overlay rather than a custom opacity or splash override.
Both sheets rise from the bottom in every locale and mirror only their
content in RTL.

`ReaderBloc.reportError(e, st)` is a public facade over the protected
`addError()` so widgets (e.g. the context panel) can route non-fatal errors
through the bloc's error pipeline without emitting state themselves.

Bookmark edits are serialized independently of page-position events. A completed
write updates the saved list but changes the current-page badge only if the
position has not changed meanwhile. Bookmark revisions also prevent an older
source-load snapshot from overwriting edits made while it was pending.
Bookmark rows delete by swipe (trash glyph in the swipe fill) and retain the
existing in-place icon-only Undo action; the cross in the header only closes
the drawer. Undo and Close glyphs are the default 20dp, aligned to the
Contents field's 16dp gutter with full 48dp targets
(`readerDrawerActionEndPadding` in `reader_drawer_layout.dart`, defined from
`AppSizes.iconActionOutset`). Geometry tests compare the visible icon boxes,
not only button bounds; native flows also exercise deletion and Undo.
The bottom chrome is a floating capsule with a progress row above it. The
progress row and the capsule form one `ToastAvoidArea`, enabled only while the
chrome shows (the hidden chrome stays mounted, slid out); the fallback
selection panel and the search navigation bar are marked too, so a toast
(Copied, Highlight saved) floats above whichever is on screen. The
capsule is 60dp tall (stadium radius 30), 16dp from the screen edges and
`appBottomSafeInset` (minimum 16dp) above the bottom, capped at 560dp wide on
wide screens. It is the shared `AppFloatingCapsule`, like the Library's
bottom capsule: the chrome surface (`colors.surface`, the colour of the
brightness pill and context popups) at 92% with a hairline `outlineVariant`
border and `AppShadows.popover`. It holds equal slots, each centring a 48dp
`AppPlainIconButton` with circular feedback: Back, Contents, Appearance ("Aa"),
Bookmark (custom filled/outline glyph passed as `iconWidget`) and Search; Row
order mirrors in RTL. The page-turn toggle is not in the capsule for books or
articles (the setting lives in Appearance). Comics have no Appearance action,
so their capsule keeps the page-turn toggle as their only route to that
setting. Page-turn and active-bookmark glyphs, the page-bookmark indicator and
the Contents tab indicator use `context.actionForeground`.

The progress row sits 8dp above the capsule, 28dp from the screen edges (the
16dp gutter plus 12dp, inside the capsule's rounded ends), and follows the
book's page progression like the slider itself. The scrubbing `Slider` (3dp
track, 12dp thumb, 48dp-tall hit area) spans the whole row right above the
capsule, under the thumb, with the same local drag preview and a single
`goToFraction` on release; only this row rebuilds while dragging. The labels
read on one line under it, inset by the slider's overlay radius
(`readerProgressTrackInset`, 14dp) so they start and end with the track: at
the start the current chapter title for books,
for articles `readingTimeLeft` (minutes left in the whole article) or the
chapter title when there is no estimate; comics show neither a time nor their
archive file names. At the end is the percent/page label: short and numeric
in every locale, it keeps its natural width, bounded only by the row, so its
digits never truncate (`reader_chrome_progress_layout.dart`); the chapter
takes the rest on one line and truncates first. Above 130% text each
label takes its own line, the chapter up to two lines and the page label
end-aligned below it, so the slider never shares its line.
Text and slider use `readerChromeInkColor` (78% of the page text over the page,
at least 4.5:1 on every reader theme) because they sit on the page, over a
page-coloured band that fades in above the row so scrolled text never runs
behind them. That band passes taps through to the page, which hides chrome.

The top chrome is one centred `readerChromeLabel` line in the same ink, with
no plate, shadow or divider: `chapter · title` once a chapter title is known,
otherwise the title, ellipsized. It keeps the top safe-area inset and a 48dp
line; for articles the line is an ink button with button semantics, the title
as its value and a 48dp-high target that opens the original URL.
Changing chrome visibility must not resize or recreate the WebView; the root
search-overlay regression verifies both contracts under iOS/Android policies.
Status-bar icon brightness follows the page colour: the top line is drawn on
the page, and the Appearance, Contents and Search sheets stop below the status
bar and only scrim it (`readerSystemUiOverlayStyle`).
Active bookmark/Undo icons and the tab indicator use the accessible action
foreground. Active search results use the same selected color pair as Contents
and settings controls; text and emphasized matches remain readable on that fill.
The brightness pill beside the page uses `PositionedDirectional(end:)`, so it
sits 16dp from the trailing edge (like the page-bookmark indicator and every
other reader edge) and slides toward it in RTL. The top line shares the
capsule's 16dp content gutter. The transient CBZ page pill sits
`appBottomSafeInset` (minimum 16dp) plus 12dp above the bottom edge. Its step buttons are
`AppPlainIconButton`s; the value button is a 48dp selected control
(`selectedControlBackground/Foreground` while a custom level is active) whose
"System" label comes from `readerBrightnessSystem`.
Brightness diagnostic formatting/logging runs only in debug builds.

`ReaderBookPositionUpdated.fromBookPosition` maps both WebViews' positions,
including the article's `minutesLeft` (`BookPosition.minutesLeft`; books send
none), which the bloc keeps as live state like the page metrics. It is never
persisted.

Position persistence keeps the 500ms trailing debounce and serializes writes,
including the first immediate article position. Repository partial updates
avoid overwriting metadata from an old snapshot. Source loading preserves live
position/document features; `close()` waits for an already-running write as
well as the latest pending position.

Highlight refresh/delete/color/note events share a separate sequential bucket.
This preserves user edit order without serializing position events behind
storage work. Color/note updates patch only their own SQL fields, and source
reloads do not replace newer annotation state. Mutation success/failure is a
typed `ReaderHighlightEffect`, rendered by `ReaderHighlightEffectListener`
without rebuilding its content child. A queued command alone never produces a
success toast. Selecting a color for a new text selection remains a preview;
the Highlight action still explicitly saves it.

WebView recovery clears stale selection UI and temporarily clears readiness.
`ReaderWebViewFailed` reports terminal failure through the bloc's error pipeline
and switches to the shared `ErrorState` (error icon, filled Retry, outlined
Go Back). Retry
recreates the reading surface from the retained document, while a late source
load cannot erase a renderer failure.

## Widget tree highlights

- **`ReaderKeepAwakeDriver` / `ReaderKeepAwakeScope`** — content-only
  screen-awake owner. It enables keep-awake only while the reader shows bare
  reading content, and releases it when chrome, drawer, bottom sheet, route
  disposal, or app backgrounding takes over.
- **Driver pattern** — stateless widgets (`_ReaderBottomChromeDriver`,
  `_ContextPanelDriver`)
  subscribe to multiple BLoC/Cubit sources via `context.select` and feed
  ready values into dumb leaf widgets (`_ReaderBottomChrome`,
  `_ContextPanel`). All BLoC/Cubit interaction lives in drivers.
- **`_ReaderWebViewBody`** hosts a `BookReaderWebView` (foliate-js) keyed on
  source id / recovery token so source swaps and WebContent recovery rebuild
  the WebView cleanly. It maps domain highlights/bookmarks into WebView
  annotations and sends pull-down bookmark events back to `ReaderBloc`.
  Text highlights use CFI annotations; comic/image-page highlights use
  normalized area annotations keyed by page index.
- **`_ReaderArticleHtmlBody`** hosts `ArticleHtmlReaderWebView` for article
  sources. Articles scroll vertically, report progress through stable sentence
  anchors in `content.html`, expose contents/search/bookmark chrome actions,
  and render text highlights through stable article anchors. Image-area
  selection remains specific to the foliate comic/fixed-layout path.
- Every reader motion (chrome slides, Contents/Search sheets, brightness pill, loading
  scrim, dimming tween, swatch rings, page overlay) resolves its duration
  through `context.motion(AppMotion.x)`, so reduced motion settles in one
  frame; the appearance step and tap-zone hint controllers jump instead.
- Reader theme (`ReaderThemeData`, font preset, layout preset) is resolved
  from `ReaderAppearanceCubit` and passed as CSS / URL params to the WebView
  (`--rf-accent-color` is the reader theme's `accentColor`, not the app
  primary); the
  WebView bodies subscribe to the document, readiness, appearance and annotation
  state they need, not to each selection-menu update. Rebuilding a body does not
  recreate its keyed WebView unless source/recovery identity changes.
- `buildBookCustomCSS` supplies semantic code panels, quotes, links and headings
  above the reflowable book color reset in `reader_webview`. Code borders retain
  the theme divider color; dark-theme descendants inherit semantic parent
  colors instead of replacing link/quote colors with primary text. The same
  semantic overlay is used by the article reader; book palette normalization
  and its contrast fallback remain owned by the book JS runtime.
- Comic page-zone taps remain available with chrome open and hide chrome while
  turning the page. Actual controls (brightness, toolbar buttons) keep their
  own hit targets. Text books retain the dismiss-only page barrier. The zone
  fraction comes from the `reader_webview` bridge contract so Flutter routing
  and JS double-tap arbitration cannot drift independently.
- Code typography retains the system monospace families and adds the bundled
  symbol fallback for missing callout numerals. The book normalizer excludes
  publisher annotations/captions from code detection, so a long explanation
  does not become a code panel merely because its class name contains `code`.
  `flutter test test/book_typography_test.dart` exercises the generated CSS
  with the production book runtime in Chromium/WebKit, including light/dark
  themes, glyph pixels and selection/CFI stability.
- Reflowable book tables use their intrinsic width inside the existing
  horizontal scroll wrapper. Publisher percentage widths cannot compress
  cells to individual letters. Paragraphs still wrap normally within cells;
  a preferred `max(100%, 40em)` table width prevents prose rows from expanding
  indefinitely, while minimum content width can exceed that cap. These rules
  do not change article table sizing or emergency wrapping in ordinary prose.

## Table Verification

After `make reader-browser-setup`, run
`flutter test test/book_table_layout_test.dart` from this package. It passes the actual
Flutter-generated CSS to Chromium and WebKit and checks publisher widths,
local scrolling, CFI stability, themes, viewport changes and sole-child tables.
The native `integration_test/table_rendering_test.dart` additionally checks
late-page table painting on iOS, scroll offsets and reading-position stability
in all three reading modes. Run it from the repository root:

```sh
READFLEX_NATIVE_DEVICE=<device-id> fvm flutter drive \
  --driver=test_driver/ui_driver.dart \
  --target=integration_test/table_rendering_test.dart -d <device-id>
```

Artifacts go to `.local/ui-device/`. iOS screenshots include a text-pixel
assertion; Android screenshots use the native driver transport. These checks
do not simulate physical-device finger gestures. Playwright's WebKit build
is not the system WKWebView: its late-column scroll-container painting can
differ, so geometry-only browser results are not a native visual guarantee.

## Dependencies

- `book_repository`, `article_repository`, `highlight_repository` — content,
  bookmark and highlight persistence
- `preferences_service` — global reader appearance, per-source overrides,
  search history, and global reader brightness preference persistence
- `screen_control_service` — content-only keep-awake plus temporary
  application brightness control
- `reader_webview` — `BookReaderWebView`, `ArticleHtmlReaderWebView`,
  `FoliateStyle`, `ReaderHighlight`, `ReaderImageAreaSelection`
- `shared` — `TextAction`, `TextSelectionContext`
- `domain_models` — `Book`, `SourceType`
- `component_library` — `ReaderThemePreset`, `AppIcons`, `AppSpacing`,
  `AppIconSize`, `AppMotion`, `AppPlainIconButton`, `AppFilterChip`,
  `EmptyState`, `ErrorState`
- `flutter_bloc`, `equatable`, `stream_transform`
