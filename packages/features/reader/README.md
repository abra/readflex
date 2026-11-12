# reader

Full-screen reader for books, comics, and saved articles. The single route
(`/reader/:sourceId`) hosts the page, drawn by the `pagecraft` engine, reader
chrome, and a text-selection context panel populated by pluggable
`TextAction`s.

Reader chrome uses the shared platform presentation (`AppScaffold`, buttons,
fields, sliders and progress). `ReaderNavigationTile` adapts chapter, bookmark
and search-result rows to Cupertino or Material. These UI choices do not
change Pagecraft controllers, document layout, pagination or persisted reading
positions. Text selection retains its adaptive SDK/native bridge and local
selection-theme overrides; app actions remain custom.

## Maintainer reading path

Start with the dependency injection in [app routing](../../../lib/app/routing.dart),
then [ReaderScreen](lib/src/reader_screen.dart), the
[state owners](#architecture--independent-units-of-state) and the format bodies
below. `reader_screen.dart` and its ten `part` files form **one Dart library**:
they share imports and private declarations. The split groups screen composition,
lifecycle, five format bodies, chrome, drawers and context panels; these files
are not independently importable modules.

| Step | Owner and contract |
|---|---|
| Resolve source | [ReaderBloc](lib/src/reader_bloc.dart) loads repositories into `ReaderDocument`, annotations and a saved position. `ReaderStatus.ready` means this data is available; it does not mean a page has been rendered. |
| Open and draw | [Screen content](lib/src/reader_screen_content.dart) selects the text, article, comic, PDF or DjVu body. The body owns its Pagecraft source/controller, reports first-page readiness and releases them on disposal. |
| Navigate and select | [ReaderSurface](lib/src/reader_surface.dart) receives commands from chrome/drawers; body callbacks report positions, search and selection to their state owners. Views receive state and UI callbacks, not repositories. |
| Persist and leave | `ReaderBloc` updates live position immediately, debounces writes by 500ms and drains pending writes on `close`. [Lifecycle scopes](lib/src/reader_screen_lifecycle.dart) release temporary brightness and keep-awake requests on background/disposal. |

For changes to opening, restoration or disposal, begin with
[bloc tests](test/reader_bloc_test.dart) and the screen tests for
[text](test/reader_screen_text_test.dart),
[articles](test/reader_screen_article_test.dart),
[comics](test/reader_screen_comic_test.dart) and
[PDF](test/reader_screen_pdf_test.dart). Surface tests exercise the command
contract separately from rendering; native selection handles and device frame
timing still need device checks. Pagecraft's parser/layout responsibilities are
documented in its [README](../../pagecraft/README.md).

## Public API

```dart
class ReaderScreen extends StatelessWidget {
  ReaderScreen({
    required String sourceId,
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
    String? initialCfi,
  });
}
```

`ReaderBloc` requests the book and optional article by `sourceId` alongside
highlights and bookmarks, and prefers the book if both repositories return a
source. Saved articles open from `Article.contentHtmlPath`. It maps both
books and articles to a source-neutral `ReaderDocument`, so article HTML is not
modeled as an EPUB. `initialSource` reuses book metadata already loaded by the
previous route; page preparation still uses the shared loading overlay. For articles,
`onArticleTitlePressed` lets the composition root open the original article URL
from the top reader chrome without coupling the reader package to
`url_launcher`. `initialCfi` opens a saved word or highlight's anchor once the
document is ready; Practice supplies it when opening an item in its source.

### Opening content

One outer loading overlay covers metadata loading and preparation of the first
visible page or article. Its indeterminate circular indicator uses the reader
theme's foreground and a localized accessibility label for every format.
The overlay fades away when the surface reports ready, or gives way to the
existing error/retry UI. Hidden indicators leave semantics and stop ticking;
under reduced motion the loading arc stays still and the overlay settles
immediately.

### External links

A link in a book, article or PDF that leaves the reader (http(s), `mailto:`,
`tel:`) never opens directly. `ReaderExternalLinkPrompt` turns each link the
page reports into `ReaderExternalLinkSheet`: "Open link?", the real
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
The popup captures input only inside its visible controls, leaving the page's
selection handles interactive so the selected range can be resized in place.
The saved-highlight popup (`ReaderSavedHighlightPopup`) is different: its
full-screen barrier exists only while the popup is open and is opaque, so the
dismissing tap never also toggles chrome or turns the page.
All three popups (text selection, image-area selection, saved highlight) clamp
horizontally inside the safe area plus a 16dp inset, so landscape cutouts
never cover them; their width is sized from the safe width.
Each action starts resolving the current selection on pointer down, before
focus can collapse it, and awaits that same snapshot on execution. The reader
also retains the latest changed range as a fallback, so expanding a word into
a paragraph cannot send the initial word to Copy, Translate, Define, or
Highlight.
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
three-line excerpt limit. Neither leaf owns repositories or the page's lifecycle.

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
offers labeled Horizontal and Vertical paging. Page animation (Slide/Cover)
is global and selected from Library's top-right Display action. It is not a
per-book control, and Reader Reset leaves it unchanged. Cover is the default;
older preferences and unknown global IDs retain it. Legacy source animation
keys are ignored while other source settings are preserved. Theme, text settings
and layout have separate groups. Font, Font size and Line spacing stay together,
8dp apart; the latter controls fill the end half of the column. Both move under
captions, as full-width controls 16dp apart, when the sheet is narrow at large text, when half the
column cannot hold three 48dp segments, or when a label would need a third
line. Layout starts 24dp below the text settings: Text alignment, Page margins,
Page turn and the available Columns choice use `AppSettingsSection` captions
above full-width controls, 16dp apart, where `AppChoiceControl`
reflows long translations instead of truncating them. Reset keeps its label
while the title can shrink to fit beside it (`BottomSheetHeader.minTitleScale`)
and otherwise becomes a tooltip-labeled icon (`headerCompactTrailing`); only
when even that does not fit does it move below the title. Controls keep
their narrow `context.select` subscriptions and existing preview/commit/reset
callbacks; scrolling the sheet does not recreate the page.
`test/reader_appearance_layout_test.dart` checks gutters, the half-width
controls in LTR/RTL, en/ru/de fit, Reset beside the title and whole theme names
at 320dp with the bundled faces; `test/reader_theme_swatches_test.dart` covers
the five, three and scrolling layouts and the opening position.
Root goldens cover portrait, landscape, 2x text and RTL, including access to
the page-turn controls and font sample. Native reader flows check equal
step heights, manual return, engine style updates,
persistence across reopening and reset to inherited settings.

```dart
abstract class TextAction {
  String get label;
  String labelFor(BuildContext context) => label;
  IconData get icon;
  Future<void> onExecute(BuildContext context, TextSelectionContext selection);
}
```

## Reader surface contract

`ReaderSurface` (`reader_surface.dart`) is the set of commands the screen
sends to whatever draws the page: navigation (`goToCfi`, `goToFraction`,
`goToHref`, `goToSectionIndex`, `goToSearchResult`, `goToBookmark`, page
turns, `toggleBookmark`), search (`searchBookStream`, `clearSearch`), text
selection (`clearSelection`, `currentTextSelection`, highlight previews in a
`Color` and an opacity), image areas (previews and retention) and
`pageThumbnail`. Every command is safe before the page is mounted. Events
from the page (positions, selections, taps, annotations, load state) are
callbacks of the body that draws it, wired to the blocs where it is built.
`_ReadyContent` picks the body and surface by source type and format
(`_PageKind`): articles scroll on `ReaderArticleSurface`, CBZ on
`ReaderComicSurface`, PDF on `ReaderPdfSurface`, DjVu on `ReaderDjvuSurface`,
EPUB, FB2 and MOBI/AZW3 on
`ReaderTextSurface`, all on `package:pagecraft`. The types the page reports
(`BookPosition`, `ReaderTocItem`, `ReaderDocumentFeatures`, search events,
`ReaderSelection` and its parts) live in this package. A body that cannot
open or lay out its document adds `ReaderSurfaceFailed` with the error.
There is no WebView: before its removal on 2026-10-30, the WebView reader with
foliate-js drew books behind the same contract; the last revision with it
is `fb4b4e5c`. Saved positions, highlights and bookmarks keep the forms it
wrote.

Paginated books, PDFs and comics observe the global `ReaderPageAnimation`
through appearance state and map it to Pagecraft's `PageTurnAnimation`.
Animation and the horizontal/vertical
axis are independent. Changing the effect preserves the controller, current
CFI, text layout, selection and fixed-page zoom; it does not reopen the book.
An animation already in progress finishes with its original effect. The
engine owns presentation; preferences and Cubit remain outside Pagecraft.

### Comics (`_ReaderComicBody`, `ReaderComicSurface`)

For a CBZ the content body mounts `_ReaderComicBody`: it opens the archive with `ComicBook` (the stored `comicPageOrderVersion`
keeps the page order of saved positions), restores the page from the
saved fake CFI or the fraction, and shows `FixedPagesView`. The
Appearance sheet's page turn sets the view's `axis` (vertical turns pages
up and down; taps keep their left and right zones as previous and next).
Its events feed the blocs and cubits: positions become
`ReaderBookPositionUpdated` (`fraction = (page + 1) / pageCount`, chapter
counter = page counter, `relocationReason` `page` for turns), the page
list becomes `ReaderTocUpdated` (each entry naming its page, counted from
1), taps go through the shared tap-zone
dispatcher, long presses create image-area drafts in a
`ComicImageAreaDraft` that `ReaderImageSelectionCubit` mirrors, saved
image-area highlights are drawn by `ComicImageAreaLayer`, and a bookmark
toggle emits `ReaderBookmarkChanged` with the page as CFI, page anchor and
`Page N / M` content, the rows the WebView reader wrote too. Readiness is
the first visible page image (`onPageShown`), which releases the loading
scrim. Area gesture boundaries set `ReaderImageSelectionState.isAdjusting`;
the popup hides while moving/resizing and returns only after final geometry
is committed. Per-pixel edits stay inside Pagecraft. An explicit engine cancel
always clears the app mirror. Note sheets keep the draft and selected colour
in the engine while the popup is hidden; cancelling the sheet restores them.
Scan-only DjVu uses the same
callbacks and state contract.
Four blue triangular corner controls have larger touch targets around them.
A solid white diagonal double-ended arrow marks each draggable corner. The
corner controls use 85% opacity to remain distinct over artwork. Image drafts
have no border or separator lines; their fill uses the selected palette colour
at 45% opacity, independent of text-highlight opacity. The page outside the
draft is dimmed to focus the selection. Saved image annotations use a 90%
multiply tint to remain visible without lightening dark ink in the artwork.
Image areas and their popup swatches keep the existing paper palette's hues
and saturation with stronger tones at 0.65 HSL lightness: the underlying
artwork is not recoloured by the reader theme.
Text annotations keep their theme-specific palette.
The area popup has explicit Cancel and Highlight actions. Its placement leaves
the outward corner targets clear; a crop spanning the viewport uses interior
space when the popup cannot fit above or below. System Back cancels the draft
before leaving Reader. Colour changes do not delay an intentional outside tap.
Each draft has a selection ID. A late save refreshes annotations without
dismissing a newer draft or addressing a closed Reader. While a write is in
progress, another draft can still be cancelled or recoloured; its Highlight
action waits for the outstanding write.
`ReaderComicSurface` implements the commands over the controller
and the draft; comics have no text, so search and text-selection commands
are inert, and previews are `ComicPageImage` providers. A document that
fails to open reports `ReaderSurfaceFailed`. The chrome, drawers and
context panel never know which body draws the page.

### PDF (`_ReaderPdfBody`, `ReaderPdfSurface`)

For a PDF the body mounts `_ReaderPdfBody`: it opens the file with
`PdfBook` (a password-protected or damaged file reports
`ReaderSurfaceFailed`), restores the page from
the saved CFI or fraction, and shows `FixedPagesView` over `PdfPages`,
with the Appearance sheet's page turn as its `axis`, margin trimming as
`visibleRectOf` and page colours as `pageColors` (pagecraft's
`pageColorsFor`: a colour matrix, so the same pixels under Impeller and
Skia).
The outline becomes `ReaderTocUpdated` with page CFIs as hrefs, the
entries' depth as `level` and the page each opens, counted from 1, as
`startPage` (an entry without a page keeps an empty href); the chrome's
chapter line is the first outline entry that opens the current page. `ReaderDocumentFeatures`
reports `pdf`, the page count and the outline, and `hasSearchableText`
once a loaded page has text. Positions and bookmarks follow the comic
body's numbers. Text layers come from a `PdfTextLayerCache` (the pages on
screen and their neighbours are loaded ahead); `PdfTextOverlay` draws
saved text highlights resolved on the page (`resolvePdfTextAnchor`: the
DOM CFIs the WebView reader wrote resolve by the highlight's text,
pagecraft's by range), the search hit and the selection. A long press selects
a word and feeds `ReaderSelectionCubit` the exact text,
the sentence as `contextText`/`markedContextText`, pagecraft's range CFI and
the selection rect as viewport fractions. While a PDF selection is adjusted,
`onSelectionDragChanged` drives `ReaderSelectionCubit.isAdjusting`: the action
popup stays mounted but hidden, and returns after the final range is reported.
The fill and the independent handle colour use the same platform selection
colours as Flutter text; choosing an annotation preview never recolours the
handles, and clearing the preview restores the configured selection fill.
Pagecraft supplies system selection controls through `native_text_selection`
on supported iOS/Android hosts, while the Reader keeps its own action popup.
The native range maps back to the same PDF anchors and context payload.
Unsupported layouts retain adaptive Flutter handles with 48dp targets and a
platform magnifier. A Flutter handle drag activates after 6 screen pixels,
independently of zoom. The endpoint follows insertion boundaries on the
nearest text line, retaining the finger's offset from the handle so touching
its target does not shift the selected text.
The overlay's `darkPage` follows the page renderer's actual colour mapping:
themed dark pages lighten marker fills at a limited opacity, while
original/light pages multiply them to preserve black glyphs. Application
brightness alone does not change this policy.
A tap on a saved highlight
focuses `ReaderHighlightFocusCubit` with the sentence as context. Margin
crops (`trimPageMargins`) are measured per page with
`detectPdfPageContent` for the box a page is fitted into and passed as
`visibleRectOf` (a page whose crop arrives later is decoded again at the
crop's density); `pageColors: theme` maps the reader theme's background
and text colour through `pageColorsFor`. `ReaderPdfSurface` implements
the commands: navigation over the controller, `searchBookStream` through
`searchPdfBook` with excerpts around the match, `goToSearchResult`
opening the hit's page and marking its range, selection preview colour
and retention on the `PdfTextSelection`, previews as `PdfPageImage`
providers; image-area commands are inert.

### DjVu (`_ReaderDjvuBody`, `ReaderDjvuSurface`)

The DjVu body opens `DjvuBook` and draws `DjvuPages` on `FixedPagesView`,
reusing the existing page animation, zoom, spread and navigation controls.
DjVu remains a book in Library; it does not join the Comics collection scope.
The picker accepts `.djvu` and `.djv`, persisted as `BookFormat.djvu`.

The native decoder runs outside the UI isolate. Reader owns the opened book,
controller and bounded `DjvuTextLayerCache`; closing the body detaches its
session and releases them. A stale opening cannot replace a newer source.
Source/open failures use the existing loading/error/retry contract.
Positions and bookmarks use fixed-page CFIs, restored before the first page.
The outline populates Chapters, while the separate Pages grid requests only
mounted thumbnails through `ReaderPageThumbnailCubit`.

`ReaderDjvuSurface` searches the hidden text with `searchDjvuBook`, emits
excerpts and navigates to the hit's page/range. `DjvuTextOverlay` selects
whole words using the file's word rectangles; selection payloads contain text,
sentence context and range CFIs for the normal reader actions. Saved text
highlights and search marks share those anchors. This uses the existing hidden
text; there is no on-device OCR or invented character geometry.

A page with no hidden text uses `ComicImageAreaLayer` for area highlights.
Only one selection layer is active per page, so text selection and area
dragging do not compete for the same long press. The selection tip appears
only after a loaded page proves that the document has selectable text.
DjVu chrome exposes Contents, page direction, Bookmark and Search, without
font controls or PDF-specific margin trimming/page-colour settings.

### Text books (`_ReaderTextBody`, `ReaderTextSurface`)

For an EPUB, FB2 or MOBI/AZW3 book the body mounts `_ReaderTextBody`: it
opens the file with pagecraft (`EpubBook`, `Fb2Book`, `MobiBook` from
`package:pagecraft/all_formats.dart`, the source by `textBookSourceOf`; a
failure reports `ReaderSurfaceFailed`) and shows `TextPagesView` over a
`TextPagesController` restored from the saved CFI, or the fraction for rows
saved without one. Fixed-layout EPUB/KF8 and vertical writing are unsupported by
the text engine and reach the reader's error/retry UI; there is no alternate
renderer fallback. Its effective `rtl` drives swipes, spread order and reported
`BookPosition.pageProgressionRtl` for edge taps. Pagecraft resolves it once before
the first spread from declared RTL, an RTL language or bounded body-text
sampling, retaining Readflex's former foliate-js fallback for books with
missing or misleading metadata. It does not depend on the app locale.
The appearance becomes the `BookStyle`: the layout
preset's font size times the device scale as `fontScale`, the font
preset's family, weight, spacing, indent, line height, alignment, the three
override switches and the theme colours; the reader's style sheet
(`buildBookCustomCSS`: prose at the reader's text size, headings scaled
from it, quotes, code, link and dark-theme colours, in px from
`BookCustomCssSizes`) as `readerStyleSheet`; the layout preset's
hyphenation (Comfortable) as `hyphenate`; on iOS, the lines the WebView
reader's WebKit drew (whole-pixel line heights, glyph line boxes with the
reader fonts' ink from `readerFontInk`, and WebKit's hyphenation limits:
three letters before a break, two lines in a row); the window, screen and colour scheme as the media
queries' `CssMediaEnvironment`; margins, the side margin share, the column
choice and the measure (32 em of the prose size) as `TextPageSettings`;
CSS generics resolve to the bundled Literata and Open Sans and symbols to
Noto Sans Symbols. The page turn sets the view's axis. The book's table
of contents becomes `ReaderTocUpdated` (entries flattened with their
depth); `ReaderDocumentFeatures` reports the format, the contents and
searchable text. Positions carry the spread as the chapter page and the
section's spreads as its total, 1500-byte locations (foliate-js's) as book
pages, `sizeTotal`, `atStart`/`atEnd` and
the contents entry as the chapter title. A bookmark is the first word on
screen as a precise range CFI with anchor version 2, so it opens on that
word in any layout; a bookmark is on screen when its start is between
the first and last things shown. A long press selects through Flutter's
`SelectionArea`, with adaptive Cupertino/Material handles;
`TextSelectionDetails` gives the context panel the
exact and whole-word text and CFIs, the sentence and what a highlight would
merge. A selection follows the reader through the section, as in the
WebView reader: a swipe, or a tap in an edge zone (`onSelectionTap` turns
it into the tap command, the middle clears the selection), turns one
spread and takes the selection's moving edge onto it; the context panel
hides while the page moves (`ReaderSelectionCubit.setAdjusting`) and its
actions get the whole range. The reader's sheet (`buildBookCustomCSS`)
gives tables `width: max-content`, `max-width: max(100%, 40em)` and
`overflow-x: auto` and keeps their words whole, so a table wider than the
page scrolls sideways in it, as the WebView reader's wrapper did (pagecraft
turns the page with a swipe on a table at its edge). Saved highlights are resolved in each
section's document and tinted under the text with the theme's colour and
opacity; the selection's colour preview and the search hit are tinted
on top. A tap on a link resolves it: a web link goes to the link sheet,
a note reference opens the note in a sheet (`TextFragmentView`), other
links go to their target. `ReaderTextSurface` implements the commands:
navigation over the controller, `searchBookStream` through
`searchTextBook` with chapter titles, `goToSearchResult` opening the hit
and marking it, selection clearing and colour preview; image-area
commands are inert and pages have no thumbnails. The table of contents
is flattened from level 1, so sub-chapters indent.

