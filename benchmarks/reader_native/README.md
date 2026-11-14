# Reader part comparison

This isolated experiment compares Rust candidates with the **current Pagecraft Dart
implementations**. The app does not depend on this package. MOBI measurements
use the production Pagecraft container with its explicit Dart reference and Rust
backend. ZIP/XML/HTML remain isolated candidates, outside the production graph.

| Operation | Dart baseline | Rust candidate |
| --- | --- | --- |
| ZIP open/list | `ZipArchive.open` and its entries | File seeks, central directory/ZIP64 parser, FRB metadata transfer and `ZipEntry` conversion |
| ZIP read | `ZipArchive.read` for the same entries, serially | File seeks and stored/raw-deflate reads, serial FRB calls returning bytes |
| XML section parsing | `ContentDocument.parseXml` | XML tokenizer → equivalent arena columns, FRB transfer, Dart ID/local-name/view indexes |
| HTML section parsing | `ContentDocument.parseHtml` | HTML5 parser → equivalent arena, FRB transfer and auxiliary indexes |
| FB2 XML DOM | `XmlDocument.parse` used by `Fb2Book.parse` | XML arena → FRB → Dart `XmlDocument`; conversion is inside the timer |
| MOBI/KF8 text stream | `MobiContainer.open(..., useDartTextReader: true).loadAllText()` | The same container using production Rust text-record I/O/decoding in one FRB batch |
| MOBI/KF8 record sequence | Dart reads first, next, middle and last records | Production Rust reads the same individual records through FRB |

Both ZIP implementations use native zlib. MOBI uses Pagecraft's internal Rust
backend (`packages/pagecraft/rust`, crate name `pagecraft_mobi_native`);
the earlier `mobi_rust` experiment is retained separately. This does not measure an entire reader or introduce a
second rendering architecture. PDF already uses PDFium through `pdfrx`; replacing
that wrapper would not compare an existing Dart PDF engine with a Rust engine.

## Reproduce

Use the repository's FVM SDK, Cargo and `flutter_rust_bridge_codegen` **2.13.0**.
Corpus selection and comparison orchestration are Dart tools; Node.js is not
required. `make test-tools` checks their evidence validation independently of
this experiment's native tests.

On macOS the release library is
`benchmarks/reader_native/rust/target/release/libpagecraft_reader_benchmark.dylib`.
Linux uses `.so`; Windows uses `pagecraft_reader_benchmark.dll`.

```sh
make get-reader-native
make test-reader-native
make build-reader-native

fvm dart scripts/reader_corpus.dart ~/Downloads/pocketbook \
  .local/performance/reader-parts/selection.json

cd benchmarks/reader_native
fvm dart run bin/prepare_reader_corpus.dart \
  ../../.local/performance/reader-parts/selection.json \
  ../../.local/performance/reader-parts/corpus
cd ../..

make benchmark-reader-parts \
  DATASET=.local/performance/reader-parts/corpus/dataset.json \
  LIBRARY=benchmarks/reader_native/rust/target/release/libpagecraft_reader_benchmark.dylib
```

The selector inventories the supplied book directory, excludes device `System`
files and selects inputs across file sizes. Limits are 12 EPUB, 8 MOBI, 4 AZW3,
4 FB2, 4 zipped FB2 and 4 CBZ. Selected files are deduplicated by SHA-256; selection
paths remain under ignored `.local/`.

Files of equal size use deterministic path code-unit ordering rather than the
old host-locale collator. A newly selected corpus can therefore differ at size
ties; reuse the frozen `dataset.json` and inputs for matched comparisons.

Preparation freezes inputs and expected output fingerprints using production
Dart. EPUB workloads read up to 24 entries and parse the two largest chapters.
MOBI workloads read every text record and, for pre-KF8 files, parse the two largest
HTML sections. Plain FB2 workloads build the existing XML DOM; zipped FB2 inputs
exercise ZIP open/read. Separately labelled synthetic CBZ files contain up to
24 unchanged PNG/JPEG images extracted from the selected archives, stored and
deflated. Image decoding and rendering are not timed.

## Measurement and correctness

One Dart AOT executable implements both adapters. Rust uses a release build and
FRB 2.13.0 with CST/DCO and NOM opaque objects. Default 64-bit mappings are kept:
FRB's `type_64bit_int` cast cannot decode these ZIP metadata fields with DCO.
Regenerate bindings with `make generate-reader-native`.

Each case runs in a fresh process in **Dart → Rust → Rust → Dart** order: one
first operation, three warmups and 21 measured operations per process. Reported
medians combine the 42 warm samples per implementation. Raw samples, per-process
medians, first-operation times, setup times, peak RSS, host/toolchain information
and SHA-256 hashes are saved with frozen executables, libraries and datasets in
`.local/performance/reader-parts/comparison-*/`.

The Dart orchestrator keeps the existing report protocol and raw samples,
validates each worker's output fingerprint and median/p95 against those
samples, and checks input hashes before freezing them. The median is the
upper-middle sorted sample and p95 uses the nearest rank. Source and artifact
hashes remain part of the report alongside frozen copies.

The timer includes the Dart-facing operation, bridge dispatch, transferred output
and the compatibility conversion described above. Input text loading, experimental
ZIP/markup library initialization and output fingerprinting are outside the timer. ZIP/MOBI
reads include file I/O with the OS file cache warm. First-operation time is not a
cold disk or application-start measurement. Both current MOBI adapters parse
their headers in Dart during setup. Production Rust library/session initialization
is lazy and included in the first operation, then amortized in warm samples.
Older frozen reports used a header-derived layout for the prototype Rust reader;
their setup times are not equivalent book-open operations.

Every operation verifies all output bytes or a canonical tree containing every
element, text/CDATA node, parent/sibling relation and sorted attributes. ZIP
metadata is checked as well. Fingerprint failures and Dart preparation failures
are retained as failures, never accepted as fast results. Peak RSS covers the
whole process, including verification allocations outside the timed interval.

Tests cover ZIP64, UTF-8/CP437 names, stored/deflated bytes, inflated-size limits,
XML namespaces and CRLF preservation, CDATA/entity normalization, malformed XML,
HTML5 tree construction and MOBI/KF8 fixtures through the actual bridge. The XML
prototype is not a fully compatible DTD/custom-entity implementation; passing
this corpus does not establish compatibility with every possible book.

These are host component measurements. They do not establish mobile FPS,
pagination speed, first-page latency or total book-open performance. The Rust
ZIP read limit belongs to this prototype; production ZIP limit behavior is
unchanged.
