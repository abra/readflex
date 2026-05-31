# shared

Cross-feature contracts. Currently hosts the `TextAction` plugin contract
that lets the reader surface buttons from other features (highlight,
flashcard, translate) without knowing anything about them.

This is the only contract package in the project that depends on Flutter —
`TextAction.icon` is an `IconData`, and actions are executed with a
`BuildContext`.

---

## Public API

| Symbol                 | Kind           | Purpose                                                         |
|------------------------|----------------|-----------------------------------------------------------------|
| `TextAction`           | abstract class | Contract implemented by features that appear in the reader menu |
| `TextSelectionContext` | data class     | Payload passed to an action when the user selects text          |

### TextAction

```dart
abstract class TextAction {
  String get label;
  IconData get icon;
  Future<void> onExecute(BuildContext context, TextSelectionContext selection);
}
```

### TextSelectionContext

| Field / getter                    | Type         | Notes                                           |
|-----------------------------------|--------------|-------------------------------------------------|
| `selectedText`                    | `String`     | Exact text the user highlighted                 |
| `normalizedSelectedText`          | `String?`    | Selection expanded to complete lexical tokens   |
| `selectionKind`                   | `String?`    | Reader-side shape: `exact`, `partial_word`, etc |
| `contextText`                     | `String?`    | Plain surrounding reader context                |
| `markedContextText`               | `String?`    | Context with the exact selection marked         |
| `normalizedMarkedContextText`     | `String?`    | Context with the normalized selection marked    |
| `textForTranslation`              | `String`     | Normalized text when present, otherwise exact   |
| `markedContextTextForTranslation` | `String?`    | Normalized marked context when present          |
| `sourceId`                        | `String`     | Source ID                                       |
| `sourceType`                      | `SourceType` | Book, article, comic, etc.                      |
| `cfiRange`                        | `String?`    | EPUB CFI range                                  |
| `pageNumber`                      | `int?`       | Legacy optional page position                   |
| `scrollOffset`                    | `double?`    | Legacy optional scroll position                 |

---

## Example: implementing a TextAction

```dart
// packages/features/highlight/lib/src/highlight_action.dart
class HighlightAction extends TextAction {
  const HighlightAction({
    required this.highlightRepository,
    required this.fsrsRepository,
  });

  final HighlightRepository highlightRepository;
  final FsrsRepository fsrsRepository;

  @override
  String get label => 'Highlight';

  @override
  IconData get icon => AppIcons.highlight;

  @override
  Future<void> onExecute(
    BuildContext context,
    TextSelectionContext selection,
  ) => showHighlightSheet(
    context,
    highlightRepository: highlightRepository,
    fsrsRepository: fsrsRepository,
    selection: selection,
  );
}
```

Actions are assembled once in `lib/app/routing.dart` and passed into
`ReaderScreen(textActions: [...])`. The reader builds its context panel
purely from the list — it never imports a feature package.

---

## Where it fits

```
shared → domain_models, flutter (widgets)
features/reader       → shared   (consumes TextAction list)
features/highlight    → shared   (implements TextAction)
features/flashcard    → shared   (implements TextAction)
features/translate    → shared   (implements TextAction)
```

---

## Rules

- Only cross-feature contracts live here. Models go in `domain_models`.
- Keep the surface tiny. Anything used by a single feature stays inside
  that feature.
- Flutter is allowed here because contracts may reference UI types
  (`IconData`, `BuildContext`). Do not add UI widgets or business logic.