### Articles (`_ReaderArticleBody`, `ReaderArticleSurface`)

A saved article opens on pagecraft, as one scrolling column.
`ArticleTextSource` reads the article's `content.html` cleaned as the
former WebView shell cleaned it
and its pictures from its `images/` folder; `TextScrollController` lays
it out the width of the window less the side margin (the shell's
`articleSidePadding` share), no wider than 32 em of prose, below the
status bar plus 32 and above the home indicator plus 40, and keeps the
sentence read across a new size, style or font. The style is the books'
(`_pagecraftBookStyle`) with the reader's layout, font and colours always
on, and the shell's softer captions (72%), quotes (86%) and table rules
(22%) ahead of the reader's sheet. Everything stored keeps the shell's
forms, so what was saved while articles read in the WebView still
resolves. `ReaderDocument.language` passes the saved article language into
`ArticleTextSource`; Pagecraft normalizes document language and text direction
from that hint and the content, retaining explicit direction on content
elements. The interface locale does not set the article's text direction.
Articles report `pageProgressionRtl: false`, so their progress line fills
left to right in every interface locale.

- **Position** — the sentence at the middle of the view as a
  `readflex-html-position:` anchor, the scroll share as progress, the
  last heading above as the chapter, minutes left at 1200 characters a
  minute from that sentence, `atStart`/`atEnd`. A sentence change, a move
  of at least 0.4%, an edge change or a bookmark change makes a new position
  report eligible. Reports are throttled to 140 ms; an end-state change or
  an explicit bookmark update bypasses that throttle.
  An article left at its start or end reopens there; otherwise at its
  sentence, centred; otherwise at its share.
