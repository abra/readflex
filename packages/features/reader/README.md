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
Foreground` pair behind the active sample and label. Font options use the
same fill-plus-check selection as the Language sheet, without an extra border.
The Font row shows the active typeface and
opens a sample picker inside the same route. Appearance's content determines
both steps' height; the picker scrolls only when its samples need more space.
Selection applies immediately through `ReaderAppearanceCubit` and stays in the
picker. Back returns to Appearance; Close or a scrim tap dismisses the whole
flow. The hidden step cannot receive input, focus or accessibility actions.
Font samples are localized and use their actual bundled typefaces. Page turn
remains the existing row with horizontal/vertical icon choices (books only).
Labels wrap/reflow without scaling down; all numeric stepper targets are at
least 48dp. Large text uses a tooltip-labeled Reset icon and stacks setting
label/control pairs. Numeric value areas grow with text scale. Controls keep
their narrow `context.select` subscriptions and existing preview/commit/reset
callbacks; scrolling the sheet does not recreate the reading WebView.
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
footer. Text rows keep the colored quote rule, optional note and location;
text copying remains available in the reader's selection menu. A missing
anchor disables navigation, not reading or expansion. Text rows retain
document direction, and row semantics announce the navigation action.
The quote rule/padding follows the document direction as one block; note text
uses its own bidi direction, independent of the UI and book. Legacy page-only
labels are localized in presentation; filtering accepts both the displayed
page label and the legacy English term. Locale changes invalidate the filtered
projection, while unrelated reading-position updates do not.

`ReaderHighlightNoteSheet` owns only the draft and discard confirmation. Saved
image-area highlights can add a previously skipped note, edit it, or save an
empty value to clear it. A null result cancels; a result containing a null note
explicitly clears/skips. `ReaderBloc` persists the patch through the existing
repository method. Close/Cancel/system Back protect dirty text; scrim/drag
dismissal is disabled. Confirmation retains the draft field and its geometry.

Image-area rows instead show a cropped preview, the localized page number as
their primary line, and an optional expandable note. Comic "chapter titles"
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
text keeps the book direction; active chapter, active search result and
bookmark rows share the plain `ListTile(selected:)` fill, drawn edge to edge
with an explicit rectangular shape: the app-wide 16dp tile radius is for inset
rows and must not bleed into full-bleed panel rows. The highlight color
filter's "All" entry is an `AppFilterChip` with a visible selected state.
Empty tabs render `EmptyState(compact: true)`. The drawer slides in from the
leading edge of the app locale.

Deleting a bookmark persists immediately and atomically replaces its row with
an Undo state. Undo restores the original ID, date and complete anchor. It is
available per row until Contents closes, not on an expiring toast. Multiple
deletions can be restored independently; errors retain a retryable row. Delete,
restore, normal bookmark toggles and dismissal share the existing serialized
bookmark event bucket. Closing during deletion clears Undo after that write.
The trailing trash changes to `AppIcons.undo`, never a text button or refresh
icon. Both use the same 48dp target and 20dp glyph in every locale/text scale,
with a localized tooltip/accessibility name. No label measurement is needed,
and adjacent rows stay in place. Only the row whose write is in flight
disables its own action; the serialized event bucket orders the rest.
Oversized Contents tab labels scroll horizontally rather than overlapping.

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
page. Page order follows the book's progression direction independently of the
app locale. Captions and controls still use the app locale. Only the visible
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

Search keeps its full-height side-sliding panel with the input above the lazy
results list. The list avoids the keyboard. Closing the panel preserves the
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
extrapolated passes before `Scrollable.ensureVisible` aligns it); the field
uses `TextInputAction.search`. Widget tests cover keyboard/large-text layouts and preserved
state; native tests exercise navigation and return in the actual renderer.
Navigation buttons are unfilled with 48dp tap targets. Widget and golden tests
cover icon/text spacing, both themes, RTL and large text, including held presses.
Search content uses a 16 logical-pixel horizontal inset inside the safe area:
the header, field, recent queries, result count and excerpts share this inset.
Close and history-removal buttons are `AppPlainIconButton`s with the default
20dp glyph on the same trailing axis, with glyph edges aligned to the field. Their 48dp targets extend into the
gutter and stay inside the safe area, including RTL.
History removal uses the shared trash icon; Close and field clearing keep the
cross. Removing a history entry does not run a search or close the panel.
Geometry tests and search goldens cover narrow/wide layouts, large text, RTL,
long queries and asymmetric landscape safe-area padding.
Icon controls are `AppPlainIconButton`s with circular feedback. The query and
return actions are themed `TextButton`s (padding only), so press feedback is
the theme's overlay rather than a custom opacity or splash override.
The panel slides in from the leading edge of the app locale
(`readerSidePanelHiddenOffset`), like the Contents drawer.

`ReaderBloc.reportError(e, st)` is a public facade over the protected
`addError()` so widgets (e.g. the context panel) can route non-fatal errors
through the bloc's error pipeline without emitting state themselves.

Bookmark edits are serialized independently of page-position events. A completed
write updates the saved list but changes the current-page badge only if the
position has not changed meanwhile. Bookmark revisions also prevent an older
source-load snapshot from overwriting edits made while it was pending.
Bookmark rows use the shared trash icon for deletion and retain the existing
in-place icon-only Undo action; the cross in the header only closes the drawer.
All three glyphs are the default 20dp, aligned to the Contents field's 16dp
gutter with full 48dp targets (`_readerDrawerActionEndPadding`). Geometry tests compare the visible icon boxes, not only button
bounds; native flows also exercise deletion and Undo.
The reader's bottom toolbar is built from `AppPlainIconButton` (48dp targets,
circular pressed feedback), including its custom filled/outline bookmark glyph
passed as `iconWidget`. Page-turn and active-bookmark glyphs, the page-bookmark
indicator and the Contents tab indicator use `context.actionForeground`; only
the filled progress slider keeps `colors.primary`. The article title in the top
chrome is an ink button with button semantics and a 48dp-high target.
Changing chrome visibility must not resize or recreate the WebView; the root
search-overlay regression verifies both contracts under iOS/Android policies.
Status-bar icon brightness follows the surface under the status bar: the app
chrome while the toolbar or a full-height panel (Contents, Search) is shown,
otherwise the page colour; the appearance sheet only scrims the page and keeps
the page-derived brightness (`readerSystemUiOverlayStyle(panelVisible:)`).
Active bookmark/Undo icons and the tab indicator use the accessible action
foreground. Active search results use the same selected color pair as Contents
and settings controls; text and emphasized matches remain readable on that fill.
The brightness pill beside the page uses `PositionedDirectional(end:)`, so it
sits at the trailing edge and slides toward it in RTL. Its step buttons are
`AppPlainIconButton`s; the value button is a 48dp selected control
(`selectedControlBackground/Foreground` while a custom level is active) whose
"System" label comes from `readerBrightnessSystem`.
Brightness diagnostic formatting/logging runs only in debug builds.

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
- Every reader motion (chrome/drawer/search slides, brightness pill, loading
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
