# library_feature

Internal Library feature package. Dart reserves the package name `library`,
so the pub package is `library_feature` while the UI surface remains
`Library`.

Content library browser: shows books and articles in a single feed with
search, one Collections picker for what to show (Books, Articles, Comics,
New, Favourites, your collections, sites and authors) and a list/grid toggle.
Surfaced as the `Library` main screen (route `/library`).

## Public API

`LibraryScreen` — stateless widget wired up in `routing.dart`. Provides BLoC
and UI preference cubits internally.

| Prop                  | Type                                | Purpose                                      |
|-----------------------|-------------------------------------|----------------------------------------------|
| `bookRepository`      | `BookRepository`                    | Book list + delete                           |
| `articleRepository`   | `ArticleRepository?`                | Optional article list + delete               |
| `collectionRepository`| `CollectionRepository`              | Collections and favourites persistence      |
| `preferencesService`  | `PreferencesService`                | Persist list/grid, theme, and locale choices |
| `isOffline`           | `bool`                               | Connectivity indicator for the Library UI   |
| `onSourcePressed`     | `Future<void> Function(...)`        | Open reader, then refresh                    |
| `onAddPressed`        | `LibraryImportLauncher`             | Open import UI at a `LibraryImportEntry`; notify successful persistence |
| `openImportOnStart`   | `bool` (default `false`)            | Open file import once after the first frame  |

