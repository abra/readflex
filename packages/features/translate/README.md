# translate

Bottom sheet that translates a text selection and optionally saves the
result to the dictionary. Shipped as a `TextAction` plugin for the reader
and as a standalone sheet launcher for any other surface that needs to
translate arbitrary text.

## Public API

| Symbol                  | Kind              | Purpose                                                |
|-------------------------|-------------------|--------------------------------------------------------|
| `TranslateAction`       | `TextAction` impl | Reader context panel button: "Translate"               |
| `TranslateSheet`        | `StatelessWidget` | Sheet body that drives `TranslateCubit`                |
| `showTranslateSheet(…)` | function          | Opens `TranslateSheet` via `showAppBottomSheet`        |

### TranslateAction

Constructor injects `TranslationService`, `DictionaryRepository`, and
`FsrsRepository`. Implements `shared.TextAction` (label: "Translate",
icon: `AppIcons.translate`) and delegates `onExecute` to
`showTranslateSheet`. Assembled once in `lib/app/routing.dart` alongside
the other reader actions.

### TranslateSheet

Props:

| Prop                  | Type                    | Purpose                               |
|-----------------------|-------------------------|---------------------------------------|
| `translationService`  | `TranslationService`    | Performs the translation              |
| `dictionaryRepository`| `DictionaryRepository`  | Persists the entry when saved         |
| `fsrsRepository`      | `FsrsRepository`        | Registers the entry for review        |
| `selection`           | `TextSelectionContext`  | Selected text + source metadata       |

## Architecture

- `TranslateCubit` — two operations: `translate(…)` and
  `saveToDictionary(…)`. Status flow: `idle → translating → translated →
  saving → saved` (with `failure` branching from the working states).
  Failures to register an FSRS row after a successful save are non-fatal
  and are only logged.
- `TranslateState` — carries `translatedText`, `usageExamples`, the
  `TranslationSource` (remote vs platform) and the last error message.

## Dependencies

Requires through constructor injection:

- `TranslationService` — fallback strategy (remote → platform). The sheet
  does not know about network state; it just calls `translate()`. When
  the remote server fails, the service silently falls back to the OS
  translator and flags `source = platform` so the UI can hide AI-only
  blocks like context and examples.
- `DictionaryRepository` — stores the saved entry.
- `FsrsRepository` — registers the new dictionary entry in the review
  queue (`ReviewableType.dictionary`).

## Plugging into the reader

```dart
// lib/app/routing.dart
ReaderScreen(
  textActions: [
    HighlightAction(...),
    FlashcardAction(...),
    TranslateAction(
      translationService: deps.translationService,
      dictionaryRepository: deps.dictionaryRepository,
      fsrsRepository: deps.fsrsRepository,
    ),
  ],
)
```
