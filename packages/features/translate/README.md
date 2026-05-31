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
- `TranslateState` — carries `translatedText`, `TranslationSource`, optional
  contextual fields for the selected word/expression, `usageExamples`,
  `naturalEquivalents`, and the last error message. DeepSeek returns
  source-language `marked_sentence`/`usage_examples` values with `[[...]]`; the
  sheet renders those markers as highlighted text.

## UI response contract

The sheet follows the same minimal order as the LLM contract:

- One ordinary word: selected word, word translation, source/target definition,
  and the source sentence with the word highlighted.
- One word inside a larger unit: selected word and its direct translation first,
  then a short note about the larger unit, source/target definition, and the
  source sentence with the larger unit highlighted.
- Selected n-word expression: selected text, translation, expression type,
  source/target definition, and the highlighted source sentence.
- Selected n-word non-expression: selected text, translation, and the
  highlighted source sentence.

When available, the sheet also shows source-language usage variants and compact
`Related` term pairs in `source — target` form after the core answer.

The key invariant is: exact selection first, larger contextual unit second only
when it exists. If the reader reports a partial-word selection, the sheet still
previews the exact user selection but sends and saves the normalized lexical
selection (`TextSelectionContext.textForTranslation`).

## Dependencies

Requires through constructor injection:

- `TranslationService` — production wiring uses `BundledTranslationService`.
  It first checks exact bundled SQLite pair packs, can call a temporary direct
  DeepSeek client when `DEEPSEEK_API_KEY` is set, and has an on-device adapter slot for
  future offline translation. The sheet does not know about
  network state or provider details.
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


## Backend handoff

Direct DeepSeek calls are a temporary development/internal path. Before a public
release, replace the direct client with a Readflex backend that owns the API key
and accepts queued enrichment requests. The intended offline flow is: save the
on-device translation with source metadata, keep it marked as temporary, then
send selected text plus nearby sentence context to the backend when connectivity
is available. The queue and temporary/enriched status fields are future work.
