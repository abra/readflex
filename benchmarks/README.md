# Performance benchmarks

The isolated [reader part comparison](reader_native/README.md) compares existing
Dart ZIP/XML/HTML and MOBI record reading with Rust through FRB, using frozen real
book inputs. Its MOBI cases use the production Rust backend and an explicit
Dart reference; the other Rust format/parser candidates remain experimental.

These checks are opt-in benchmarks, not part of `make test`. Run with the pinned
SDK and avoid concurrent builds, coverage collection, or emulator workloads
when comparing elapsed times.

```sh
make test-performance
```

- `reader_search_benchmark_test.dart`: 1k/5k/20k one-result chunks through the
  production search cubit; one warmup and three samples. Records median elapsed
  microseconds, state emissions, and cumulative result entries published.
- `library_benchmark_test.dart`: 1k/5k/20k books through the production Library
  state projection/search; one warmup and five samples, plus 10k cached reads.
- `vellum_document_benchmark_test.dart`: synthetic XHTML chapters of 100/400/1600
  paragraphs (about 100 KB to 1.7 MB) through `ContentDocument.parseXml`; one
  warmup and three samples. Records source bytes, node count, median parse,
  style resolution (user-agent sheet plus a book-like sheet) and box building
  microseconds, and a full-tree walk; then the same boxes with `hyphens: auto`
  on English prose (soft hyphens inserted, the first run building the
  per-isolate hyphenator) and the column laid out at 360 px with and without
  them (the test font, so relative cost, not device time).
- Results: `.local/performance/reader-search.json`, `library.json` and
  `vellum-document.json`. Preserve
  before/after artifacts locally before rerunning, since these paths are replaced.

Normal tests enforce structural budgets, without flaky stopwatch thresholds:
`reader_search_stress_test.dart` checks burst emissions, no lost results,
cancellation and completion; `test/ui/library_scaling_test.dart` bounds mounted
tiles during scrolling and verifies cached projection identity at 20k books.

These are host/JIT measurements, not release-device frame, peak-memory or import
benchmarks. The Library workload starts from loaded models; it does not include
SQLite reads or cover decoding. The search workload measures burst handling, not
vellum's search through a book or every continuous-stream pattern.

Run database query/index measurements:

```sh
fvm flutter test benchmarks/perf_audit_test.dart --dart-define=PERF_AUDIT_COMMAND=db --dart-define=PERF_AUDIT_SCALE=20000
```

Use these numbers to justify production changes; do not turn the benchmark into
a strict pass/fail test without platform-specific thresholds.

## MOBI Dart/Rust experiment

Record the production Dart decoder in host AOT, with Node.js 20+ and the pinned SDK:

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
lockfiles and is not a runtime dependency. The app uses the separate production
`packages/vellum_mobi_native` backend. Requirements for this experiment:
Rust/Cargo with edition 2024 support, the pinned Flutter
SDK and Node.js 20+. Install dependencies, check parity and measure:

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
with `dart build cli` (Vellum's transitive packages have native hooks), then prints
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
node scripts/mobi_benchmark.mjs run --label rust-frb \
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
versus 6,079,712 bytes for the Dart worker. CLI bundles also contain Vellum's
PDFium/Objective-C assets; these figures do not measure an APK/IPA size delta.

The selected experimental configuration is CST/DCO/NOM. Production continues
using Dart: PalmDOC merits a real-book/device experiment, while real HUFF books,
book-open/first-page time, batch-size/memory tradeoffs, cancellation and mobile
packaging remain unverified.
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
