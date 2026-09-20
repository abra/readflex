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
| `AssetExtractor`         | Utility   | Copies book/article reader assets and reading fonts from rootBundle. Version/build plus asset revision controls replacement; matching existing files are skipped and missing files are retried. DEV bootstrap forces extraction. |
| `BookMetadataExtractor`  | Utility   | Spawns a timeout-bounded `HeadlessInAppWebView` running foliate-js in import mode to extract `{title, author, description, coverData, coverMimeType}` from any supported format. Malformed bridge payloads fail promptly; an invalid optional cover does not discard valid metadata. Used by the import flow. |
| Bridge types             | Models    | `BookPosition`, `ReaderSelection`, `ReaderImageAreaSelection`, `ReaderHighlight`, `ReaderBookmark`, `ReaderBookmarkChange`, `FoliateStyle` — DTOs exchanged with JS. |

## JS <-> Flutter bridge

```
JS -> Flutter:  onLoadEnd, onRelocated/onArticlePositionChanged,
                onSelectionEnd, onSelectionInteractionChanged,
                onImageAreaSelected, onSelectionCleared,
                onAnnotationClick, onExternalLink, onClick, onSearch,
                handleBookmark, onReaderLoadFailed, onJsError
Flutter -> JS:  goToCfi, goToBookmark, goToSectionIndex, goToPercent, goToHref,
                pageLeft, pageRight, nextPage, prevPage, changeStyle,
                addAnnotation, removeAnnotation, toggleBookmarkHere,
                startSearch, cancelSearch, clearSearch, setArticleBookmarks,
                getCurrentTextSelection, clearSelection, clearSelectionAfterTextAction,
                showSelectionHighlightPreview, clearSelectionHighlightPreview,
                showImageAreaSelectionPreview, clearImageAreaSelectionPreview
```

Shared selection/click handlers are registered by
`registerSharedReaderHandlers` so the widget body stays focused on
position + annotation glue.

On Android, visible reader WebViews retain Hybrid Composition and the existing
platform-view lifecycle contract. Selection handles are reader-owned (see below);
this change does not also switch composition modes. The reader mirrors app
lifecycle into native `WebView.onPause()` /
`onResume()` calls and serializes transitions. Other platforms keep their native
lifecycle behavior. Hybrid Composition trades Flutter compositing performance
for native-view fidelity; actual foreground/background and frame-time checks on
physical devices remain release gates.

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

### Book Fonts

Reading presets use the selected family first, then the bundled Noto Sans
Symbols for missing glyphs such as U+267E (permanent paper sign). `AssetExtractor`
copies the same font used by Flutter into the local reader-server assets;
Flutter's font registry is not visible to the WebView. Each reflowable chapter
declares the fallback with an absolute local URL, because chapter documents use
blob URLs. The browser fetches it only when needed; there is no remote font
service, eager preload, text-node rewrite or per-character scan.

`overrideFont: false` and the `book` preset retain publisher families. The reader
feature's code overlay retains its monospace families first and adds the same
symbol fallback last. Fixed-layout documents are not replaced. This is supplemental
symbol coverage, not complete Unicode or emoji support. Browser tests verify
actual font pixels, all reading presets, lazy loading and selection/CFI stability.

### Book Colors

For reflowable books, `FoliateStyle.overrideColor` replaces publisher text and
solid background colors **together**: the document uses the reader palette,
text descendants inherit their semantic parent's color, and publisher block
fills become transparent. Borders use `currentColor`. This prevents reader-dark
text from landing on a publisher-dark caption background in a light theme.
The low-specificity reset runs before `customCSS`, so reader code panels, quotes
and accent links can retain their own styling. SVG/MathML, images and embedded
media are excluded; fixed-layout books do not receive this reset.