`LibraryImportEntry` (exported) names the import step to open: `menu` from
the "+" button, `file` from the empty library's Upload a file, `article` from
its Save an article. `openImportOnStart: true` calls
`onAddPressed(entry: LibraryImportEntry.file, ...)` exactly once after the
first frame (onboarding's "Add a book"); rebuilding the same screen does not
reopen it, and it goes through the same in-flight guard and refresh as the
header action.

## Architecture

Independent state units keep domain loading, persisted display preferences,
selection, and collection commands separate:

- `LibraryBloc` — domain data. Loads books and article metadata into a single
  `LibraryState.sources` list of `LibrarySource` values and exposes
  `visibleItems` sorted by `lastOpenedAt ?? addedAt` DESC, then
  `addedAt` DESC and title. Narrows by one `selectedCollectionScope` and
  `searchQuery` (debounced 300ms). `visibleItems` is cached per state
  instance so the bloc keeps one source-of-truth list without recomputing
  the projection on every rebuild.
- `LibraryLayoutCubit` — UI-only list-vs-grid toggle, persisted through
  `PreferencesService.libraryLayoutMode`.
- `LibraryThemeCubit` — app theme mode selector, persisted through
  `PreferencesService.themeMode`.
- `LibraryLocaleCubit` — app language selector, persisted through
  `PreferencesService.locale`.
- `LibrarySelectionCubit` — multi-select state for bulk source actions.
- `AddToCollectionCubit` / `ManageCollectionCubit` — collection mutations and
  their transient command state.

The Library exposes protected Favourites, persisted manual collections, and
derived author/site smart collections.

`LibraryImportLauncher({required onImported, entry})` completes when the
import UI closes. Implementations declare `entry` with a default
(`entry = LibraryImportEntry.menu`); Library always passes it. Its caller invokes `onImported()` after each successful persistence,
even if a dismissed sheet's import finishes later. Only that callback refreshes
Library; closing/cancelling the sheet alone does not read storage again.
Late callbacks after Library disposal are ignored.

Books and articles are requested together. Loads carry a generation token so
an older response/error cannot replace newer data. A superseded delete refresh
still emits its completion effect without restoring stale list contents.
The existing delayed refresh on reader-route return remains intact to avoid
moving list tiles during a reverse route/Hero transition.

Article metadata comes from a SQL projection via `getLibrarySources`, not a
full-text article read. Search and scope changes reuse the same source list.
Favourite membership reads are scoped in SQLite rather than loading every
manual collection's memberships a second time.

The screen uses separate widgets (`LibraryListView`, `LibraryGridView`) for
each layout and a local `TextEditingController` for the search field so
keystrokes don't churn bloc state.
List separators use the shared `DividerTheme` for color and thickness, matching
the import sheet. They are painted above cover shadows so the line stays visible.

Empty-state is handled twice: truly empty library vs. a search or collection
that shows nothing.
The empty library (`LibraryEmptyState`) shows the book icon in a 72dp circle
tinted with the accent at low alpha, the serif `headlineSmall` title and muted
subtitle, then two full-width commands stacked 10dp apart: filled **Upload a
file** (`LibraryImportEntry.file`) and outlined **Save an article**
(`LibraryImportEntry.article`), followed by the muted file kinds caption. It
applies the 16dp screen gutter once and disables both commands while an
import flow is open.
The filtered empty state offers **Reset filters**. It clears search text and
the collection scope in one `LibraryFiltersReset` event without reading
storage. Reset and query events share a switchable debounce stream so pending
search text cannot come back after a reset. The collection scope is switched
from the bottom capsule's collection switcher and cleared from the
Collections picker's Library row.

### One way to narrow the Library

There are no filter chips: what the Library shows is always one collection
scope, picked in the Collections sheet. The former filters are built-in
scopes (`LibraryCollectionScopeType.books`, `articles`, `comics`, `unread`,
`builtIn` in that order), built by `LibraryBloc` on every load in one pass
over the sources and listed in the first group after Favourites and
Library. `libraryBuiltInScopeMatches` is the single predicate for
both their counts and the narrowed list: books exclude comics, and New is
`LibrarySource.isNew` (never opened, nothing read), the cover badge's rule.
Their labels are localized (`libraryScopeBooks`, `…Articles`, `…Comics`,
`…New`), they have no manage menu, and the picker's search finds them by the
localized name. All four are always built, even when empty, so a selected
scope that empties (the last new item opened) stays selected instead of
silently jumping to Library. `LibraryState.pickerBuiltInCollectionScopes`
lists only those that narrow: an empty scope or one holding the whole library
would repeat Library and is left out, unless it is the selected one. The
picker reserves height only for listed rows.

A built-in scope cannot be combined with Favourites or a manual collection;
search still narrows inside any scope. This trades rare combinations for a
single place, at the bottom of the screen, that says what is shown.
Load errors go through `addError` and a `LibraryStatus.failure` retry surface.
Delete errors keep the list usable and report failure through a deletion effect;
a failed single delete re-reads storage rather than re-emitting the old list.
The list swipe's `confirmDismiss` awaits that effect (matched by source id): the
row leaves only after storage confirms, and a failed write springs it back
beside the error toast.
Delete confirmations follow the shared safe-default model: the safe choice is
the filled primary, named for what it keeps ("Keep" for library items, "Keep
collection" for a collection, never "Cancel"), and Delete is the outlined
error-coloured secondary (`AppSheetActions`, `destructiveSecondary: true`) in
the layout's `footer`, 24dp after the body text and 16dp above the route's
safe area. Keep closes only the confirmation and never writes. The list swipe background, cover New/finished
badges and selection checks use directional placement, so they mirror in RTL.
Grid selection scale, progress fill and the list/grid cross-fade resolve their
durations through `context.motion`, settling in one frame under reduced motion.

## Library Controls

List metadata and the header's item count use `ColorScheme.onSurfaceVariant`,
without reducing text opacity. Widget tests check at least 4.5:1 contrast on
the actual list, selected-row and header backgrounds in both themes.

The header title names what is shown: the selected scope's label
(`libraryCollectionScopeLabel`, the full Favourites name) or Library in
`headlineMedium`, on the 16dp gutter. It is a heading (`Semantics(header:
true)`, key `libraryHeaderTitle`), not a control: no chevron, no ink, no tap.
Switching collections belongs to the bottom capsule alone, so the top of the
screen has no second, out-of-reach way to do it. Under it a muted `bodySmall`
subtitle counts the current scope (`LibraryState.scopeItemCount`: the whole
library or the selected collection, ignoring search). There is no count pill,
collection pill, folder button or chip row; the header ends with the search
field. The compact offline icon stays reserved after the title.

The header's only action is Display (⋮), the shared `AppPlainIconButton`: a
transparent resting surface, circular pressed feedback and a 48dp target. The
title row ends `AppSizes.iconActionOutset` short of the 16dp edge so the
Display target bleeds into the gutter and its 20dp glyph ends exactly where
the search field does. Search uses the same utility-action behavior
for its smaller clear glyph. Muted header glyphs use `onSurfaceVariant`, not
an alpha over `onSurface`.

Adding and switching collections happen where the thumb rests, in one
bottom capsule, `LibraryFloatingActions`, in the Scaffold's floating action
slot: the shared `AppFloatingCapsule` (translucent surface, hairline outline,
popover shadow, as the reader chrome), `kLibraryFloatingActionsHeight` (56dp)
tall and lifted `kLibraryFloatingActionsLift` (8dp) above the Scaffold's
margin. Two 48dp controls sit 4dp inside it and 4dp apart; the row follows
the reading direction, so "+" keeps the outer corner in RTL too.

- `LibraryCollectionsButton`, at the start: the shown collection's icon
  (`libraryCollectionScopeIcon`, the same glyph as its picker row; Library
  uses `AppIcons.library`), its name (`libraryCollectionScopeLabel`, or
  Library) on one line and a 16dp chevron. It is a stadium `TextButton`
  whose 20dp glyph is centred in the round end; it is read as one button
  (label Choose collection, value the name) and is the only way into the
  Collections picker. Inside a collection it takes the selected pair
  (`selectedControlBackground` / `…Foreground`). Tests check 4.5:1 text
  contrast over black and white covers under the translucent capsule.
- `LibraryAddButton`, at the outer end: a filled `primary` circle with a
  24dp `onPrimary` "+" (tooltip Add to Library), flat inside the capsule. It
  opens import at `LibraryImportEntry.menu` and takes Material's disabled
  filled colours while an import is open; switching collections stays
  available meanwhile. Colours are explicit because `iconButtonTheme` styles
  secondary square buttons.

The capsule is at most `kLibraryFloatingActionsMaxWidth` (320dp) wide and
stops 16dp short of the start edge on narrow screens, so a long name
truncates instead of becoming a bar over the covers. The floating action
slot strips safe insets; side insets only occur in landscape, where the cap
binds first. Its height is fixed, so its text scales up to
`kLibraryFloatingActionsMaxTextScale` (200%), which still fits one line in
48dp. A new name resizes it over `AppMotion.short` with "+" anchored at the
outer end; under reduced motion there is no `AnimatedSize` at all, because a
zero-duration one re-dirties itself during its own layout. Only the capsule
selects the collection scope; the Scaffold rebuilds for its visibility alone.

The capsule appears only once the library has loaded items: the empty
library offers its own two import commands, while an empty collection keeps
it so it can be left. Selection mode gives the bottom to the selection bar,
and the Scaffold scales the capsule out and back in. The header keeps
orientation (the title and count) and the rare Display action. See the
thumb-reach rule in the root `test/ui/README.md`.

The title is never truncated. A `TextPainter` measure inside the title row's
`LayoutBuilder` (`resolveLibraryTitleLayout`) keeps the title and actions on
one row when they fit at the current text scale; otherwise the actions move
to their own end-aligned row above and the title takes the full width below,
wrapping to two lines. If its widest word (or the two lines) still overflow,
the title font shrinks in 5% steps down to 0.7× the role; past that it wraps
further rather than ellipsize.
List rows own the 16dp screen gutter (the `ListView` has no horizontal
padding): the cover sits on the gutter with the header title, the top hairline
spans 16…16, while the selection tint and the swipe-delete background run
edge to edge with the delete glyph ending 16dp from the screen edge.
A selected row fills with `selectedControlBackground` and switches its title
and metadata to `selectedControlForeground`; the cover itself keeps a shared
translucent marker wash (`kLibraryCoverSelectionTintAlpha`) under the opaque
`selectionMarker*` check so artwork stays visible. The grid's finished badge
uses the `successContainer`/`onSuccessContainer` pair. Grid covers no longer
show the file format (list rows and semantics keep it). Never-opened sources
(`LibrarySource.isNew`, the New collection's predicate) get a top-start New pill
inside the cover: `surface` fill, `actionForeground` `labelSmall` w700, at
least 20dp tall and growing with the text scale; generated cover text
reserves its height.

The picker's first group has no title. Favourites is always its first row,
directly under the search field (16dp below it), however many built-in
scopes are listed or which scope is selected: it is the one curated
collection every reader has. A search that misses it hides it like any other
row. The Library row (`AppIcons.library`, the total item count, no menu)
comes next, then the built-in scopes. It is selected with the same pill,
check and semantics as other rows when no scope is active, follows the
collection search, and pops `LibraryCollectionScopeCleared`, which the screen
turns into `LibraryCollectionScopeChanged(null)`. Row icons and section titles
sit on the 24dp sheet gutter with the search field, and row menu glyphs end where the close glyph
does. Rows keep an 8dp inset for their selection pill and a trailing 48dp
menu target; the list subtracts both (`AppSizes.iconActionOutset`) from its
padding, so the pill bleeds 8dp into both gutters (16dp from the sheet edges)
and the target extends into the trailing gutter without shrinking. Labels and
counts in rows without a menu keep its slot, so every count ends 12dp before
the same 48dp column as Add to collection's check slot. Insets mirror in RTL.
Selection includes a check, paired theme colors and selected semantics; the
menu glyph is `onSurfaceVariant`, or `selectedControlForeground` on the
selected row. Row press/focus feedback remains enabled.

Collections -> Manage is one guarded sheet flow. Back returns to the
same query and scroll offset; Save/Delete refreshes that list in place. Close
exits the whole flow after the existing draft guard. Like other guarded forms,
this flow disables scrim/drag dismissal, reserving the normal handle height.
The selector stays mounted offstage during editing; toggling staged removals
does not read storage or rebuild its search. Standalone management remains
available with its existing dismissal result. Both entry paths retain the
route-owned bottom safe area across manage/delete/discard steps.
The header reserves only the compact offline icon, not a hidden localized word.
The lazy grid uses up to three columns, reducing the count on narrow viewports
and with enlarged text. Covers sit directly on the 16dp gutter with no tile
inset, and both layouts start their first cover `kLibraryContentTopPadding`
(12dp) below the header's search field: the list row's own padding supplies it,
the grid adds it as top padding. Content bottom padding comes from
`libraryContentBottomPadding(context)`: the bottom capsule (56dp), its 8dp lift,
the Scaffold's 16dp margin and a 16dp gap, plus any bottom safe inset beyond
16dp, so the last row's progress bar is never under the capsule. "No results"
pads its scroll view the same way so Reset filters can scroll clear of it;
the empty library has no capsule and no padding. The selection bar is mounted
in `bottomNavigationBar` only while selecting, because an occupied slot
strips the body's bottom inset; while selecting the bar owns the safe area
and the capsule's space stays reserved, so the end of the list never moves.

### Continue reading

In the default view (no search, no collection scope, not
selecting) the first item of both the list and the grid scroll view is
`LibraryContinueReadingCard` for `LibraryState.continueReadingSource`: the
source with the latest `lastOpenedAt` among unfinished sources with
`0 < readingProgress < 1`, computed once per state. The card sits on the
16dp gutter, `kLibraryContentTopPadding` below the search field and
`kLibraryContinueReadingGap` (16dp) above the first cover, and scrolls with
the content. It uses the card surface (`surfaceContainerLow`), `AppRadius.lg`
and 12dp padding: a 64×96 shared cover, the Continue reading overline, a serif
`titleMedium` title (two lines), the muted author, a 4dp rounded
`actionForeground` progress bar on a muted track and a
"{percent}% · {time left}" caption. Time left is
`readingTimeLeft(LibrarySource.estimatedMinutesLeft)` and is omitted when
unknown (books have no character count). The whole card is one button
(label: title; value: percent read and time left) that calls the same
`onSourcePressed` as tiles; long-press does nothing.
Generated cover titles budget the actual TextScaler height rather than the
unscaled font size.

A collection read failure retains the last valid stored scopes and selection,
while books/articles still refresh. First-load failure does not manufacture an
empty Favourites scope. The Collections sheet shows the shared `ErrorState`
(filled Retry), subscribing to Library state so recovery does not close/reopen
the sheet. Its empty and no-match placeholders, the manage sheet's empty
collection (in both its fixed and scrolling layouts) and Add to collection's
load failure use `EmptyState(compact: true)` / `ErrorState` rather than ad hoc
text and buttons.
Source repositories, not LibraryBloc, own atomic membership cleanup on deletion.

Selection hides the bottom capsule and shows a bottom action bar: selected count,
explicit cancel, add to collection, and secondary delete. Scaffold reserves its
height, including `AppBottomSafeArea` and 16dp below the commands. Cancel/trash
glyphs align with the screen's 16dp gutter while retaining 48dp targets
(`AppSizes.iconActionOutset`); the trash stays `error` as the bar's bulk
destructive command and the filled label goes through `AppButtonLabel`.
System Back still clears selection. Display and
selection changes reuse loaded sources instead of querying storage again.

Display shares `ActionBottomSheetLayout.scrollable`, `AppSettingsSection` and
`AppChoiceControl` with reader Appearance. The Language row is the shared
`AppDrillInRow` with a `value`, padded to the 56dp settings-row height. Layout/theme segments adapt to rows
when localized labels at the current text scale do not fit. Groups are separated
by spacing, without an extra divider above Language. The language row
shows the current language beside the chevron, mirrored for RTL. When they do
not fit alongside the label, the value and chevron move together onto the next
line. Display and `LibraryLanguageSheet` are horizontal steps in one modal, not
stacked bottom sheets. Display's content determines the common height, bounded
by available space, with only the standard 16dp content padding below Language
and the modal's system safe area. The language grid fills that height rather than
stretching Display.
Language's five rows have no extra vertical gaps. Options retain their 48dp
minimum tap targets and vertical inner padding; the grid ends with 8dp body
padding. Column gaps and horizontal option padding are 8dp, with 4dp before
the checkmark; the body subtracts that 8dp inset from the 24dp gutters so
labels and checkmarks sit on the content edge with the title while the tinted
pill bleeds into the gutter. At standard text size all ten options fit without scrolling on
320dp and wider portrait phones, without enlarging Display. Oversized text or
insufficient viewport space retains scrolling rather than clipping choices or
shrinking targets. Step navigation preserves the height. Changing the locale, text
scale or available viewport can resize Display when its controls wrap.
Choosing a language applies and persists it immediately through
`LibraryLocaleCubit`, keeping Language open for further choices. Reselecting the
current language also stays on this step. Header Back and system Back return to
Display; neither rolls back the selected language. No Save action is needed.
Close, a scrim tap and dragging the handle dismiss the whole flow from either step.
The 300ms slide uses the current locale's direction and retains it throughout the
transition. Reduced motion switches immediately.
Only the active step accepts input or exposes semantics. Hidden Display retains
its layout size and scroll position without painting or accepting focus.
Animation updates translations rather than rebuilding settings. No post-frame
measurement or intrinsic layout is needed to match the two steps' heights.
The picker uses two
columns when every native language name fits with its checkmark slot, and one
column otherwise. It measures the actual font and text scale instead of using
a device breakpoint or shrinking text. Options have natural heights with a
48dp minimum tap target; the selected option has a checkmark, themed fill, and
single-selection semantics. Each step uses one scroll viewport only when needed
within the common height. Full-width edge fades appear only where content
continues offscreen. This eagerly lays out the fixed set of ten languages,
without intrinsic sizing or per-scroll text measurement.

Collection source rows use the shared trash icon to remove membership, not
delete the book or article from the library. Their localized tooltips name the
source; the close icon is reserved for dismissing the sheet.
The 20dp trash glyph aligns with the header close glyph at the 24dp content
gutter. Its 48dp target extends into that gutter without changing text insets;
the geometry mirrors in RTL. Source-row hairlines span 24…24.
"Delete collection" is a compact destructive `TextButton` (no icon,
`foregroundColor: error`, `AppButtonLabel`, 48dp target, muted while busy) at
the end of the source-count row directly under the name field:
`Row[Expanded(count), button]`, the count centred in the 48dp row. The row
ends 8dp in (the theme pads text buttons 16dp) so the label sits on the 24dp
gutter while the ink bleeds into it; it mirrors in RTL. When the label and
the count cannot share the line (large text, long translations, measured with
`TextPainter` like the sibling sites), the row stacks: count on its own line,
button below aligned to the end. The step-height estimate uses the same rule.
There is no separate delete entry, hairline or gap above the footer any more.
Both the fixed and the scrolling layout keep one rhythm: the source list's
own 16dp bottom after the last row, then the shared footer padding
(`ActionBottomSheetLayout.defaultFooterPadding`: 24dp above the command and
16dp below). The footer is one full-width filled Save (the step's header
already has Close/Back, so no Cancel sits beside it, per the Command Footers
contract). Save wraps `AppBusyButtonLabel`, so a write shows a spinner with
stable geometry while Save, Close and the row actions are disabled. The delete
confirmation body is start-aligned `bodyMedium` on the 24dp gutter like the
Discard and Delete items confirmations.
Collection edits remain staged until Save. At the root, Close and system Back
prompt only when there are actual edits. Drag/scrim dismissal is disabled for
this form so it cannot bypass the guard. Delete is secondary and has its own
confirmation. Discard and delete confirmations are steps in the same sheet,
not nested dialogs. Both use the safe-default pairing: Keep editing / Keep
collection (`commonKeepEditing` / `commonKeep`) is filled, Discard /
Delete (`commonDiscardChanges` / `commonDelete`) is the outlined error-coloured
secondary, placed secondary-left, primary-right.
Header/system Back from a confirmation returns to the draft without writing it.
Keep also returns to editing without deleting anything. Close on
delete exits the flow or requests the discard decision when there are edits;
it never acts as Back. Repeated Close on the discard decision leaves that guard
visible until the user chooses Discard or returns to editing.
Large text and keyboard-constrained layouts scroll the form in a single lazy
sliver viewport while keeping Save available on the same 24dp gutters. No
collection/source is deleted by leaving the form.
Removing membership retains the row and replaces trash with `AppIcons.undo`,
the same curved-arrow role as bookmark restoration. A localized status explains
that removal takes effect after Save. The status slot retains its height;
Undo does not shift neighboring rows, shrink the sheet or move the footer.
Several removals can be staged/restored independently, including after a save
failure. Only Save writes membership changes; restoring all edits disables it.
The source snapshot and counts are prepared once; toggles update counts and a
set in constant time without removal-animation ticks or whole-list copies.
Rows remain lazily built. Only navigation between form steps animates height.
The preferred height includes the source rows' 48dp action targets, row and list
padding, dividers, and footer. A short list must fit without scrolling or edge
shadows when the viewport permits; shadows only indicate real hidden content.

Add to collection opens on destinations: Favourites and a lazy list of manual
collections. The whole row adds sources, without a separate plus icon. A
checkmark marks disabled destinations already containing every selected source;
partially matching destinations still accept the missing sources. The checkmark
slot remains reserved so item counts stay aligned.
One grouped membership query (bounded parameter batches) supplies this state,
not a query per visible row or a read of every collection's source IDs.
New collection is an `AppDrillInRow`; it opens a separate name form in the
same route. Destination rows clip their ripple to `AppRadius.sm` and keep a
4dp ink inset that bleeds past the 24dp gutter, so their icons sit with the
New collection icon and the dividers span 24…24. Their trailing 48dp slot
matches the Collections picker's menu column: the check glyph ends on the
gutter and counts end 12dp before the slot in both sheets. The name form's
footer is one full-width filled "Create and add" (`FilledButton` with
`AppBusyButtonLabel`, busy from the cubit, disabled while the name is empty)
in the layout's `footer` slot: the step's header has Back and Close, so no
Cancel sits beside it. The write shows a spinner in that button rather than a
progress strip over the field; the destination step keeps its 2dp strip while
a row write is in flight because it has no command button to host a spinner.
The complete destination step, including its wrapping header, determines both
steps' height. Back returns to destinations and preserves the draft; Close
dismisses the flow. While the name field is non-empty the form wraps itself in
`AppSheetDismissGuard`: Close, a scrim tap and drag-down do not dismiss but show
the same Keep editing / Discard decision as Manage (`commonKeepEditing` filled,
`commonDiscardChanges` outlined in the error color); Discard leaves the flow, Keep editing or
header/system Back return to the form with the draft intact, and repeated
Close/scrim attempts keep the decision visible. An empty form keeps the handle
and dismisses freely. System Back from the form remains a step back to
destinations, not a dismissal, so it never asks. Slide direction follows the
locale, with an immediate reduced-motion transition. Hidden steps retain layout but expose no input, focus or semantics.
The keyboard and enlarged text leave actions reachable, with full-width fades
only for genuinely overflowing content. A failed initial load shows Retry;
mutation failures retain the current step and draft. Busy guards prevent double
submission; while a write is in flight the destination step also holds
`AppSheetDismissGuard`, so scrim tap and drag-down wait like Close and system
Back. Closing during a write does not emit late state or reload its snapshot.
Shared headers/actions remain in `component_library`.

## Dependencies

- `book_repository` — book data source
- `article_repository` — article data source
- `collection_repository` — manual collection and favourites persistence
- `preferences_service` — layout, theme, and locale persistence
- `domain_models` — `Book`, `Article`, `LibrarySource`
- `component_library` — theme, `SearchField`, `ScrollEdgeFadeStack`, `EmptyState`,
  `ErrorState`, `AppDrillInRow`, `AppPlainIconButton`, `AppSheetActions`,
  `AppIcons`, `AppSpacing`, `AppRadius`, `AppMotion`
- `flutter_bloc`, `equatable`, `stream_transform` (for debounce)
