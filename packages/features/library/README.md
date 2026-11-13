# library_feature

Internal Library feature package. Dart reserves the package name `library`,
so the pub package is `library_feature` while the UI surface remains
`Library`.

Content library browser: shows books and articles in a single feed with
search, one Collections picker for what to show (Books, Articles, Comics,
New, Favourites, your collections, sites and authors) and a list/grid toggle.
Surfaced as the `Library` main screen (route `/library`).

## Platform presentation

`AppScaffold`, `AppButton`, `AppIconButton` and `AppTextField` select the
platform presentation through `context.isCupertino`; the feature keeps one
bloc and navigation flow. iOS uses a Cupertino page, native fields and
`CupertinoSliverRefreshControl` inside the library scroll view. Android keeps
Material controls and `RefreshIndicator`. Covers and the thumb toolbar share
the app's custom presentation on both platforms. Collection destinations use
native checkmark rows on iOS and checkbox rows on Android.

Search retains its controller, focus node, horizontal viewport and live
`EditableText` through toolbar and keyboard transitions. The closed search
snapshot uses the same text style and offset. Platform-root tests cover this
identity, refresh, 200% text and phone RTL; native keyboard checks live in
`integration_test/library_controls_test.dart`.

## Public API

`LibraryScreen` — stateless widget wired up in `routing.dart`. Provides BLoC
and UI preference cubits internally.

| Prop                  | Type                                | Purpose                                      |
|-----------------------|-------------------------------------|----------------------------------------------|
| `bookRepository`      | `BookRepository`                    | Book list + delete                           |
| `articleRepository`   | `ArticleRepository?`                | Optional article list + delete               |
| `collectionRepository`| `CollectionRepository`              | Collections and favourites persistence      |
| `fsrsRepository`      | `FsrsRepository?`                   | Review counts for the Practice entry; `null` shows none |
| `preferencesService`  | `PreferencesService`                | Persist list/grid, theme, locale and global reader animation |
| `isOffline`           | `bool`                               | Connectivity indicator for the Library UI   |
| `onSourcePressed`     | `Future<void> Function(...)`        | Open reader, then refresh                    |
| `onAddPressed`        | `LibraryImportLauncher`             | Open import UI at a `LibraryImportEntry`; notify successful persistence |
| `onPracticePressed`   | `Future<void> Function()?`          | Open Practice; the Library reloads its counts when it closes. `null` shows no entry |
| `openImportOnStart`   | `bool` (default `false`)            | Open file import once after the first frame  |

