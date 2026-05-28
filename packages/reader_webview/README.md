# reader_webview

WebView widget and utilities for the reader. Thin wrapper over
`flutter_inappwebview` that talks to bundled foliate-js running inside the
WebView.

foliate-js assets are bundled with this package under `assets/foliate-js/`.
At runtime they are extracted to a writable directory where `reader_server`
can serve them over localhost.

## What's included

| Symbol                   | Kind      | Purpose                                                              |
|--------------------------|-----------|----------------------------------------------------------------------|
| `BookReaderWebView`      | Widget    | Loads foliate-js `index.html`, which fetches the book file from `/book/<path>`. Emits position, selection, search, highlight-tap and bookmark events; accepts imperative calls (goToCfi, pageLeft/pageRight, nextPage, changeStyle, addAnnotation, toggleBookmark). |
| `AssetExtractor`         | Utility   | Copies bundled foliate-js assets from rootBundle to a target directory. Version-gated via app version plus reader asset revision: unchanged version skips, changed version re-writes everything. |
| `BookMetadataExtractor`  | Utility   | Spawns a `HeadlessInAppWebView` running foliate-js in import mode to extract `{title, author, description, coverData, coverMimeType}` from any supported format. Used by the import flow. |
| Bridge types             | Models    | `BookPosition`, `ReaderSelection`, `ReaderHighlight`, `ReaderBookmark`, `ReaderBookmarkChange`, `FoliateStyle` — DTOs exchanged with JS. |

## JS <-> Flutter bridge

```
JS -> Flutter:  onLoadEnd, onRelocated, onSelectionEnd, onSelectionCleared,
                onAnnotationClick, onClick, onSearch, handleBookmark,
                onJsError
Flutter -> JS:  goToCfi, pageLeft, pageRight, nextPage, prevPage,
                changeStyle, addAnnotation,
                removeAnnotation, toggleBookmarkHere, startSearch,
                cancelSearch, clearSearch
```

Shared selection/click handlers are registered by
`registerSharedReaderHandlers` so the widget body stays focused on
position + annotation glue.

## Reader document normalization

Loaded iframe documents are treated as untrusted, publisher-controlled HTML.
`readflex_document_normalizer.js` applies small runtime fixes after foliate-js
loads a section: language/direction metadata is normalized, wide tables are
wrapped in a scroll container, inline images
with text siblings are marked so prose CSS does not treat them as image-only
paragraphs, and code-like blocks get a stable class for reader styling. The
normalizer mutates only the live WebView document; it does not rewrite the
user's original EPUB files or saved article files on disk.

## Dependencies

- `domain_models` — shared reader style and enum types
- `flutter_inappwebview` — underlying WebView
- `path`

The widget is stateless with respect to the reader server: it receives
`serverPort` as a constructor argument. The server itself lives in the
`reader_server` package.
