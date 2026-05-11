# catalog

Content library browser: shows all books in a single feed with filter
segments, search, and a list/grid toggle. Surfaced as the `Library`
bottom-nav tab (route `/library`).

## Public API

`CatalogScreen` — stateless widget wired up in `routing.dart`. Provides both
BLoC and layout cubit internally.

| Prop                  | Type                                | Purpose                                      |
|-----------------------|-------------------------------------|----------------------------------------------|
| `bookRepository`      | `BookRepository`                    | Book list + delete                           |
| `preferencesService`  | `PreferencesService`                | Persist list/grid layout choice              |
| `onBookPressed`       | `Future<void> Function(Book)`       | Open reader, then refresh on return          |
| `onAddPressed`        | `AsyncCallback`                     | Open the import-flow bottom sheet            |

## Architecture

Two independent units of state:

- `CatalogBloc` — domain data. Loads books and exposes `visibleItems` sorted
  by `lastOpenedAt ?? addedAt` DESC, then `addedAt` DESC and title,
  supports `filter` (`all / books / comics / unread / finished`) and
  `searchQuery` (debounced 300ms). `visibleItems` is a computed getter over
  the full list so the bloc only stores one source-of-truth list.
- `CatalogLayoutCubit` — UI-only list-vs-grid toggle, persisted through
  `PreferencesService.catalogLayoutMode`.

The screen uses separate widgets (`CatalogListView`, `CatalogGridView`) for
each layout and a local `TextEditingController` for the search field so
keystrokes don't churn bloc state.

Empty-state is handled twice: truly empty library vs. all items filtered out.
Non-fatal repository errors from delete/load go through `addError` + a
`CatalogStatus.failure` state with a retry button.

## Dependencies

- `book_repository` — data source
- `preferences_service` — layout persistence
- `domain_models` — `Book`
- `component_library` — theme, `SearchField`, `ScrollEdgeFade`, `EmptyState`,
  `ErrorState`, `MediaCollectionCard`, `AppIcons`, `AppSpacing`, `AppRadius`
- `flutter_bloc`, `equatable`, `stream_transform` (for debounce)
