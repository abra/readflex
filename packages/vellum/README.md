# vellum

The native reader engine: the Flutter/Dart analogue of foliate-js. One
package opens a book file, understands its format, lays its pages out and
draws them, and reports positions, selections and taps back. The app embeds
`VellumView` where it embeds the WebView today; `vellum` knows nothing about
the app's domain models, repositories or blocs.

Plan and progress: `.local/reports/native-reader-steps-2026-10-27.md`.

## Modules

Each foliate-js module has one Dart counterpart with the same
responsibility, so parity can be checked module by module.

| foliate-js | vellum | Responsibility |
|---|---|---|
| `vendor/zip.js` | `src/container/zip_archive.dart` | ZIP read in place: central directory once, entries on demand; ZIP64; stored and deflate |
| `comic-book.js` | `src/formats/comic_book.dart`, `comic_page_order.dart` | CBZ pages in the reader's order (`pageOrderVersion`), cover, title |
| (browser `naturalWidth`) | `src/image/image_dimensions.dart` | image size from PNG/JPEG/GIF/BMP/WebP headers, EXIF-rotated, without decoding |
| `readflex_page_content.js`, `readflex_page_geometry.js`, `readflex_page_colors.js` | `src/image/page_content.dart`, `src/fixed_layout/pdf_page_content.dart`, `src/fixed_layout/page_colors.dart` | ink box of a page sample, margin crop, theme colours for image pages |
| `pdf.js` (pdf.js) | `src/formats/pdf_book.dart`, `src/pdf/`, `src/fixed_layout/pdf_page_image.dart` | `PdfBook` over pdfium (`pdfrx_engine`): page sizes, outline, Info dictionary, password; `PdfPageImage`/`PdfPageTile`/`PdfPageThumbnail`; `initializePdfEngine` |
| `epub.js`, `fb2.js`, `mobi.js` | `src/formats/` | sections, table of contents, metadata, `resolveHref` |
| `getMetadata` in `book.js` | `src/metadata/` | `BookMetadata` for the library's import: title, author, cover as a small JPEG (`readComicMetadata`, `encodeCoverThumbnail`) |
| `epubcfi.js` | `src/epubcfi/` | CFI parse, range ↔ CFI, compare, fake CFIs, PDF text anchors |
| browser DOM and CSS | `src/document/` | node tree with DOM child indices, CSS subset, cascade |
| browser layout | `src/layout/` | paragraph `TextSpan` trees laid out by `TextPainter`; blocks, images and tables as `RenderBox`es |
| `paginator.js` | `src/paginator/` | columns and pages, scroll mode as slivers, layout cache, anchor ↔ page |
| `fixed-layout.js`, `readflex_page_zoom.js`, image areas in `book.js` | `src/fixed_layout/` | spreads, orientation, RTL, `FixedPagesView` with zoom and tap arbitration, `FixedPagesController`, image areas, thumbnails |
| `overlayer.js` | `src/overlayer.dart` | highlights and image areas painted over pages |
| `search.js`, `text-walker.js` | `src/search/` | search with the same normalization and excerpts (`searchText`) |
| text layer of `pdf.js` | `src/formats/pdf_text_layer.dart` | `PdfTextLayer`: a box per character, words, sentences, search and text anchors on a page |
| `progress.js`, `footnotes.js` | `src/progress.dart`, `src/footnotes.dart` | section fractions, locations, footnotes |
| `view.js` | `src/view/` | `VellumView`, `VellumController` |
| `readflex_*.js` | `src/interaction/` | tap zones, selection handles, columns, page colors, zoom |

## Layers

`container`, `formats`, `epubcfi` and `document` are pure Dart (no
`dart:ui`): they run in isolates and are tested without a Flutter binding.
`formats/pdf_book.dart` talks to pdfium through `pdfrx_engine` and one
FFI call of its own; `src/pdf/` is the Flutter side of that (loading the
library the app bundles). `metadata`, `layout`, `paginator`, `fixed_layout`, `overlayer`, `view` and
`interaction` are Flutter and use the framework's own primitives:
`TextPainter` metrics, `RenderBox` layout, `PageView` physics,
`SelectableRegion` handles, `ImageProvider`/`ImageCache`, `ChangeNotifier`
controllers. There is no DOM or CSS engine emulation on top of Flutter.

## Containers

