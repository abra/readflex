# reader

Book reader. Single full-screen route (`/reader/:sourceId`) that hosts the
WebView-based reading surface, bottom action chrome, and a text-selection
context panel populated by pluggable `TextAction`s.

## Public API

```dart
class ReaderScreen extends StatelessWidget {
  ReaderScreen({
    required String sourceId,
    required int serverPort,                       // local reader_server port
    required BookRepository bookRepository,
    ArticleRepository? articleRepository,
    required HighlightRepository highlightRepository,
    required PreferencesService preferencesService,
    required ScreenControlService screenControlService,
    required List<TextAction> textActions,         // plug-in actions
    List<String> initialSearchHistory = const [],
    Book? initialSource,
    SourceType initialSourceType = SourceType.book,
    ValueChanged<List<String>>? onSearchHistoryChanged,
    VoidCallback? onSourceOpened,
  });
}
```

`sourceId` resolves first through `BookRepository.getBookById`; when an
`ArticleRepository` is provided, article sources are converted into reader
books through `ArticleRepository.toReaderBook`. `initialSource` and
`initialSourceType` let the route avoid a loading flash when the source was
already loaded by Library/SourceDetails.

## TextAction plugin system

The reader knows nothing about highlight persistence. Callers assemble a
`List<TextAction>` (from `shared/`) in the composition root (`routing.dart`) and
pass it in. On text selection the context panel renders one `IconButton` per
action. The active implementation is supplied by the `highlight` feature.

```dart
abstract class TextAction {
  String get label;
  IconData get icon;
  Future<void> onExecute(BuildContext context, TextSelectionContext selection);
}
```

## Architecture — independent units of state

| Unit                          | Responsibility                                                             |
|-------------------------------|----------------------------------------------------------------------------|
| `ReaderBloc`                  | Content: load book + highlights/bookmarks, debounced position save (500ms) |
| `ReaderUiCubit`               | Chrome, drawer, appearance-sheet and search-highlight UI state             |
| `ReaderSearchCubit`           | Book-search debounce, streamed results, progress and recent queries        |
| `ReaderSelectionCubit`        | Current text selection (text + `cfiRange`)                                 |
| `ReaderAppearanceCubit`       | Per-source reader appearance overrides over global preferences             |
| `ReaderBrightnessCubit`       | System/custom reader brightness state and active window override lifecycle |

`ReaderBloc.reportError(e, st)` is a public facade over the protected
`addError()` so widgets (e.g. the context panel) can route non-fatal errors
through the bloc's error pipeline without emitting state themselves.

## Widget tree highlights

- **`ReaderKeepAwakeDriver` / `ReaderKeepAwakeScope`** — content-only
  screen-awake owner. It enables keep-awake only while the reader shows bare
  reading content, and releases it when chrome, drawer, bottom sheet, route
  disposal, or app backgrounding takes over.
- **Driver pattern** — stateless widgets (`_ReaderBottomChromeDriver`,
  `_ContextPanelDriver`)
  subscribe to multiple BLoC/Cubit sources via `context.select` and feed
  ready values into dumb leaf widgets (`_ReaderBottomChrome`,
  `_ContextPanel`). All BLoC/Cubit interaction lives in drivers.
- **`_ReaderWebViewBody`** hosts a `BookReaderWebView` (foliate-js) keyed on
  source id / recovery token so source swaps and WebContent recovery rebuild
  the WebView cleanly. It maps domain highlights/bookmarks into WebView
  annotations and sends pull-down bookmark events back to `ReaderBloc`.
- Reader theme (`ReaderThemeData`, font preset, layout preset) is resolved
  from `ReaderAppearanceCubit` and passed as CSS / URL params to the WebView; the
  `_ReaderWebViewBody` itself is rebuilt only on preference changes, never
  on selection or reminder state.

## Dependencies

- `book_repository`, `article_repository`, `highlight_repository` — content,
  bookmark and highlight persistence
- `preferences_service` — global reader appearance, per-source overrides,
  search history, and global reader brightness preference persistence
- `screen_control_service` — content-only keep-awake plus temporary
  application brightness control
- `reader_webview` — `BookReaderWebView`, `FoliateStyle`, `ReaderHighlight`
- `shared` — `TextAction`, `TextSelectionContext`
- `domain_models` — `Book`, `SourceType`
- `component_library` — `ReaderThemePreset`, `AppIcons`, `AppSpacing`,
  `AppIconSize`
- `flutter_bloc`, `equatable`, `stream_transform`
