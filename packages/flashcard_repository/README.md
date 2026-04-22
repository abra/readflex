# flashcard_repository

Domain repository for flashcards (front/back cards grouped into decks).

Follows the standard repository pattern: receives `AppDatabase` via its
constructor and extracts `flashcardsDao` internally. Storage exceptions are
wrapped into `StorageException` (from `domain_models`) before surfacing.

## Public API

| Method                                                        | Purpose                                |
|---------------------------------------------------------------|----------------------------------------|
| `getFlashcards()`                                             | All cards                              |
| `getFlashcardsByDeck(deckId)`                                 | Cards in a deck                        |
| `getFlashcardById(id)`                                        | Lookup by id                           |
| `getFlashcardsByIds(ids)`                                     | Batch lookup                           |
| `addFlashcard({deckId, front, back, hint, sourceHighlightId, creationSource})` | Create a card         |
| `updateFlashcard(card)`                                       | Update fields                          |
| `deleteFlashcard(id)`                                         | Delete card                            |

A card can optionally point at the `Highlight` it was derived from via
`sourceHighlightId`, and carries a `CreationSource` (manual, ai, imported).

## Review state

This package stores only card content. FSRS scheduling, review logs, and
"due today" queries live in `fsrs_repository` — one centralized FSRS store
for flashcards, highlights, and dictionary entries.

## Dependencies

- `domain_models` — `Flashcard`, `CreationSource`, `StorageException`
- `local_storage` — `AppDatabase`, `FlashcardsDao`
- `uuid`