- **Progress line** — a passive 3dp track below the top title shows the
  live scroll share from `ReaderArticleProgressCubit`, updated once per
  frame by the article host. It stays visible at the safe top edge
  when the title is hidden, follows the reader's colours, and lets page
  gestures pass through. Only the indicator rebuilds on progress updates;
  the fill tracks the actual position directly, including small moves
  between the throttled position reports to `ReaderBloc`. Opening or closing
  an article clears its live progress. Its accessibility label announces
  the localized percentage read.
- **Contents** — headings with an id by depth, else up to twelve blocks
  of 48 characters or more by their first words; each with the share of
  the scroll where it starts once the article is laid out.
- **Bookmarks** — the sentence read; it is on screen when its anchor or
  its text matches.
- **Selection** — a long press selects through Flutter's `SelectionArea`;
  supported hosts then use system controls through `native_text_selection`,
  with Flutter controls retained for unsupported geometry. The context panel
  remains the Reader's own;
  `ArticleSelection` gives the context panel the shell's payload: the
  text with white space collapsed, 200 characters of context within the
  sentence or block, its anchor, the saved highlights it merges.
- **Highlights** — saved anchors resolved in the document, tinted
  oldest first; the colour preview on top.
- **Search** — the sentences in order (`searchArticle`), each hit with
  its heading; every hit is tinted, the one opened apart; one hidden
  under the search bar is marked on the bar's edge
  (`ReaderSearchOcclusionMarker`, which pagecraft books use too).