`LibraryImportEntry` (exported) names the import step to open: `menu` from
the "+" button, `file` from the empty library's Upload a file, `article` from
its Save an article. `openImportOnStart: true` calls
`onAddPressed(entry: LibraryImportEntry.file, ...)` exactly once after the
first frame (onboarding's "Add a book"); rebuilding the same screen does not
reopen it, and it goes through the same in-flight guard and refresh as the
bottom "+" action.

## Architecture

Independent state units keep domain loading, persisted display preferences,
selection, and collection commands separate:

- `LibraryBloc` — domain data. Loads books and article metadata into a single
  `LibraryState.sources` list of `LibrarySource` values, and, given an
  `FsrsRepository`, the review counts into `LibraryState.practice`
  (`LibraryPracticeSummary`: saved words, highlights, cards due and the next
  review deadline). Counts load alongside the sources. A failed count read is
  reported and preserves the last counts without failing Library. It exposes
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
- `LibraryPageAnimationCubit` — global Slide/Cover page animation in the
  header's Display sheet. Persists `readerPageAnimation` and observes the
  preferences stream; an older queued snapshot cannot undo a newer choice.
  All paginated books, PDFs and comics use it. Cover is the default; articles
  scroll without a page animation. It does not edit source appearance.
- `LibrarySelectionCubit` — multi-select state for bulk source actions.
- `AddToCollectionCubit` / `ManageCollectionCubit` — collection mutations and
  their transient command state.

The Library exposes protected Favourites, persisted manual collections, and
derived author/site smart collections.

### Practice entry

Practice has no tab; the Library is its one way in, in two places:

- `LibraryPracticeRow` follows the Continue reading panel in the default view
  (no search or collection), once something is saved for
  review: "N cards due today" with the accent-tinted glyph, or "All caught
  up" with the totals, muted. It scrolls with the rows, so a short window at
  large text keeps its list. It still opens Practice when nothing is due,
  including Review ahead. A reader who never saves sees no row.
- The due count is words due plus highlights due while Practice settings
  review highlights (`practiceReviewHighlights`), read from
  `PreferencesService` at each load, so the row and the badge agree with the
  hub.
- While the app is in the foreground, `LibraryBloc` schedules one timer for
  the next eligible review deadline. It refreshes only the narrow review
  queue status, then schedules the next deadline; it does not poll or reload
  books and articles. Entering the background cancels the timer; resuming
  refreshes the queue immediately. A failed queue read preserves the last
  counts and retries after one minute while active. Closing the bloc cancels
  pending work.
- `LibraryPracticeButton` sits separately above "+", outside the bottom
  capsule, only when Practice has a destination and at least one card is due.
  Zero or unknown counts hide the action. Its 48dp touch target is transparent.
  `AppFloatingPracticeIcon` fills the 32dp card silhouettes with the opaque
  surface colour so content cannot show through. Its weight-300 outline keeps
  the strokes close to 2dp. The silhouette combines the capsule's popover
  shadow with a soft, static primary-colour aura. The due count is its badge.
  One semantics node: "Practice, N cards due today".
- The badge is a custom 16dp pill with a 2dp ring in the app surface's colour,
  anchored at the glyph's top-end corner with an 8dp outset; a wider count
  grows inwards. 1–99 shows the exact count, and 100 or more
  shows "99+". Its width and height stay within the 48dp touch target; at
  enlarged text the single-line number scales down only when needed to fit.
  The full count remains in the row, the Practice section and button semantics.

Both call `onPracticePressed`; the screen suspends search focus like opening
the reader and dispatches `LibraryRefreshRequested` when Practice pops.

`LibraryImportLauncher({required onImported, entry})` completes when the
import UI closes. Implementations declare `entry` with a default
(`entry = LibraryImportEntry.menu`); Library always passes it. Its caller invokes `onImported()` after each successful persistence,
even if a dismissed sheet's import finishes later. Only that callback refreshes
Library; closing/cancelling the sheet alone does not read storage again.
Late callbacks after Library disposal are ignored.

Books and articles are requested together. Loads carry a generation token so
an older response/error cannot replace newer data. A superseded delete refresh
still emits its completion effect without restoring stale list contents.
While the reader is open, Library refreshes on its `onSourceOpened` (which
brings the new opened time) and applies every `onReadingPositionSaved`
progress to that one source without reading storage
(`LibrarySourceProgressSaved`): a save changes nothing else Library shows, and
it fires about once per page. A source read for the first time is therefore
already in Continue reading, with its current progress, when the reader closes
instead of moving there in view. A load that read a row before a save keeps
the saved progress. The delayed refresh on reader-route return remains as a
fallback and avoids moving list tiles during a reverse route/Hero transition.

Article metadata comes from a SQL projection via `getLibrarySources`, not a
full-text article read. Search and scope changes reuse the same source list.
Favourite membership reads are scoped in SQLite rather than loading every
manual collection's memberships a second time.

The screen scrolls one `LibraryContentScrollView` in both layouts: the
Continue reading panel and the secondary Practice row share its leading sliver, the sources
follow as `LibraryListSliver` or `LibraryGridSliver`. Switching List and Grid
swaps only the sources sliver, which fades in over `AppMotion.short` (nothing
slides: a slide would move the covers under the still row and card); the row
and the card keep their elements and the scroll position survives. One
consequence: Flutter derives a scroll view's semantic `scrollIndex` from its
slivers in paint order, so with the card above the rows it reports the first
row, not the card; the card and the rows still carry their own indexes. The
search field has a local `TextEditingController` so keystrokes don't churn
bloc state.
List separators use the shared `DividerTheme` for color and thickness, matching
the import sheet. They are painted above cover shadows so the line stays visible.

Wide windows (`AppWindowSize.isWide`: at least 840 × 480, so never a phone)
use the extra width without stretching anything:

- The grid keeps its phone rule (as many 88dp tiles as fit, up to six; text
  scales the tile up to 150%) and adds a column whenever covers would pass
  160dp (`libraryGridColumnCount`). A full 1200dp content frame shows seven
  covers instead of stretching the artwork. Every phone width gives the same
  count as before.
- The list lays its rows out in two columns, read across then down, with the
  screen gutters outside and the grid's 12dp gap between them
  (`BookLibraryListTile.gutters`). Each line is as tall as its taller row;
  every line after the first starts with both hairlines. Swipe to delete
  and selection work per row as in one column, and screen readers count
  sources, not lines: each row and the Continue reading card carry their own
  index, as in the grid.
- Selection keeps cancellation in a separate circular floating button and
  the selected count, collection action and delete in a contextual capsule.
  The same controls adapt to narrow and wide windows.

`AppContentFrame` bounds the successful Library header and scroll content to
1200dp, with an extra 8dp outer inset in wide windows in addition to the 16dp
inner gutters. The grid computes its columns from the space it receives,
including Split View. The header exposes a settings glyph on phones and the
localized Display options label in wide windows.

At 600dp width and 480dp height, utility and collection actions use 24dp
glyphs, while the item count and Continue reading metadata use the existing
15sp text roles. Narrow windows keep their compact roles. Touch targets,
cover-only grid geometry, normal import/filter capsule height and source actions
are unchanged;
the Display action measures the same glyph/text sizes it paints.

Continue reading is an inset rounded, outlined tonal panel with a compact
60×90 phone cover, native progress fill and the full-title fitting behavior. Selection
keeps the panel in place and uses the shared selected color pair.

Grid sources use the original cover-only 2:3 tiles (`BookLibraryGridTile`),
with 12dp gaps in both directions and no metadata below the artwork. Embedded
images fill the cover; generated artwork shows the title and the book's author
or article's site on the cover. New/finished badges, selection and progress
remain cover overlays. The whole cover opens or selects one source and exposes
one semantics node. The lazy grid keeps its original 88dp minimum tile width
at normal text size and scales the width limits up to 150% for enlarged text.

Empty-state is handled twice: truly empty library vs. a search or collection
that shows nothing.
The empty library (`LibraryEmptyState`) shows the book icon in a 72dp circle
tinted with the accent at low alpha, the serif `headlineSmall` title and muted
subtitle, then two full-width commands stacked 10dp apart: filled **Upload a
file** (`LibraryImportEntry.file`) and outlined **Save an article**
(`LibraryImportEntry.article`), followed by the muted file kinds caption. It
applies the 16dp screen gutter once and disables both commands while an
import flow is open. Like onboarding, its column stops at
`AppSizes.centeredColumnMaxWidth` (480) in every window, so on tablets and
landscape phones the buttons keep a button's shape.
When a non-empty library lists nothing, the body says why and offers the one
way out. A search without matches shows No results found / Try a different
search with **Clear search** (`commonClearSearch`), which empties the field,
drops focus and sends an empty `LibrarySearchQueryChanged`; the collection
scope stays. Without a search only a collection can hide every source, so an
empty collection shows This collection is empty with that collection's glyph
and **Show entire Library**, which clears the scope. Neither reads storage.
An empty query applies at once while other queries are debounced; the search
stream is a `switchMap`, so clearing cancels a pending query and old text
cannot come back. The collection scope is switched
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
Library item deletion uses `showAppConfirmationDialog`: a native Cupertino or
Material confirmation dialog on the root navigator, including on tablets.
The count-aware title and message retain the selected item count. Keep is the
safe default and Delete is destructive; only explicit confirmation returns
`BookDeletionScope.keepLearningData`. Keep and system dismissal do not write.
Collection deletion and discard decisions remain steps in their guarded sheet
flow, using the filled safe choice and outlined destructive secondary through
`AppSheetActions`. The list swipe background, cover New/finished
badges and selection checks use directional placement, so they mirror in RTL.
Grid selection scale, the grid and Continue reading progress fills and the
list/grid cross-fade resolve their durations through `context.motion`,
settling in one frame under reduced motion.
Both progress fills are `LibraryProgressFill`: it eases to a new value over
`AppMotion.short` with `kLibraryProgressFillCurve`, and holds a value that
changes while the route is covered (tickers off, as under the reader) until the
Library shows again. Started while covered, the animation would be over by the
time the reader closes, because a ticker started during a frame keeps that
frame's time.

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
collection pill, folder button or chip row; the header ends with a
`kLibraryHeaderBottomPadding` (12dp) background band under the count.
The scroll view starts below the band, so scrolled covers clip at its lower
edge and the top scroll fade starts there.
The compact offline icon stays reserved after the title.

The header's only action is Display, the shared `AppPlainIconButton`: a
transparent resting surface, circular pressed feedback and a 48dp target. The
title row ends `AppSizes.iconActionOutset` short of the 16dp edge so the
Display target bleeds into the gutter and its 20dp glyph ends on the content
edge. Search uses the same utility-action behavior for its smaller clear glyph.
Muted header glyphs use `onSurfaceVariant`, not
an alpha over `onSurface`.

Adding, switching collections and searching happen where the thumb rests, in one
bottom capsule, `LibraryFloatingActions`, in the Scaffold's floating action
slot: the shared `AppFloatingCapsule` (translucent surface, hairline outline,
popover shadow, as the reader chrome), `kLibraryFloatingActionsHeight` (56dp)
tall and lifted `kLibraryFloatingActionsLift` (8dp) above the Scaffold's
margin. Its controls have 48dp targets inside a 4dp inset; the row follows
the reading direction, so "+" keeps the outer corner in RTL too.
When cards are due and Practice has a destination, its 48dp action sits 8dp
above the capsule, centred over "+" in both directions. The floating group
keeps its bottom anchor, so adding Practice does not move the capsule or "+".

`LibraryFloatingActionsLocation` places it like `endFloat`, 16dp above the
bottom safe inset or the keyboard, whichever is higher. `endFloat` alone
loses the safe inset while any keyboard inset is reported (the Scaffold
zeroes its `minViewPadding.bottom`), so it rode a closing keyboard into the
home indicator area and jumped back up on the last frame; the location gets
the view's bottom padding from the screen instead, so the capsule follows
the keyboard continuously both ways. It compares by that inset, because the
Scaffold animates the button to every new location.

- `LibraryCollectionsButton`, at the start: the shown collection's icon
  (`libraryCollectionScopeIcon`, the same glyph as its picker row; Library
  uses `AppIcons.library`), its name (`libraryCollectionScopeLabel`, or
  Library) on one line and a 16dp chevron. It is a stadium `AppButton.text`
  whose 20dp glyph is centred in the round end; it is read as one button
  (label Choose collection, value the name) and is the only way into the
  Collections picker. Inside a collection it takes the selected pair
  (`selectedControlBackground` / `…Foreground`). Tests check 4.5:1 text
  contrast over black and white covers under the translucent capsule.
- `LibraryCapsuleActionButton`, at the outer end: a filled `primary` circle with a
  24dp `onPrimary` "+" (tooltip Add to Library), flat inside the capsule. It
  opens import at `LibraryImportEntry.menu` and takes the shared disabled
  filled colours while an import is open; switching collections stays
  available meanwhile. Its circular fill is explicit in `AppIconButton`.
- Search sits between the collection switcher and "+". Opening it moves the
  magnifier to the directional start as the capsule expands into a field above
  the keyboard. The filled end button's "+" cross-fades to a directional chevron
  (Back); Clear search appears beside it when the query is nonempty. Back clears
  the query, closes editing and drops focus; Clear only empties the query and
  retains focus. Both keep the selected collection. The field uses the user's
  text scale and a compact localized hint when needed, with the full hint in
  semantics. The screen owns its controller, focus and search mode; content
  widgets receive values and UI callbacks only.

Browsing is at most `kLibraryFloatingActionsMaxWidth` (320dp) wide and
stops 16dp short of the start edge on narrow screens, so a long name
truncates instead of becoming a bar over the covers. The screen supplies the
original horizontal safe insets, which the Scaffold strips from its floating
action slot, so neither mode can enter a landscape cutout. Its height is fixed,
so its text scales up to
`kLibraryFloatingActionsMaxTextScale` (200%), which still fits one line in
48dp. Name changes tween from the current width over `AppMotion.short`, with
"+" anchored at the outer end. Reduced motion settles the explicit width
directly. Scope-only changes stay in the capsule's selector; entering or leaving
search also updates the screen's editing and focus state.
Search uses the available width up to 480dp, preserving the same directional
end and bottom anchor. Width, magnifier position and the plus/chevron cross-fade
share one eased progress over `AppMotion.short` (200ms). The collection label
fades out before the field fades in; directional clips keep both clear of the
moving magnifier. Closing reverses from the current progress, including during
rapid toggles. The end button retains its native element and cannot import
until closing finishes. Reduced motion settles all three changes together.
Inactive controls leave input, focus and semantics. There is one live editable
field, even through rapid reversals; stable positioned children retain its
native input connection throughout opening and keyboard frames. Closing uses
a frozen query and scroll offset instead of another live editor. Viewport and
collection-name width changes animate separately from search progress. The
screen performs no extra storage reads to enter or leave search.
Practice is hidden while editing so the field owns the floating group.

The capsule appears only once the library has loaded items: the empty
library offers its own two import commands, while an empty collection keeps
it so it can be left. Selection replaces this group with the separate cancel
button and contextual action capsule at the same bottom anchor.
The floating controls switch immediately at their resting position.
The Scaffold slot stays mounted with a `Visibility` wrapper and
`AppFloatingActionButtonAnimator.none`, so it cannot cache exiting controls
or scale/rotate the whole group. Hidden controls leave layout, input and
semantics; collection-name and browse/search changes animate inside the capsule.
System Back first leaves selection, then search, before navigating away; the
native keyboard handles its own first Back dismissal. Selecting a source while
searching retains the query and scope; cancelling selection restores the field
without requesting focus. Opening a reader or Practice suspends search focus;
returning preserves editing and the query without reopening the keyboard.
The header keeps
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
padding): the cover sits on the gutter with the header title. Beside it the
title (two lines) and the author line (`bodySmall`, muted; for articles the
author and the site, `Author · Site`) start at the cover's top, and the status
line (kind glyph and label · percent, New or Done) ends at its bottom; the file
format is left out, as it says nothing to a reader. The text column is at
least as tall as the cover (a min-size `Column` under a `minHeight`, no
intrinsic layout), so a long title or large text grows the row instead of
clipping, with at least 6dp above the status line. The top hairline
spans 16…16, while the selection tint and the swipe-delete background run
edge to edge with the delete glyph ending 16dp from the screen edge.
A selected row fills with `selectedControlBackground` and switches its title
and metadata to `selectedControlForeground`; the cover itself keeps a shared
translucent marker wash (`kLibraryCoverSelectionTintAlpha`) under the opaque
`selectionMarker*` check so artwork stays visible. The grid's finished badge
uses the `successContainer`/`onSuccessContainer` pair. Neither covers nor rows
show the file format (semantics keep it). Never-opened sources
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
menu target; the list subtracts the adaptive glyph's outset
(`AppPlainIconButton.defaultIconOutsetOf(context)`, 14dp narrow, 12dp medium) from its
padding, so the pill bleeds 8dp into both gutters (16dp from the sheet edges)
and the target extends into the trailing gutter without shrinking. Labels and
counts in rows without a menu keep its slot, so every count ends 12dp before
the same 48dp menu column. Insets mirror in RTL. The separate Add to collection
panel uses checkboxes to stage destinations rather than row menus.
Selection includes a check, paired theme colors and selected semantics; the
menu glyph is `onSurfaceVariant`, or `selectedControlForeground` on the
selected row. Row press/focus feedback remains enabled.
The picker is one lazy list of section titles and rows (the last row of a
section keeps the 16dp gap below it), so only rows on screen are built,
however many sites and authors there are. Labels are lowercased once per
state, and a keystroke only filters them. Screen readers count the rows,
not the titles.

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
and with enlarged text. Its delegate takes the count from the width in layout,
so the keyboard resizing the body relayouts the grid without rebuilding its
tiles or the Continue reading card.
Covers sit directly on the 16dp gutter with no tile
inset, and both layouts start their first cover `kLibraryContentTopPadding`
(12dp) below the title/count header's band: the list row's
own padding supplies it, the grid adds it as top padding. Content bottom
padding comes from `libraryContentBottomPadding(context)`: the bottom capsule
(56dp), another 56dp only while its due-card action is shown (48dp target plus
8dp gap), its 8dp lift, the Scaffold's 16dp margin and a 16dp gap over the body's
bottom padding (the safe inset the keyboard leaves uncovered), so the last row ends
16dp above the highest floating action with or without a home indicator and
on every keyboard frame. Ordinary "No results" feedback
pads its scroll view the same way so its command can scroll clear of it.
When the keyboard leaves very little height above an active search capsule,
feedback becomes a compact message; Clear and Back remain in the capsule
instead of a second recovery command behind it.
The empty library has no capsule and no padding. Selection also uses floating
controls, preserving the body's safe inset and content geometry when it starts
or ends. The floating groups are `ToastAvoidArea`s: toasts float above the
visible controls and leave them tappable.

