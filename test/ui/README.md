# UI Verification

This suite complements feature widget/cubit tests and the reader's Chromium and
WebKit regressions. It is not a claim that every OS interaction or every possible
combination of settings is automated.

## Commands

Run from the repository root with the FVM-pinned Flutter SDK:

```sh
make get
make reader-browser-setup
make test-ui
make test-goldens
make verify
make coverage
make test-performance
```

- `test-ui`: production-root flows and golden comparisons, no device needed.
- `test-goldens`: only visual comparisons, without modifying baselines.
- `verify`: formatting, analysis, all active package tests, root UI/goldens,
  and reader JS/browser regressions. Native device tests are separate.
- `coverage`: the same test suites with owned Dart line/branch reports and
  per-test outcomes in a fresh `.local/coverage/run-*/` directory.
- `test-performance`: repeated 1k/5k/20k Library/search workloads, with diagnostic
  JSON results in `.local/performance/`; no hard machine-dependent time limit.

For native WebViews, boot a simulator/emulator or connect an authorized device:

```sh
fvm flutter devices
make test-device DEVICE=<device-id>
# Also collect Dart line coverage after the actions:
make test-device DEVICE=<device-id> COVERAGE=1
```

This uses a debug test build. iOS needs the project's supported Xcode/runtime
and CocoaPods setup; Android needs its SDK and the configured JDK. Normal build
and signing prerequisites still apply to physical iOS devices. No API keys,
`run.sh`, live backend, or monitoring DSN are needed. Do not pass production
credentials to this deterministic test suite.

## Coverage

| Surface or contract | Automated checks | Where |
| --- | --- | --- |
| Onboarding | Skip/complete, routing, saved preference after remount; all three pages in five visual profiles | `onboarding_test.dart` |
| Library | Search/clear, empty results, layout preference; UI changes do not issue new storage reads | `app_flows_test.dart` |
| Library appearance | Grid, display sheet, empty search results in all profiles | `library_golden_test.dart` |
| Library scaling | Grid/list remain virtualized with 20k books, callbacks address the right item, cached projections are reused | `library_scaling_test.dart` |
| Collections | Create with selected book, rename, cancel/confirm deletion; preserve book and clean membership | `app_flows_test.dart` |
| Article import | Extraction error, retry, actual repository/SQLite write, root remount; offline/online button availability | `app_flows_test.dart` |
| Translate | Success, error, pending result; word/text answers before context, unfilled language menus and collapsed/expanded details in all profiles | `surfaces_golden_test.dart` |
| Contextual translation | Selected word/IPA and its visible translation, separate contextual answer and expression scope, collapsed/expanded explanations in all visual profiles | `translation_word_golden_test.dart` |
| Native translation sheet | Real phone viewport, word/expression scopes including rather, IPA rendering, visible general meaning, native clipboard and target-language change with deterministic responses | `integration_test/translation_sheet_test.dart` |
| Define | Single definition, inflected word plus contextual expression, and not-found surfaces in all profiles | `surfaces_golden_test.dart` |
| Shared text tools | Search clear control and highlight palette in all profiles; import menu layout | `surfaces_golden_test.dart` |
| Reader appearance | Portrait/landscape, 2x text and RTL; header/values readable, body scrolls, final control reachable | `reader_appearance_golden_test.dart` |
| Native book actions | Expand word to phrase, translate exact final range, copy result, Define fallback, dismiss selection menu | `integration_test/reader_flows_test.dart` |
| Selected page continuation | Both endpoints in Slide/Vertical, one-page synthetic swipe, menu hides/reanchors, complete range reaches Translate | `integration_test/reader_flows_test.dart` |
| Native persistence | Explicit highlight writes text/CFI to real repository and renders nonzero geometry after book reopen | `integration_test/reader_flows_test.dart` |
| Native reader lifecycle | Search navigation and CFI survive synthetic pause/resume without replacing WebView state; DOM remains readable | `integration_test/reader_flows_test.dart` |
| Native article actions | Store fixture article, keep one native tint when changing palette color, expand word to sentence, translate complete range, close menu | `integration_test/reader_flows_test.dart` |
| Native search UI | Query actual book, navigate result, rerun history, clear field/remove history, empty results | `integration_test/reader_flows_test.dart` |
| Native bookmarks | Create, reopen book, confirm storage, delete from Contents and reopen again | `integration_test/reader_flows_test.dart` |
| Native appearance | Theme/font/size/page-turn reach preferences and DOM; persist per book, reset without replacing live WebView | `integration_test/reader_flows_test.dart` |
| Native translation failure | Failed response, closed selection menu, retry same range successfully | `integration_test/reader_flows_test.dart` |
| Native translation controls | Expand details without a request; change target preserving auto source and exact range; return to selection in the same WebView | `integration_test/reader_flows_test.dart` |
| Native definition controls | Keep selected form and canonical lemma; copy word and expression independently with one lookup; return to the same WebView | `integration_test/reader_flows_test.dart` |

