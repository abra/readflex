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

- `LibraryBloc` — domain data. Loads books and articles and exposes
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

The screen uses separate widgets (`LibraryListView`, `LibraryGridView`) for
each layout and a local `TextEditingController` for the search field so
keystrokes don't churn bloc state.

Empty-state is handled twice: truly empty library vs. all items filtered out.
The filtered empty state offers **Reset filters**. It clears search text,
content filter, and collection scope in one `LibraryFiltersReset` event without
reading storage. Reset and query events share a switchable debounce stream so
pending search text cannot restore an obsolete filter. Collection selection
and clearing use separate labeled 48px targets; clearing never opens the picker.
Load errors go through `addError` and a `LibraryStatus.failure` retry surface.
Delete errors keep the list usable and report failure through a deletion effect.

## Dependencies

- `book_repository` — book data source
- `article_repository` — article data source
- `collection_repository` — manual collection and favourites persistence
- `preferences_service` — layout, theme, and locale persistence
- `domain_models` — `Book`, `Article`, `LibrarySource`
- `component_library` — theme, `SearchField`, `ScrollEdgeFadeStack`, `EmptyState`,
  `ErrorState`, `AppIcons`, `AppSpacing`, `AppRadius`
- `flutter_bloc`, `equatable`, `stream_transform` (for debounce)