### Continue reading

In the default view (no search, no collection scope),
`LibraryContinueReadingCard` precedes Practice and the sources in both layouts.
Wide windows place the secondary Practice row beside it; without Practice,
the reading module stops growing at 800dp. It shows
`LibraryState.continueReadingCardSource`: `continueReadingSource`, the source
with the latest `lastOpenedAt` among unfinished sources with
`0 < readingProgress < 1`, computed once per state. The card is that source's
place: `LibraryState.listedItems` (cached like `visibleItems`) leaves it out of
the list and grid below, so the book is never shown twice; searching or a
collection drops the card and lists the source in its place again. The item
count still includes it.

The card uses `AppSurfaceRole.contentCard`: a quiet opaque card with an iOS
continuous 18dp shape, or the Material surface color and 16dp outlined shape.
Its tap feedback follows the same resolved shape. It keeps 16dp outer
horizontal insets and 16dp inner padding, `kLibraryContentTopPadding` below
the header's band and `kLibraryContinueReadingGap` (16dp) above the first
cover; it scrolls with the content. The `LibraryListCoverSlot` stays 60×90 on
phones and tablets, followed by `kLibraryListCoverToTextGap` (14dp).
The text column holds a header with the Continue reading label
and progress/time caption, a serif `titleMedium` title (`titleLarge` in wide
windows; the largest font that
fits the complete title in the available width and height, with wrapping and
no ellipsis; see `resolveContinueReadingTitleLayout`), the muted
author and a 4dp rounded
`actionForeground` progress bar on a muted track (a `LibraryProgressFill`,
keyed by source, so another book taking the card does not animate). The
caption reads "{percent}% · {time left}". Time left is
`readingTimeLeft(LibrarySource.estimatedMinutesLeft)` and is omitted when
unknown (books have no character count).