Existing package suites cover finer-grained contracts: library filters,
favourites and undo, import validation and file-service failures, translation
language selection and retries, definition copying, reader chrome/drawers,
search, bookmarks, appearance, accessibility semantics, and lifecycle races.
They remain part of `make verify`; root tests target composition across these
boundaries instead of duplicating every widget assertion.

The reader browser suites load actual bundled assets in Chromium/WebKit and
cover selection gestures, CFI round trips, document security, image policies,
and highlight geometry/pixels. See
[`reader_webview/README.md`](../../packages/reader_webview/README.md).

## Visual Baselines

There are 26 captures per profile (130 PNGs), including appearance before/after
scrolling to the last control, translation language menus and collapsed/expanded
translation details, single-word/text translations and contextual dictionary
expressions and separate word/contextual translations. Expanded-detail captures scroll to the final alternative
when the viewport cannot display the complete result:

| Profile | Logical viewport | Theme | Locale | Text scale |
| --- | --- | --- | --- | --- |
| `phone` | 390 x 844 | Light | English | 1 |
| `dark` | 390 x 844 | Dark | English | 1 |
| `largeText` | 320 x 568 | Light | German | 2 |
| `landscape` | 844 x 390 | Light | English | 1 |
| `tabletRtl` | 768 x 1024 | Dark | Arabic | 1 |

Only widget goldens use these dimensions. The native suite keeps the device's
real viewport and records it in its results. Large-text onboarding content is
scrollable; the navigation controls remain outside the scrolling content.

Fonts are explicitly registered from the component library and `test/fonts/`.
Book IDs are fixed because cover colors depend on the ID. Backend responses,
preferences, and storage are controlled. Pending translation is held by a
completer and captured at a fixed pump interval, without waiting on an infinite
progress animation.

Pixel equality is exact, not a permissive percentage threshold. Use the same
Flutter/engine and host platform for comparisons; changes of engine or host
rasterizer can require a reviewed baseline migration. Initial baselines were
created on macOS arm64 with Flutter 3.44.9. Keep that environment for automated
comparisons until another host has been explicitly validated.

When the design intentionally changes:

```sh
make test-goldens
make update-goldens
make test-ui
```

Review changed images before accepting them. Do not update goldens just to turn
an unexplained failure green. Committed expected images live in `goldens/`;
comparison failures write actual/master/diff PNGs under `.local/ui-goldens/`.
The comparison command does not regenerate expected images.

## Native Artifacts and Isolation

The book translation flow also checks that the request and visible Sentence
quote contain the selected sentence only, without neighbouring paragraph text.
The highlight-overlap flow saves two highlights, selects a wider sentence,
translates it without changing storage, explicitly replaces the contained
highlights, re-saves without losing the note, and reopens the rendered result.
Selection is constructed in the real WebView DOM; native handle dragging still
requires a device gesture check.
Android captures use `adb exec-out screencap -p` on the device selected by
`make test-device`, including native WebView handles and system overlays. A
test-only loopback server on an ephemeral host port receives named capture
requests through ADB reverse on device port 34179. It validates artifact names
and PNG signatures, bounds waits, rejects overlapping captures and closes the
forwarding on driver completion. Neither it nor its client is used by the app's
normal entry point. Direct `flutter drive` invocations must also set
`READFLEX_NATIVE_DEVICE=<device-id>`; iOS keeps the standard screenshot path.
Do not use `convertFlutterSurfaceToImage()` with native Hybrid Composition:
the SDK screenshot callback can wait indefinitely for an already-consumed frame.