`readflex_contrast_guard.js` is a fallback for surviving priority styles, such
as inline `!important` text/backgrounds. On document load and CSS updates it
checks direct text against composed solid ancestor backgrounds in light and
dark themes. Background results are cached for that pass; there is no scroll
listener, polling or text-node rewrite. It restores its inline overrides before
rechecking and when `overrideColor` is disabled. Fixed-layout books are excluded.
Background images/gradients and image pixels are not analyzed or recolored, so
this is not a guarantee of contrast for text over arbitrary artwork.
`customCSS` remains an independent overlay even with `overrideColor: false`.

`test_browser/book_theme_colors.test.mjs` exercises the production EPUB loader
and styling in Chromium/WebKit: nested publisher blocks, tables, semantic
overrides, inline priority, fixed layout, and selection/CFI stability on theme
changes. The guard's unit tests also bound repeated ancestor style reads.

### Text Selection

On touch devices the native DOM selection remains active while the reader
popup is visible. This keeps selection controls available and lets
`selectionchange` update the popup payload as the user expands or contracts the
range. The range is cleared only after an action completes or the selection is
dismissed; iOS system edit-menu suppression is handled by the vendored
`flutter_inappwebview_ios` patch. On Android the vendored
`flutter_inappwebview_android` patch clears system action-menu items without
finishing `ActionMode`, which would also hide native selection handles. Visible
readers additionally opt into `useCustomSelectionHandles`: Android recognizes
long press, consumes the native selection UI, and sends normalized viewport
coordinates to `readflex_selection_start.js`. Browser word-boundary operations
create the DOM range, including words spanning inline elements. Non-reader
WebViews default to native handling. See
[`README.readflex.md`](../../third_party/flutter_inappwebview_android/README.readflex.md)
for native callback tests and update requirements.
The JS runtime snapshots every changed DOM range. For books, the snapshot is
revisioned per iframe so `currentTextSelection()` reads only the document the
user most recently selected in instead of an older range from a neighboring
page. The live range is preferred; the snapshot remains available if WebKit
collapses the native selection while focus moves to the Flutter action popup.

Selecting inside or across a saved text highlight never opens its edit menu or
clears the native range. Only an ordinary tap without an active text selection
opens the saved-highlight editor. Books and articles report fully contained
highlight IDs (including equal ranges) using DOM boundaries, not rectangle hit
tests; partial intersections and adjacent highlights are excluded. Articles
reuse their rendered ranges. No highlight is deleted by selecting, previewing,
translating or cancelling; replacement occurs only on explicit Highlight save.
Browser tests exercise both touch event paths, both book pagination axes,
forward/backward range changes, inline nodes, repeated occurrences and tap editing.

EPUB TOC navigation preserves publisher fragment IDs. When an element anchor
has no layout boxes (for example a hidden empty span inside a heading), the
paginator looks for nearby rendered content, forwards first and backwards at
the document end. The fallback visits at most 128 DOM nodes per direction,
only on the exceptional navigation path; normal element and CFI-range targets
keep their existing rectangle path. No publisher DOM or saved CFI is rewritten.
`test_browser/epub_toc_navigation.test.mjs` covers same/cross-chapter navigation,
hidden inline/standalone/end markers, named anchors and `display: contents`
in horizontal/vertical pagination and continuous scrolling.
Chapter links without fragments target the body's first layout box instead
of a numeric zero offset, avoiding empty leading columns from publisher
margins without changing the book's layout or fractional progress navigation.

Book text-action context is extracted by `readflex_selection_context.js` from
the actual DOM range. `Intl.Segmenter` finds the containing sentence (or the
sentences touched by a larger selection) within the nearest text block, across
inline tags. Marked and plain context use the same source text and preserve
the selected occurrence, punctuation and word adjacency. Publisher formatting
whitespace is collapsed before segmentation; source line wraps are not treated
as sentence boundaries. Extraction does not mutate DOM, selection handles or
CFI anchors, and does not read layout metrics.

