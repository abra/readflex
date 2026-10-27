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
    ValueChanged<double>? onReadingPositionSaved,     // saved progress
    void Function(String url, String title)? onArticleTitlePressed,
    ValueChanged<String>? onOpenExternalLink,
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

### External links

A link in a book, article or PDF that leaves the reader (http(s), `mailto:`,
`tel:`) never opens directly. `ReaderExternalLinkPrompt` turns each link the
WebView reports into `ReaderExternalLinkSheet`: "Open link?", the real
destination, Copy link and Open. Only Open hands the link, unchanged, to
`onOpenExternalLink`; Copy puts it on the clipboard with a toast; Close, a scrim
tap or Back keep the page as it was. One sheet at a time, so a double tap or a
navigation the page starts itself cannot stack sheets; other schemes and links
without a host are ignored, as they were.

`ReaderExternalLinkDestination` decides what the sheet shows: the host (an
email address, a phone number) first and never shortened, so link text cannot
hide where a link goes, then the whole address in at most three lines. Only
escaped non-ASCII text is decoded for reading, so Cyrillic or Arabic paths read
as words while `%2F`/`%3A` stay escaped as browsers show them, and anything that
decodes to control or bidi-format characters (`%E2%80%AE`) stays escaped too.
Addresses read left to right in RTL interfaces. Routing opens confirmed web
links in the in-app browser (`LaunchMode.inAppBrowserView`: Safari View
Controller, Custom Tabs), so Done returns to the same page, and email or phone
links in their apps. Tests: `reader_external_link_destination_test.dart`,
`reader_external_link_prompt_test.dart`; root goldens
`reader_external_link_golden_test.dart`.

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
`ReaderThemeSwatches` shows each theme as a sample in the preset's page colors
(`readerAppearanceSample`) with its name: an ink tile with a 48dp target and
`Semantics(button, selected)`. Only the selected sample's 2dp accent ring and
accent name mark the choice; there is no tinted block behind it. All five sit
in one row when every name fits its column on one line with the ink, else in
rows of three (so "Бумага" never breaks mid-word); when even three do not fit
(large text), they scroll in one row under `ScrollEdgeFadeStack` fades that
opens with the selected theme centered and then keeps the reader's position.
Each swatch keeps a 4dp ink inset around its sample
(`ReaderThemeSwatches.inkInset`), so the sheet body gutter is reduced by that
inset for the swatches only: sample borders, the "Theme" label, the Font row
and the setting rows all sit on the 24dp gutter while the ink tiles bleed 4dp
past it. Font options use the same fill-plus-check
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
offers labeled Horizontal and Vertical paging. The compact rows come first and
together, 8dp apart: Font, then Font size, Line spacing and Page margins, whose
controls fill exactly the end half of the column so they start on the split
of the two-option choices below. All three move under captions, as full-width
controls 16dp apart, when the sheet is narrow at large text, when half the
column cannot hold three 48dp segments, or when a label would need a third
line. Text alignment and Page turn are `AppSettingsSection` captions above
full-width choices, 16dp below the group above, where `AppChoiceControl`
reflows long translations instead of truncating them. Reset keeps its label
while the title can shrink to fit beside it (`BottomSheetHeader.minTitleScale`)
and otherwise becomes a tooltip-labeled icon (`headerCompactTrailing`); only
when even that does not fit does it move below the title. Controls keep
their narrow `context.select` subscriptions and existing preview/commit/reset
callbacks; scrolling the sheet does not recreate the reading WebView.
`test/reader_appearance_layout_test.dart` checks gutters, the half-width
controls in LTR/RTL, en/ru/de fit, Reset beside the title and whole theme names
at 320dp with the bundled faces; `test/reader_theme_swatches_test.dart` covers
the five, three and scrolling layouts and the opening position.
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

## Reader surface contract

`ReaderSurface` (`reader_surface.dart`) is the set of commands the screen
sends to whatever draws a book: navigation (`goToCfi`, `goToFraction`,
`goToHref`, `goToSectionIndex`, `goToSearchResult`, `goToBookmark`, page
turns, `toggleBookmark`), search (`searchBookStream`, `clearSearch`), text
selection (`clearSelection`, `currentTextSelection`, highlight previews),
image areas (previews, retention, control bounds) and `pageThumbnail`. It
was extracted from what the screen asked of `BookReaderWebViewState`;
`ReaderWebViewSurface` forwards to the WebView under the screen's key and
is a no-op before it mounts, exactly as the key-based calls were. Events
from the surface (positions, selections, taps, annotations, load state)
remain the callbacks of the surface widget, wired to the blocs where it is
built (`_ReaderWebViewBody`). A native engine (`package:vellum`) takes the
WebView's place behind this contract one format at a time; articles keep
their own WebView outside it for now.

