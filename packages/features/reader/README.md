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
    ValueChanged<List<String>>? onSearchHistoryChanged,
    VoidCallback? onSourceOpened,
    void Function(String url, String title)? onArticleTitlePressed,
  });
}
```

`sourceId` resolves first through `BookRepository.getBookById`; when an
`ArticleRepository` is provided, saved articles are loaded as article sources
and opened from `Article.contentHtmlPath`. Internally `ReaderBloc` maps both
books and articles to a source-neutral `ReaderDocument`, so article HTML is not
modeled as an EPUB. `initialSource` lets the route avoid a loading flash
when a book source was already loaded by the previous route. For articles,
`onArticleTitlePressed` lets the composition root open the original article URL
from the top reader chrome without coupling the reader package to
`url_launcher`.

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
| `ReaderBloc`                  | Content: load source document + highlights/bookmarks, debounced position save (500ms) |
| `ReaderUiCubit`               | Chrome, drawer, appearance-sheet and search-highlight UI state             |
| `ReaderSearchCubit`           | Book-search debounce, streamed results, progress and recent queries        |
| `ReaderSelectionCubit`        | Current text selection (text + `cfiRange`)                                 |
| `ReaderImageSelectionCubit`   | Current image-page area selection for comics/fixed-layout pages            |
| `ReaderImageHighlightCubit`   | Persists image-page highlights with optional notes, then `ReaderBloc` refreshes annotations |
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
  Text highlights use CFI annotations; comic/image-page highlights use
  normalized area annotations keyed by page index.
- **`_ReaderArticleHtmlBody`** hosts `ArticleHtmlReaderWebView` for article
  sources. Articles scroll vertically, report progress through stable sentence
  anchors in `content.html`, and expose contents/search/bookmark chrome actions.
  Text/image annotation editing remains on the foliate book/comic path.
- Reader theme (`ReaderThemeData`, font preset, layout preset) is resolved
  from `ReaderAppearanceCubit` and passed as CSS / URL params to the WebView; the
  WebView body itself is rebuilt only on preference changes, never on selection
  or reminder state.

## Dependencies

- `book_repository`, `article_repository`, `highlight_repository` — content,
  bookmark and highlight persistence
- `preferences_service` — global reader appearance, per-source overrides,
  search history, and global reader brightness preference persistence
- `screen_control_service` — content-only keep-awake plus temporary
  application brightness control
- `reader_webview` — `BookReaderWebView`, `ArticleHtmlReaderWebView`,
  `FoliateStyle`, `ReaderHighlight`, `ReaderImageAreaSelection`
- `shared` — `TextAction`, `TextSelectionContext`
- `domain_models` — `Book`, `SourceType`
- `component_library` — `ReaderThemePreset`, `AppIcons`, `AppSpacing`,
  `AppIconSize`
- `flutter_bloc`, `equatable`, `stream_transform`
