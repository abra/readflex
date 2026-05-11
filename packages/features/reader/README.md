# reader

Book reader. Single full-screen route (`/reader/:sourceId`) above the shell,
hosts the WebView-based reading surface, top/bottom chrome, a text-selection
context panel populated by pluggable `TextAction`s, and an inline
review-reminder banner.

## Public API

```dart
class ReaderScreen extends StatelessWidget {
  ReaderScreen({
    required String sourceId,
    required int serverPort,                       // local reader_server port
    required BookRepository bookRepository,
    required HighlightRepository highlightRepository,
    required List<TextAction> textActions,         // plug-in actions
    Future<int> Function(String sourceId)? onCheckDueItems,
    void Function(BuildContext, String sourceId)? onStartMiniReview,
  });
}
```

`sourceId` resolves to a `Book` via `BookRepository.getBookById`.

## TextAction plugin system

The reader knows nothing about highlights, flashcards, translations or
dictionaries. Callers assemble a `List<TextAction>` (from `shared/`) in the
composition root (`routing.dart`) and pass it in. On text selection the
context panel renders one `IconButton` per action. Current implementations
are supplied by the `highlight`, `flashcard`, and `translate` features.
Saving translated text to the dictionary happens inside the `translate`
feature; `dictionary` is not a direct reader action.

```dart
abstract class TextAction {
  String get label;
  IconData get icon;
  Future<void> onExecute(BuildContext context, TextSelectionContext selection);
}
```

## Architecture — four independent units of state

| Unit                          | Responsibility                                                             |
|-------------------------------|----------------------------------------------------------------------------|
| `ReaderBloc`                  | Content: load book + highlights, debounced position save (500ms)           |
| `ReaderChromeCubit`           | Top AppBar / bottom progress bar visibility                                |
| `ReaderSelectionCubit`        | Current text selection (text + `cfiRange`)                                 |
| `ReaderReviewReminderCubit`   | Periodic timer; flips `showReminder` when `onCheckDueItems` returns > 0    |

`ReaderBloc.reportError(e, st)` is a public facade over the protected
`addError()` so widgets (e.g. the context panel) can route non-fatal errors
through the bloc's error pipeline without emitting state themselves.

## Widget tree highlights

- **`_ReaderCallbacksScope`** — `InheritedWidget` that carries
  `onCheckDueItems` and `onStartMiniReview` down through 4+ levels without
  prop drilling. Created at the top of `ReaderScreen.build`.
- **Driver pattern** — stateless widgets (`_TopChromeDriver`,
  `_BottomChromeDriver`, `_ContextPanelDriver`, `_ReviewReminderDriver`)
  subscribe to multiple BLoC/Cubit sources via `context.select` and feed
  ready values into dumb leaf widgets (`_ReaderTopChrome`,
  `_ReaderBottomChrome`, `_ContextPanel`, `_ReviewReminderBanner`). All
  BLoC/Cubit interaction lives in drivers.
- **`_ReaderWebViewBody`** hosts a `BookReaderWebView` (foliate-js) keyed on
  source id / recovery token so source swaps and WebContent recovery rebuild
  the WebView cleanly.
- Reader theme (`ReaderThemeData`, font preset, layout preset) is resolved
  from `PreferencesScope` and passed as CSS / URL params to the WebView; the
  `_ReaderWebViewBody` itself is rebuilt only on preference changes, never
  on selection or reminder state.

## Review reminder

Non-intrusive banner at the bottom. `ReaderReviewReminderCubit` runs a
`Timer.periodic` (default 5 min) that invokes `onCheckDueItems(sourceId)`;
when the callback returns > 0 the banner appears. "Review" calls
`onStartMiniReview` (opens an overlay mini-session without leaving the
reader). Dismiss hides until the next positive tick. The reader itself has
zero flashcard/highlight knowledge — both callbacks are injected by the
composition root.

## Dependencies

- `book_repository`, `highlight_repository` — content and highlight
  persistence
- `preferences_service` — `PreferencesScope` for `ReaderAppearance` (theme,
  font, layout presets)
- `reader_webview` — `BookReaderWebView`, `FoliateStyle`, `ReaderHighlight`
- `shared` — `TextAction`, `TextSelectionContext`
- `domain_models` — `Book`, `SourceType`
- `component_library` — `ReaderThemePreset`, `AppIcons`, `AppSpacing`,
  `AppIconSize`
- `flutter_bloc`, `equatable`, `stream_transform`