Surrounding collection is capped at 2048 UTF-16 code units and 256 traversal
steps per side; selections above 4096 units bypass sentence segmentation.
It starts at the selected range, not the beginning of a chapter. Cross-block
selections, unavailable `Intl.Segmenter`, or sentence boundaries outside the
budget fall back to selected text only, never an arbitrarily clipped prefix.
Exact and normalized selections reuse context when their boundaries agree.
JS tests cover generated repeated-word occurrences and multilingual boundaries;
Chromium/WebKit tests cover markup invariance, element offsets, CFI round trips,
DOM/selection preservation and bounded work on very large blocks.

For reflowable books, a touch gesture that starts or acquires a DOM selection
belongs to selection until release/cancel, even if the range briefly collapses.
The paginator reads selection from its own iframe, skips ordinary swipe/snap
handling and cancels vertical drag previews/release animations. `Vertical` is
paginated layout with vertical page animation, not continuous `Scroll`.
`readflex_selection_navigation.js` keeps handle adjustment separate from page
navigation. Hold/release at an edge does not turn. A separate swipe or edge tap
(including the page margins) turns exactly one page, preserving the fixed DOM
boundary and placing the moving endpoint one visible grapheme into the incoming
page. Reverse navigation shrinks the range and can cross the fixed endpoint;
grabbing the other handle changes which endpoint is fixed. Cancelled gestures
do not turn, and pending navigation cannot overwrite a newer selection.
The paginator's existing scroll listener blocks native auto-scroll of paginated
selected text, including Chromium's scrolling of overflow:hidden containers.
There is no per-selection scroll listener or periodic polling. Continuous
Scroll is unaffected. A native Range cannot span different spine documents:
continuation stops at the current chapter boundary without unloading it.

On iOS visible text endpoints use native handles; offscreen article endpoints
can use the temporary continuation controls described below.
On Android `readflex_selection_handles.js` owns
the controls from the initial word selection through extension and page
continuation, including continuous-scroll and text-bearing fixed layouts.
There is no handoff between OEM and reader handle shapes. Their 48px touch targets,
localized labels and keyboard arrows operate on the same DOM selection. Controls
are removed on document disposal and hidden on cancellation/layout changes.
Android controls are restored on focus/visibility return and after resize if
the active document still has a selection. This does not recreate a cleared range.
Pointer work is coalesced per animation frame. Geometry reads only endpoints;
page-boundary traversal is bounded. `onSelectionInteractionChanged` hides the
Flutter action menu during adjustment, then a 160ms settle publishes the latest
text/CFI. Trace-disabled handle updates do not serialize the selected text.
Settled/action reads preserve native paragraph breaks and cache them for focus
loss when the Flutter popup opens.

On iOS and Android, an active native text range is the only temporary selection tint. The
popup's SVG color preview is suppressed while native selection exists and is
removed if native selection returns. Color swatches still choose the saved
highlight color; fallback previews remain available without a native range.
Saved highlights are not removed by selection-preview cleanup.

`RemoteFile` bounds its LRU by 128 entries and 8 MiB of retained bytes, including
larger ZIP chunks. An oversized read bypasses cache admission without flushing
recent chunks. Neighbour probes and identical in-flight ranges still share
bytes/requests. The limit excludes returned slice copies, in-flight buffers,
decompressed content and decoded images; it is not a total reader memory limit.

`ArticleHtmlReaderWebView` reports scroll progress through sentence anchors,
table of contents from headings, document features, clicks, search batches,
bookmark changes, text selections, and highlight taps. It also renders and
updates article text highlights through stable article anchors.
CSS Custom Highlights is preferred. Older WebViews use the existing SVG
`Overlayer` implementation without wrapping or changing text nodes. Fallback
redraws are coalesced on layout/font/image changes; scrolling needs no redraw.
On both iOS and Android, articles suppress the temporary color preview while a
native text selection exists. A fallback preview is removed when the native
range returns, without clearing selection, mutating text or rebuilding saved
highlights. Preview styles are separate from persisted annotation styles.
Palette swatches choose the color for explicit Highlight save; they do not tint
the native selection a second time.