### Native comics (`_ReaderComicBody`, `ReaderComicSurface`)

`ReaderScreen.nativeFormats` (from `READFLEX_NATIVE_FORMATS`, empty by
default) names the formats drawn natively. For a CBZ in that set the
content body mounts `_ReaderComicBody` instead of the WebView body: it
opens the archive with `ComicBook` (the stored `comicPageOrderVersion`
keeps the page order of saved positions), restores the page from the
saved fake CFI or the fraction, and shows `FixedPagesView`. The
Appearance sheet's page turn sets the view's `axis` (vertical turns pages
up and down; taps keep their left and right zones as previous and next,
as the WebView's `page-turn-axis` did). Its events feed
the same blocs and cubits: positions become `ReaderBookPositionUpdated`
with the WebView's numbers (`fraction = (page + 1) / pageCount`, chapter
counter = page counter, `relocationReason` `page` for turns), the page
list becomes `ReaderTocUpdated`, taps go through the shared tap-zone
dispatcher, long presses create image-area drafts in a
`ComicImageAreaDraft` that `ReaderImageSelectionCubit` mirrors, saved
image-area highlights are drawn by `ComicImageAreaLayer`, and a bookmark
toggle emits `ReaderBookmarkChanged` with the page as CFI, page anchor and
`Page N / M` content, matching the rows the WebView writes. Readiness is
the first visible page image (`onPageShown`), which releases the loading
scrim. `ReaderComicSurface` implements the commands over the controller
and the draft; comics have no text, so search and text-selection commands
are inert, and previews are `ComicPageImage` providers. A document that
fails to open reports `ReaderWebViewFailed` as the WebView would.
`_ReadyContentBody` picks the surface and body per format, so the chrome,
drawers and context panel never know which engine is drawing.

### Native PDF (`_ReaderPdfBody`, `ReaderPdfSurface`)

