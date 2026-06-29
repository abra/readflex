# reader_webview

WebView widgets and utilities for the reader. Thin wrappers over
`flutter_inappwebview` that talk to bundled reader HTML/JS running inside the
WebView.

foliate-js assets are bundled with this package under `assets/foliate-js/`.
The vertical article reader shell lives under `assets/article-html/`. At runtime
both asset families are extracted to a writable directory where `reader_server`
can serve them over localhost.

## What's included

| Symbol                   | Kind      | Purpose                                                              |
|--------------------------|-----------|----------------------------------------------------------------------|
| `BookReaderWebView`      | Widget    | Loads foliate-js `index.html`, which fetches the book file from `/book/<path>`. Emits position, selection, search, highlight-tap and bookmark events; accepts imperative calls (goToCfi, pageLeft/pageRight, nextPage, changeStyle, addAnnotation, toggleBookmark). |
| `ArticleHtmlReaderWebView` | Widget  | Loads the vertical article shell, fetches saved `content.html` from `/article/<dir>/content.html`, emits progress/TOC/document-feature/search/bookmark events, and accepts `goToPercent`, `goToHref`, `goToCfi`, `changeStyle`, `startSearch`, `cancelSearch`, `clearSearch`, `toggleBookmarkHere`, and `setArticleBookmarks`. |
| `AssetExtractor`         | Utility   | Copies bundled foliate-js assets from rootBundle to a target directory. Version-gated via app version plus reader asset revision: unchanged version skips, changed version re-writes everything. |
| `BookMetadataExtractor`  | Utility   | Spawns a `HeadlessInAppWebView` running foliate-js in import mode to extract `{title, author, description, coverData, coverMimeType}` from any supported format. Used by the import flow. |
| Bridge types             | Models    | `BookPosition`, `ReaderSelection`, `ReaderImageAreaSelection`, `ReaderHighlight`, `ReaderBookmark`, `ReaderBookmarkChange`, `FoliateStyle` — DTOs exchanged with JS. |

## JS <-> Flutter bridge

```
JS -> Flutter:  onLoadEnd, onRelocated/onArticlePositionChanged,
                onSelectionEnd, onImageAreaSelected, onSelectionCleared,
                onAnnotationClick, onClick, onSearch, handleBookmark, onJsError
Flutter -> JS:  goToCfi, goToBookmark, goToSectionIndex, goToPercent, goToHref,
                pageLeft, pageRight, nextPage, prevPage, changeStyle,
                addAnnotation, removeAnnotation, toggleBookmarkHere,
                startSearch, cancelSearch, clearSearch, setArticleBookmarks,
                showImageAreaSelectionPreview, clearImageAreaSelectionPreview
```

Shared selection/click handlers are registered by
`registerSharedReaderHandlers` so the widget body stays focused on
position + annotation glue.

`ArticleHtmlReaderWebView` reports scroll progress through sentence anchors,
table of contents from headings, document features, clicks, search batches, and
bookmark changes. Text selection and highlight annotation mutation remain
foliate-only until the article HTML surface gets equivalent contracts.

`onSelectionEnd` carries both the exact selected text and, when the user
selects only part of a word/span, a lexical `normalizedText` expanded to
complete word boundaries. Text actions can preserve the exact selection for
highlights while using the normalized fields for future lexical actions.

`onImageAreaSelected` is the image-page counterpart used by comics/fixed-layout
pages. It carries a zero-based page index, a normalized rectangle relative to
the visible page image, and a viewport position for the floating highlight menu.

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
