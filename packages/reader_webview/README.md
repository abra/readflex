# reader_webview

WebView widget and utilities for the reader. Thin wrapper over
`flutter_inappwebview` that talks to bundled foliate-js running inside the
WebView. Articles are packaged as single-chapter EPUBs at import time
(`article_repository.EpubBuilder`) so they render through the same
foliate-js code path as books.

foliate-js assets are bundled with this package under `assets/foliate-js/`.
At runtime they are extracted to a writable directory where `reader_server`
can serve them over localhost.

## What's included

| Symbol                   | Kind      | Purpose                                                              |
|--------------------------|-----------|----------------------------------------------------------------------|
| `BookReaderWebView`      | Widget    | Loads foliate-js `index.html`, which fetches the book/article EPUB from `/book/<path>`. Emits position, selection, and highlight-tap events; accepts imperative calls (goToCfi, nextPage, changeStyle, addAnnotation). |
| `AssetExtractor`         | Utility   | Copies bundled foliate-js assets from rootBundle to a target directory. Version-gated via an `.asset_version` sentinel: unchanged version skips, changed version re-writes everything. |
| `BookMetadataExtractor`  | Utility   | Spawns a `HeadlessInAppWebView` running foliate-js in import mode to extract `{title, author, description, coverData, coverMimeType}` from any supported format. Used by the import flow. |
| Bridge types             | Models    | `BookPosition`, `ReaderSelection`, `ReaderHighlight`, `FoliateStyle` — DTOs exchanged with JS. |

## JS <-> Flutter bridge

```
JS -> Flutter:  onLoadEnd, onRelocated, onSelectionEnd, onSelectionCleared,
                onAnnotationClick, onClick
Flutter -> JS:  goToCfi, nextPage, prevPage, changeStyle, addAnnotation,
                removeAnnotation
```

Shared selection/click handlers are registered by
`registerSharedReaderHandlers` so the widget body stays focused on
position + annotation glue.

## Dependencies

- `domain_models` — shared reader style and enum types
- `flutter_inappwebview` — underlying WebView
- `path`

The widget is stateless with respect to the reader server: it receives
`serverPort` as a constructor argument. The server itself lives in the
`reader_server` package.
