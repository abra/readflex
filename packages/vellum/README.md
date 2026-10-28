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

## CFIs (`src/epubcfi`)

`cfi.dart` is the port of `epubcfi.js`: the same grammar, canonical
strings and ordering, so every anchor one reader saved resolves in the
other. `Cfi.parse` reads a string with or without the `epubcfi(...)`
wrapper in one pass over its code units into an immutable model:
`CfiLocation` (paths after each `!` indirection) or `CfiRange` (a shared
parent, then the start and the end), each path a list of `CfiStep`s with
index, id assertion, character offset, temporal and spatial offsets, text
assertions and side bias. `toString` writes the canonical form back
(offsets only on odd, character-data steps; reserved characters escaped
with `^`), `collapse` turns a range into its start or end, `compareTo`
orders anchors as `epubcfi.js` does (step by step, a missing step first,
offsets only at the last step, ranges by start then end) and
`buildCfiRange` joins two points into a range sharing their common steps.
Malformed strings throw `CfiFormatException`; `Cfi.tryParse` returns null.
Ten thousand saved anchors parse and sort in well under a second (test).

`cfi_resolve.dart` maps CFIs to positions in a document and back
(`cfiFromRange`, `cfiFromPoint`, `cfiToRange`, `cfiToElement`,
`cfisFromElements`) through `CfiNode`/`CfiDocument` (`cfi_node.dart`), the
slice of a tree CFIs need: elements and character data with children,
parent, id and attributes. Any format's tree implements it; the reader's
own document model will, and `XmlCfiDocument` wraps a `package:xml` tree
for XHTML, FB2 and package documents (one wrapper per node, ids indexed
once). Resolution follows the spec's indexing the way the browser did:
a parent's children read as `[element, text, element, ..., element]`, so
adjacent text nodes merge into one odd-numbered chunk with their offsets
summed, a missing chunk between two elements still takes a number, index
0 and n+2 are the virtual positions before and after the children, and
the last step's id assertion wins when the document has that element. A
`CfiNodeFilter` makes nodes transparent (`skip`: their children count as
the parent's, foliate-js#100) or invisible (`reject`), both for the path
and for the merged offsets. A step past the children throws
`CfiResolveException`. Points are `CfiPoint(node, offset)` as DOM range
boundaries: a character offset in text, a child index in an element.

Parity is recorded, not assumed: `test/fixtures/cfi/expected.json` holds
what `epubcfi.js` produced in Chromium for the fixture documents (every
text node at three offsets, ranges across neighbouring text nodes,
every element, `fromElements` over the body or spine, with and without a
filter), generated by `packages/reader_webview/test_browser/cfi_fixtures.mjs`
(`node test_browser/cfi_fixtures.mjs` from `packages/reader_webview`).
The Dart tests replay the same positions and must match string for
string and node for node. Two things the browser does that the port does
not copy: a DOM `Range` whose end lands before its start collapses (the
fixtures record each end on its own), and `epubcfi.js` cannot address the
root's own children (head, body).

`fake_cfi.dart` keeps the fast path for sections without a spine
(`epubcfi(/6/N)`: comics, PDF pages), `pdf_anchor.dart` the PDF text
anchors described under PDF.

## EPUB (`src/formats/epub`)

`EpubBook` is the port of the `EPUB` class in `epub.js` without the
browser parts (blob URLs, media overlay playback). `EpubBook.open(path)`
reads the ZIP through `ZipEpubFiles`; `EpubBook.load(files)` takes any
`EpubFiles` (`MemoryEpubFiles` in tests). Opening follows `init()` step
by step: `META-INF/container.xml` names the first package document;
`META-INF/encryption.xml` lists obfuscated resources (`EpubEncryption`:
IDPF keys are the SHA-1 of the unique identifier without whitespace over
the first 1040 bytes, Adobe keys the first UUID identifier over 1024;
other algorithms are left encoded); `EpubResources` reads the manifest,
spine (`page-progression-direction`, `linear`, `properties`), guide and
the cover (the `cover-image` property, else the EPUB 2 `meta name="cover"`,
else the guide's cover page) and gives every itemref its spine CFI
through `cfisFromElements`; spine entries without a manifest item are
skipped but keep their CFI numbering. `sections` carry the container
path, uncompressed size, CFI, linearity, page spread and media overlay
item. The navigation document (`parseEpubNav`: toc, page-list,
landmarks, other navs with their headings; `a` or `span` labels with the
`title` fallback) wins over the NCX (`parseEpubNcx`: navMap, pageList,
navLists; a navPoint without a target takes the first one below); a
malformed navigation document is ignored, a malformed package or
container document fails the open. Landmarks fall back to the guide.
`parseEpubMetadata` reads Dublin Core elements and EPUB 3 `meta`
properties with `refines` (title types, file-as, alternate scripts,
roles with schemes, identifier types, subjects' terms and authorities,
collections), the EPUB 2 `opf:role`/`opf:file-as`/`opf:scheme`
attributes, `rendition:*` and `media:*` metas (durations as SMIL clock
values), and summarises them as `EpubMetadata` with contributors grouped
by MARC relator (`author`, `translator`, `illustrator`, ...). The
iBooks/Kobo display options set `rendition.layout` to `pre-paginated`
and give the first linear section a page spread when the book does not
open to a spread.

Hrefs are container paths resolved as `resolveURL` resolves them
(`resolveEpubUrl`): relative to the package document, the navigation
document or the section, with Calibre's `%2C`/`%3A` put back, the query
dropped and escapes decoded as JavaScript's `decodeURI` decodes them
(`decodeEpubUri`: reserved characters stay encoded, so `ch%2C1.html` does
not find `ch,1.html`, as in the browser). `resolveHref` maps a path with
a fragment to a section index, `resolveCfi` maps a CFI to the section
its first path names (dropping an id assertion that is not an itemref,
the Epub.js bug `epub.js` works around), `readSectionText` and
`readResource` read on demand with fonts deobfuscated, `readCover`
returns the cover bytes, following a cover page to its image.

Parity is recorded as for CFIs: `test/fixtures/epub/expected.json` holds
what `epub.js` in Chromium made of the fixture publications under
`test/fixtures/epub/` (an EPUB 3 with refines, obfuscated fonts, a DRM
entry, a nested package directory, an encoded href, a non-linear item, a
ghost spine entry and media overlays; an EPUB 2 with NCX, guide cover and
legacy attributes; a fixed-layout book with display options), generated
by `packages/reader_webview/test_browser/epub_fixtures.mjs`
(`node --test test_browser/epub_fixtures.mjs` from `packages/reader_webview`).
The Dart tests replay the same files and compare sections, navigation,
metadata, manifest, cover and resolutions. One difference by design:
`epub.js` keeps `dc:publisher` under the same key a publisher role would
use; vellum keeps the string in `metadata.publisher` and roles in
`metadata.contributors`.

## FB2 (`src/formats/fb2`, `src/text/charsets.dart`)

`Fb2Book` is the port of `fb2.js`. `Fb2Book.open(path)` reads a `.fb2`
file or the first `.fb2` entry of a `.fb2.zip`/`.fbz` archive;
`Fb2Book.parse(bytes)` decodes by the XML declaration's encoding
(`decodeFb2Text`: UTF-8 by default, UTF-16 by byte order mark, and the
single-byte charsets FB2 files declare through `decodeCharset`:
windows-1251, windows-1252, koi8-r, cp866, iso-8859-5, latin1, as
tables generated from Python's codecs). The FB2 tree is converted into
the same XHTML `fb2.js` built: the conversion tables (`STYLE`, `SECTION`,
`POEM`, `TABLE`, `BODY`) are `_Rule` maps keyed by FB2 element name, each
giving the XHTML tag, the child table (or the current one) and the
attributes copied; every converted element keeps its `id` and gets the
FB2 name as its class, `a` becomes an anchor with the XLink href (and
`epub:type="noteref"` for notes), `image` becomes `img` whose `src` is a
`data:` URI for an inline `binary`, `stanza` lines become text and
`br`s. Elements the tables do not know are dropped with their subtrees,
as in the browser; prefixed FB2 names are matched by local name.

The first body's top-level elements each become a section, every further
body one non-linear section with the `notesBodyType` class, each wrapped
in the WebView's XHTML template (`Fb2Section.xhtml`, without the
stylesheet link) so saved CFIs resolve in the same elements. A section's
label is the first title, subtitle or paragraph, its direct subsections'
titles are numbered with `data-foliate-id` for `index#n` links, its size
is the document's bytes without image data. `metadata` follows
`book.metadata` (people as `Fb2Person` with `Last, First` sort names,
document-info people and `program-used` as `bkp` contributors, the
annotation as XHTML); `readCover` decodes the `coverpage` binary;
`resolveHref` returns `Fb2TocTarget` for `index#n` or `Fb2IdTarget` for
`#id`.

Parity is recorded as for EPUB: `test/fixtures/fb2/expected.json` holds
the browser's converted XHTML, metadata, sizes, table of contents and
resolutions for `rich.fb2` (every rule, nested sections, notes and
comments bodies, binaries, external and missing images) and
`cp1251.fb2`, generated by
`packages/reader_webview/test_browser/fb2_fixtures.mjs`
(`node --test`). The Dart tests compare the XHTML as trees. Differences
by design: `fb2.js` loses `img` `alt`/`title` (its XML document does not
reflect the properties) and returns a nickname as a bare string, vellum
keeps the attributes and always a person; sizes differ by the stylesheet
link and serializer whitespace (checked within 200 bytes).

## MOBI and KF8 (`src/formats/mobi`)

`MobiBook.open(path)` is the port of `mobi.js`: `PdbFile` reads the Palm
database header and record offsets and serves records on demand from
the file (a 40 MB book costs its record table until a record is read);
`MobiContainer` parses record 0 (`MobiHeaders`: PalmDOC, MOBI, KF8 and
EXTH headers, as offset tables), moves to the KF8 part of a combined
file through the EXTH boundary record, and decodes text records: trailing
entries stripped by the trailing flags, then PalmDOC (`decompressPalmDoc`)
or Huffman/CDIC (`HuffCdicDecoder`, dictionary entries decompressed
lazily and cached) decompression; resources come back deobfuscated and
inflated for fonts (`FONT` records, `dart:io` zlib) and without their
header for audio and video. Metadata is EXTH first, then the header's
title and locale language, with HTML character references decoded
(`unescapeHtml`, `src/text/html_entities.dart`); the cover is the EXTH
cover or thumbnail resource. The result is a `Mobi6Book` for version 6
files or a `Kf8Book` for version 8 and combined files.

`Mobi6Book` reads all text records into one stream (as `mobi.js` must,
`filepos` offsets count bytes of the whole), splits it at
`<mbp:pagebreak>` tags into sections, and gives each section's HTML with
an `<a id="filepos<n>">` anchor inserted at every referenced offset, the
offset string kept as written. The guide comes from the first section's
`<reference>` tags, the table of contents from the guide's `toc` page
nested by the indentation of `p` and `blockquote` ancestors, both parsed
with `package:html`. `Kf8Book` reads the FDST flow table and the skeleton
and fragment indexes (`readMobiIndex`: INDX/TAGX tag tables with control
bytes and CNCX strings), builds sections as skeletons with fragments
inserted at their offsets, loads raw text from whichever end of the
stream is nearer (`loadRaw`), serves `kindle:flow:`/`kindle:embed:`
resources, maps `kindle:pos:fid:X:off:Y` links to sections and to a
selector for the element at that position, reads the NCX index into the
table of contents, the guide index into landmarks, and the RESC record's
spine into page spreads; direction, fixed layout and the original
resolution come from EXTH.

Fixtures are built, not collected: `MobiBuilder` (`package:vellum/testing.dart`)
writes MOBI 6 and KF8 files record by record, including a PalmDOC
compressor, EXTH, trailing entries, INDX/TAGX index records and FDST,
and `test/fixtures/mobi/` holds its output (`mobi_fixtures_test` keeps
the files in step with the builder). `expected.json` records what
`mobi.js` made of them in Chromium
(`packages/reader_webview/test_browser/mobi_fixtures.mjs`, `node --test`;
with `MOBI_FILES=a.mobi:b.azw3` it records real books instead, for ad hoc
parity runs), and the parity test compares metadata, every section's
document tree, sizes, navigation and link targets. Differences by
design: `mobi.js` gives the header's locale language as a bare string,
vellum always a list.

## Document tree (`src/document`)

`ContentDocument` is what the browser's DOM was to foliate-js: the
parsed section that layout, CFIs, search and highlights walk. It is an
arena, one index per node into parallel typed arrays (kind, parent,
first and last child, next sibling, child count, name, attribute
range), with names interned and attributes in two flat lists, so a
chapter costs a few hundred kilobytes and a walk allocates nothing;
`ContentNode` views (the `CfiNode` the CFI code needs) are created on
demand and cached, one per node, so identity holds for `CfiPoint`.
`parseXml` streams `package:xml` events (HTML5 entity mapping for
XHTML's `&nbsp;`, nesting validated, `ContentParseException` on bad
markup); `parseHtml` runs `package:html` for `text/html` sections and
MOBI 6 text, implied `html`/`head`/`body` included; `parse` picks by
media type. The tree keeps what CFIs see and what the browser kept:
elements and character data, text and CDATA as separate nodes, text
split by a comment as two nodes, no comments, no namespace
declarations; line breaks fold to LF and XML attribute values fold line
breaks and tabs to spaces. The corpus test hashes every section's
`ContentDocument` against the browser's tree, and the CFI fixture test
runs on both `XmlCfiDocument` and `ContentDocument`.

## CSS (`src/css`)

The styling engine the layout reads from, written against the CSS
specs rather than a browser's behavior, in layers:

- `css_tokenizer.dart` — CSS Syntax Level 3 §4: tokens with decoded
  escapes, typed numbers, `url()`, bad-string and bad-url tokens; never
  throws.
- `css_syntax.dart` — §5: `CssStyleSheet.parse` gives qualified rules
  (prelude + declarations) and at-rules (`@media` blocks hold rules,
  `@font-face` and `@page` hold declarations), with the spec's error
  recovery: a malformed declaration is dropped, a stray `}` joins the
  next prelude, a rule cut off by the end of input is kept.
- `css_selector.dart` — Selectors Level 3 as books use them: type,
  universal, class, id, every attribute operator, the structural
  pseudo-classes (`:first-child`, `:nth-child(an+b)`, `:not()`,
  `:lang()`, `:root`, `:empty` …), all four combinators, selector
  lists, specificity; pseudo-elements and dynamic pseudo-classes parse
  and never match, an unknown selector drops its rule. Matching runs on
  `ContentDocument` indices without allocating.
- `css_values.dart` — lengths (absolute units to px at parse time, `em`,
  `rem`, `ex`, `ch` and viewport units resolved at compute time,
  percentages kept), colors (named, hex, `rgb()`, `hsl()`, alpha,
  `currentcolor`), font family lists.
- `css_properties.dart` — the supported longhands with their grammar,
  inheritance and initial value, and the shorthands (`margin`,
  `padding`, `border*`, `font`, `background`, `text-decoration`,
  `list-style`, `break-*`) expanded into them; an invalid value drops
  the declaration, unknown properties are ignored.
- `computed_style.dart` and `style_resolver.dart` — the cascade:
  user-agent, user and author origins, `!important` reversing them,
  specificity and order, inline `style` above every author rule,
  presentational attributes (`align`, `width`, `bgcolor`, `<font>`,
  Kindle's `height`/`width` on paragraphs) below; `inherit`, `initial`,
  `unset`; `em` chains, keyword sizes, `bolder`/`lighter`, `line-height`
  numbers kept as factors; `@media` blocks skipped only when they say
  `print`. Rules are bucketed by their rightmost compound, elements
  resolve in document order with their parent finished, and identical
  computed styles are interned (`ComputedStyles.distinctStyleCount`).
- `ua_stylesheet.dart` — the HTML standard's rendering rules, trimmed to
  the supported properties.
- `stylesheet_loader.dart` — the sheets a section asks for, in cascade
  order: `<link rel="stylesheet">`, `<style>`, `@import` inlined before
  the importing sheet, print-only media skipped, cycles and depth
  bounded, external sheets cached per book (`StyleSheetCache`);
  `cssFontFacesOf` lists `@font-face` sources for the font loader.

Tests: a table per layer in `test/css/`, a fuzz test that mutates real
stylesheets 1500 times and tokenizes random code points, and the corpus
test resolves every section of every real book with its own sheets.
`benchmarks/vellum_document_benchmark_test.dart` times style resolution
beside parsing.

## Corpus parity (`test/corpus`)

The fixture tests prove parity on books built for them; the corpus test
proves it on real ones. `packages/reader_webview/test_browser/corpus_snapshot.mjs`
opens every EPUB, FB2 and MOBI under `VELLUM_CORPUS` with foliate-js in
Chromium and records metadata, cover size, each section's size, flags
and a SHA-256 of its canonical document tree (element names, attributes
in name order with whitespace folded, text with CRLF folded, every
string length-prefixed), navigation and link targets; `VELLUM_TREES=1`
keeps the trees so a mismatch points at the first differing character.
`corpus_parity_test.dart` opens the same files with vellum, compares
field by field through one format-neutral adapter, and times every open
and section load with the process memory growth (`VELLUM_CORPUS_REPORT`
writes the Markdown table). It is skipped when `VELLUM_CORPUS` is unset:
the corpus is not in the repository. Lessons it taught the document
model: XHTML needs the HTML named entities (`&nbsp;`), attribute values
fold line breaks, text folds CRLF, and a section the browser cannot
parse is one vellum may still show.

## Import metadata (`src/metadata`)

`readComicMetadata`, `readPdfMetadata`, `readEpubMetadata`,
`readFb2Metadata` and `readMobiMetadata` give a `BookMetadata` (title,
author, description, `CoverImage`) for the library's import, the
counterpart of `book.metadata` and `getCover()` in foliate-js. Text
formats take the book's own metadata, join authors with `, `, and fall
back to the file name (`.fb2.zip` counts as one extension) when there is
no title. Every cover goes through `encodeCoverThumbnail`
(`CoverThumbnailSpec`, 480×720 by default): the engine decodes the image
straight at the target size and a short-lived isolate encodes the JPEG,
so a page scan never becomes a full-size bitmap; an image the engine
cannot decode means no cover, not a failed import.

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
