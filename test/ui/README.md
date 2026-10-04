# UI Verification

This suite complements feature widget/cubit tests and the reader's Chromium and
WebKit regressions. It is not a claim that every OS interaction or every possible
combination of settings is automated.

## Review Checklist

Use this checklist for the affected component and its consumers, not as a
reason to redesign working screens. It adapts the relevant UI/UX Pro Max rules
on stable layout, component states, semantic tokens and accessibility to
Readflex. Its web styles, generated palettes, framework preferences and numeric
presets are not project requirements. No external skill installation, Python
CLI, network lookup or generated design-system files are needed to run tests.

Before implementation, identify the actual user problem and inspect the existing
component, feature state and regression tests. For visual proposals, compare
full screens using the same viewport, locale, theme, text scale and content;
label crops as details, not as replacement screenshots. Obtain approval when
the task asks for proposals. Preserve unrelated UI and intentional differences
such as immediate settings versus explicitly saved collection drafts.

| Check | Readflex contract and evidence |
| --- | --- |
| Consistency | Reuse semantic tokens, header, choice, input and action components from `component_library`; compare settings via `settings_consistency_test.dart`. Do not invent per-screen colors, typography or icon geometry. |
| Stable layout | Errors and busy states must not unexpectedly displace controls. Verify geometry during transitions as well as after settling; import form and shared sheet tests cover these paths. Do not solve this with arbitrary empty fixed-height space. |
| Navigation | Back unwinds a step; Close exits the flow subject to draft guards. Check system Back, scrim/drag, interrupted transitions and reduced motion in the owning feature tests. |
| Scrolling | Short content has no false overflow/fades; long content has reachable last actions and a fixed header where the component promises one. Test both ends, keyboard insets and rotation. |
| Controls | Check enabled, selected, disabled and loading semantics, localized labels, hit targets and duplicate-command prevention, not just the visible icon or color. Shared accessibility tests exercise both mobile platform policies. |
| Text and themes | Check real long translations, phone RTL, 200% text, light/dark themes and essential text visibility. Contrast tests cover named text/background pairs, not every possible rendering. |
| State and recovery | Check empty, loading, success, error/retry and offline states where supported. UI-only changes must not add network/storage work. Keep unfinished product flows explicitly out of scope. |
| Performance | Prefer existing bounded-work tests and profile real interactions when changing layout, lists or gestures. Do not add intrinsic layout, broad rebuilds, repeated text measurements or eager loading merely to satisfy a screenshot. |

The component specifications and dimensions remain in
[`component_library/README.md`](../../packages/component_library/README.md);
semantics ownership and inline-link exceptions remain in
[`ACCESSIBILITY.md`](../../ACCESSIBILITY.md). Keep this checklist focused on
verification instead of maintaining another set of design tokens.

Reader content is a separate surface from app controls. Wide tables/code may
need horizontal scrolling; do not clip or squeeze them to obey a generic web
rule. Font/layout changes can affect pagination and saved anchors. Gesture
changes need reader JS/browser tests plus native iOS and Android checks; DOM
selection alone is not native handle dragging. Brightness and unrelated reader
behavior are not part of a general UI consistency pass.

Close out with the commands actually run, the profiles/devices inspected and
unverified cases. Put temporary screenshots/logs under `.local/`, and generated
review reports under `.local/reports/`. A passing checklist is not a claim of
complete accessibility, visual correctness or performance on all devices.

## Commands

Run from the repository root with the FVM-pinned Flutter SDK:

```sh
make get
make reader-browser-setup
make test-ui-contracts
make test-ui
make test-goldens
make verify
make coverage
make test-performance
```

- `test-ui-contracts`: component-library tests, import form/navigation, Display
  step navigation and representative root layout contracts. No goldens, devices
  or API keys; a focused subset, not a replacement for feature tests or `verify`.
  These tests also run in the existing full suite, without a second invocation.
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

Native tests unmount their root widget during cleanup to dispose subscriptions
and routes. Do not use `--keep-app-running` for normal verification: it leaves
the test process showing an empty surface, not the production Library. Relaunch
the regular app with `run.sh` after device testing.
On iOS Simulator, disable I/O > Keyboard > Connect Hardware Keyboard for the
native keyboard scenario. The iOS binding captures the Flutter surface, not the
OS keyboard overlay; the test additionally asserts real nonzero keyboard insets.