- **Links** — an `#id` scrolls its element to the top, a web, mail or
  phone address goes to the link sheet, a path inside the saved article
  does nothing.

`ReaderArticleSurface` implements the commands over the session the
body attaches; there are no pages to turn, image areas or thumbnails.

## Architecture — independent units of state

| Unit                          | Responsibility                                                             |
|-------------------------------|----------------------------------------------------------------------------|
| `ReaderBloc`                  | Content: load source document + highlights/bookmarks, debounced position save (500ms) |
| `ReaderUiCubit`               | Chrome, drawer, appearance-sheet and search-highlight UI state             |
| `ReaderSearchCubit`           | Search debounce, streamed results, recent queries, active match and return anchor |
| `ReaderSelectionCubit`        | Current text selection (text + `cfiRange`) and adjustment phase             |
| `ReaderArticleProgressCubit`  | Live article scroll fraction for the persistent progress line, separate from saved positions |
| `ReaderImageSelectionCubit`   | Current image-page area selection for comics/fixed-layout pages            |
| `ReaderImageHighlightCubit`   | Persists image-page highlights with optional notes, then `ReaderBloc` refreshes annotations |
| `ReaderHighlightFocusCubit`   | Saved-highlight popup focus and its viewport position                       |
| `ReaderAppearanceCubit`       | Per-source reader appearance overrides over global preferences             |
| `ReaderBrightnessCubit`       | System/custom reader brightness state and active window override lifecycle |
| `ReaderKeepAwakeCubit`        | Screen-awake requests while bare reader content is active                   |
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
- **Delivery.** The PDF body passes margin crops as `visibleRectOf` and the
  theme's colour matrix as `pageColors` to `FixedPagesView`, which crops and
  recolours the bitmaps. Other formats ignore them.
