# source_details

Details surface for books, comics, articles, and other reading sources. It sits
between Library and the reader:

```text
Library -> SourceDetailsScreen -> ReaderScreen
```

The package intentionally uses "source" wording because the surface can display
both stored book/comic files and imported articles. Articles are converted to
the reader's `Book` model only when the user opens them.

## Public API

`SourceDetailsScreen` — stateless route widget wired in `routing.dart` for
`/source/:sourceId`.

| Prop | Type | Purpose |
|------|------|---------|
| `sourceId` | `String` | Source id from the route |
| `bookRepository` | `BookRepository` | Loads book/comic sources |
| `articleRepository` | `ArticleRepository?` | Optional article lookup + reader conversion |
| `highlightRepository` | `HighlightRepository` | Loads per-source highlight count |
| `onReadPressed` | `Future<void> Function(Book, SourceType)` | Opens the reader |
| `initialSource` | `LibrarySource?` | Optional route extra to avoid a loading flash |
| `onArticleTitlePressed` | `void Function(String url, String title)?` | Opens the original article URL |

## Architecture

- `SourceDetailsScreen` creates `SourceDetailsBloc` and dispatches
  `SourceDetailsLoadRequested`.
- `SourceDetailsView` renders only bloc state and UI callbacks.
- On return from reader, the screen reloads the source so the button label and
  reading metadata reflect the latest stored source row.
- The bloc resolves books first, then articles when `articleRepository` is
  available. Review rows show lightweight per-source highlight counts loaded
  via repository count methods; the view does not query repositories directly.
- The bottom bar is thumb-first: back action on the left, the read/continue
  CTA taking the remaining space.
- Cover rendering uses the shared cover frame/Hero primitives from
  `component_library` so Library and details endpoints keep compatible Hero
  geometry.

## Dependencies

- `book_repository` — book/comic lookup.
- `article_repository` — article lookup and conversion to reader book.
- `highlight_repository` — highlight count for the source.
- `domain_models` — `Book`, `BookFormat`.
- `component_library` — cover frame, Hero wrapper, icons, spacing, error and
  loading states.
- `flutter_bloc`, `equatable`.
