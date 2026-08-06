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
