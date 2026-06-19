# library_feature

Internal Library feature package. Dart reserves the package name `library`,
so the pub package is `library_feature` while the UI surface remains
`Library`.

Content library browser: shows books and articles in a single feed with
filter segments, search, and a list/grid toggle. Surfaced as the `Library`
bottom-nav tab (route `/library`).

## Public API

`LibraryScreen` — stateless widget wired up in `routing.dart`. Provides both
BLoC and layout cubit internally.

| Prop                  | Type                                | Purpose                                      |
|-----------------------|-------------------------------------|----------------------------------------------|
| `bookRepository`      | `BookRepository`                    | Book list + delete                           |
| `articleRepository`   | `ArticleRepository?`                | Optional article list + delete               |
| `preferencesService`  | `PreferencesService`                | Persist list/grid layout choice              |
| `onSourcePressed`     | `Future<void> Function(...)`        | Open reader, then refresh                    |
| `onAddPressed`        | `AsyncCallback`                     | Open the import-flow bottom sheet            |

## Architecture

Two independent units of state:

- `LibraryBloc` — domain data. Loads books and articles and exposes
  `visibleItems` sorted by `lastOpenedAt ?? addedAt` DESC, then
  `addedAt` DESC and title. Supports `filter`
  (`all / books / articles / comics / unread / finished`) and
  `searchQuery` (debounced 300ms). `visibleItems` is cached per state
  instance so the bloc keeps one source-of-truth list without recomputing
  the projection on every rebuild.
- `LibraryLayoutCubit` — UI-only list-vs-grid toggle, persisted through
  `PreferencesService.libraryLayoutMode`.

The screen uses separate widgets (`LibraryListView`, `LibraryGridView`) for
each layout and a local `TextEditingController` for the search field so
keystrokes don't churn bloc state.

Empty-state is handled twice: truly empty library vs. all items filtered out.
Non-fatal repository errors from delete/load go through `addError` + a
`LibraryStatus.failure` state with a retry button.

## Dependencies

- `book_repository` — book data source
- `article_repository` — article data source
- `preferences_service` — layout persistence
- `domain_models` — `Book`, `Article`, `LibrarySource`
- `component_library` — theme, `SearchField`, `ScrollEdgeFade`, `EmptyState`,
  `ErrorState`, `MediaCollectionCard`, `AppIcons`, `AppSpacing`, `AppRadius`
- `flutter_bloc`, `equatable`, `stream_transform` (for debounce)