The fifteen native scenarios write screenshots and `results.json` to a fresh
`.local/ui-device/run-*/` directory, printed by the driver.
Screenshots are inspection artifacts, not cross-device golden assertions. The
driver checks that screenshot data is nonempty; test assertions check actual
widgets, service arguments, storage, DOM content, and highlight geometry.
Artifacts use stable names within each run; one platform does not overwrite
another's screenshots. Results include platform, viewport and completion time.

With `COVERAGE=1`, the host driver collects VM line coverage into `lcov.info` after
the interactions. It does not add coverage work to production builds or during
interaction measurements. Native coverage needs a debug build and a reachable
VM service, and intentionally does not claim branch coverage.

After `make coverage` and native runs on unchanged Dart inputs, combine them:

```sh
node scripts/coverage_report.mjs .local/coverage/<host-run> \
  .local/ui-device/<ios-run> .local/ui-device/<android-run>
```

This updates that host report with the union of line hits, not an average of
percentages. Each supplied native run must have `COVERAGE=1` evidence. Hashes
cover owned Dart sources/tests, pubspecs, root lockfile and SDK pin; mismatched or
incomplete runs fail instead of silently merging stale results. Hashes do not
attest native plugin binaries or an OS/GPU configuration.

`report.json` lists package totals, executable line/branch gaps, actual test
names/outcomes, and unmeasured files. Generated Dart and third-party packages
are excluded. Export-only/constants files can legitimately be unmeasured; the
report lists them rather than inventing a denominator. JS/browser suite success
is recorded separately and is not included in a Dart coverage percentage.

`test/support/ui_test_app.dart` mounts production `AppScopes` and its router.
Repositories use an in-memory SQLite connection and a temporary document root;
preferences use their in-memory platform implementation. Services outside the
app are deterministic test doubles. Cleanup stops the server, closes resources,
restores preferences, and removes fixture files, including on setup failure.

The FB2 book is seeded with a stable ID, not imported through a native file
picker. Native article rendering uses the actual article repository; the root
article flow separately tests import UI through that repository. Fixtures are
original text, with no third-party books or live network content.

These tests do not open the user's application database, but installing any
test build can replace an app with the same bundle ID. Prefer a dedicated
simulator/emulator rather than a device holding valuable app data.

## Checks Still Requiring Native or Live Environments

- Native long-press handles, edge dragging and cross-page selections in
  Vertical/Scroll/Slide, and iOS system context menus. DOM selection is not a
  simulation of those OS controls.
- Actual app switching, GPU/context loss, process death, and release-mode
  performance. Synthetic lifecycle callbacks do not reproduce these conditions.
- Native file picker, permissions, installed system dictionary handlers,
  ML Kit model downloads, and real airplane-mode behavior.
- VoiceOver/TalkBack interaction. Semantics assertions are useful but do not
  run an operating system screen reader.
- Physical Android/iOS variations and all supported book formats. Native
  fixtures currently cover FB2 and an article; they are not a full format matrix.
- Live backend authentication, timeouts and provider quality. No external
  service is contacted by fixture flows.

Inactive feature stubs are not implemented or presented as tested end-to-end
features. Add cases here as those contracts become real.

## Performance Guardrails

No screenshot polling, fixture dependencies, or test font assets are added to
the release app. Read-only WebView test accessors do not register listeners.
Root library tests assert storage-read counts; native resume asserts WebView
state identity. Library scaling bounds mounted tiles during scrolling at 20k
items. Search stress checks burst emission/copy volume, partial updates,
immutable snapshots, debounce, cancellation, terminal errors and completion.
Tests use bounded readiness waits and wait for document content
after bridge readiness. These checks detect specific regressions, not FPS or
memory budgets. Use existing `benchmarks/` and profile-mode device measurements
for performance claims.
