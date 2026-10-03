# library_feature

Internal Library feature package. Dart reserves the package name `library`,
so the pub package is `library_feature` while the UI surface remains
`Library`.

Content library browser: shows books and articles in a single feed with
filter segments, search, and a list/grid toggle. Surfaced as the `Library`
main screen (route `/library`).

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
| `onAddPressed`        | `LibraryImportLauncher`             | Open import UI; notify successful persistence |

## Architecture

Independent state units keep domain loading, persisted display preferences,
selection, and collection commands separate:

- `LibraryBloc` — domain data. Loads books and article metadata into a single
  `LibraryState.sources` list of `LibrarySource` values and exposes
  `visibleItems` sorted by `lastOpenedAt ?? addedAt` DESC, then
  `addedAt` DESC and title. Supports `filter`
  (`all / books / articles / comics / unread`) and
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

`LibraryImportLauncher({required onImported})` completes when the import UI
closes. Its caller invokes `onImported()` after each successful persistence,
even if a dismissed sheet's import finishes later. Only that callback refreshes
Library; closing/cancelling the sheet alone does not read storage again.
Late callbacks after Library disposal are ignored.

Books and articles are requested together. Loads carry a generation token so
an older response/error cannot replace newer data. A superseded delete refresh
still emits its completion effect without restoring stale list contents.
The existing delayed refresh on reader-route return remains intact to avoid
moving list tiles during a reverse route/Hero transition.

Article metadata comes from a SQL projection via `getLibrarySources`, not a
full-text article read. Search/filter state changes reuse the same source list.
Favourite membership reads are scoped in SQLite rather than loading every
manual collection's memberships a second time.

The screen uses separate widgets (`LibraryListView`, `LibraryGridView`) for
each layout and a local `TextEditingController` for the search field so
keystrokes don't churn bloc state.
List separators use the shared `DividerTheme` for color and thickness, matching
the import sheet. They are painted above cover shadows so the line stays visible.

Empty-state is handled twice: truly empty library vs. all items filtered out.
The filtered empty state offers **Reset filters**. It clears search text,
content filter, and collection scope in one `LibraryFiltersReset` event without
reading storage. Reset and query events share a switchable debounce stream so
pending search text cannot restore an obsolete filter. Collection selection
and clearing use separate labeled 48px targets; clearing never opens the picker.
Load errors go through `addError` and a `LibraryStatus.failure` retry surface.
Delete errors keep the list usable and report failure through a deletion effect.

## Library Controls

Selection replaces the import FAB with a bottom action bar: selected count,
explicit cancel, add to collection, and secondary delete. Scaffold reserves its
height, including the safe area. System Back still clears selection. Display and
selection changes reuse loaded sources instead of querying storage again.

Display shares `ActionBottomSheetLayout.scrollable`, `AppSettingsSection` and
`AppChoiceControl` with reader Appearance. Layout/theme segments adapt to rows
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
the checkmark. At standard text size all ten options fit without scrolling on
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

Collection edits remain staged until Save. At the root, Cancel, Close and system
Back prompt only when there are actual edits. Drag/scrim dismissal is disabled for this form
so it cannot bypass the guard. Delete is secondary and has its own confirmation.
Discard and delete confirmations are steps in the same sheet, not nested dialogs.
Header/system Back from a confirmation returns to the draft without writing it.
Cancel on delete also returns to editing without deleting anything. Close on
delete exits the flow or requests the discard decision when there are edits;
it never acts as Back. Repeated Close on the discard decision leaves that guard
visible until the user chooses Discard or returns to editing.
Large text and keyboard-constrained layouts scroll the form in a single lazy
sliver viewport while keeping Save/Cancel available. No collection/source is
deleted by canceling the form. Footer actions stack when localized labels at
the user's text scale cannot fit side by side.
The preferred height includes the source rows' 48dp action targets, row and list
padding, dividers, and footer. A short list must fit without scrolling or edge
shadows when the viewport permits; shadows only indicate real hidden content.

Add to collection uses a lazy sliver list and shared footer actions. It stays
usable with the keyboard open and large text; a failed initial load shows Retry,
not a misleading empty collection form. Sheet titles, close targets and action
layout come from `component_library` rather than feature-specific copies.

## Dependencies

- `book_repository` — book data source
- `article_repository` — article data source
- `collection_repository` — manual collection and favourites persistence
- `preferences_service` — layout, theme, and locale persistence
- `domain_models` — `Book`, `Article`, `LibrarySource`
- `component_library` — theme, `SearchField`, `ScrollEdgeFadeStack`, `EmptyState`,
  `ErrorState`, `AppIcons`, `AppSpacing`, `AppRadius`
- `flutter_bloc`, `equatable`, `stream_transform` (for debounce)
