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

Display uses compact layout/theme segments, falling back to full-width rows
when localized labels at the current text scale do not fit. Groups are separated
by spacing, without an extra divider above Language. The language row
shows the current language beside the chevron, mirrored for RTL. When they do
not fit alongside the label, the value and chevron move together onto the next
line. It opens `LibraryLanguageSheet` and returns to Display after choosing a
language; persistence remains in `LibraryLocaleCubit`. The picker uses two
columns when every native language name fits with its checkmark slot, and one
column otherwise. It measures the actual font and text scale instead of using
a device breakpoint or shrinking text. Options have natural heights with a
48dp minimum tap target; the selected option has a checkmark, subtle fill, and
single-selection semantics. The sheet fits its content and uses one scroll
viewport only when needed. Full-width edge fades appear only where content
continues offscreen. This eagerly lays out the fixed set of ten languages,
without intrinsic sizing or per-scroll text measurement.

Collection edits remain staged until Save. Cancel, Close and system Back prompt
only when there are actual edits. Drag/scrim dismissal is disabled for this form
so it cannot bypass the guard. Delete is secondary and has its own confirmation.
Discard and delete confirmations are steps in the same sheet, not nested dialogs.
Back from a confirmation returns to the draft without writing it.
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