## Coverage

| Surface or contract | Automated checks | Where |
| --- | --- | --- |
| Shared control accessibility | Named tap targets under iOS/Android policies, selected/disabled choice semantics, stable control geometry and named/noninteractive busy actions in LTR/RTL at normal/large text | `packages/component_library/test/control_accessibility_contract_test.dart` |
| Theme text roles | Primary/secondary text on surface, sheet and input backgrounds; foreground/fill contrast for primary, secondary and destructive controls in light/dark | `packages/component_library/test/app_theme_test.dart` |
| Onboarding | Skip/complete, routing, saved preference after remount; all three pages in five visual profiles | `onboarding_test.dart` |
| Library | Search/clear, empty results, layout preference; UI changes do not issue new storage reads | `app_flows_test.dart` |
| Library appearance | Grid, display sheet, empty search results in all profiles | `library_golden_test.dart` |
| Settings consistency | Display and Appearance share header geometry, section typography/gaps, content gutters, 48dp stepper targets and full-width fades in light/dark themes | `settings_consistency_test.dart` |
| Library scaling | Grid/list remain virtualized with 20k books, callbacks address the right item, cached projections are reused | `library_scaling_test.dart` |
| Collections | Create with selected book, rename, cancel/confirm deletion; preserve book and clean membership | `app_flows_test.dart` |
| Sheet navigation | Header/system Back vs whole-flow dismissal, URL draft retention, guarded collection Close; delete/discard headers across visual profiles | Feature widget tests, `collection_management_golden_test.dart`, `integration_test/library_controls_test.dart` |
| Collection layout | Light/dark, 200%, landscape, RTL; edit form and unsaved changes confirmation | `collection_management_golden_test.dart` |
| Selection and languages | Bottom selection bar, explicit cancel, compact two-column language picker, one-column large-text fallback and full-width scroll fades in all visual profiles | `library_golden_test.dart` |
| Native library controls | Selection, compact language grid without scrolling, one Display/Language modal with identical step height, immediate language changes without leaving the picker (including RTL and reselecting), explicit Back, light/dark choices, import header alignment, close-icon gutters and 48dp targets across import/Display/Language/Manage collection, keyboard, short collection without false overflow/fades, inline keep/discard edits on an isolated fixture library | `integration_test/library_controls_test.dart` |
| Display step navigation | Stable bounds during slides, UI locale change including RTL, Back/Close/system Back, interrupted transitions, rotation, retained Display scroll, small screens, large text and reduced motion | `packages/features/library/test/library_display_sheet_test.dart` |
| Article import | Extraction error, retry, actual repository/SQLite write, root remount; offline/online button availability | `app_flows_test.dart` |
| Import recovery | Book progress/failure, invalid Paste, article failure and retained URL; readable actions in EN/RU/AR phone, dark, 200% DE and landscape | `import_flow_golden_test.dart` |
| Book import consent | Stable compact step height throughout forward/back animations at four phone widths; content grows without false overflow/fades; all locales at 1x/2x text, normal legal-paragraph line height, inline-link taps/semantics, explicit acceptance, rotation, reachable actions and return height | `import_book_terms_test.dart`, `import_flow_golden_test.dart` |
| Translate | Success, error, pending result; word/text answers before context, unfilled language menus and collapsed/expanded details in all profiles | `surfaces_golden_test.dart` |
| Contextual translation | Selected word/IPA, context-first answer with expression scope, separate word meaning, collapsed/expanded explanations in all visual profiles | `translation_word_golden_test.dart` |
| Reader search surfaces | Side-sliding panel with shared 16px content insets, recent queries with long text, active result, previous/next controls and return action in all visual profiles | `reader_search_golden_test.dart` |
| Native translation sheet | Real phone viewport, word/expression scopes including rather, IPA rendering, visible general meaning, native clipboard and target-language change with deterministic responses | `integration_test/translation_sheet_test.dart` |
| Define | Single definition, inflected word plus contextual expression, and not-found surfaces in all profiles | `surfaces_golden_test.dart` |
| Shared text tools | Search clear control and highlight palette in all profiles; import menu layout | `surfaces_golden_test.dart` |
| Reader appearance | Portrait/landscape, 2x text and RTL; header/values readable, final control and font sample reachable, Appearance/Font retain equal height with manual return | `reader_appearance_golden_test.dart` |
| Native book actions | Expand word to phrase, translate exact final range, copy result, Define fallback, dismiss selection menu | `integration_test/reader_flows_test.dart` |
| Selected page continuation | Both endpoints in Slide/Vertical, one-page synthetic swipe, menu hides/reanchors, complete range reaches Translate | `integration_test/reader_flows_test.dart` |
| Native persistence | Explicit highlight writes text/CFI to real repository and renders nonzero geometry after book reopen | `integration_test/reader_flows_test.dart` |
| Native reader lifecycle | Search navigation and CFI survive synthetic pause/resume without replacing WebView state; DOM remains readable | `integration_test/reader_flows_test.dart` |
| Native article actions | Store fixture article, search near its end and return without remounting, keep one native tint when changing palette color, expand word to sentence, translate complete range, close menu | `integration_test/reader_flows_test.dart` |
| Native search UI | Query actual book, previous/next matches, reopen without rescan, system Back, return to initial reading position without remounting, clear field/remove history, empty results | `integration_test/reader_flows_test.dart` |
| Native bookmarks | Create, reopen book, confirm storage, delete from Contents and reopen again | `integration_test/reader_flows_test.dart` |
| Native appearance | Font step preserves sheet height and waits for Back; theme/font/size/page-turn reach preferences and DOM, persist per book, reset without replacing live WebView | `integration_test/reader_flows_test.dart` |
| Native translation failure | Failed response, closed selection menu, retry same range successfully | `integration_test/reader_flows_test.dart` |
| Native translation controls | Expand details without a request; change target preserving auto source and exact range; return to selection in the same WebView | `integration_test/reader_flows_test.dart` |
| Native definition controls | Keep selected form and canonical lemma; copy word and expression independently with one lookup; return to the same WebView | `integration_test/reader_flows_test.dart` |

