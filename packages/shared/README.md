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

| Field          | Type         | Notes                                |
|----------------|--------------|--------------------------------------|
| `selectedText` | `String`     | Text the user highlighted            |
| `sourceId`     | `String`     | Book or article ID                   |
| `sourceType`   | `SourceType` | `book` or `article`                  |
| `cfiRange`     | `String?`    | EPUB CFI range (books only)          |
| `pageNumber`   | `int?`       | Page number if the reader exposed it |
| `scrollOffset` | `double?`    | Scroll offset for articles           |

---

## Example: implementing a TextAction

```dart
// packages/features/highlight/lib/src/highlight_text_action.dart
class HighlightTextAction implements TextAction {
  const HighlightTextAction({required this.highlightRepository});

  final HighlightRepository highlightRepository;

  @override
  String get label => 'Highlight';

  @override
  IconData get icon => Icons.brush_outlined;

  @override
  Future<void> onExecute(
    BuildContext context,
    TextSelectionContext selection,
  ) => showHighlightSheet(context, selection, highlightRepository);
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
