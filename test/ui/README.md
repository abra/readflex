# UI Verification

This suite complements feature widget/cubit tests and Pagecraft's reader-engine
tests. It is not a claim that every OS interaction or every possible
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
| Thumb reach | On a 390x844 phone held in one hand, the screen's primary action (Library "+"), frequent switches (the Library's collection switcher, sharing the bottom capsule with "+") and controls used repeatedly in one session (the reader capsule, match navigation) sit in the bottom third. Secondary panels are bottom sheets whose header lands mid-screen; the in-place reader panels use `AppInlineSheet` at 60%. The top holds orientation and rare actions: titles (the Library title is a heading, not a second collection switcher), search entry, Display. Narrowing the Library has one place, the Collections picker; there are no filter chips at the top. Do not move a frequent action to the top for tidiness, or stack a second row of chrome at the bottom. |
| Scrolling | Short content has no false overflow/fades; long content has reachable last actions and a fixed header where the component promises one. Content scrolling under a fixed header clips on a band below its last control (the Library's 12dp under search), so the fade never sits flush against a field. Test both ends, keyboard insets and rotation. |
| Controls | Check enabled, selected, disabled and loading semantics, localized labels, hit targets and duplicate-command prevention, not just the visible icon or color. Shared accessibility tests exercise both mobile platform policies. |
| Text and themes | Check real long translations, phone RTL, 200% text, light/dark themes and essential text visibility. Contrast tests cover named text/background pairs, not every possible rendering. |
| State and recovery | Check empty, loading, success, error/retry and offline states where supported. UI-only changes must not add network/storage work. Keep unfinished product flows explicitly out of scope. |
| Performance | Prefer existing bounded-work tests and profile real interactions when changing layout, lists or gestures. Do not add intrinsic layout, broad rebuilds, repeated text measurements or eager loading merely to satisfy a screenshot. |

The component specifications and dimensions remain in
[`component_library/README.md`](../../packages/component_library/README.md);
semantics ownership and inline-link exceptions remain in
[`ACCESSIBILITY.md`](../../ACCESSIBILITY.md). Keep this checklist focused on
verification instead of maintaining another set of design tokens.

Reader content is a separate surface from app controls: pagecraft lays out tables
and code by CSS's own rules, not a generic app rule. Font/layout changes can
affect pagination and saved anchors. Gesture changes need pagecraft widget tests
plus on-device iOS and Android checks; a synthesized gesture is not a finger on
Flutter's adaptive selection handles. Brightness and unrelated reader
behavior are not part of a general UI consistency pass.

Expanded windows use bounded Library and Practice workspaces, and reader
Contents/Search become trailing panels. Review narrow and expanded windows
separately: resizing must retain queries, selection and focused fields. The
phone's frequent controls remain at the bottom; expanded panels use explicit
Close rather than vertical sheet gestures.

Control readability uses the separate 600×480 medium-window threshold:
default utility glyphs become 24dp and important captions use existing 15sp
roles. Test 800×1280 portrait and 1280×800 landscape as well as narrow Split
View and phone landscape. Short filter labels still need a 48×48dp target;
larger glyphs must retain the surface gutter and explicit size overrides.
Reader captions may grow their dock at 130%; large text must not be clipped
to its normal-height strip. The tablet Practice and Reader golden flows cover
both medium and expanded windows, with Arabic/German 200% Practice cases.

Close out with the commands actually run, the profiles/devices inspected and
unverified cases. Put temporary screenshots/logs under `.local/`, and generated
review reports under `.local/reports/`. A passing checklist is not a claim of
complete accessibility, visual correctness or performance on all devices.

## Commands

Run from the repository root with the FVM-pinned Flutter SDK:

```sh
make get
make test-tools
make test-ui-contracts
make test-ui
make test-goldens
make verify
make coverage
make test-performance
```

To export the actual full-screen golden captures for a visual review while
keeping baseline comparison enabled:

```sh
READFLEX_VISUAL_CAPTURE_DIR=.local/ui-review/actual make test-ui
```

The export mirrors the `goldens/<profile>/...` paths. It does not accept a
changed image as a baseline or suppress a failed comparison.

- `test-ui-contracts`: component-library/toast tests, import form/navigation, Display
  step navigation and representative root layout contracts. No goldens, devices
  or API keys; a focused subset, not a replacement for feature tests or `verify`.
  These tests also run in the existing full suite, without a second invocation.
- `test-ui`: production-root flows and golden comparisons, no device needed.
- `test-goldens`: only visual comparisons, without modifying baselines.
- `test-tools`: Dart coverage/benchmark tool tests in `test/tooling/`, also
  included in `make test`; these run without the app UI suites or Node.js.
- `verify`: formatting, analysis, all active package tests (pagecraft's
  included) and root UI/goldens. Native device tests are separate.
- `coverage`: the same test suites with owned Dart line/branch reports and
  per-test outcomes in a fresh `.local/coverage/run-*/` directory.
- `test-performance`: repeated 1k/5k/20k Library/search workloads, with diagnostic
  JSON results in `.local/performance/`; no hard machine-dependent time limit.

For native reader flows, boot a simulator/emulator or connect an authorized device:

```sh
fvm flutter devices
make test-device DEVICE=<device-id>
# Full native phone regression, including Practice and Arabic reading:
make test-phone DEVICE=<phone-id>
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
native keyboard scenario. Check both the global preference and the selected
device's override; a per-device value can keep the hardware keyboard connected
after changing only the global setting. The iOS binding captures the Flutter
surface, not the OS keyboard overlay; the test additionally asserts real nonzero
keyboard insets.

### Native tablets

Use an iPad Simulator or Android tablet emulator whose actual logical viewport
has a shortest side of at least 600dp. The tablet batches use the native window;
they do not resize a phone with a synthetic tester surface. The current profiles
are a 13-inch iPad at 1032 × 1376 logical pixels and an Android tablet at
1280 × 800dp, with the dimensions reversed after rotation.

```sh
make test-tablet DEVICE=<tablet-id>
make test-tablet-layout DEVICE=<tablet-id>
# Also verify the same open book across real orientation changes:
make test-tablet-layout DEVICE=<tablet-id> ROTATION=1
```

`test-tablet` runs the 20-case native regression batch: tablet viewport, Library
controls/collections, text-book and article actions, EPUB/FB2/MOBI import, CBZ
zoom, PDF, the native MOBI backend, notes and toasts. `test-tablet-layout` runs
four tests covering Library grid/list and RTL selection, book columns and reading
position, Arabic EPUB page direction, and completion of a Practice session.
Both targets use the normal test app with isolated storage and deterministic
service implementations; no live backend or private configuration is needed.

Physical rotation is opt-in (`ROTATION=1` or `ROTATION=true`). When the output
prints `READFLEX_TABLET_ROTATE:portrait` or `READFLEX_TABLET_ROTATE:landscape`,
turn the device or use the Simulator's native Device > Rotate Left/Right command
within 45 seconds. The test waits for the actual Flutter viewport and ready page
layout, then checks the reading anchor, controller identity, font scale and
columns. The default run checks the current native orientation without waiting
for these commands.

Before tablet runs, dismiss first-launch OS overlays such as Android's "Viewing
full screen" prompt. Such a window can take focus, intercept taps and prevent a
clipboard read even while Flutter still finds the underlying widget. Inspect the
native screenshot and focused window before treating this as an app regression.

`test-phone` runs the corresponding native phone batch with 22 cases, including
the same reader/Library actions plus Arabic reading and a full Practice session.
It requires an actual window below 600dp on its shortest side; the tablet batch
requires at least 600dp. Neither substitutes a synthetic tester viewport.

These tests complement the existing phone RTL and large-text cases. They provide
functional assertions and screenshots on the named simulator/emulator profiles;
they do not establish physical-device selection-handle behavior, VoiceOver or
TalkBack correctness, or device FPS. Artifacts and restore/cleanup rules are the
same as for `test-device` above.

## Coverage

| Surface or contract | Automated checks | Where |
| --- | --- | --- |
| Shared control accessibility | Named tap targets under iOS/Android policies, selected/disabled choice semantics, stable control geometry and named/noninteractive busy actions in LTR/RTL at normal/large text | `packages/component_library/test/control_accessibility_contract_test.dart` |
| Toast feedback | Bottom placement 16dp above the safe inset or 8dp above the highest `ToastAvoidArea` (Library floating controls, reader chrome, selection panel, search bar), with the avoided control still tappable and a control mid-entrance counted at rest; neutral `inverseSurface` plate with a colored glyph in light/dark; 4s success and 6s/persistent error durations; 48dp circular/localized Close, full-message semantics, independent swipe, idle insertion and responsive safe-area layout; full-screen success/error over Library in all profiles, with RTL overridden to 390 x 844 | Toast package tests, `toast_golden_test.dart`, `integration_test/toast_test.dart` |
| Theme text roles | Primary/secondary text on surface, sheet and input backgrounds; foreground/fill contrast for primary, secondary and destructive controls in light/dark | `packages/component_library/test/app_theme_test.dart` |
| Onboarding | Welcome screen: an 80dp app icon above "Welcome to Readflex", a heading that shrinks instead of breaking a word (CJK never shrinks); four feature rows of equal weight with the real menu labels and no feature staged as a hero; Add your first book / Not now callbacks, 48dp targets and contrast; 480dp column on tablets, large-text scrolling in every locale, RTL; five visual profiles. Routing and the saved preference after remount live in `test/app/readflex_app_test.dart` | `onboarding_test.dart` |
| Library | Search/clear, empty results, layout preference; UI changes do not issue new storage reads | `app_flows_test.dart` |
| Library appearance | Cover-only 2:3 grid with generated title/author/site text on the artwork and 12dp gaps, display sheet, empty search results (Clear search) and pressed Display/search-clear actions in all profiles; list rows with title and author at the cover top and the status at its bottom, without the file format, and the compact favourites badge in light/dark and on an Arabic phone; an empty collection offers Show entire Library | `library_golden_test.dart`, `collection_management_golden_test.dart` |
| Wide windows | A 13-inch iPad in both orientations: the Library list in two columns (light, dark, Arabic RTL) that screen readers still count per source, the grid adding columns instead of growing covers, the empty library at the onboarding width (also on narrow tablets and landscape phones), directional cancel FAB and contextual selection capsule, and the Appearance sheet's Columns row in light/dark. Selection controls and the modal collection sheet retain readable labels and reachable actions with enlarged text and constrained widths. | `tablet_layout_golden_test.dart`, `library_selection_bar_test.dart`, library `library_wide_window_test.dart`, reader `reader_appearance_sheet_test.dart` |
| Reader text layout | The window and the Columns choice reach pagecraft's page settings and style end to end: every window keeps the 32em measure, phones and narrow windows keep one column (a portrait phone page stays as it was, a landscape phone centres the measure), a wide window adds Auto/One/Two, articles keep one column at the measure, PDF pages keep their layout and offer no Columns row; tablet-sized windows (shortest side ≥600) get 12.5% larger book and article text, rotation keeps it, narrow Split View and phone landscape stay at the phone size, and the reader's own text size stays 100% and applies on top; the keyboard, even across a rotation, never turns a portrait page into a spread; book and article text keeps clear of a landscape phone's side insets (display cutout) while the page fills the window | `reader_text_layout_test.dart`, reader `reader_text_columns_test.dart` and `reader_device_font_scale_test.dart`, pagecraft `text_page_geometry_test.dart` |
| Settings consistency | Display and Appearance share header geometry, section typography/gaps, content gutters, 48dp stepper targets and full-width fades in light/dark themes | `settings_consistency_test.dart` |
| Library scaling | Grid/list remain virtualized with 20k books, callbacks address the right item, cached projections are reused; 320/390dp grids adapt columns at 200% text | `library_scaling_test.dart` |
| Collection recovery | Retain last loaded scopes on partial failure; Retry replaces the error inside the same sheet, including phone/landscape, 200% text and RTL | Library bloc and `collection_scope_recovery_test.dart` |
| Library floating actions | One `AppFloatingCapsule`: collection switcher (icon, name, chevron; reads as Choose collection + name) then the filled "+" at the outer end in LTR/RTL. Practice appears only with a destination and a positive due count, separately 8dp above it, centred over "+": 32dp card silhouettes with an opaque surface fill, popover shadow and soft static primary-colour aura, transparent surrounding button area, 48dp target and due badge contained in it; content cannot show through the cards in light/dark themes; showing or hiding Practice preserves the capsule's bottom anchor and adjusts content clearance to the visible actions. 4.5:1 collection label contrast over black and white covers, tinted inside a collection; 320dp cap and start gutter with long names and at 320dp/200%; text clamped at 200%; resize skipped under reduced motion; hidden in selection and in an empty library, kept in an empty collection; scope changes rebuild only the floating actions; 16dp above the safe inset or the keyboard, following a moving keyboard without dipping into the inset; the last row ends 16dp above the highest floating action with a home indicator and an open keyboard | Library screen tests, Practice and Library goldens |
| Library review deadline | One foreground timer refreshes only the eligible review queue at its next deadline, so a due reminder can appear without a gesture. Background cancels the timer; resume refreshes immediately; disposal cancels pending work. No periodic polling or source-list reload; failed reads preserve counts and retry after one minute while active | Library bloc and Practice-entry tests |
| Continue reading | Full-width band with 12dp above and below its unchanged 60×90 cover (cover on the grid's first column, mirrored in RTL); full titles wrap and fit both width and height with adaptive font size and no ellipsis, all visible text stays within the cover's vertical bounds, including 320dp phone RTL/200%; the book is not repeated below it and returns to its place while searching or in a collection; long-press selects it in place, the card stays while selecting so covers do not move, and a selected card keeps its progress bar visible in light/dark; five visual profiles | `library_home_golden_test.dart`, Library screen and card tests |
| Built-in collections | Favourites as the first row directly under the picker search (with or without built-ins, inside a built-in), then Library, then Books, Comics and New rows of a mixed library, no manage menu, localized search, the title naming the chosen scope, rows that would repeat Library left out, in all visual profiles | Library state/bloc/screen tests, `library_home_golden_test.dart` |
| Collections | Create with selected book, rename, cancel/confirm deletion; preserve book and clean membership | `app_flows_test.dart` |
| Sheet navigation | Header/system Back vs whole-flow dismissal, URL draft retention, guarded collection Close; delete/discard headers across visual profiles | Feature widget tests, `collection_management_golden_test.dart`, `integration_test/library_controls_test.dart` |
| Review session return | On iOS/macOS the session fades in place over 200ms, skipped under reduced motion; closing Session complete must not slide its background over Review ahead. The hub reloads counts after the session closes | `practice_review_transition_test.dart`, `practice_flow_test.dart` |
| Practice review timestamps | Word/highlight rows and word details show the stored FSRS date in the current locale and local time, respecting 12/24-hour preference. Muted supporting text wraps on a separate line from the source/chapter so long metadata cannot hide the schedule; composite row semantics retain it. Unscheduled items keep New/Due. Check phone/tablet, light/dark, large text and phone RTL | Practice `practice_review_schedule_test.dart`, `practice_schedule_golden_test.dart` |
| Collection layout | Light/dark, 200%, landscape, RTL; selector menu alignment, active favourites badge, edit form and unsaved changes confirmation | `collection_management_golden_test.dart` |
| Selection and languages | Separate cancel FAB and contextual selection capsule, compact two-column language picker, one-column large-text fallback and full-width scroll fades in all visual profiles | `library_golden_test.dart` |
| Native library controls | Selection, compact language grid without scrolling, one Display/Language modal with identical step height, immediate language changes without leaving the picker (including RTL and reselecting), explicit Back, light/dark choices, import header alignment, close-icon gutters and 48dp targets across import/Display/Language/Manage collection, keyboard, short collection without false overflow/fades, inline keep/discard edits on an isolated fixture library | `integration_test/library_controls_test.dart` |
| Display step navigation | Stable bounds during slides, UI locale change including RTL, Back/Close/system Back, interrupted transitions, rotation, retained Display scroll, small screens, large text and reduced motion | `packages/features/library/test/library_display_sheet_test.dart` |
| Article import | Extraction error, retry, actual repository/SQLite write, root remount; offline/online button availability | `app_flows_test.dart` |
| Import recovery | Book progress/failure, invalid Paste, article failure and retained URL; readable actions in EN/RU/AR phone, dark, 200% DE and landscape | `import_flow_golden_test.dart` |
| Book import consent | Stable compact step height throughout forward/back animations at four phone widths; content grows without false overflow/fades; all locales at 1x/2x text, normal legal-paragraph line height, inline-link taps/semantics, explicit acceptance, rotation, reachable actions and return height | `import_book_terms_test.dart`, `import_flow_golden_test.dart` |
| Translate | Success, error, pending result, Nothing to translate with Define; word/text answers before context, unfilled language menus and collapsed/expanded details in all profiles. The same-language flow (no request, Define outcome, Select language for long text) lives in translate `translate_same_language_test.dart`; the coordinator's language outcomes in `contextual_translation_coordinator_test.dart` | `surfaces_golden_test.dart` |
| Contextual translation | Selected word/IPA, context-first answer with expression scope, separate word meaning, collapsed/expanded explanations in all visual profiles | `translation_word_golden_test.dart` |
| Reader search surfaces | Inline sheet at 60% (full in landscape and with large text) with shared 16px content insets, recent queries with long text, active result, previous/next controls and return action in all visual profiles | `reader_search_golden_test.dart` |
| Native translation sheet | Real phone viewport, word/expression scopes including rather, IPA rendering, visible general meaning, native clipboard and target-language change with deterministic responses | `integration_test/translation_sheet_test.dart` |
| Define | Single definition, inflected word plus contextual expression, and not-found surfaces in all profiles | `surfaces_golden_test.dart` |
| Shared text tools | Search clear control and highlight palette in all profiles; import menu layout | `surfaces_golden_test.dart` |
| Reader selection tip | Waits for the painted page, a book page turn hides it for the session (a restore does not), a selection ends it for good, a returning reader never sees it; the inverse plate in light/dark and 200% text, where "Got it" moves below the message | `reader_selection_tip_test.dart`, reader `reader_selection_tip_test.dart` and `reader_selection_tip_cubit_test.dart` |
| Reader progress row | The page slider spans the row right above the capsule; under it the book's chapter (one line, truncating first) and the page label (never loses digits), inset to the track's ends; at 2x text the chapter takes up to two lines with the page label below; capsule-width cap on landscape and tablet, in all visual profiles | `reader_progress_golden_test.dart`, reader `reader_bottom_chrome_test.dart` |
| Reader page animations | Slide/Cover is global, selected in Library's Display sheet; Reader retains direction controls and Reset leaves the global effect unchanged. Legacy source animation keys cannot override it. Localized 48dp choices at 320dp/200% and phone RTL, persistence/reopening and stable Display/Language step heights. Both renderers share geometry/painting, keep the effect fixed during an active turn and preserve layout, selection, position and zoom when it changes | Library display/cubit tests and `library_golden_test.dart`; reader appearance/screen tests; pagecraft `text_pages_view_test.dart`, `fixed_pages_view_test.dart`, `pdf_pages_view_test.dart` |
| Reader appearance | Portrait/landscape, 2x text and RTL; header/values readable, final control and font sample reachable, Appearance/Font retain equal height with manual return | `reader_appearance_golden_test.dart` |
| Native book actions | Expand word to phrase, translate exact final range, copy result, Define fallback, dismiss selection menu | `integration_test/reader_flows_test.dart` |
| Native persistence | Explicit highlight writes text/CFI to real repository, renders nonzero geometry after reopen, and opens by tapping its Highlights row without copy/arrow controls | `integration_test/reader_flows_test.dart` |
| Native book import | EPUB, FB2 and MOBI built in the test import through `pagecraft` on the device: title and author from the book, the cover decoded by the platform codecs and scaled to 480×720, each import under 5 s, all three shown in the Library | `integration_test/native_import_test.dart` |
| Native DjVu | Original three-page fixture imports through the production helper with document metadata and a first-page cover; native DjVu pages render, hidden-text search opens its result, Pages requests previews, a page bookmark persists, and reopening restores the saved page | `integration_test/djvu_reader_test.dart`; reader `reader_djvu_surface_test.dart`, `reader_screen_djvu_test.dart` |
| Initial position persistence | A reopened book opens on its saved page and closing it keeps the saved position | reader `reader_screen_text_test.dart` |
| Active chapter contrast | Actual selected TOC tile uses paired foreground/background colors, including alpha compositing; light/dark, large text and phone RTL snapshots | `reader_contents_golden_test.dart` |
| Contents tab layout | Tabs fill the sheet with equal widths when possible; otherwise each icon and label keeps its measured width and shares the spare space equally. Horizontal scrolling and edge fades appear only when the total width overflows, preserving the 8dp bar inset, 16dp scrolling gutter, large text and phone RTL | reader `reader_contents_tab_bar_test.dart`, `reader_toc_drawer_test.dart`; `reader_contents_golden_test.dart`, `pdf_contents_golden_test.dart` |
| Native reader lifecycle | Search navigation and CFI survive synthetic pause/resume without replacing the page view; the page keeps its text | `integration_test/reader_flows_test.dart` |
| Native article actions | Store fixture article, search near its end and return without remounting, keep one native tint when changing palette color, expand word to sentence, translate complete range, close menu | `integration_test/reader_flows_test.dart` |
| Native search UI | Query actual book, previous/next matches, reopen without rescan, system Back, return to initial reading position without remounting, clear field/remove history, empty results, trailing glyph alignment with 48dp targets | `integration_test/reader_flows_test.dart` |
| Native bookmarks | Create, reopen book, confirm storage, delete/restore by icon from Contents and reopen again; trash/Undo/close glyph alignment with 48dp targets; same icon flow in CBZ | `integration_test/reader_flows_test.dart`, `integration_test/comic_highlights_test.dart` |
| Native appearance | Font step preserves sheet height and waits for Back; theme/font/size/page-turn reach preferences and the page's text size, persist per book, reset without replacing the live page view | `integration_test/reader_flows_test.dart` |
| Native translation failure | Failed response, closed selection menu, retry same range successfully | `integration_test/reader_flows_test.dart` |
| Native translation controls | Expand details without a request; change target preserving auto source and exact range; return to selection on the same page | `integration_test/reader_flows_test.dart` |
| Native definition controls | Keep selected form and canonical lemma; copy word and expression independently with one lookup; return to the same page | `integration_test/reader_flows_test.dart` |

Existing package suites cover finer-grained contracts: library built-in collections,
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

pagecraft's own suites cover formats, CSS, layout, selection, CFI round trips,
image policies and highlight geometry; see
[`pagecraft/README.md`](../../packages/pagecraft/README.md).

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
Library also captures its list and pressed search-clear action at 390 x 844
in dark Arabic under `goldens/dark/*-phone-rtl.png`; this does not use the
tablet RTL viewport. Library press snapshots allow one 100ms frame for gesture
recognition and another for the highlight to paint before release, then assert
that the action opens Display or clears the search.

Onboarding has an additional 390 x 844 light Arabic phone capture at
`goldens/phone/onboarding-phone-rtl.png`, alongside its normal dark Arabic
tablet profile. Its supported-format caption includes DjVu in every locale;
the 320 x 568/200% cases check all locales for overflow and reachable actions.

Only widget goldens use these dimensions. The native suite keeps the device's
real viewport and records it in its results. Large-text onboarding content is
scrollable; the Add your first book / Not now actions remain outside the scrolling content.

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
Selections are made with a long press dragged across the words, through the
page's `SelectionArea` and the reader's action menu; dragging the platform's
handles still requires a hands-on device check.
Android captures use `adb exec-out screencap -p` on the device selected by
`make test-device`, including Flutter selection handles and system overlays. A
test-only loopback server on an ephemeral host port receives named capture
requests through ADB reverse on device port 34179. It validates artifact names
and PNG signatures, bounds waits, rejects overlapping captures and closes the
forwarding on driver completion. Neither it nor its client is used by the app's
normal entry point. Direct `flutter drive` invocations must also set
`READFLEX_NATIVE_DEVICE=<device-id>`; iOS keeps the standard screenshot path.
Do not use `convertFlutterSurfaceToImage()` with native Hybrid Composition:
the SDK screenshot callback can wait indefinitely for an already-consumed frame.

The native scenarios write screenshots and `results.json` to a fresh
`.local/ui-device/run-*/` directory, printed by the driver. Driver protocol
logging is disabled because it duplicates screenshot payloads into large logs.
Unlock the test device and dismiss first-run OS overlays before running them
(for example Android's "Viewing full screen" prompt after a cold emulator boot).
Flutter finders cannot detect these windows; inspect native screenshots when
taps, clipboard access or page gestures unexpectedly fail together.
Screenshots are inspection artifacts, not cross-device golden assertions. The
driver checks that screenshot data is nonempty; test assertions check actual
widgets, service arguments, storage, the page's text, and highlight geometry.
Artifacts use stable names within each run; one platform does not overwrite
another's screenshots. Results include platform, viewport and completion time.

With `COVERAGE=1`, the host driver collects VM line coverage into `lcov.info` after
the interactions. It does not add coverage work to production builds or during
interaction measurements. Native coverage needs a debug build and a reachable
VM service, and intentionally does not claim branch coverage.

After `make coverage` and native runs on unchanged Dart inputs, combine them:

```sh
fvm dart scripts/coverage_report.dart .local/coverage/<host-run> \
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
report lists them rather than inventing a denominator.

`test/support/ui_test_app.dart` mounts production `AppScopes` and its router.
Repositories use an in-memory SQLite connection and a temporary document root;
preferences use their in-memory platform implementation. Services outside the
app are deterministic test doubles. Cleanup closes resources,
restores preferences, and removes fixture files, including on setup failure.

The FB2 book is seeded with a stable ID, not imported through a native file
picker. Native article rendering uses the actual article repository; the root
article flow separately tests import UI through that repository. Fixtures are
original text, with no third-party books or live network content.

`integration_test/library_controls_test.dart` also checks Library search/clear
with native text input: the field retains focus and bounds, the source returns,
and storage read counts stay unchanged. Its `library-search-clear.png` records
the populated field; iOS captures omit the operating system keyboard overlay.

These tests do not open the user's application database, but installing any
test build can replace an app with the same bundle ID. Prefer a dedicated
simulator/emulator rather than a device holding valuable app data.

## Checks Still Requiring Native or Live Environments

- Native selection handles, edge dragging and iOS system context menus. A
  synthesized long-press drag is not a simulation of those OS controls. A
  selection carried across a page turn is checked with taps and swipes
  (pagecraft `text_pages_view_test`, reader `reader_screen_text_test`,
  `integration_test/native_text_reader_test.dart`); dragging a selection handle on a device
  to the page edge does not turn the page.
- Actual app switching, GPU/context loss, process death, and release-mode
  performance. Synthetic lifecycle callbacks do not reproduce these conditions.
- Native file picker, permissions, installed system dictionary handlers,
  ML Kit model downloads, and real airplane-mode behavior.
- VoiceOver/TalkBack interaction. Semantics assertions are useful but do not
  run an operating system screen reader.
- Physical Android/iOS variations and all supported book formats. Native
  fixtures cover text books, articles, CBZ, PDF and DjVu in separate scenarios;
  they are not a complete format, decoder or device matrix.
- Live backend authentication, timeouts and provider quality. No external
  service is contacted by fixture flows.

Inactive feature stubs are not implemented or presented as tested end-to-end
features. Add cases here as those contracts become real.

## Consistency Regressions

The component tests check 24dp sheet content edges independently from 48dp
action targets, circular Copy feedback, and opaque selection-marker contrast.
Feature tests cover selected collection semantics/background geometry in both
directions and themes, retained query/scroll position through Manage, and
Back/Close draft outcomes without extra Library reads. Reader tests cover mixed
quote/note directions, localized page fallback labels and add/edit/clear notes.
`reader_note_golden_test.dart` adds draft/discard states in all five profiles.
Onboarding asserts the static RTL layout with no running animations;
toast tests distinguish 4s success feedback from the longer error duration and
the non-expiring accessible-navigation error policy.

`library/test/sheet_layout_contract_test.dart` measures footer gaps for standalone
and nested collection routes with 0/24/34dp system insets and an open keyboard,
plus bulk-action glyph gutters in both directions. Manage tests cover independent
trash/curved-arrow Undo toggles, stable row/footer bounds, cancel/save/failure
and lazy source rows without removal-animation ticks. Collection goldens include
the pending-removal state; native Library controls check the same Undo target
and the footer's actual screen-to-button gap. The reader search-overlay test
also checks equal 48dp chrome targets and circular feedback without remounting
or resizing the reader.

The native consistency batch combines existing Library/import controls and CBZ
Highlights flows with the note editor's keyboard, discard and clear workflow:

```sh
READFLEX_NATIVE_DEVICE=<id> fvm flutter drive \
  --driver=test_driver/ui_driver.dart \
  --target=integration_test/ui_consistency_test.dart -d <id>
```

Use the same target on Android and iOS. Fixtures remain isolated, without live
providers. The note-editor case checks the real sheet and keyboard, not dragging
an image selection or opening its native context menu. Screenshots and results
go to `.local/ui-device/`; this batch does not measure release FPS or replace
VoiceOver/TalkBack and physical-device gesture checks. After device tests, run
the normal `lib/main.dart` app so the test harness's empty final frame is not
left on the device.

## Performance Guardrails

Approved secondary-surface changes have additional production-widget coverage:
`reader_contents_golden_test.dart` checks icon-only bookmark Undo geometry, full
quote expansion, filtering and whole-row navigation without copy/arrow controls.
`reader_highlight_list_tile_test.dart` covers text/image row actions, accessible
navigation semantics, missing anchors and independent expansion at 2x text.
`add_to_collection_golden_test.dart` covers destination membership, the modal
multi-collection bottom sheet, explicit confirmation, creation within the same
route and draft return.
Both use the real repositories and a phone-sized Arabic override for `tabletRtl`.
Import phase and translation menu snapshots remain in the existing suites.
Reader-native rendering is tested separately: `comic_zoom_test.dart` zooms and
turns a comic, opens Pages, waits for the engine's previews and navigates from
a thumbnail. `pdf_reader_test.dart` opens a generated PDF on pagecraft. It checks
the default trimmed page rendered denser than the screen and sharp zoom, the
dark theme's colors, then turns both options off from the real Appearance
sheet, runs PDF search, draws a saved highlight and previews the pages.
Its double taps use a real-time gap without awaiting a rendered frame between
the taps; slow emulator frames must not turn them into separate single taps.
`results.json` records the inter-tap interval, zoom scales and chrome visibility.
`table_rendering_test.dart` checks that a table wider than the page keeps its
words whole, scrolls sideways under a swipe and, at its edge, turns the page.
`pdf_contents_golden_test.dart` and `reader_appearance_golden_test.dart`
snapshot the PDF Contents tabs and the PDF Appearance sheet in every profile;
`reader_pdf_controls_test.dart` checks that sheet choices reach the engine's
page view.
The 500-page cubit/widget workloads bound active requests and retained previews;
they do not assert FPS or peak image-decoder memory.

`comic_highlights_golden_test.dart` exercises the production Highlights drawer
with 100 saved areas, previews loaded only for mounted rows, tab/close
cancellation, retained filters, expandable notes and row navigation; preview
failure and retry are reader `reader_image_highlight_preview_test.dart`.
New image-area snapshots cover light/dark, narrow 2x text, landscape and Arabic
on a 390x844 phone. The thumbnail widget tests assert crop pixels, aspect ratio
and clamping, rather than just finding an Image widget.
`integration_test/comic_highlights_test.dart` verifies icon-only bookmark Undo, the
engine's thumbnails and destination-page navigation on iOS and Android using the
generated CBZ, without network access or changes to on-page selection gestures.

No screenshot polling, fixture dependencies, or test font assets are added to
the release app. Root library tests assert storage-read counts; native resume
asserts the page view's state identity. Library scaling bounds mounted tiles during scrolling at 20k
items. Search stress checks burst emission/copy volume, partial updates,
immutable snapshots, debounce, cancellation, terminal errors and completion.
Tests use bounded readiness waits and wait for document content
after bridge readiness. These checks detect specific regressions, not FPS or
memory budgets. Use existing `benchmarks/` and profile-mode device measurements
for performance claims.