`ZipArchive.open(path)` parses the end-of-central-directory record (with
a trailing comment and ZIP64) and the central directory; `entries` are
plain data. `read(entry, maxBytes:)` inflates through `dart:io` zlib and
checks the inflated size against the directory; `readDetached(path, entry)`
does the same through a fresh handle for `Isolate.run`. Reads on one
archive are serialized because `RandomAccessFile` allows one pending
operation. Encrypted entries and methods other than stored/deflate are
listed but refused on read with `VellumException`. CRCs are not verified:
a damaged image fails to decode and a damaged chapter fails to parse, and
both are reported where they are used. Names use UTF-8 when the archive
flags it, otherwise UTF-8 if the bytes decode and CP437 if not.

## Comics

`ComicBook.open(path, pageOrderVersion:)` lists the archive's images in
reading order and reads a page's bytes on demand; decoding and caching
belong to the image layer. The order must match the WebView reader's for
saved positions to land on the same page: version 0 is the legacy
code-unit sort of names with a lowercase image extension; version 1
(`currentComicPageOrderVersion`) takes any extension case, skips
`__MACOSX` and `._` entries and sorts naturally. `naturalFilenameCompare`
reproduces `Intl.Collator('en', {numeric: true, sensitivity: 'variant'})`
with the collator's ties broken by code units: digit runs by value with
leading zeros ignored, punctuation before digits before letters, Latin
diacritics and Cyrillic `ё` as secondary differences, case last. The
reference is `test/fixtures/icu_natural_order.json`, every pair of 56
names as Node's collator orders them, plus probes for letters outside it.
Not modelled: contractions of other languages and non-decimal numerals;
such names fall back to code-point order.

`probeImageDimensions` reads the displayed size from an image header so
spreads can be planned before the bytes are decoded.

## PDF (`src/formats/pdf_book.dart`, `src/pdf`)

pdfium is the one third-party engine in vellum, for PDF only, through
`pdfrx_engine` (the Dart API of pdfrx, no widgets) and `pdfium_flutter`
(the library itself: an XCFramework on iOS and macOS, a bundled native
asset on Android). `PdfBook.open(path, password:)` reads every page's
displayed size in points (a `/Rotate` page comes back turned), the outline
as `PdfOutlineEntry` trees with 0-based page indices (an entry whose
destination is missing or out of range keeps `pageIndex` null), and
`Title`/`Author` of the Info dictionary through `FPDF_GetMetaText`, which
`pdfrx_engine` does not expose; that call runs while the engine's worker
is paused, as pdfium allows one caller at a time. Page sizes are read in
one pass in the worker isolate: 200 pages take well under a second.
An encrypted file without the right password throws
`PdfPasswordRequiredException`; anything pdfium cannot read throws
`VellumException` with pdfium's reason. The app calls
`initializePdfEngine()` once before the first open.

