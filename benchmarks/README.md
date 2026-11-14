# Performance benchmarks

The isolated [reader part comparison](reader_native/README.md) compares existing
Dart ZIP/XML/HTML and MOBI record reading with Rust through FRB, using frozen real
book inputs. Its MOBI cases use the production Rust backend and an explicit
Dart reference; the other Rust format/parser candidates remain experimental.

These checks are opt-in benchmarks, not part of `make test`. Run with the pinned
SDK and avoid concurrent builds, coverage collection, or emulator workloads
when comparing elapsed times.

Orchestration under `scripts/` uses Dart from that SDK; Node.js is not required.
`make test-tools` validates the tools in isolation, including frozen-input
hashes, worker correctness evidence and statistics calculated from raw samples.

```sh
make test-performance
```

- `reader_search_benchmark_test.dart`: 1k/5k/20k one-result chunks through the
  production search cubit; one warmup and three samples. Records median elapsed
  microseconds, state emissions, and cumulative result entries published.
- `library_benchmark_test.dart`: 1k/5k/20k books through the production Library
  state projection/search; one warmup and five samples, plus 10k cached reads.
  A separate case compares metadata-only and full-body reads for 1k articles
  in an in-memory SQLite database, with one warmup and five samples.
- `pagecraft_document_benchmark_test.dart`: synthetic XHTML chapters of 100/400/1600
  paragraphs (about 100 KB to 1.7 MB) through `ContentDocument.parseXml`; one
  warmup and three samples. Records source bytes, node count, median parse,
  style resolution (user-agent sheet plus a book-like sheet) and box building
  microseconds, and a full-tree walk; then the same boxes with `hyphens: auto`
  on English prose (soft hyphens inserted, the first run building the
  per-isolate hyphenator) and the column laid out at 360 px with and without
  them (the test font, so relative cost, not device time).
- Results: `.local/performance/reader-search.json`, `library.json`,
  `library-sqlite.json` and `pagecraft-document.json`. Preserve
  before/after artifacts locally before rerunning, since these paths are replaced.

Normal tests enforce structural budgets, without flaky stopwatch thresholds:
`reader_search_stress_test.dart` checks burst emissions, no lost results,
cancellation and completion; `test/ui/library_scaling_test.dart` bounds mounted
tiles during scrolling and verifies cached projection identity at 20k books.

These are host/JIT measurements, not release-device frame, peak-memory or import
benchmarks. The Library projection workload starts from loaded models; its
separate SQLite case excludes durable writes and neither case decodes covers.
The search workload measures burst handling, not pagecraft's search through a
book or every continuous-stream pattern.

Run database query/index measurements:

```sh
fvm flutter test benchmarks/perf_audit_test.dart --dart-define=PERF_AUDIT_COMMAND=db --dart-define=PERF_AUDIT_SCALE=20000
```

Use these numbers to justify production changes; do not turn the benchmark into
a strict pass/fail test without platform-specific thresholds.

## Native import, opening and reading

The native app harness imports real EPUB, FB2, MOBI, AZW3, CBZ and PDF files,
opens them from the Library, mounts the first page and turns a page. Pass plain
FB2 files: the current import entry determines format from the final extension,
so archived FB2 is not an equivalent import workload. `PAGECRAFT_BOOKS` separates
paths with `|`, so input filenames must not contain that delimiter. Quote the
whole define in the shell; commas and spaces are preserved by the pinned
Flutter CLI. On Android first push files to a device-readable directory. The
iOS simulator can read host paths.

```sh
READFLEX_NATIVE_DEVICE=<android-device-id> fvm flutter drive --profile \
  --driver=test_driver/ui_driver.dart \
  --target=integration_test/native_books_open_test.dart \
  -d <android-device-id> \
  '--dart-define=PAGECRAFT_BOOKS=/data/local/tmp/books/book.epub|/data/local/tmp/books/book.mobi' \
  --dart-define=PAGECRAFT_PERF_REPEATS=3 \
  --dart-define=PAGECRAFT_PERF_SCREENSHOTS=false
```

Reports and optional screenshots go to `.local/ui-device/run-*/`. Each raw row
includes file bytes, import/open milliseconds, repeat number and process RSS.
Import calls the production `importBookFile`: metadata/cover extraction, file
copy with progress and repository insertion are timed together. File picking,
application startup and picker-copy cleanup are excluded. Each repeat uses a
fresh app, in-memory SQLite database and real temporary book/cover files. These
numbers do not measure durable database writes. Repeats share the Dart process,
native initialization and OS caches; process peak RSS is cumulative.

Opening starts at the Library tap after its tile becomes tappable and ends
when the first page is mounted. Each readiness poll delays 30 ms then pumps
30 ms (roughly 60 ms plus frame alignment on a live binding). It excludes the
old fixed tap-settling delay and does not establish the physical first painted
pixel or complete image decoding. Screenshots and image-settling delays are
outside the open interval. Keep the recorded platform, build mode and viewport
with the raw samples; compare medians and ranges on the same device.

