# domain_models

Immutable domain models, enums, and exceptions shared across repositories,
services, and features. Pure Dart — no Flutter, no storage, no services.

Every model is a plain `class` extending `Equatable`, with a `copyWith`
method and a `const` constructor. Every enum has a `from(String)`
parser that falls back to a default, and (where storage keys differ
from Dart names) a `toStorageString()` helper.

---

## Models

| Model             | Represents                                                |
|-------------------|-----------------------------------------------------------|
| `Book`            | A file-backed source in the library (books, PDFs, comics) |
| `Article`         | A saved web article with local content and reader state   |
| `ArticleBlock`    | Structured article content returned by the cleaner        |
| `ExtractedArticle` | Cleaner response before local persistence assigns paths  |
| `LibrarySource`   | Unified library/details projection for books and articles |
| `SourceBookmark`  | Bookmark anchored to a source with CFI/page metadata      |
| `Highlight`       | Text highlight attached to a reading source               |
| `Flashcard`       | Flashcard with front/back and creation source             |
| `DictionaryEntry` | Saved word or phrase with translation and usage examples  |
| `ReviewItem`      | FSRS state for a reviewable item (flashcard/highlight/…)  |
| `ReviewLog`       | Single review event, persisted for history and statistics |
| `FsrsCardData`    | Embedded FSRS v6 state (stability, difficulty, due date)  |

Flashcard, dictionary, and FSRS models are dormant in the current app surface.
They stay in `domain_models` for storage compatibility and future restoration.

## Enums

| Enum                   | Values                                        |
|------------------------|-----------------------------------------------|
| `SourceType`           | `book`, `article`                             |
| `BookFormat`           | `epub`, `fb2`, `mobi`, `pdf`, `azw3`, `cbz`   |
| `ArticleTextDirection` | `ltr`, `rtl`                                  |
| `HighlightColor`       | `yellow`, `green`, `blue`, `pink`, `purple`   |
| `ReviewableType`       | `flashcard`, `highlight`, `dictionary`        |
| `FsrsState`            | `newCard`, `learning`, `review`, `relearning` |
| `Rating`               | `again`, `hard`, `good`, `easy`               |
| `CreationSource`       | `manual`, `aiHighlight`, `aiSelection`        |

## Exceptions

| Exception           | Thrown when                                             |
|---------------------|---------------------------------------------------------|
| `StorageException`  | A storage operation fails unexpectedly (wraps `cause`)  |
| `NotFoundException` | An entity with the given `id` is missing from storage   |

Repositories wrap raw Drift/SQL errors into `StorageException`. Features
catch domain exceptions only; they never see a `SqliteException` directly.
Add a new domain exception only when the UI needs to react differently —
otherwise reuse `StorageException`.

---

## Pattern

```dart
class Book extends Equatable {
  const Book({required this.id, required this.title, ...});

  final String id;
  final String title;
  // ...

  Book copyWith({String? title, /* ... */}) => Book(/* ... */);

  @override
  List<Object?> get props => [id, title, /* ... */];
}
```

Nullable fields that need to be clearable in `copyWith` use the `_absent`
sentinel trick so `copyWith(author: null)` actually clears the author
instead of being treated as "no change". See `Book` and `FsrsCardData`
for the canonical shape.

---

## Where it fits

```
domain_models  (pure Dart, only depends on equatable)
        ▲
        │
        ├── shared, local_storage
        ├── *_repository packages
        ├── service packages
        └── features/*
```

Nothing in this package imports from anywhere else in the repo.

---

## Rules

- Plain `class` extending `Equatable`. `final class` only where Dart
  enforces it (e.g. `sealed` children).
- Immutable fields, `const` constructors, `copyWith`.
- No Flutter imports. No storage types. No services.
- Enums declare `from(String)` parsers with a default fallback so
  corrupted storage values never crash the app.