For a PDF in `nativeFormats` the body mounts `_ReaderPdfBody`: it opens
the file with `PdfBook` (a password-protected or damaged file reports
`ReaderWebViewFailed` with the document kind), restores the page from
the saved CFI or fraction, and shows `FixedPagesView` over `PdfPages`,
with the Appearance sheet's page turn as its `axis`, margin trimming as
`visibleRectOf` and page colours as `pageColors` (vellum's
`pageColorsFor`: a colour matrix, so the same pixels under Impeller and
Skia).
The outline becomes `ReaderTocUpdated` with page CFIs as hrefs and the
entries' depth as `level` (an entry without a page keeps an empty href);
the chrome's chapter line is the first outline entry that opens the
current page, as the WebView matched TOC hrefs. `ReaderDocumentFeatures`
reports `pdf`, the page count and the outline, and `hasSearchableText`
once a loaded page has text. Positions and bookmarks follow the comic
body's numbers. Text layers come from a `PdfTextLayerCache` (the pages on
screen and their neighbours are loaded ahead); `PdfTextOverlay` draws
saved text highlights resolved on the page (`resolvePdfTextAnchor`: the
WebView's DOM CFIs resolve by the highlight's text, vellum's by range),
the search hit and the selection. A long press selects a word and feeds
`ReaderSelectionCubit` what the WebView's bridge sent: the exact text,
the sentence as `contextText`/`markedContextText`, vellum's range CFI and
the selection rect as viewport fractions; a tap on a saved highlight
focuses `ReaderHighlightFocusCubit` with the sentence as context. Margin
crops (`trimPageMargins`) are measured per page with
`detectPdfPageContent` for the box a page is fitted into and passed as
`visibleRectOf`; `pageColors: theme` maps the reader theme's background
and text colour through `pageColorsFor`. `ReaderPdfSurface` implements
the commands: navigation over the controller, `searchBookStream` through
`searchPdfBook` with the WebView's excerpt shape, `goToSearchResult`
opening the hit's page and marking its range, selection preview colour
and retention on the `PdfTextSelection`, previews as `PdfPageImage`
providers; image-area commands are inert.

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
| `ReaderPageThumbnailCubit`   | UI-only bounded preview queue/cache, owned by the visible Pages or Highlights tab |
| `ReaderSelectionTipCubit`     | One-time "Press and hold a word" tip: when it shows, hides and ends for good |

### PDF page appearance

PDF pages are images, so the Appearance sheet swaps its text controls for page
controls: the theme, Margins (Whole page or Trimmed), Page colors (Theme or
Original) and Page turn, each a caption above a full-width choice, 16dp apart. `showReaderAppearanceSheet(pdfControls: true)` builds
this variant without the font step, and the chrome's appearance button reads
"Appearance" instead of "Font" for PDF.

- **Defaults.** Trimmed and Theme come from `ReaderAppearancePreferences`
  (`trimPageMargins`, `pageColors`). Changes in the sheet are per-book
  overrides through `ReaderAppearanceCubit`; Reset returns to the defaults.
- **Delivery.** The reader maps both into `FoliateStyle.cropPageMargins` and
  `FoliateStyle.pageColors`; `reader_webview` crops and recolors the bitmaps.
  Other formats ignore them.
- **Progress.** The bottom chrome shows `percent · page / total` for PDF from
  the zero-based page fixed layouts report, so page 15 reads 15.

`test/ui/reader_pdf_controls_test.dart` drives the sheet, the WebView style
and the Pages tab end to end; `reader_appearance_sheet_test.dart` covers the
variant's controls, persistence, Reset, semantics and 2x text.

### Line length and text columns

`readerTextColumns` (`reader_text_columns.dart`) keeps lines readable. In
every window it gives `FoliateStyle` a measure of `kReaderMaxLineWidthEm`
(32em of body text, about 68 characters), so a phone in landscape and a
tablet in portrait centre one column of it instead of running ~85 characters
across the page. A phone page in portrait is narrower than the measure, even
at the smallest reader size, and lays out as before.

A wide window (`AppWindowSize.isWide`: at least 840 × 480, never a phone)
also gets the reader's Columns choice:

- **Auto** (default, `maxColumnCount` 0): one column in portrait; in
  landscape two pages side by side while each keeps most of the measure, so
  large text or a short window falls back to one column.
- **One**: one column at the measure; the margins grow around it.
- **Two**: a spread in either orientation.

Foliate applies it in one layout pass, including on rotation, so the style
reaches the WebView again only when the window crosses the wide threshold or
the choice changes. Narrow windows, phones included, keep one column at the
measure whatever the choice says; articles always keep one column at the
measure; PDF and comic pages keep their own layout. Appearance shows
**Columns** (Auto / One / Two, under Page turn) only for reflowable books in a
wide window (`showReaderAppearanceSheet(showColumnControls:)`); the choice is
a per-book override like the other rows (`ReaderAppearanceCubit.setColumns`,
`ReaderAppearanceOverride.columns`) and Reset clears it. Root
`test/ui/reader_text_layout_test.dart` follows the style through window
changes; `reader_webview` browser tests cover the layout itself.

In every window the style also carries the side safe-area insets
(`MediaQuery.padding` left/right), so book and article text stays clear of a
landscape phone's display cutout while the page and its tap zones still fill
the window. The tap-edge lines sit inside the same insets.

### Text size in tablet-sized windows

`readerDeviceFontScale` (`reader_device_font_scale.dart`) multiplies the base
font size that `FoliateStyle` sends to the page. The reader's own text size
(100% by default in Appearance) applies on top and never changes. It combines
two independent corrections:

- A tablet-sized window, at least 600 on its shortest side like Android's
  `sw600dp`, gets 12.5% larger text on every platform: 18px instead of 16px.
  A tablet is held further away, and the 32em measure grows with the text, so
  lines keep their length in characters. The shortest side ignores
  orientation: rotation never resizes the text, phones stay phones in
  landscape, and a narrow Split View or Slide Over window reads like a phone.
  The style reaches the WebView again only when a resize crosses that
  threshold.
- Android WebViews render text smaller than iOS at the same size, so Android
  adds up to 12% on phones and 4% on tablets.

The platform is `defaultTargetPlatform`, not the `Theme`'s: the correction
belongs to the WebView engine the app runs on, which the plugin picks the same
way. Books and articles share the multiplier; PDF and comic pages are images
and ignore it.

### One-time selection tip

The first time a page of selectable text is on screen, a tip at the bottom
says "Press and hold a word" and names the selection menu's commands by their
real labels (`highlightAction`, `commonCopy`, `translationAction`,
`dictionaryAction`), with "Got it".

- **When it is due:** a ready article, EPUB, FB2, MOBI or AZW3, or a PDF whose
  features report a text layer (`readerSupportsSelectionTip`); never a comic.
  The WebView must have painted the page, and no chrome, search navigation or
  selection may be on screen. A tap on the chrome while the page loads does
  not use up the session.
- **Policy (`ReaderSelectionTipCubit`):** at most once per reader session and
  in at most `maxShows` (3) sessions. "Got it" or any text selection ends it
  for good. Opening the controls or a book page turn (relocation reason
  `page` or `snap`, `isReaderPageTurn`) hides it until the next session.
  Articles are not hidden by scrolling: their shell also reports image loads
  and layout observers as `scroll`. `PreferencesService` stores
  `readerSelectionTipShowCount` and `readerSelectionTipDismissed`.
- **Wiring:** `ReaderScreen` provides the cubit. `ReaderSelectionTipDriver`
  sits in the content `Stack` and feeds it through
  `ReaderSelectionTipScope`, which calls the cubit from lifecycle methods,
  never `build`. The content's position handler reports page turns.
- **Look (`ReaderSelectionTipCard`):** the neutral inverse plate of the app's
  toasts. The glyph and "Got it" take the opposite theme's action color
  (`primaryFixedDim` on the light theme's dark plate, `primary` on the dark
  theme's light plate), at least 4.5:1. From 130% text "Got it" moves below
  the message. The tip is inset 16dp from the edges and the safe area, at
  most 560dp wide and 60% of the screen tall; past that its message scrolls.
  It sits in a `ToastAvoidArea`, fades with `AppMotion.short`, and appears at
  once under reduced motion. The message is a live region.

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
scrolling the sheet itself. While hidden it keeps the position it last showed
(and keeps it through the closing slide), so page turns do not rebuild it; the
CBZ page pill likewise reads page numbers only for image pages.

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
A label cut by the sheet edge fades into the sheet (`ScrollEdgeFadeStack`,
horizontal) so it reads as more tabs to scroll to; the divider stays whole.
The "Contents" title stays on one line: a long translation at large text
shrinks to at most `readerDrawerTitleMinFontScale` (0.8) of its size before it
ellipsizes (`readerFittedTitleFontSize`). The three Contents search fields
fall back to the short `commonSearch` hint when the full one would be cut.

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

`readerContentsTabs` decides the Contents tabs per format:

- **CBZ** replaces Chapters with Pages: a comic's table of contents is its page
  list, so taps open the page's TOC entry.
- **PDF** keeps Chapters first, even without an outline (the tab then shows
  its empty state), and adds Pages once the document reports its page count.
  Pages taps call `goToSectionIndex`; the current page is the zero-based
  chapter page that fixed layouts report.
- **Other books** keep Chapters, Bookmarks and Highlights.

Filled tabs share the width equally, so the bar scrolls once the widest label
does not fit its share; four tabs in Arabic or German scroll from the gutter.

`ReaderPageGrid` shows the pages of both formats, initially revealing the saved
page. The grid keeps the 16dp drawer gutter on every side (plus the bottom
system inset) with 12dp between tiles. Page order follows the book's
progression direction independently of the app locale. Captions and controls still use the app locale. Only the visible
Pages or Highlights tab owns `ReaderPageThumbnailCubit`; its callback is
`ReaderSurface.pageThumbnail`, which answers an `ImageProvider` (the WebView
wraps an encoded preview of at most 96 KiB in a `MemoryImage`; the native
engine returns its own provider decoded at preview width), and the View
receives no repository or engine controller. One preview is loaded at a time.
Offscreen queued requests are discarded; a 24-entry LRU evicts providers from
the Flutter image cache. Per-tile selectors avoid rebuilding the grid/list for
each response. Multiple highlights on one page share one provider and
image-cache entry; their normalized crops are painted without allocating
separate cropped bitmaps or decoding the archive again. Per-page
consumer counts prevent a disappearing row from cancelling another visible
area's request. Visible comic lists/grids use zero cache extent, so offscreen
rows do not start preview work; text lists keep their normal prefetch.
Closing/changing tabs evicts owned Flutter image-cache
entries and ignores late responses. Failure keeps page navigation available and
offers Retry. There is no startup thumbnail generation or whole-archive decode.
The JS/WebView side's limits are documented in `reader_webview/README.md`.
Tests cover shared-page leases, cancellation/retry, crop pixels/aspect ratio,
long notes and missing anchors. `reader_contents_tabs_test.dart` pins the tab
rules; `reader_toc_drawer_test.dart` covers PDF Chapters/Pages with and
without an outline, page taps, the late page count, the fitted title, tab
fades and compact search hints; `reader_drawer_title_fit_test.dart` pins the
fit math; `test/ui/pdf_contents_golden_test.dart` snapshots both PDF
tabs in every visual profile. `test/ui/comic_highlights_golden_test.dart` checks
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
including the first position of any source (`0` to above `0`), which is saved
at once because it is what puts the source in Library's Continue reading.
Repository partial updates avoid overwriting metadata from an old snapshot.
Source loading preserves live position/document features; `close()` waits for
an already-running write as well as the latest pending position.
`onReadingPositionSaved` fires with the saved progress after each write
reaches the repository, including the flush on `close()`, never after a failed
one. The Library uses it to update that source while the reader still covers
it, without reading storage.

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