- **Progress.** The bottom chrome shows `percent · page / total` for PDF from
  the zero-based page fixed layouts report, so page 15 reads 15.

`test/ui/reader_pdf_controls_test.dart` drives the sheet, the page view and
the Pages tab end to end; `reader_appearance_sheet_test.dart` covers the
variant's controls, persistence, Reset, semantics and 2x text.

### Line length and text columns

`readerTextColumns` (`reader_text_columns.dart`) keeps lines readable. In
every window it gives the page settings a measure of `kReaderMaxLineWidthEm`
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

pagecraft lays the pages out again only when the window or the choice changes
the columns. Narrow windows, phones included, keep one column at the
measure whatever the choice says; articles always keep one column at the
measure; PDF and comic pages keep their own layout. Appearance shows
**Columns** (Auto / One / Two, under Page turn) only for reflowable books in a
wide window (`showReaderAppearanceSheet(showColumnControls:)`); the choice is
a per-book override like the other rows (`ReaderAppearanceCubit.setColumns`,
`ReaderAppearanceOverride.columns`) and Reset clears it. Root
`test/ui/reader_text_layout_test.dart` follows the page settings through
window changes; pagecraft's `text_page_geometry_test.dart` covers the layout
itself.

In every window the page settings also carry the side safe-area insets
(`MediaQuery.padding` left/right), so book and article text stays clear of a
landscape phone's display cutout while the page and its tap zones still fill
the window. The tap-edge lines sit inside the same insets.

### Text size in tablet-sized windows

`readerDeviceFontScale` (`reader_device_font_scale.dart`) multiplies the base
font size of the book style. The reader's own text size
(100% by default in Appearance) applies on top and never changes. It combines
two independent corrections:

- A tablet-sized window, at least 600 on its shortest side like Android's
  `sw600dp`, gets 12.5% larger text on every platform: 18px instead of 16px.
  A tablet is held further away, and the 32em measure grows with the text, so
  lines keep their length in characters. The shortest side ignores
  orientation: rotation never resizes the text, phones stay phones in
  landscape, and a narrow Split View or Slide Over window reads like a phone.
- Android adds up to 12% on phones and 4% on tablets: the sizes the WebView
  reader gave it, whose Chromium drew text smaller than iOS, kept so books
  read as they did.

The platform is `defaultTargetPlatform`, not the `Theme`'s: the correction
follows the device the app runs on. Books and articles share the multiplier; PDF and comic pages are images
and ignore it.

### One-time selection tip

The first time a page of selectable text is on screen, a tip at the bottom
says "Press and hold a word" and names the selection menu's commands by their
real labels (`highlightAction`, `commonCopy`, `translationAction`,
`dictionaryAction`), with "Got it".

- **When it is due:** a ready article, EPUB, FB2, MOBI or AZW3, or a PDF whose
  features report a text layer (`readerSupportsSelectionTip`); never a comic.
  The page must be painted, and no chrome, search navigation or
  selection may be on screen. A tap on the chrome while the page loads does
  not use up the session.
