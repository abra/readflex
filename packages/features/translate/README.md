# translate

Reader text action and bottom sheet for contextual translation.

The feature implements `TranslateAction` from the shared reader text-action
contract. It owns only UI and sheet state: request building, language selectors,
loading/error states, and target-language preference updates.

## Public API

| Symbol | Purpose |
|--------|---------|
| `TranslateAction` | Reader context-panel action wired by `routing.dart` |
| `showTranslateSheet` | Opens the translation sheet for a `TextSelectionContext` |

## Architecture

```text
routing.dart
  -> TranslateAction(...)
    -> showTranslateSheet(...)
      -> TranslateCubit
        -> ContextualTranslationService
        -> PreferencesService
```

The sheet does not create HTTP clients, ML Kit translators, or repositories.
Those are composed in the root app and passed through the action.
Request construction rejects a stale normalized single-word snapshot when the
exact selection has already been expanded to multiple words.

Short words and expressions use `contextual_lookup` so the backend can resolve
their meaning inside the surrounding sentence. Complete sentences, paragraphs,
and long selections use `text_translation`; in that mode the complete selected
range is the translation target and lexical analysis fields are not rendered.
For contextual lookup, the sheet previews the complete source context and
highlights the selected range from the reader's marked-context contract. The
contextual translation remains the primary result, followed by the complete
sentence translation and optional lexical details. Text-translation mode shows
the exact selected source and one complete translation without those duplicate
sections. Single-token lookup results use headline typography; multi-word and
complete-text translations use body typography. The sheet body has a bounded,
scrollable viewport so long contexts and lexical results do not overflow.