Continuous articles use `readflex_article_selection.js` to hold the viewport
still during handle adjustment. Release the handle, scroll with a
separate content swipe, then adjust again. Ordinary touch/wheel/keyboard
scrolling and explicit navigation preserve the range. A range change revokes
the scrolling permission; focus loss cannot leave a stale bypass behind.

The Android article controller retains its layout guard against selection-driven
scrolling: it temporarily pins the article container and preserves document
height while an endpoint is visible or a control is being dragged. A
separate content gesture unpins it before scrolling; with both endpoints
offscreen it stays unpinned so subsequent swipes can latch normally. Original
inline styles are restored on clear, cancellation and disposal. No text nodes
are moved, and styles are not rewritten on every range update. iOS does not
use this Android-specific layout guard.

An offscreen endpoint has a temporary edge continuation control. Grabbing it
alone does not change the range; dragging moves that endpoint and preserves
the opposite DOM boundary, including when direction reverses or boundaries
cross. When both endpoints are offscreen on the same side, only the nearer
one is exposed. iOS returns to native handles when the endpoint is visible;
Android keeps the same reader controls both onscreen and at the edge. Moving
or scrolling an endpoint offscreen never transfers ownership to a native handle
or resets the opposite boundary. Android content gestures do not use the native
handle-distance heuristic; only the actual control owns a handle drag.
The shared shadow host is named so the app's empty-content CSS does not hide
its controls; it has no light-DOM text content by design.
Touch targets respect host-provided and CSS environment safe-area insets.

Selection text/context is published after a 160ms settle or read live for an
explicit action, never serialized on every handle movement. Endpoint geometry
is bounded; control motion is coalesced per frame. Scroll interception uses a
passive listener, not polling. Adjustment hides the Flutter action menu without
disposing its state. Continuation controls capture the fixed boundary on press
but notify adjustment on movement: hiding the overlay during pointerdown can
interrupt Android hybrid-composition input. Cancellation/disposal remove
pending work and controls.
Browser tests cover both directions, reversal/crossing, safe areas, focus loss,
explicit navigation, gesture cancellation, disposal and deferred serialization.
They also cover repeated scrolling, redundant selection events, layout/style
restoration, repeated upward/downward continuation, the app's empty-content
normalization and the absence of per-update style mutations. Native gesture
probes supplement, but do not replace, real-device testing of the full app,
including the Flutter action menu's visibility transitions.

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
paragraphs, and code-like blocks get a stable class for reader styling. Publisher
class/ID hints for annotations, captions, callouts, descriptions, explanations
and titles exclude prose from code detection, including camel-case names.
Otherwise, long code annotations would accidentally inherit a code panel and
monospace typography while short annotations remained prose. Semantic `pre`
content and separately nested code blocks keep their code treatment. The
normalizer mutates only the live WebView document; it does not rewrite the
user's original EPUB files or saved article files on disk.

Table scroll wrappers keep their overflow even when they are a section's only
`div`; the generic publisher-container overflow reset must not target
`.readflex-wide-table`. Width and word-wrapping policy is supplied by
`reader`'s `buildBookCustomCSS`. The existing gesture guard keeps horizontal
table gestures out of page-turn handling, and `cfi-skip` keeps wrapping out of
saved text positions. Do not add per-scroll DOM rewriting or layout observers
to enforce table widths.

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
Book selection regressions load the actual `book.js` runtime and EPUB directory
loader (with fixture transport) as well as the standalone paginator. They cover
unwanted delayed page turns, iframe gesture ownership, cancelled gestures and
release animations, both moving endpoints, reverse/crossing navigation, page
margin taps, Android continuation controls, text serialization bounds, backward
range/CFI round trips and iOS/Android preview suppression. Initial Android
selection tests cover the normalized native gesture bridge, browser word
boundaries across inline nodes, RTL/CJK/Cyrillic and supplementary Unicode
letters, fixed layouts, and handle restoration after focus loss.
Synthetic touch events and the iOS user-agent branch test the JS contracts,
not the operating system's selection handles or native tint rendering.
Desktop Playwright WebKit with feature detection disabled is not an actual old
iOS device; neither browser tests nor fake platform callbacks replace native
device smoke tests.

