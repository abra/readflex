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
| `BookMetadataExtractor`  | Utility   | Spawns a timeout-bounded `HeadlessInAppWebView` running foliate-js in import mode to extract `{title, author, description, coverData, coverMimeType}` from any supported format. Malformed bridge payloads fail promptly; an invalid optional cover does not discard valid metadata. Used by the import flow. |
| Bridge types             | Models    | `BookPosition`, `ReaderSelection`, `ReaderImageAreaSelection`, `ReaderHighlight`, `ReaderBookmark`, `ReaderBookmarkChange`, `FoliateStyle` — DTOs exchanged with JS. |

## JS <-> Flutter bridge

```
JS -> Flutter:  onLoadEnd, onRelocated/onArticlePositionChanged,
                onSelectionEnd, onImageAreaSelected, onSelectionCleared,
                onAnnotationClick, onExternalLink, onClick, onSearch,
                handleBookmark, onReaderLoadFailed, onJsError
Flutter -> JS:  goToCfi, goToBookmark, goToSectionIndex, goToPercent, goToHref,
                pageLeft, pageRight, nextPage, prevPage, changeStyle,
                addAnnotation, removeAnnotation, toggleBookmarkHere,
                startSearch, cancelSearch, clearSearch, setArticleBookmarks,
                showImageAreaSelectionPreview, clearImageAreaSelectionPreview
```

Shared selection/click handlers are registered by
`registerSharedReaderHandlers` so the widget body stays focused on
position + annotation glue.

On Android, visible reader WebViews use Texture Layer Hybrid Composition and
mirror the app lifecycle into native `WebView.onPause()` / `onResume()` calls.
This keeps the platform view attached to the current Flutter surface after the
app moves between the foreground and background. Other platforms keep their
native lifecycle behavior.

Both visible readers enable Android `onRenderProcessGone` and handle iOS
`onWebContentProcessDidTerminate`. A terminated renderer is replaced with a new
native WebView, never reused. Recovery retains the latest position and current
appearance/annotations; callbacks from the old controller are ignored. There
is at most one automatic recovery per mounted reader. A second termination,
main-frame load error, JS document-load failure, or 60-second bootstrap timeout
calls `onLoadFailed(ReaderLoadFailure)`. `onLoading` clears feature readiness
during recovery; `onReady` completes it. The existing iOS deep-CFI startup
workaround still restores by progress after an initial pagination crash.
Metadata extraction treats renderer termination as an import error and disposes
the headless WebView.

This recovery addresses WebView renderer termination, not arbitrary Flutter
engine/Impeller EGL failures. Device lifecycle and renderer-crash checks are
still required before release.

EPUB link events cross the bridge as the destination URL only. The reader
feature forwards that value through its callback boundary, and app routing
opens only validated HTTP(S) links with the platform URL launcher.

On touch devices the native DOM selection remains active while the reader
popup is visible. This keeps the platform drag handles available and lets
`selectionchange` update the popup payload as the user expands or contracts the
range. The range is cleared only after an action completes or the selection is
dismissed; iOS system edit-menu suppression is handled by the vendored
`flutter_inappwebview_ios` patch.
The JS runtime snapshots every changed DOM range. For books, the snapshot is
revisioned per iframe so `currentTextSelection()` reads only the document the
user most recently selected in instead of an older range from a neighboring
page. The live range is preferred; the snapshot remains available if WebKit
collapses the native selection while focus moves to the Flutter action popup.

`ArticleHtmlReaderWebView` reports scroll progress through sentence anchors,
table of contents from headings, document features, clicks, search batches,
bookmark changes, text selections, and highlight taps. It also renders and
updates article text highlights through stable article anchors.
CSS Custom Highlights is preferred. Older WebViews use the existing SVG
`Overlayer` implementation without wrapping or changing text nodes. Fallback
redraws are coalesced on layout/font/image changes; scrolling needs no redraw.

`onSelectionEnd` carries both the exact selected text and, when the user
selects only part of a word/span, a lexical `normalizedText` expanded to
complete word boundaries. Text actions can preserve the exact selection for
highlights while Translate and Define use the normalized lexical fields.

`onImageAreaSelected` is the image-page counterpart used by comics/fixed-layout
pages. It carries a zero-based page index, a normalized rectangle relative to
the visible page image, and a viewport position for the floating highlight menu.

## Reader document normalization

Before rendering, `readflex_content_security.js` sanitizes publisher EPUB
documents with vendored DOMPurify when `allowScript` is false. This removes
scripts, event attributes, unsafe URLs and active embeds before section Blob
creation. A section CSP also disables script execution. The trusted parent
reader retains DOM access for pagination, selection and CFI annotations.
CSS, ordinary document structure and inline SVG remain supported. This is
not a blanket offline/network policy for all EPUB resources.

The article shell sanitizes saved fragments before DOM insertion and permits
only repository-generated `images/<filename>.<image-extension>` image paths.
This also protects articles imported by older versions; remote images that
were not saved locally remain inactive. Tables, code and sentence anchors are
preserved. Updating bundled security assets requires an `assetRevision` bump.

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

The widgets are stateless with respect to the reader server: they receive its
token-scoped `serverBaseUri` as an immutable constructor argument. The server
itself and its filesystem access policy remain in the `reader_server` package.

## Browser verification

From the repository root, run `make reader-browser-setup` to install the pinned
npm dependencies and Playwright Chromium/WebKit (Node.js 20+ required). On
Linux, Playwright may additionally require `npx playwright install-deps chromium
webkit` from this package directory, using the host's package manager.

`make test` includes the browser suites and fails if prerequisites are missing.
For a focused run in this package:

```sh
npm run test:browser
READER_BROWSER=webkit npm run test:browser
```

Tests exercise actual EPUB fixed/reflow loaders and the article shell, including
malicious markup, preserved styles/CFIs, image policy, load errors and fallback
highlight geometry/pixel changes at desktop and mobile sizes. Flutter tests
use the plugin platform interface to simulate renderer death and late callbacks.
Desktop Playwright WebKit with feature detection disabled is not an actual old
iOS device; neither browser tests nor fake platform callbacks replace native
device smoke tests.

DOMPurify is pinned and vendored without edits. See
`assets/foliate-js/src/vendor/DOMPurify-README.md` for provenance and updates.