Existing package suites cover finer-grained contracts: library filters,
favourites and undo, import validation and file-service failures, translation
language selection and retries, definition copying, reader chrome/drawers,
search, bookmarks, appearance, accessibility semantics, and lifecycle races.
They remain part of `make verify`; root tests target composition across these
boundaries instead of duplicating every widget assertion.

`component_library/test/sheet_contract_test.dart` checks shared header geometry,
heading semantics, adaptive footer actions, stable busy-button size, and action
foreground contrast. Library tests cover a single book/article with and without
keyboard insets (no vertical overflow or fades), real overflow at both ends of a
long collection, failed collection loading/retry, and lazy collection rows.
Definition tests keep the header and Close action fixed while long entries scroll.

The reader browser suites load actual bundled assets in Chromium/WebKit and
cover selection gestures, CFI round trips, document security, image policies,
and highlight geometry/pixels. See
[`reader_webview/README.md`](../../packages/reader_webview/README.md).

## Visual Baselines

Each profile includes captures of search results, recent queries, appearance before/after
scrolling to the last control, translation language menus and collapsed/expanded
translation details, single-word/text translations and contextual dictionary
expressions and separate word/contextual translations, selection/language
controls, and collection edit/discard surfaces. Expanded-detail captures scroll to the final alternative
when the viewport cannot display the complete result:

| Profile | Logical viewport | Theme | Locale | Text scale |
| --- | --- | --- | --- | --- |
| `phone` | 390 x 844 | Light | English | 1 |
| `dark` | 390 x 844 | Dark | English | 1 |
| `largeText` | 320 x 568 | Light | German | 2 |
| `landscape` | 844 x 390 | Light | English | 1 |
| `tabletRtl` | 768 x 1024 | Dark | Arabic | 1 |

Import recovery also has `phoneRu` (390 x 844, light, Russian, 1x) and
`phoneRtl` (390 x 844, dark, Arabic, 1x) captures. The import RTL suite explicitly
overrides the tablet profile's viewport so RTL is verified on a phone too.

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
