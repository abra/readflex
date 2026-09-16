# reader

Full-screen reader for books, comics, and saved articles. The single route
(`/reader/:sourceId`) hosts the WebView-based reading surface, bottom action
chrome, and a text-selection context panel populated by pluggable
`TextAction`s.

## Public API

```dart
class ReaderScreen extends StatelessWidget {
  ReaderScreen({
    required String sourceId,
    required Uri serverBaseUri,                    // token-scoped localhost URI
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
    ValueChanged<String>? onExternalLink,
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
`onExternalLink` separately forwards book links to the app shell's validated
HTTP(S) launcher.

## TextAction plugin system

The reader does not depend on sibling action implementations or translation/
dictionary services. New text-highlight creation is delegated through TextAction;
saved-highlight edits and image highlights use its injected repository.
Callers assemble a `List<TextAction>` (from `shared/`) in the composition root
(`routing.dart`) and pass it in. On text selection the context panel renders
actions in a two-row popup: highlight colors and Highlight are above the
general Copy, Translate, and Define commands. Active feature implementations
are supplied by sibling packages such as `highlight`, `translate`, and
`dictionary`; the UI-only `CopyTextAction` remains in Reader.
The popup captures input only inside its visible controls, leaving the WebView
selection handles interactive so the selected range can be resized in place.
Each action starts resolving the current WebView range on pointer down, before
focus can collapse the native WebKit selection, and awaits that same snapshot
on execution. The reader runtime also retains the latest changed range as a
fallback, so expanding a word into a paragraph cannot send the initial word to
Copy, Translate, Define, or Highlight.
Before Translate or Define presents another surface, the driver dismisses the
selection popup, waits for that frame to finish, and then executes the action
from its stable context. This prevents a context menu from remaining visible
behind a modal or native dictionary surface without losing the captured range.

`ReaderHighlightControls` is a presentation-only leaf: 48px swatches expose
their selected/enabled states, and only the palette scrolls when the popup is
narrow. Save/edit/delete commands stay visible. Its callbacks preserve the
existing preview/explicit-save contract and pointer-down selection capture.
`ReaderSearchResultTile` respects the system text scaler for both its chapter
label and highlighted excerpt, while retaining document direction and the
three-line excerpt limit. Neither leaf owns repositories or WebView lifecycle.

The appearance sheet constrains its scrollable body to the remaining modal
height while keeping the header visible. Narrow large-text layouts stack the
title/reset and setting label/control pairs; numeric fields grow with the text
scaler. Root goldens check portrait, landscape, 2x text, and RTL layouts, including
untruncated setting labels/values and access to the final page-turn control.

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
| `ReaderSearchCubit`           | Document-search debounce, streamed results, progress and recent queries    |
| `ReaderSelectionCubit`        | Current text selection (text + `cfiRange`) and adjustment phase             |
| `ReaderImageSelectionCubit`   | Current image-page area selection for comics/fixed-layout pages            |
| `ReaderImageHighlightCubit`   | Persists image-page highlights with optional notes, then `ReaderBloc` refreshes annotations |
| `ReaderAppearanceCubit`       | Per-source reader appearance overrides over global preferences             |
| `ReaderBrightnessCubit`       | System/custom reader brightness state and active window override lifecycle |

`ReaderSearchCubit` debounces typing by 300ms and batches incoming results and
progress at 16ms intervals. A done event or stream close flushes immediately;
published result lists remain immutable snapshots. Reset, query replacement,
terminal error, and close discard pending updates and reject late events.
Synchronous renderer failures and stream errors become recoverable error state.
Stress tests bound emissions and cumulative published entries for bursts; the
benchmark under `benchmarks/` measures 1k/5k/20k-result workloads separately from
device frame performance. Continuous streams still publish cumulative snapshots,
so the burst benchmark is not a claim of constant work for every stream shape.

`ReaderBloc.reportError(e, st)` is a public facade over the protected
`addError()` so widgets (e.g. the context panel) can route non-fatal errors
through the bloc's error pipeline without emitting state themselves.

Position persistence keeps the 500ms trailing debounce and serializes writes,
including the first immediate article position. Repository partial updates
avoid overwriting metadata from an old snapshot. Source loading preserves live
position/document features; `close()` waits for an already-running write as
well as the latest pending position.

Highlight refresh/delete/color/note events share a separate sequential bucket.
This preserves user edit order without serializing position events behind
storage work. Color/note updates patch only their own SQL fields, and source
reloads do not replace newer annotation state. Mutation success/failure is a
typed `ReaderHighlightEffect`, rendered by `ReaderHighlightEffectListener`
without rebuilding its content child. A queued command alone never produces a
success toast. Selecting a color for a new text selection remains a preview;
the Highlight action still explicitly saves it.

WebView recovery clears stale selection UI and temporarily clears readiness.
`ReaderWebViewFailed` reports terminal failure through the bloc's error pipeline
and switches to the localized failure surface with Retry and Go Back. Retry
recreates the reading surface from the retained document, while a late source
load cannot erase a renderer failure.

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
  anchors in `content.html`, expose contents/search/bookmark chrome actions,
  and render text highlights through stable article anchors. Image-area
  selection remains specific to the foliate comic/fixed-layout path.
- Reader theme (`ReaderThemeData`, font preset, layout preset) is resolved
  from `ReaderAppearanceCubit` and passed as CSS / URL params to the WebView; the
  WebView bodies subscribe to the document, readiness, appearance and annotation
  state they need, not to each selection-menu update. Rebuilding a body does not
  recreate its keyed WebView unless source/recovery identity changes.

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