Up to 130% text, the 122dp card keeps its compact text between the cover's top
and bottom edges, with 16dp inner vertical padding. Title fitting checks both
the available width and height, using the actual scaled font metrics and a bounded
binary search when the theme size does not fit; the progress bar ends at the
cover's bottom edge. The title and author stay together, with unused space below.

Above 130% text, the card grows with its content. Its first row keeps the cover
beside the complete Continue reading label and progress/time caption, both
wrapping naturally. The full title follows at the unchanged `titleMedium`
(`titleLarge` in wide windows), then the author and progress bar. No title
fitting, line limit or ellipsis reduces the requested text size in this layout;
the Library scroll view keeps its last content reachable. Both layouts retain
the full title, progress and time estimate in the source button's semantics.

It behaves like a row through the same `onSourcePressed` /
`onSourceLongPressed`: tap opens the source, long-press starts selection with
it, and releasing a long-press never opens it. The card stays while selecting,
so entering selection never moves the covers under it; there a tap toggles it,
and a selected card takes the selected-control pair
(`selectedControlBackground` / `…Foreground`) for its fill, text and progress
bar (the accent fill would vanish on dark mode's accent fill), with the row's
outline, wash and check on the cover. It is one button (label: title; value:
percent read and time left) with the rows' tap and long-press hints and
selected state.
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

Selection replaces the import/filter capsule with a separate circular cancel
FAB at the directional start and a contextual capsule at the end. The capsule
holds the selected source count, the collection action and delete. Delete uses
the same 48dp circle as "+", filled with `error` and an `onError` icon; cancel
remains neutral. The two floating controls
share a bottom anchor and retain their touch targets when labels grow.
Counts above 999 show `999+`; semantics and the tooltip retain the exact count.
The count starts 24dp inside the capsule in both single-row and stacked layouts,
mirrored in RTL.
The collection action opens a modal bottom sheet; it changes destinations,
not the Library's current filter. Closing that sheet leaves book selection
active. System Back closes the sheet before it clears selection. Display and
selection changes reuse loaded sources instead of querying storage again.

Display shares `ActionBottomSheetLayout.scrollable`, `AppSettingsSection` and
`AppChoiceControl` with reader Appearance. The Language row is the shared
`AppDrillInRow` with a leading language icon. Layout, theme and page-animation
choices all pair their labels with icons in the shared choice control.
The row retains its current-language `value` and minimum 56dp height.
Layout/theme segments adapt to rows when localized labels at the current text
scale do not fit. Groups are separated
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
shrinking targets. Step navigation preserves the height. While Language is
active, hidden Display keeps the locale and language-row value it had on entry,
so translated choice labels cannot enlarge the active picker. Language itself
uses the live app locale. Back adopts the chosen locale in Display and lets its
controls determine their new natural height. Text scale or available viewport
changes still resize the flow when its controls wrap.
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
The adaptive 20/24dp trash glyph aligns with the header close glyph at the 24dp content
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
The estimate also measures the name field (one `bodyLarge` line inside the
input theme's padding) instead of assuming 56dp: Geist sets 17pt × 1.45 on a
25dp line, and a fixed guess left a one- or two-item list scrolling by 1dp
with its edge fade showing.
There is no separate delete entry, hairline or gap above the footer any more.
Both the fixed and the scrolling layout keep one rhythm: the source list's
own 16dp bottom after the last row, then the shared footer padding
(`ActionBottomSheetLayout.defaultFooterPadding`: 24dp above the command and
16dp below). The footer is one full-width filled Save (the step's header
already has Close/Back, so no Cancel sits beside it, per the Command Footers
contract). Save wraps `AppBusyButtonLabel`, so a write shows a spinner with
stable geometry while Save, Close and the row actions are disabled. The delete
confirmation body is start-aligned `bodyMedium` on the 24dp gutter like the
the sibling Discard decision.
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
that removal takes effect after Save. The status slot retains its height, so
the label transition does not resize source rows or move their action targets
and footer.
The title is vertically centered beside the source icon until removal is staged.
It then moves upward within the reserved text area over `AppMotion.short`
(200ms), with the status fading in after the title clears its line. Undo reverses
the same row-local animation from its current position; reduced motion switches
immediately. Text metrics follow the active font, locale and text scale.
Several removals can be staged/restored independently, including after a save
failure. Only Save writes membership changes; restoring all edits disables it.
The source snapshot and counts are prepared once; toggles update counts and a
set in constant time without whole-list copies. Only the affected label animates;
animation frames reuse its text children without rebuilding the form or rows.
Rows remain lazily built. Only navigation between form steps animates height.
The preferred height includes the source rows' 48dp action targets, row and list
padding, dividers, and footer. A short list must fit without scrolling or edge
shadows when the viewport permits; shadows only indicate real hidden content.

Add to collection opens `AddToCollectionSheet` through the shared
`showAppBottomSheet` route. The modal scrim covers the Library, including the
contextual capsule and separate cancel FAB. The shared form presentation owns
its width, centered tablet placement, safe-area margins, drag handle and keyboard
offset. Standalone Manage collection uses the same form role. The destination
list remains lazy and bounded. When the keyboard or large text leaves too little space for
its controls, the whole sheet content scrolls; search, destinations and the
primary action remain reachable. Step changes reset that outer scroll to the
header; keyboard resizing preserves form focus.

The searchable destinations are Favourites and manual collections. Checkboxes
stage one or more destinations; the primary action names their count and is
disabled until there is a pending destination. Rows already containing every
selected source are checked and disabled. Other destinations accept the missing
sources without removing any existing memberships. One grouped membership query
with bounded parameter batches supplies this state, rather than a read per row
or a read of every collection's source IDs. Filtering and checking destinations
only change cubit state.

Add writes every pending destination in one repository transaction, including
Favourites when selected. Failure retains the choices for retry; success closes
the sheet, clears book selection and refreshes Library. The write does not depend
on a subsequent snapshot read to report success. Busy guards prevent duplicate
submissions and dismissal during persistence. A failed initial load offers Retry.

New collection opens a name form within the same sheet. Create collection explicitly
persists an empty collection, returns to the list and selects that destination.
The selected sources are added only by the final Add action. Closing afterward
keeps the explicitly created collection and discards the pending destination
choices. Sheet Close, the scrim or a downward dismissal retains the selected
books. The separate cancel FAB ends book selection after the sheet is closed.
Header/system Back from the name form returns to the list with the typed name
intact; Back from the destination list dismisses the sheet. A typed name remains
protected after Back: Close or scrim asks Keep editing / Discard; downward
dismissal is disabled while a typed name or write needs protection. Pending
destination checkboxes alone require no discard decision.
Opening the sheet dismisses prior feedback so it cannot cover the commands.
Shared controls remain in `component_library`.

## Dependencies

- `book_repository` — book data source
- `article_repository` — article data source
- `collection_repository` — manual collection and favourites persistence
- `fsrs_repository` — review counts for the Practice entry
- `preferences_service` — layout, theme, locale, and global reader animation persistence
- `toast_service` — feedback placement above the visible floating controls
- `domain_models` — `Book`, `Article`, `LibrarySource`
- `component_library` — theme, `SearchField`, `ScrollEdgeFadeStack`, `EmptyState`,
  `ErrorState`, `AppDrillInRow`, `AppPlainIconButton`, `AppSheetActions`,
  `AppConfirmationDialog`, `AppIcons`, `AppSpacing`, `AppRadius`, `AppMotion`
- `flutter_bloc`, `equatable`, `stream_transform` (for debounce)