Pages are drawn through `ImageProvider`s, as comic pages are, so the
framework's image cache holds the budget and `Image`, `precacheImage` and
error handling work unchanged. `PdfPageImage(book, pageIndex,
targetWidth)` renders the whole page at a width (the frame in device
pixels, `thumbnailWidth` for previews); pdfium draws in its worker
isolate into a BGRA buffer that `decodeImageFromPixels` turns into a
texture, and the buffer is freed only after that copy, since it is native
memory viewed from Dart. A width whose page would exceed
`PdfPageImage.maxPixels` (6 Mpx, the WebView reader's cap on one bitmap)
is reduced. A zoomed page gets sharp through `PdfPageTile(book, pageIndex,
fullWidth, region)`: the region of the page at the zoomed size, drawn
over the fitted page, so 4× zoom never costs a 4× page. `PdfPageThumbnail`
is the preview widget. `readPdfMetadata(path)` is the import side: Info
title (or the file name when there is none; the WebView import stored
"Unknown"), author, and the first page rendered by pdfium straight at
the cover size and JPEG-encoded through `encodeCoverFromPixels`.

`PdfTextLayer.load(book, page)` is the text layer: pdfium's reading-order
text with one `\n` per line and a `PdfBox` per character in display
points (`/Rotate` applied, origin top-left, so one factor scales it to the
drawn page). On it: `charIndexAt` and `wordAtPoint` (a tap lands on the
nearest glyph within a glyph's height; words are letters, digits and
marks with inner apostrophes and hyphens), `boxesOf` (one box per line,
for selections and highlights), `contextOf` (the sentence around a
selection with the selection in `[[…]]`, as
`readflex_selection_context.js` built it: sentences end at `.!?…` plus
closing quotes before whitespace, line breaks are whitespace, a sentence
cut by the 2048-character window falls back to the selection),
`search` and `rangeOfText`. `src/search/text_search.dart` is the shared
search: case- and diacritic-insensitive (Latin-1, Latin Extended-A,
combining marks, й/ё) with whitespace runs folded, excerpts of 50
characters per side with an ellipsis when cut, offsets mapped back to the
original text.

Anchors (`src/epubcfi/pdf_anchor.dart`): the WebView reader anchored PDF
highlights with CFIs into the DOM text layer `pdf.js` drew, which only
that DOM resolves. vellum writes `epubcfi(/6/N!/2[vellum],/1:start,/1:end)`,
so the page step still reads in both readers (`fakeCfiToIndex`) and the
character range is exact for vellum; `resolvePdfTextAnchor` takes that
range when the text still matches and searches the highlight's saved
text on the page otherwise, which is how the WebView's highlights open
here.

Margin crops and page colours keep the WebView reader's rules.
`detectPdfPageContent(book, page)` has pdfium draw a sample with its long
side at 160 px and `detectContentBox` (pure) finds the ink: the paper tone
is the median of the ring inside the ignored 1 % edge, a pixel is ink 28
luminance steps away from it, rows and columns need 1 % (at least two)
inked samples so specks do not stretch the box, one sample pixel of
slack is added. `contentCrop` turns the box into the crop: 2 % padding,
pages whose ink is narrower than half the page stay whole, the height
grows to the viewport's aspect anchored at the ink top and shifts up at
the bottom edge. `pageColorsFor(themed:, background:, foreground:)` is
null for the original setting and for white paper (luminance ≥ 0.98);
themes darker than 0.4 invert. `paintPageWithColors` draws a page image
with those colours through one `ColorFilter.matrix` (`pageColorFilter`,
cached per `PageColors`): light themes map white to the background and
black to the text colour, linearly between; dark themes invert luminance
in YIQ, which keeps hues so a blue figure stays blue, then map the
inverted paper to the background and the inverted ink to the text colour.
One draw, the same cost as an unrecoloured page, and the same pixels under
Impeller and Skia. The WebView's canvas recipe (blend modes inside a
layer) is not used: Impeller renders `saveLayer` plus `difference`/`hue`
blends as a no-op, so a dark theme left pages white on iOS.

`PdfTextOverlay` goes into `FixedPagesView.pageOverlayBuilder` with the
page's `PdfTextLayer`: it draws saved `PdfTextHighlight`s, the search
hit and the selection held in a `PdfTextSelection` (`ChangeNotifier`) the
app owns, as `ComicImageAreaDraft` holds an image-area draft. A long
press (280 ms) on a word selects it and drags its end over the text; a
drag from either handle (44 px targets at the selection's ends, the
nearer one where they overlap) moves that end by character; a tap
outside clears the selection; a tap on a saved highlight reports it.
Reports carry the selection's rect as fractions of the whole view for the
app's chrome. While a selection is up the view's input is locked, as for
image areas. Both overlays repaint through `RepaintAfterBuild`: the app
restyles a selection from a popup's `initState` and `dispose`, so a change
may arrive mid-frame, and the repaint then waits for the end of the frame
while the model keeps its call order. `PdfTextLayerCache`
keeps the layers of the last 12 pages read and tells listeners when one
arrives; `searchPdfBook` streams hits page by page through it (or loads
and drops layers without it) and stops when the subscription is
cancelled.

## Metadata (`src/metadata`)

`readComicMetadata(path)` is what the app's import calls instead of the
headless WebView: the title is the file name without its extension, as
`comic-book.js` sets it, and the cover is the first page in reading order.
`encodeCoverThumbnail` turns any image the engine decodes into a JPEG that
fits `CoverThumbnailSpec` (480×720, quality 85 by default): the engine
decodes straight to the target size with EXIF orientation applied, so a
page scan never becomes a full-size bitmap, and only the JPEG encoding of
the small frame (`package:image`) runs in Dart, in a short-lived isolate.
A first page over `maxCoverBytes` (32 MiB) or one that does not decode
leaves the cover null and the import goes on without it, as it does when
foliate-js hands back no cover. A file that is not a comic throws
`VellumException`.

## Fixed-layout pages (`src/fixed_layout`)

`FixedPagesController` is the model (`ChangeNotifier`, like `PageController`):
pages pair into spreads as `fixed-layout.js` pairs sections without
`page-spread` hints (left then right, mirrored for right-to-left); a
viewport taller than 1.2 widths shows one page at a time; a turn moves
within the spread first, then enters the next spread from the side the
reader came from; `goToCfi` takes the fake CFIs the WebView reader saves
(`epubcfi(/6/N)`), `goToFraction` the slider's fraction; `position`
reports the numbers the app shows (`fraction = (page + 1) / pageCount`,
chapter counter = page counter, one byte-based location). Every turn,
jump or rotation resets zoom (`zoomEpoch`).