For a breakdown of text preparation and execution, run the same driver with
`--target=integration_test/pagecraft_text_engine_test.dart` and text books in
`PAGECRAFT_BOOKS`. It records file opening, up to 30 linear sections per book,
section preparation, image probing, initial layout, full layout and pagination
separately. `firstPageMs` is initial layout alone;
`prepareToFirstPageMs` also includes section preparation and image probing.
The first book additionally exercises selection, whole-book search and 12 page
turns with raw action times, individual build/raster/total frame timings and
frame summaries. Frames are filtered to each turn's action interval; screenshot
and inter-turn preparation frames are excluded. `resumeMiddleMs` measures
navigation to the expected section and spread at 50% of the already-open book,
including its layout and mounted-view update, rather than reopening a file.
Turn times include the test gesture and animation; they are not per-frame
execution times. The screenshot toggle also applies to this text-engine suite;
the repeat define applies only to `native_books_open_test.dart`.

`integration_test/article_performance_test.dart` uses the same driver to measure
saving a fixture article, Library-to-reader opening, reopening at a saved middle
position, search and 12 real-time scroll animations with raw Flutter frame
timings. `PAGECRAFT_PERF_REPEATS` defaults to 3 there. Article persistence uses the
same isolated in-memory SQLite and real temporary files. Network download and
extraction, application bootstrap and durable database writes are excluded.

Use profile mode on a physical phone for device latency and frame budgets.
The iOS simulator supports debug mode only: omit `--profile` there. Debug,
simulator and emulator results are diagnostics, not bounds or predictions for
physical release performance. `native_article_test.dart` separately exercises
a saved fixture article's open/scroll/search/reopen flow; it excludes network
download and extraction. No current harness measures complete process startup.

For application startup, Flutter's built-in trace uses the normal entry point:

```sh
fvm flutter run --profile --trace-startup -d <android-device-id>
```

Preserve `build/start_up_info.json` and `build/start_up_timeline.json` before
repeating: Flutter replaces them. The timings begin at engine entry; distinguish
the first built frame from the first rasterized frame. They include application
dependency initialization, but do not measure the OS launch before engine entry
or establish that Library data is ready. A profile APK's size also differs from
release APK/AAB delivery size; keep its ABI list with any size measurements.

