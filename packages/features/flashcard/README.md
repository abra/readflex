# flashcard

Bottom sheet for creating a flashcard from a text selection: front / back /
optional hint, save. Surfaced from the reader's context panel as a
`TextAction` plug-in — the reader feature itself knows nothing about
flashcards.

## Public API

Two exported symbols:

```dart
class FlashcardAction extends TextAction { ... }   // reader plug-in

Future<void> showFlashcardSheet(
  BuildContext context, {
  required FlashcardRepository flashcardRepository,
  required FsrsRepository fsrsRepository,
  required TextSelectionContext selection,
});
```

`FlashcardAction` is wired into the reader's `List<TextAction>` in the
composition root (`routing.dart`). It carries its own repository
dependencies so the reader stays source-agnostic. `label` is `Flashcard`,
`icon` is `AppIcons.flashcard`.

`showFlashcardSheet` is available for non-reader flows (e.g. creating a
card directly from a saved highlight).

## Architecture

Single `FlashcardCubit` (state in `flashcard_state.dart`, `part of`).

- Status machine: `idle → saving → success | failure`
- Fields tracked: `front`, `back`, `hint`. Computed `canSave` requires
  non-empty `front` and `back`; the save button stays disabled until both
  fields are filled.
- On `save()` the cubit calls `FlashcardRepository.addFlashcard(...)` with
  `deckId = selection.sourceId` (each book/article acts as its own deck),
  then registers the new card in `FsrsRepository.createReviewItem(...)`.
  The FSRS call is wrapped in its own try/catch and treated as non-fatal:
  the flashcard is already saved, a missing FSRS row just means the card
  won't surface in review until re-registered.
- Sheet uses `BlocConsumer` to auto-pop on `success`; `failure` renders an
  inline error line above the save button.

The sheet is stateless UI over the cubit, with a `SelectionPreviewCard` at
the top echoing the selected passage.

## Dependencies

- `flashcard_repository` — persistence
- `fsrs_repository` — review-item registration
- `shared` — `TextAction`, `TextSelectionContext`
- `domain_models` — `SourceType`, `ReviewableType`
- `component_library` — `ActionBottomSheetLayout`, `SelectionPreviewCard`,
  `ButtonLoadingIndicator`, `showAppBottomSheet`, `AppSpacing`
- `flutter_bloc`, `equatable`