The root `make test-device DEVICE=<id>` suite also exercises actual native
WebViews through the production router, local reader server, and isolated
repositories. It verifies expanded book/article selections reaching Translate,
Define fallback, clipboard, menu dismissal, multi-page continuation in both
directions/axes with menu hide/reanchor, handle clearance, retained color and
complete translation payloads, persisted highlight geometry after reopening,
and synthetic lifecycle callbacks. `debugController` and
`debugIsReady` on both WebView states are read-only `@visibleForTesting` accessors
for readiness and the existing JS bridge; they add no runtime polling or
listeners. The suite sets DOM ranges, not native selection handles, and its
lifecycle events do not background the actual OS application. See the root
[`test/ui/README.md`](../../test/ui/README.md) for device artifacts and gaps.
Android screenshots use the test driver's ADB capture, not
`convertFlutterSurfaceToImage()`: the latter competes for the image frame used
by Hybrid Composition and can leave the SDK screenshot future waiting forever.
The transport is test-only, loopback-bound, restricted to the selected device
and closed after the driver completes; it adds nothing to the normal app.

Selection device smoke checks (iOS and Android): open a reflowable book in
`Vertical`, long-press a word, drag either handle to the top/bottom edge and
reverse direction, then release and wait at least two seconds. Check that the
page remains still. Swipe/tap once, verify exactly one complete page advances,
and physically re-grab the incoming handle. Test a fresh left-handle selection
backwards as well as right-handle forwards; return and cross the initial point.
Check that Copy/Translate/Highlight use the complete final range. Deselect and
swipe both ways to verify normal page turns. On iOS check that native selection
has no extra yellow/pink preview
layer and that saving a highlight still applies the chosen color. Also verify
continuous `Scroll` and horizontal `Slide`; selection across actual device page
boundaries still requires this native check, beyond the DOM/CFI tests.
In a long article, drag from mid-screen to each edge, hold, then reverse.
The viewport must stay still while dragging. Release, scroll separately and
re-grab either handle; verify both boundaries and the final action text.
Sparse synthetic MOVE events are not equivalent to a physical high-frequency
handle drag. On Android check that the same Readflex controls appear from the
initial long press, without a second OEM pair or a transient change of shape.
Reader-owned Android controls use the system `Magnifier` on API 28+ while
dragging. The shared handle controller sends the moving text boundary, not the
knob position, through a numeric-only private JS-to-Java bridge. Movement is
batched with `requestAnimationFrame`; no Dart callbacks, widget rebuilds, text
serialization or document-wide scans are added to the drag path. Android
coalesces native updates and rejects requests outside an active physical touch.
The magnifier is dismissed on release/cancellation, selection cleanup, loss of
window focus, pause, detachment and disposal. API 24-27 keep working handles
without a magnifier. iOS retains native handles and magnification.
While a reader handle is captured, the book/article controller also rejects a
new native long-press selection. A delayed Android MOVE must not let the
long-click timer replace the active range with a new word.

During device checks, inspect the magnified text while dragging both endpoints,
including after a page turn, and check that no loupe remains after release or
background/foreground. Android 29+ uses a compact rounded aperture; Android 28
uses the platform's legacy magnifier appearance. This enhancement does not
restore Chromium's native selection handles after programmatic range changes.
Also check TalkBack/VoiceOver separately;
localized labels and keyboard tests do not certify screen-reader usability.
Flutter's Texture Layer Hybrid Composition has a
[documented magnifier limitation](https://docs.flutter.dev/platform-integration/android/platform-views#texture-layer).
The reader retains native Hybrid Composition for platform-view fidelity. Repeat
performance and actual background/foreground checks on the affected device
when changing this setting or updating Flutter/WebView.

DOMPurify is pinned and vendored without edits. See
`assets/foliate-js/src/vendor/DOMPurify-README.md` for provenance and updates.
