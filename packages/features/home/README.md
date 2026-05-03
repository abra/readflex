# home

Dashboard shown on the `Home` tab: reading stats, progress, and recent
books. First thing the user sees once they have content in the library.

## Public API

`HomeScreen` — stateless widget wired up in `routing.dart` for the `/home`
route. Builds its own `HomeBloc` internally and dispatches the initial load.

| Prop                  | Type                              | Purpose                                     |
|-----------------------|-----------------------------------|---------------------------------------------|
| `bookRepository`      | `BookRepository`                  | Recent books                                |
| `highlightRepository` | `HighlightRepository`             | Total highlights counter                    |
| `fsrsRepository`      | `FsrsRepository`                  | Due-flashcards counter                      |
| `onBookPressed`       | `void Function(Book)`             | Navigate to reader for the tapped book      |
| `onPracticePressed`   | `VoidCallback`                    | Jump to the Practice tab when due > 0       |

## Architecture

Single `HomeBloc` (`home_bloc.dart` with `part`-ed event/state files). Simple
state machine with `HomeStatus.{initial, loading, success, failure}`.

- `HomeLoadRequested` — fetches books, highlights, and due items in
  parallel, sorts books by `lastOpenedAt ?? addedAt` (top 5), and derives
  counters (`totalSources`, `totalHighlights`, `dueFlashcards`).

Non-fatal errors during load flip state to `failure`; retry re-dispatches
`HomeLoadRequested`.

## Dependencies

- `book_repository`, `highlight_repository`, `fsrs_repository` — data sources
- `domain_models` — `Book`
- `component_library` — theme, `StatCard`, `EmptyState`, `ErrorState`,
  `CenteredCircularProgressIndicator`, `AppIcons`, `AppSpacing`
- `flutter_bloc`, `equatable`