- **Policy (`ReaderSelectionTipCubit`):** at most once per reader session and
  in at most `maxShows` (3) sessions. "Got it" or any text selection ends it
  for good. Opening the controls or a book page turn (relocation reason
  `page` or `snap`, `isReaderPageTurn`) hides it until the next session.
  Articles are not hidden by scrolling, the way an article is read. `PreferencesService` stores
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

Narrow Cupertino Contents/Search panels share `BottomSheetHeader` with modal
sheets: a centred, wrapping title and circular Close. Their fields, tabs, page
grid and list rows share the 24dp content gutter. Android and expanded 420dp
sidebars retain their leading headers and 16dp gutters. `readerDrawerContentInset`
owns that distinction; changing the frame never recreates a query, tab or scroll
position. The match-navigation dock keeps its separate 16dp gutter.

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
Each row ends on the panel gutter with its start position as a muted
`bodySmall` label in tabular figures, baseline-aligned with the title: the
estimated start page (announced as "Page N"; the renderer's page 0 reads 1),
else the whole start percent, else nothing. On the active row the label takes
the selected foreground, since the dark selected fill is tonal. The active
chapter uses a rounded tonal fill inset 8dp from the panel edge, keeping the
same text and position gutters. Active search results and bookmark rows keep
their full-width selection surfaces. The highlight color
filter strip starts on the panel gutter like the search field above it, with
8dp above and below its 48dp targets; its "All" entry is an `AppFilterChip`
with a visible selected state and the swatches beside it paint 32dp circles
(`ReaderHighlightColorButton(size:)`), while the selection popups keep 24dp.
Highlight rows own both panel gutters inside the body so Read more / Show less
(`ReaderHighlightExpandButton`, `AppButtonLabel`) ends its label on the
trailing gutter with the platform button padding. Android and sidebars let
the 48dp target reach the edge; narrow Cupertino adds 12dp outside its native
12dp button padding to align the label with the 24dp gutter. Quote, note and
location text keep their panel
edges. Beside a location the button is bounded to half the row, so a long or
2x label wraps inside it instead of overflowing.
Empty tabs render `EmptyState(compact: true)`, scrollable when a short sheet
leaves it less room than it needs.

Contents is an `AppInlineSheet` (component_library) in the reader's stack, not
a route. On phones it opens at 60% of the height below the status bar, so the title, tabs
and search field land mid-screen and the current chapter is under the thumb;
the page stays visible, dimmed, above it. Dragging the header or scrolling a
list forward grows it to just below the status bar; a downward fling, pulling a
list past its top, the scrim, Close and System Back step it down or close it.
Landscape phones and large text open it at full. Expanded windows use the
shared trailing side panel. Hidden, it stays mounted
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
(`bodySmall`, muted) on the panel gutters, with no leading icon or trailing
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
On iOS, Contents uses `AppChoiceControl` synchronized with its tab controller:
a native segmented control when labels fit, wrapping accessible choices for
long labels or large text. Four-tab PDF and DjVu panels use proportional segment
widths to keep the control in one compact row when its full labels fit. Phones
use the existing compact Reader caption role (`labelSmall`, 12sp); medium windows
retain the native choice control's existing `bodyMedium` role (15sp), including
inside a 420dp iPad sidebar. Three-tab panels retain their existing typography
and equal-width fit rule. Narrow windows and large translated labels retain the
wrapping fallback with 48dp targets rather than scrolling sideways.
On Android, Contents tabs fill the available width
without shrinking their labels. They
share equal widths when every label fits; otherwise, each tab keeps room for
its icon and label and receives an equal share of the spare width. Only a total
width that exceeds the available space enables horizontal scrolling. The bar
keeps an 8dp inset and each tab reserves at least 8dp beside its contents, so
scrolling starts on the panel gutter. Measurements respect the locale, text
scale and reading direction.
A label cut by the sheet edge fades into the sheet (`ScrollEdgeFadeStack`,
horizontal) so it reads as more tabs to scroll to. Selected tabs use the same
tonal fill and foreground as settings choices, without an underline or divider.
Contents and Search use `titleMedium` headings with heading semantics.
On Android and in expanded sidebars, the "Contents" title stays on one line:
a long translation at large text
shrinks to at most `readerDrawerTitleMinFontScale` (0.8) of its size before it
ellipsizes (`readerFittedTitleFontSize`). The three Contents search fields
fall back to the short `commonSearch` hint when the full one would be cut.

Deleting a highlight from the saved-highlight popup follows the same model
(`highlightEdits` in `ReaderState`): the page annotation disappears and the
existing toast shows, while the Highlights tab keeps the row muted as
"Highlight removed" with an icon-only Undo until Contents closes
(`ReaderHighlightUndoDismissed` purges it). The bloc retains the repository's
`HighlightDeletion` snapshot while Undo is available. `restoreHighlight`
restores the original ID, date, complete anchor and review schedule in one
transaction, keeping the citation connected to its review history. It refuses
deleted sources and preserves newer rows if already restored. The page
overlay refreshes from the repository. Restore failures keep the row
with Undo. Removed rows neither navigate nor expand; image rows keep their
preview.

`readerContentsTabs` decides the Contents tabs per format:

- **CBZ** replaces Chapters with Pages: a comic's table of contents is its page
  list, so taps open the page's TOC entry.
- **PDF and DjVu** keep Chapters first, even without an outline (the tab then
  shows its empty state), and add Pages once the document reports its page count.
  Pages taps call `goToSectionIndex`; the current page is the zero-based
  chapter page that fixed layouts report.
- **Other books** keep Chapters, Bookmarks and Highlights.

`ReaderPageGrid` shows comic, PDF and DjVu pages, initially revealing the saved
page. The grid keeps the panel gutter horizontally and 16dp vertically (plus the bottom
system inset) with 12dp between tiles. Page order follows the book's
progression direction independently of the app locale. Captions and controls still use the app locale. Only the visible
Pages or Highlights tab owns `ReaderPageThumbnailCubit`; its callback is
`ReaderSurface.pageThumbnail`, which answers the engine's `ImageProvider`
decoded at preview width, and the View
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
overlay the existing page: opening/closing them never changes its height or
repaginates the document. The reader passes only the covered height fraction to
the page. If the active match lies behind the panel, an amber edge marker
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
`readerDrawerListBottomPadding` (16dp plus any unconsumed insets), the same
formula as the Contents lists. Every inline sheet consumes the keyboard;
narrow Cupertino and expanded side panels also consume their safe bottom inset.
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
the drawer. Undo glyphs are 20dp on phones and 24dp in medium windows,
aligned to the Contents field's panel gutter with full 48dp targets.
Cupertino Close keeps its native 28dp circular plate; the action centres align
(`readerDrawerActionEndPadding` in `reader_drawer_layout.dart`, derived from
the window's glyph size and 48dp target). Geometry tests compare the visible icon boxes,
not only button bounds; native flows also exercise deletion and Undo.
The bottom chrome is one rounded reading dock: status, seeking and actions
share an opaque app surface, hairline outline and `AppShadows.popover`. The
dock forms one `ToastAvoidArea`, enabled only while the
chrome shows (the hidden chrome stays mounted, slid out); the fallback
selection panel and the search navigation bar are marked too, so a toast
(Copied, Highlight saved) floats above whichever is on screen. The dock keeps
16dp side gutters and `appBottomSafeInset` (minimum 16dp) above the bottom,
inside a centered 560dp maximum column. Its phone action strip is 60dp tall,
with equal slots centring 48dp `AppPlainIconButton`s: Back, Contents, Appearance,
Bookmark (custom filled/outline glyph passed as `iconWidget`) and Search; Row
order mirrors in RTL. Expanded Material windows add captions in a strip at
least 80dp tall; its height grows with the rendered label's scaled line height
so two translated lines fit through 130% text. Expanded Cupertino windows
show captions only when every complete name fits on one line at the existing
17sp label role, through 130% text. Their slots share the remaining width after
each name's measured width and padding, with aligned icon centres and caption
baselines. If the names do not fit, or text is larger, the dock keeps the
60dp icon strip and localized tooltips. The whole captioned action is a button.
The existing tooltip and capability rules remain for every format.
Medium windows (at least 600dp wide and 480dp tall) use the existing
`labelLarge` role for chrome status and numbers, Material Contents tabs, Search
counters, theme names and available action captions. This role is 15sp in the
Material theme and 17sp in the Cupertino theme. Native Contents choices retain
their existing 15sp `bodyMedium` role. Medium utility glyphs use 24dp;
phone roles stay unchanged, including short landscape windows. Measurement
uses the same role and scaler as rendering, and progress numbers retain
tabular figures. This only changes controls, not the page layout or location.
The page-turn toggle is not in the dock for books or
articles (the setting lives in Appearance). Comics have no Appearance action,
so their dock keeps the page-turn toggle as their only route to that
setting. Page-turn and active-bookmark glyphs, the page-bookmark indicator and
other action accents use `context.actionForeground`.

Status sits above the seek track, inset 12dp inside the dock, and follows the
book's page progression like the slider itself. The scrubbing `AppSlider`
spans the row above the actions, with the same local drag preview and a single
`goToFraction` on release; only this row rebuilds while dragging. Android keeps
the 3dp track and 12dp thumb; iOS keeps its native Cupertino thumb and track.
Both have a 48dp-tall control and allow direct track taps to seek. Native
accessibility increment/decrement actions commit immediately, without waiting
for drag callbacks that Cupertino does not send. The labels
read on one line above it, inset to the painted track (14dp on Material,
8dp on Cupertino) so they start and end with the track: at
the start the current chapter title for books,
for articles `readingTimeLeft` (minutes left in the whole article) or the
chapter title when there is no estimate; comics show neither a time nor their
archive file names. At the end is the percent/page label: short and numeric
in every locale, it keeps its natural width, bounded only by the row, so its
digits never truncate (`reader_chrome_progress_layout.dart`); the chapter
takes the rest on one line and truncates first. Above 130% text each
label takes its own line, the chapter up to two lines and the page label
end-aligned below it, so the slider never shares its line.
Text and slider use the app surface's `onSurfaceVariant` and `outlineVariant`,
so selecting a dark reading page in a light app never makes the dock unreadable.
`test/reader_cupertino_dock_test.dart` checks the native iPad dock in both
orientations, light/dark app palettes, translated captions and enlarged text,
including aligned glyphs, complete names, track insets and action semantics.

The top chrome is one centred `readerChromeLabel` line (`labelLarge` in medium
windows) in `readerChromeInkColor`
(78% of the page text over the page), with
no plate, shadow or divider: `chapter · title` once a chapter title is known,
otherwise the title, ellipsized. It keeps the top safe-area inset and a 48dp
line; for articles the line is an ink button with button semantics, the title
as its value and a 48dp-high target that opens the original URL.
Changing chrome visibility must not resize or recreate the page; the root
search-overlay regression verifies both contracts under iOS/Android policies.
Status-bar icon brightness follows the page colour: the top line is drawn on
the page, and the Appearance, Contents and Search sheets stop below the status
bar and only scrim it (`readerSystemUiOverlayStyle`).
Active bookmark/Undo icons and the tab indicator use the accessible action
foreground. Active search results use the same selected color pair as Contents
and settings controls; text and emphasized matches remain readable on that fill.
The brightness pill beside the page uses `PositionedDirectional(end:)` and
slides toward that edge in RTL. Phones keep a 56dp pill with 4dp inner padding,
16dp inside the safe edge. Expanded windows use a 48dp pill with no extra
horizontal padding, floating 8dp inside the safe edge. Both keep the same
48dp controls; the compact tablet width leaves room for the floating gap.
The temporary overlay preserves the reading canvas. The top line shares the
capsule's 16dp content gutter. The transient CBZ page pill sits
`appBottomSafeInset` (minimum 16dp) plus 12dp above the bottom edge. Its step buttons are
`AppPlainIconButton`s; the value button is a 48dp selected control
(`selectedControlBackground/Foreground` while a custom level is active) whose
"System" label comes from `readerBrightnessSystem`.
Brightness diagnostic formatting/logging runs only in debug builds.
Brightness input queues its platform target before awaiting preference storage.
Intent and lifecycle checks discard stale reads and adjustments, so a pending
System action or activation cannot override newer slider or button input.
Relative button steps compose while the initial system level is loading;
absolute slider/System choices cancel pending steps. Activation drains the
previous lifecycle's platform reset before sampling a new brightness baseline.

`ReaderBookPositionUpdated.fromBookPosition` maps every body's positions,
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
success toast. A new text selection keeps its platform-adaptive selection
tint; opening the action panel does not preview the default annotation
colour. Explicitly choosing a colour starts the preview, including the first
tap on the already-selected Yellow swatch. The Highlight action saves it.
For books and articles `ReaderTextSelectionStyle` derives the temporary fill
from the same accent as the current Cupertino/Material handles. On iOS this
avoids inheriting MaterialApp's primary tint for Cupertino's blue handles.
Flutter draws these selection controls over Pagecraft's text layout.
The reader supplies its own action popup in place of Flutter's default toolbar.
The saved annotation palette is separate.

`ReaderSurfaceFailed` reports a page that cannot open or lay out its document,
with the error, through the bloc's error pipeline and switches to the shared
`ErrorState` (error icon, filled Retry, outlined Go Back). Retry recreates the
page from the retained document, while a late source load cannot erase the
failure.

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
- **`_ReaderTextBody`, `_ReaderPdfBody`, `_ReaderComicBody`** host pagecraft's
  pages keyed on the source id, so a source swap rebuilds them cleanly. Each
  maps domain highlights and bookmarks onto its engine: text highlights by
  CFI, comic highlights as normalized areas keyed by page index.
- **`_ReaderArticleBody`** hosts pagecraft's `TextScrollView` for article
  sources (see Articles above). Articles scroll vertically, report progress
  through stable sentence anchors in `content.html`, expose
  contents/search/bookmark chrome actions, and render text highlights through
  stable article anchors. Image-area selection remains specific to comics and
  fixed-layout pages.
- Every reader motion (chrome slides, Contents/Search sheets, brightness pill, loading
  scrim, dimming tween, swatch rings, page overlay) resolves its duration
  through `context.motion(AppMotion.x)`, so reduced motion settles in one
  frame; the appearance step and tap-zone hint controllers jump instead.
- Reader theme (`ReaderThemeData`, font preset, layout preset) is resolved
  from `ReaderAppearanceCubit` into pagecraft's `BookStyle` and page settings;
  the bodies subscribe to the document, readiness, appearance and annotation
  state they need, not to each selection-menu update. Rebuilding a body does
  not recreate its pages unless the source changes.
- `buildBookCustomCSS` supplies semantic code panels, quotes, links and
  headings, read after the book's own CSS. Code borders retain the theme
  divider color; dark-theme descendants inherit semantic parent colors instead
  of replacing link/quote colors with primary text. The same semantic overlay
  is used by the article reader.
- Comic page-zone taps remain available with chrome open and hide chrome while
  turning the page. Actual controls (brightness, toolbar buttons) keep their
  own hit targets. Text books retain the dismiss-only page barrier. Each edge
  zone is `readerLeftTapZoneEnd` (30%) of the page.
- Code typography retains the system monospace families and adds the bundled
  symbol fallback for missing callout numerals. pagecraft's document normalizer
  excludes publisher annotations/captions from code detection, so a long
  explanation does not become a code panel merely because its class name
  contains `code`.
- Book and article tables follow CSS's automatic layout, as wide as their
  content up to 40em with their words whole; one wider than the page
  scrolls sideways inside it (`overflow-x: auto` in the reader's sheet,
  pagecraft's `ColumnScroller`). `test/book_table_layout_test.dart` lays tables
  out under the reader's sheet; `integration_test/table_rendering_test.dart`
  scrolls one on a device.

## Dependencies

- `book_repository`, `article_repository`, `highlight_repository` — content,
  bookmark and highlight persistence
- `preferences_service` — global reader appearance, per-source overrides,
  search history, and global reader brightness preference persistence
- `screen_control_service` — content-only keep-awake plus temporary
  application brightness control
- `pagecraft` — the reader engine: text, comic, PDF and article pages, CFIs,
  search and selection
- `shared` — `TextAction`, `TextSelectionContext`
- `domain_models` — `Book`, `SourceType`
- `component_library` — `ReaderThemePreset`, `AppIcons`, `AppSpacing`,
  `AppIconSize`, `AppMotion`, `AppPlainIconButton`, `AppFilterChip`,
  `EmptyState`, `ErrorState`
- `flutter_bloc`, `equatable`, `stream_transform`
