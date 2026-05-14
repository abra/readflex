# source_details

Details surface for books, comics, and other reading sources. It sits between
entry points such as Library/Home and the reader:

```text
Library/Home -> SourceDetailsScreen -> ReaderScreen
```

The package intentionally uses "source" wording even though the current domain
model is `Book`: EPUB/FB2/PDF/AZW3 are books, while CBZ is treated as a comic.

## Public API

`SourceDetailsScreen` — stateless route widget wired in `routing.dart` for
`/source/:sourceId`.

| Prop | Type | Purpose |
|------|------|---------|
| `sourceId` | `String` | Source/book id from the route |
| `bookRepository` | `BookRepository` | Loads the source |
| `onReadPressed` | `Future<void> Function(Book)` | Opens the reader |
| `initialSource` | `Book?` | Optional route extra to avoid a loading flash |

## Architecture

- `SourceDetailsScreen` creates `SourceDetailsBloc` and dispatches
  `SourceDetailsLoadRequested`.
- `SourceDetailsView` renders only bloc state and UI callbacks.
- On return from reader, the screen reloads the source so the button label and
  reading metadata reflect the latest `Book` row.
- The bottom bar is thumb-first: back action on the left, the read/continue
  CTA taking the remaining space.
- Cover rendering uses the shared cover frame/Hero primitives from
  `component_library` so Library and details endpoints keep compatible Hero
  geometry.

## Dependencies

- `book_repository` — source lookup.
- `domain_models` — `Book`, `BookFormat`.
- `component_library` — cover frame, Hero wrapper, icons, spacing, error and
  loading states.
- `flutter_bloc`, `equatable`.
