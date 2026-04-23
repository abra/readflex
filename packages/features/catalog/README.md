# catalog

Content library browser: shows all books and articles in a single merged feed
with filter segments, search, and a list/grid toggle. Surfaced as the
`Library` bottom-nav tab (route `/library`).

## Public API

`CatalogScreen` — stateless widget wired up in `routing.dart`. Provides both
BLoC and layout cubit internally.

| Prop                  | Type                                | Purpose                                      |
|-----------------------|-------------------------------------|----------------------------------------------|
| `bookRepository`      | `BookRepository`                    | Book list + delete                           |
| `articleRepository`   | `ArticleRepository`                 | Article list + delete                        |
| `preferencesService`  | `PreferencesService`                | Persist list/grid layout choice              |
| `onBookPressed`       | `Future<void> Function(Book)`       | Open reader, then refresh on return          |
| `onArticlePressed`    | `Future<void> Function(Article)`    | Open reader, then refresh on return          |
| `onAddPressed`        | `AsyncCallback`                     | Open the import-flow bottom sheet            |

## Architecture

Two independent units of state:

- `CatalogBloc` — domain data. Merges books and articles into a single
  `items` list sorted by `addedAt` DESC, supports `filter`
  (`all / books / articles / saved / finished`) and `searchQuery` (debounced
  300ms). `visibleItems` is a computed getter over `items` so the bloc only
  stores one source-of-truth list.
- `CatalogLayoutCubit` — UI-only list-vs-grid toggle, persisted through
  `PreferencesService.catalogLayoutMode`.

The screen uses separate widgets (`CatalogListView`, `CatalogGridView`) for
each layout and a local `TextEditingController` for the search field so
keystrokes don't churn bloc state.

Empty-state is handled twice: truly empty library vs. all items filtered out.
Non-fatal repository errors from delete/load go through `addError` + a
`CatalogStatus.failure` state with a retry button.

## Dependencies

- `book_repository`, `article_repository` — data sources
- `preferences_service` — layout persistence
- `domain_models` — `Book`, `Article`
- `component_library` — theme, `SearchField`, `ScrollEdgeFade`, `EmptyState`,
  `ErrorState`, `MediaCollectionCard`, `AppIcons`, `AppSpacing`, `AppRadius`
- `flutter_bloc`, `equatable`, `stream_transform` (for debounce)