`FixedPagesView` draws any `FixedPageSource` (`ComicPages` over a
`ComicPageSource`, `PdfPages` over a `PdfBook`) with framework parts:
`PageView` under a `Directionality` for the reading direction (its
`axis` turns pages sideways or, for the reader's vertical page turn, up
and down, where reading direction does not apply),
`PageScrollPhysics`, `allowImplicitScrolling` for neighbours,
`InteractiveViewer` for pinch and pan (1–4×), a `CustomMultiChildLayout`
that gives facing pages one scale and a shared gutter (a PDF's known
`pageAspect` lays the spread out before anything is drawn), and a
`FixedPagePainter` per page drawing the source's `pageImage` at the frame
width in device pixels through `paintPageWithColors`. A zoom gesture
re-decodes the page denser, up to the pixel budget; when that is not
sharp enough (a zoomed PDF), the frame renders the on-screen part as a
tile after the gesture (`sharpenRegion`, `tileFor`, `tileCovers` in
`zoom_tiles.dart`, the WebView's rules: 1.1× threshold, 20 % pan margin,
6 Mpx) and drops it at fit. `visibleRectOf` gives each page a margin crop:
the visible part is fitted and laid out, the whole page is rendered at the
density the crop is shown at, and overlays still receive the whole page's
rect (`imageRect`), which then extends past the frame. `pageColors` apply
theme colours to pages and tiles alike. Taps follow
`readflex_page_zoom.js`: edge zones (`edgeTapZoneFraction`, 0.3) fire at
once and never zoom; a centre tap waits 280 ms for a second one within
32 px, which zooms to 2.5× at the point or back to fit; zoomed pages treat
every tap as a centre tap and swipes as pans. `onTap` receives fractions
of the view, what the app's tap-zone logic takes today. Reduced motion
jumps instead of animating.

`ComicPageImage` is an `ImageProvider`: the page's bytes from a
`ComicPageSource`, decoded to a target width, cached by the framework's
image cache under (source, page, width). `ComicPageThumbnail` and
`PdfPageThumbnail` use the providers at 240 px (comics with the 16 MiB
budget of the WebView previews).

`FixedPagesView.onPageShown` reports a visible page's first image, which
is the moment a document is readable; `FixedPagesViewportScope` lets
overlays express rectangles as fractions of the whole view, the coordinate
space the app's selection chrome positions itself in.

`ComicImageAreaLayer` goes into `FixedPagesView.pageOverlayBuilder`: saved
areas in fractions of the image, and a draft held in a
`ComicImageAreaDraft` (`ChangeNotifier`) the app owns. A long press
(280 ms) starts a draft of the WebView reader's default size centred on
the finger; while it exists the view's input is locked, drags inside move
it, drags from the corner zones (64 screen px, capped at 40 % of the
rectangle) resize it down to 1.5 %, a tap outside cancels it unless the
app retains it under a sheet. A long press on a saved area reports the
topmost one. Sizes meant in screen pixels are divided by the zoom.

## Tests

`fvm flutter test` from this directory. `package:vellum/testing.dart` is
the test-support library, for this package and for packages that embed it:
`ZipBuilder` writes archives byte by byte so flags, methods, ZIP64 records
and damage are under the test's control (one test cross-checks an archive
written by `package:archive`); `encodeSolidPng` and `buildComicArchive`
generate deterministic comics, so goldens in `test/fixed_layout/goldens/`
are stable (regenerate with `--update-goldens` only for an intended
change); `FakeComicSource` is an in-memory page source. PDF tests call
`preparePdfEngineForTests()` first: the `pdfium_dart` build hook downloads
the host library during `flutter test`, but this Flutter records it in
`build/native_assets/<os>/native_assets.json` while the engine's loader
looks for `.dart_tool/native_assets.yaml`, so the helper reads Flutter's
manifest and points the engine at the library. PDF fixtures live in
`test/fixtures/pdf/` with their PostScript sources; `make_fixtures.sh`
regenerates them with Ghostscript (outline, rotated page and Info
dictionary through pdfmarks, a user-password file, 200 pages).
`test/metadata/` decodes
real covers through the engine in plain `test`s and reads the JPEG back
to check colours and the quantization table. In widget tests,
opening a real archive is a chain of file reads that complete on the real
event loop: alternate `runAsync` and `pump`, as the reader's screen test
does, and write fixtures with the synchronous file API.
