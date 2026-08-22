# shared

Cross-feature contracts. Currently hosts the `TextAction` plugin contract
that lets the reader surface Highlight, Translate, and Define without knowing
anything about their persistence or service implementations.

This is the only contract package in the project that depends on Flutter —
`TextAction.icon` is an `IconData`, and actions are executed with a
`BuildContext`.

---

## Public API

| Symbol                 | Kind           | Purpose                                                         |
|------------------------|----------------|-----------------------------------------------------------------|
| `TextAction`                | abstract class | Contract implemented by features that appear in the reader menu |
| `ColorHighlightTextAction`  | abstract class | Highlight action contract with caller-selected color            |
| `TextSelectionContext`      | data class     | Payload passed to an action when the user selects text           |

### TextAction

```dart
abstract class TextAction {
  String get label;
  String labelFor(BuildContext context) => label;
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
| `compatibleNormalizedSelectedText`| `String?`    | Normalized text only when it contains the exact range |
| `effectiveSelectedText`           | `String`     | Compatible normalized text, otherwise exact     |
| `effectiveMarkedContextText`      | `String?`    | Matching normalized marked context when valid   |
| `sourceLanguageHint`              | `String?`    | Best-known document language hint for actions   |
| `sourceId`                        | `String`     | Source ID                                       |
| `sourceType`                      | `SourceType` | Book or article; comics are book sources        |
| `cfiRange`                        | `String?`    | Reader anchor for the exact selection           |
| `normalizedCfiRange`              | `String?`    | Reader anchor for the normalized selection      |
| `pageNumber`                      | `int?`       | Legacy optional page position                   |
| `scrollOffset`                    | `double?`    | Legacy optional scroll position                 |
| `progress`                        | `double?`    | Normalized source progress at selection time    |
| `chapterTitle`                    | `String?`    | Visible chapter title at selection time         |
| `containedHighlightIds`           | `List<String>` | Existing highlights contained by the selection |

---

## Example: implementing a TextAction

```dart
// packages/features/highlight/lib/src/highlight_action.dart
class HighlightAction extends ColorHighlightTextAction {
  const HighlightAction({
    required this.highlightRepository,
  });

  final HighlightRepository highlightRepository;

  @override
  String get label => 'Highlight';

  @override
  String labelFor(BuildContext context) => context.l10n.highlightAction;

  @override
  IconData get icon => AppIcons.highlight;

  @override
  Future<void> onExecute(
    BuildContext context,
    TextSelectionContext selection,
  ) => onExecuteWithColor(context, selection, HighlightColor.yellow);

  @override
  Future<void> onExecuteWithColor(
    BuildContext context,
    TextSelectionContext selection,
    HighlightColor color,
  ) => highlightRepository.addHighlight(/* selection anchor + color */);
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
features/translate    → shared   (implements TextAction)
features/dictionary   → shared   (implements TextAction)
```

---

## Rules

- Only cross-feature contracts live here. Models go in `domain_models`.
- Keep the surface tiny. Anything used by a single feature stays inside
  that feature.
- Flutter is allowed here because contracts may reference UI types
  (`IconData`, `BuildContext`). Do not add UI widgets or business logic.