For warmed application controls, use `make profile-ui DEVICE=<physical-device-id>`.
This separate profile-only harness measures Library search/keyboard transitions,
Reader chrome, Appearance and long Highlight scrolling. The host runner validates
the device and rejects an existing or unknown physical Readflex installation
before building. Use a dedicated test device; see the
[UI verification workflow](../test/ui/README.md#native-ui-frame-profiling) for
installation safety, artifacts and emulator opt-in. Flutter build/raster samples
exclude native keyboard rendering and compositor presentation; they are not
end-to-end FPS or proof of physical performance from an emulator.

## MOBI Dart/Rust experiment

Record the retained Dart reference decoder in host AOT with the pinned SDK:

```sh
make benchmark-mobi
# Optional real compressed books; repeat --book for every input:
make benchmark-mobi ARGS='--book /path/to/book.mobi --book /path/to/book.azw3'
```

Each baseline run creates a fresh `.local/performance/mobi/<label>-*/` directory with an
AOT CLI bundle, frozen `dataset.json` and `report.json`. The entry point under
`bin/` lets `dart build cli` handle transitive native hooks for the Dart baseline
as well as for the candidate. Default workloads are 64 KiB
and 1 MiB multilingual PalmDOC records, 512 KiB binary literal runs, 64 KiB and
1 MiB synthetic HUFF/CDIC phrases, and the committed `six.mobi` fixture. The
synthetic HUFF dictionary exercises direct and table-2 codes, two CDIC records
and cached recursive phrases; it does not represent a real HUFF-compressed book.
HUFF/CDIC records and dictionaries are also extracted when a supplied book uses
that compression. Expected decoded bytes are frozen before timing. Do not commit datasets
extracted from private/copyrighted books.

Each case runs in three fresh processes, each with five warmup batches and 21
measured batches. Reports retain every timing, session setup and first-batch
times, decoded byte counts, peak process RSS, SDK, host fingerprint and artifact
hashes/sizes. Full byte equality is checked after every batch, outside timing.
Timed intervals include output allocation and the entire Dart-facing call;
dataset reads, process startup and global library initialization are excluded.
Peak RSS includes the worker, input dataset and expected bytes, not just decoder
allocations. These are decoder measurements, not book-open, first-page or FPS
measurements, and first-batch timings are not a cold OS disk-cache measurement.

The isolated candidate lives in `mobi_rust/` and pins the Dart runtime, Rust
runtime and generator to `flutter_rust_bridge` 2.13.0. Its generated bridge uses
`full_dep: true`: CST/DCO transfers with NOM opaque objects, selected after
comparing against the serialization-only SSE/MOI configuration. FRB's
[codec documentation](https://cjycode.com/flutter_rust_bridge/guides/miscellaneous/codec)
describes the copy/allocation tradeoff for byte buffers. It has its own Pub/Cargo
lockfiles and is not a runtime dependency. Both `mobi_rust/` and `reader_native/`
stay outside the app's Pub workspace: use their dedicated `get-*` targets,
which enforce their own locks. They consume Pagecraft as a path dependency
without inheriting the workspace's development resolution. Reader-parts reports
fingerprint the shared root workspace lock and the experiment's own lock;
there is no separate Pagecraft Pub lockfile. The app uses Pagecraft's internal
production backend in `packages/pagecraft/rust`. Requirements for this experiment:
Rust/Cargo with edition 2024 support and the pinned Flutter SDK. Install
dependencies, check parity and measure:

```sh
make get-mobi-rust
make test-mobi-rust
make benchmark-mobi-rust ARGS='--dataset <baseline-directory>/dataset.json'
```

`test-mobi-rust` runs Rust formatting, Clippy with warnings denied, Rust tests,
Dart analysis and tests through the release native library. Coverage includes
every two-byte PalmDOC input, seeded random/truncated records, multilingual
round trips, the committed MOBI fixture, HUFF codes of 1–32 bits, split CDIC
dictionaries, lazy recursive caches and session disposal. Rust tests additionally
reject cycles, invalid offsets and excessive expansion. These checks are opt-in;
ordinary `make analyze`/`make test` do not require the experimental package.

`build-mobi-rust` builds Cargo with `--locked --release` and an AOT Dart worker
with `dart build cli` (Pagecraft's transitive packages have native hooks), then prints
their paths. Both workers require Dart's product build mode; the Rust worker
also rejects a debug Rust library. Loading is explicit through
`MOBI_RUST_LIBRARY`; the experiment adds no hooks or changes to app runners.
`open` loads the dictionary into an
opaque native decoder. `decodeBatch` makes one asynchronous FRB call for the
whole batch, returning materialized byte buffers; FRB serializes mutable access
to the cached dictionary. `close` explicitly disposes the opaque resource.
Conversions, dispatch and returned buffers are inside the measured interval.

The Rust implementation preserves Dart's PalmDOC truncation and invalid-back-
reference zero fill. For HUFF it adds explicit errors for zero-length codes,
cycles, nesting beyond 128 levels, and decoded records or cached phrases beyond
64 MiB. These experimental limits are not a claim of identical handling of all
malformed inputs. Container I/O, trailing entries, text decoding and reader
layout still use existing code. A production candidate must validate these
limits against real books and the runtime's cancellation/lifecycle needs.

Generated bindings are committed; running the experiment needs no generator or
LLVM. Regeneration requires LLVM/libclang, the pinned `ffigen` dev dependency
and the exact generator. After changing `rust/src/api.rs`, run:

```sh
cargo install flutter_rust_bridge_codegen --version 2.13.0 --locked
make generate-mobi-rust
```

For an already built candidate or a Dart control repeat:

```sh
fvm dart scripts/mobi_benchmark.dart run --label rust-frb \
  --dataset <baseline-directory>/dataset.json --worker <candidate-executable> \
  --bundle <candidate-build-directory>/bundle \
  --library <release-rust-library>
make compare-mobi BASELINE=<baseline-directory>/report.json CANDIDATE=<candidate-directory>/report.json
```

`run` copies the executable, dataset and supplied libraries/artifacts into its
new report directory before measuring. `--bundle` preserves the directory
layout and native assets produced by `dart build cli`. `--library` also sets the worker's
`MOBI_RUST_LIBRARY` to that frozen copy; optional extra `--artifact` files are
hashed too. Builds retain `build.json` with Rust compiler details, bridge
configuration and source/lockfile hashes; `benchmark-mobi-rust` includes it in
the report. Keep `--bundle` for Dart CLI bundle repeats and omit `--library`;
standalone executables need no `--bundle`. Preserve existing datasets:
adding a workload changes the dataset hash and requires a new matched baseline.

The Dart orchestration retains the existing frozen dataset/report protocols,
raw sample arrays, upper-middle median and nearest-rank p95 definitions. It
checks worker-reported statistics against those samples and keeps SHA-256
evidence for inputs, expected outputs and artifacts; changing the tool language
does not make incompatible or unverified runs comparable.

The comparator rejects different datasets, expected outputs, SDKs, machines,
sampling parameters and incomplete/unverified runs. It reports warm median/p95,
speed ratio and peak process RSS without an automatic winner. Repeat Dart and
Rust in A/B/B/A order with no concurrent builds; compare repeat-to-repeat noise.
Before choosing a production backend, use representative real books (including
HUFF/CDIC), compare malformed-input behavior, then measure complete book opening
and first-page latency through the app on the same physical phone in profile
mode. Evaluate added app binary size and build complexity alongside latency and
memory; host AOT kernel results alone do not select a mobile backend.

### Host measurements, 2026-11-01

These are archived measurements from the SDK below, not a rerun with the current
Flutter 3.50.0 pin. Preserve their artifacts or repeat both backends on the same
current environment before making a new comparison.

Apple M1, macOS arm64, 16 GiB RAM, Dart 3.12.2 from Flutter 3.44.9, Rust 1.99.1.
Two reference Dart → Rust → Rust → Dart series used the same frozen dataset, with three
processes × 21 samples per case in each report. The table gives the range of
the two report medians, in milliseconds, for the CST/DCO series:

| Decoded workload | Dart median ms | Rust + FRB median ms | Paired speedup | Peak RSS MiB, Dart / Rust |
|---|---:|---:|---:|---:|
| PalmDOC multilingual, 64 KiB | 0.764–0.781 | 0.084–0.119 | 6.6–9.1× | 51.6–51.9 / 33.3–34.9 |
| PalmDOC multilingual, 1 MiB | 12.496–12.758 | 1.091–1.146 | 10.9–11.7× | 51.6–51.7 / 81.0–81.6 |
| PalmDOC literal runs, 512 KiB | 5.833–6.116 | 0.358–0.415 | 14.7–16.3× | 51.6–51.9 / 50.0–50.2 |
| Synthetic HUFF phrases, 64 KiB | 0.085–0.089 | 0.055 | 1.5–1.6× | 32.6 / 31.8–32.8 |
| Synthetic HUFF phrases, 1 MiB | 0.835–0.960 | 0.658–0.670 | 1.3–1.4× | 49.4 / 58.7–61.9 |
| `six.mobi`, 625 decoded bytes | 0.013 | 0.013–0.014 | 0.9–1.0× | 29.3–29.4 / 29.8–31.3 |

These include the bridge and output buffers. HUFF's modest median gain does
not establish a tail-latency improvement: its 1 MiB p95 was 0.862–2.442 ms for
Rust versus 1.438–1.560 ms for Dart. The tiny fixture has higher Rust session
setup/first-call overhead, despite similar warm times. Dart control medians
changed by about 2–5% for PalmDOC and up to 15% for HUFF in this series.

The first SSE/MOI series gave only 4.2–5.4× PalmDOC speedups and slower HUFF
medians than Dart. CST/DCO/NOM improved the bridge configuration, but the large
PalmDOC batch still raised whole-process peak RSS by about 30 MiB. The measured
CST/DCO Rust dylib is 915,024 bytes and its Dart executable 6,178,784 bytes,
versus 6,079,712 bytes for the Dart worker. CLI bundles also contain Pagecraft's
PDFium/Objective-C assets; these figures do not measure an APK/IPA size delta.

This historical experiment selected CST/DCO/NOM. Production now uses Pagecraft's
internal Rust crate `pagecraft_mobi_native` for MOBI/KF8 record I/O and decoding;
the [reader part comparison](reader_native/README.md) uses that backend against
the retained Dart reference. The measurements above do not establish
book-open/first-page time, batch-size/memory tradeoffs or mobile FPS.
An optimized Dart decoder has not been measured; these results compare the
current implementation with this Rust candidate.

Local evidence (ignored by version control):

- Dataset SHA-256: `1d496fd331990daf7378d01e5539929628a8fbe7d519340d6d1917a8805a02ab`.
- SSE series under `.local/performance/mobi/`: `dart-before-frb-IPjI32`,
  `rust-frb-a-sxJEH7`, `rust-frb-b-ldx2SJ`, `dart-after-frb-eAgGg5`.
- CST/DCO series: `dart-before-dco-5BOvj9`, `rust-frb-dco-a-0cVZlD`,
  `rust-frb-dco-b-tI8Yhb`, `dart-after-dco-Xy2JKp`.
- The final Makefile/CLI bundle validation series is `dart-cli-before-kzNdNN`,
  `rust-cli-a-R3EtOm`, `rust-cli-b-dTpdWy`, `dart-cli-after-oBIVjg`. Its Dart
  controls drifted by up to 84%, so precise ratios from this series are noisy;
  the closing control still gave 12.135 → 1.148 ms for 1 MiB PalmDOC. The table
  above uses the earlier reference series, whose controls were more stable.
- Each directory retains `report.json`, frozen inputs and executable artifacts;
  `.local/performance/mobi/comparison-2026-11-01.json` summarizes both series.
