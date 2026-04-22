# reader_webview

WebView widgets and utilities for the reader. Thin wrappers over
`flutter_inappwebview` that talk to bundled foliate-js (books) or a small
article reader shell (articles) running inside the WebView.

foliate-js assets are bundled with this package under `assets/foliate-js/`
and the article shell under `assets/article/`. At runtime they are extracted
to a writable directory where `reader_server` can serve them over localhost.

## What's included

| Symbol                   | Kind      | Purpose                                                              |
|--------------------------|-----------|----------------------------------------------------------------------|
| `BookReaderWebView`      | Widget    | Loads foliate-js `index.html`, which fetches the book from `/book/<path>`. Emits position, selection, and highlight-tap events; accepts imperative calls (goToCfi, nextPage, changeStyle, addAnnotation). |
| `ArticleReaderWebView`   | Widget    | Loads the article shell from `/assets/article/`, injects HTML via `initArticle()`. Emits scroll fraction, selection, and tap events; accepts scrollToFraction, changeStyle, renderHighlights. |
| `AssetExtractor`         | Utility   | Copies bundled assets (foliate-js + article shell) from rootBundle to a target directory. Version-gated via an `.asset_version` sentinel: unchanged version skips, changed version re-writes everything. |
| `BookMetadataExtractor`  | Utility   | Spawns a `HeadlessInAppWebView` running foliate-js in import mode to extract `{title, author, description, coverData, coverMimeType}` from any supported format. Used by the import flow. |
| Bridge types             | Models    | `BookPosition`, `ArticlePosition`, `ReaderSelection`, `ReaderHighlight`, `FoliateStyle`, `ReaderStyle` — DTOs exchanged with JS. |

## JS <-> Flutter bridge

Both widgets use named `InAppWebViewController` JavaScript handlers.
Shared handlers (`onSelectionEnd`, `onSelectionCleared`, `onClick`) are
registered by `registerSharedReaderHandlers` to avoid duplication between
the two reader types.

```
JS -> Flutter:  onReady, onRelocated, onSelectionEnd, onSelectionCleared,
                onAnnotationClick / onHighlightTap, onClick
Flutter -> JS:  goToCfi / scrollToFraction, nextPage / prevPage,
                changeStyle, addAnnotation / renderHighlights, removeAnnotation
```

## Dependencies

- `domain_models` — shared reader style and enum types
- `flutter_inappwebview` — underlying WebView
- `path`

The widgets are stateless with respect to the reader server: they receive
`serverPort` as a constructor argument. The server itself lives in the
`reader_server` package.
