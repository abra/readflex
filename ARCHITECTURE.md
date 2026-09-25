# Readflex Architecture

This document is the maintainer-facing architecture map for the current
Readflex codebase. Keep it aligned with real code when changing package
boundaries, dependency flow, app startup, routing, or known production gaps.

The code remains the source of truth. If this document and implementation
diverge, fix both in the same change.

## Architecture Style

Readflex follows a practical multi-package Flutter architecture inspired by the
WonderWords / Real-World Flutter approach:

- Feature code is grouped by feature package.
- Shared infrastructure is grouped by specialized package, not by a generic
  `common` package.
- The root app package composes dependencies, owns routing, and connects
  features through callbacks and narrow contracts.
- Feature packages do not depend on other feature packages.
- Repositories and services hide data sources, platform details, backend
  clients, and storage implementation from feature UI.

The resulting dependency direction is:

```text
lib/app
  -> features/* Screen or Sheet entry points
    -> feature Bloc/Cubit
      -> repository/service contracts
        -> local_storage, platform/backend adapters, filesystem

features/* do not import sibling features.
```

## Package Creation Rule

Use a separate package when code has a stable responsibility that is used by
more than one feature/package, or when the package boundary protects a
technical concern that should not leak into UI code.

Preferred package shapes:

- `packages/features/<feature>` for a screen, bottom sheet, or user-facing flow.
- `packages/<name>_repository` for domain persistence and data-source
  orchestration.
- `packages/<name>_service` for platform, backend, or infrastructure contracts.
- A named specialized package such as `component_library` or `reader_webview`
  when the responsibility is neither a feature nor a
  repository/service.

Do not create a broad `common` package. If code is reusable, name the actual
responsibility. The existing `packages/shared` package is intentionally narrow:
it currently contains only cross-feature contracts for reader text actions. Do
not add unrelated helpers, widgets, or business logic there.

## Root App Package

The root package (`readflex`) is the composition and integration layer.

| Path | Responsibility |
|------|----------------|
| `lib/main.dart` | Calls `starter()` only. |
| `lib/app/starter.dart` | Flutter binding and `runApp` in the same error zone, bloc observer, build/frame tracing, recovery screen. |
| `lib/app/app_bootstrap.dart` | Validates configuration before monitoring, retains monitoring across retries, prepares reader assets/server, transfers ownership to the running app. |
| `lib/app/config` | Compile-time/runtime configuration via `ApplicationConfig` and environment helpers. |
| `lib/app/composition.dart` | Creates the database, repositories, services, filesystem directories, and app-wide dependencies. |
| `lib/app/dependency_container.dart` | Dependency holder plus ordered, idempotent resource disposal and bootstrap rollback. |
| `lib/app/resource_disposer.dart` | Reverse-order cleanup registry; retains externally owned monitoring during rollback. |
| `lib/app/dependency_scope.dart` | Inherited scope for app-wide dependencies. |
| `lib/app/app_scopes.dart` | Mounts dependency, preference, connectivity, and lifecycle scopes. |
| `lib/app/readflex_app.dart` | Material app, theme/locale and a router retained across preference changes. |
| `lib/app/app_lifecycle.dart` | Restores a stopped reader server on iOS resume; best-effort resource disposal on detach, not pause or widget unmount. |
| `lib/app/routing.dart` | GoRouter route table, route guards, navigation callbacks, feature wiring. |
| `lib/app/screens` | App-only screens that are not reusable feature packages. |

There is no global service locator. App-wide objects are created once in
`composition.dart`, stored in `DependenciesContainer`, mounted in the widget
tree, and passed explicitly into feature entry points from `routing.dart`.
Owned resources register cleanup as they are created and close in reverse
order. A partially failed bootstrap rolls back only resources created by that
attempt; the logger and error reporter remain available for retry diagnostics.

`AppBootstrap.run` owns each attempt until its synchronous `onReady` callback
returns. Dependency construction rolls back its partial resources internally;
asset preparation or synchronous `onReady` failures roll back the completed
container. Later Flutter build errors use the installed error handlers; they
are not caught as a failed bootstrap attempt.
Configuration and monitoring failures use the same recovery path. The running
container closes monitoring on final disposal. Composition timing stays in logs,
not in the widget tree. Tests substitute bootstrap factories rather than opening
production storage or contacting a backend.

Lifecycle resume requests share one in-flight reader-server restart. Detach
waits for that restart before closing resources and prevents subsequent restarts
on the disposed runtime. This preserves the existing terminal-detach policy;
an embedding that reattaches a disposed runtime would need a fresh bootstrap.

Reader navigation uses `ReaderRouteArguments` for both a preloaded book and the
post-open callback. The URL source ID is authoritative; a mismatched preloaded
book is ignored, and deep links need no payload. Route builders wire features;
the import-sheet adapter retains temporary file access until import finishes.

`AppBlocObserver` disables event/transition formatting in release, before any
state `toString()` calls. Error reporting remains enabled. Test-only partial
configuration/container doubles live in `test/support/app_fakes.dart`.

## Dependency Flow

Feature entry points follow this rule:

```text
routing.dart
  passes repositories/services/callbacks to Screen or Sheet

Screen/Sheet
  creates Bloc/Cubit and owns feature composition

View/private widgets
  read Bloc/Cubit state, dispatch events, and call UI callbacks
```

Rules:

- `routing.dart` is allowed to import feature packages and connect them.
- Feature packages must not import sibling feature packages.
- Feature `View` widgets must not receive repositories, services, parsers,
  DAOs, or backend clients directly.
- Small UI-only state may use a feature-local UI cubit.
- Feature widgets can use `context.read<T>()` for their own bloc/cubit. Prefer
  assigning it near the top of `build()` or the callback scope when that makes
  callbacks easier to read.
- Navigation belongs to the root app/router layer. Features receive callbacks
  such as `onSourcePressed`, `onReadPressed`, or `onArticleTitlePressed`.

This keeps feature UI testable and prevents accidental coupling between
features.

## Accessibility

Accessibility is a UI contract in this codebase. Prefer built-in Flutter and
Material semantics first, then add explicit `Semantics` to custom controls whose
role, state, value, or gesture would otherwise be unclear.

Reusable component semantics belong in `component_library`; feature-specific
labels and values belong inside the feature package that owns the UI. Do not
pass repositories, services, parsers, or storage objects into Views for
accessibility. Derive labels and values from the existing bloc/cubit state and
UI callbacks.

Keep the detailed rules in `ACCESSIBILITY.md` aligned with real code and tests.

## Localization

`readflex_localizations` is the single source of truth for supported locales,
generated Flutter localization delegates, and user-facing UI copy. The root app
wires `ReadflexLocalizations.localizationsDelegates`,
`ReadflexSupportedLocales.locales`, and the current locale from
`PreferencesScope.localeOf(context)` into `MaterialApp`.
The user-selected locale is persisted in `preferences_service`; the Library
display sheet owns the current language picker through a feature cubit.

Feature packages may depend on `readflex_localizations` for UI labels,
validation text, toast text, empty states, tooltips, and semantics labels. Bloc
and Cubit state should not store localized UI strings. Prefer typed enum error
codes in state, then map those codes to `context.l10n` in the View/Sheet that
renders the message. Custom backend or parser reasons may still be carried as a
separate custom message when the source already produced a meaningful
user-facing reason.

User content such as book titles, article titles, author names, URLs, and
collection names is data, not UI copy, and should not be translated by the app.

When adding or renaming a localized key:

- Update the English template ARB and every supported locale ARB.
- Regenerate typed classes with `fvm flutter gen-l10n` from
  `packages/readflex_localizations`.
- Keep tests on stable contracts: supported locale metadata, delegates, and
  typed state/error codes rather than hardcoded business-layer UI strings.

## Package Map

### Core Contracts and Storage

| Package | Responsibility | Local dependencies |
|---------|----------------|--------------------|
| `domain_models` | Pure domain models, enums, value objects, and app/domain exceptions. No Flutter, storage, or service dependencies. | none |
| `local_storage` | Single Drift database (`readflex.db`), tables, DAOs, migrations, storage rows. | none |
| `component_library` | Design tokens, theme extensions, reusable UI components, bottom-sheet shell, shared visual primitives. | none |
| `readflex_localizations` | Generated Flutter localizations, ARB files, supported locale metadata, and `BuildContext` localization helpers. | none |
| `shared` | Narrow cross-feature contracts. Currently reader text-action and selection contracts. | `domain_models` |

Domain models are the neutral contract between repositories, services, blocs,
and UI. Storage rows and DAO types should remain behind repositories.

### Repositories

| Package | Responsibility | Local dependencies |
|---------|----------------|--------------------|
| `book_repository` | Imported books, cover metadata, source bookmark/progress, filesystem ownership for books. | `domain_models`, `local_storage`, `monitoring` |
| `article_repository` | Extracted articles, bounded remote assets, and vertical HTML reader content. | `domain_models`, `local_storage`, `monitoring`, `remote_content_policy` |
| `collection_repository` | Manual library collections and built-in favorite membership. | `domain_models`, `local_storage` |
| `highlight_repository` | Highlight persistence and domain mapping. | `domain_models`, `local_storage` |

Repositories orchestrate data sources and return domain models/exceptions.
Feature blocs/cubits talk to repositories; feature UI should not import DAOs.

Legacy vocabulary, flashcard, and FSRS storage tables/domain models are still
present for migration compatibility and future restoration. The active
Dictionary feature is a monolingual lookup surface and intentionally does not
reuse those saved-translation tables. The last revision containing the legacy
vocabulary features is `189e2cc1`.

### Services and Infrastructure

| Package | Responsibility | Notes |
|---------|----------------|-------|
| `article_extraction_service` | Remote article cleaner client and guarded client-fetch fallback extraction contract. | Validates every URL and redirect hop, bounds response size/time, and returns `ExtractedArticle` domain data. |
| `connectivity_service` | Reactive connectivity status and UI scope. | UI signal only; services still handle their own failures. |
| `contextual_translation_service` | Contextual translation request/result contracts, remote client, cache, and ML Kit offline fallback coordinator. | Used by the `translate` feature. |
| `dictionary_service` | System definition UI bridge contract and typed HTTP client/models for monolingual dictionary lookup. | Used by the `dictionary` feature; native implementations live in the app runners. |
| `device_screen_brightness` | Native/plugin brightness access. | Low-level platform package used by `screen_control_service`. |
| `monitoring` | Logger, log observers, analytics/error reporter contracts, GlitchTip reporting, and no-op fallbacks. | GlitchTip is active when configured; analytics remains a no-op. |
| `preferences_service` | Preferences model, storage, repository, service, and scope. | Used by Library, Reader, and app composition. |
| `remote_content_policy` | Shared outbound HTTP URL and DNS safety policy plus validated direct transport. | Rejects credentials, non-HTTP(S) schemes, private/local addresses, and unsafe or mixed DNS results; connects to the accepted address without a second DNS lookup. |
| `reader_server` | Localhost HTTP server for reader assets and book/article files. | Supports range requests for books and local article HTML/assets for WebView readers. |
| `reader_webview` | Foliate book WebView wrapper, vertical article HTML wrapper, JS bridges, asset extraction, metadata extraction. | Used by Reader and Import Flow. |
| `screen_control_service` | Keep-awake and brightness coordination for active reading sessions. | Wraps low-level brightness plugin. |
| `toast_service` | Thin toastification wrapper. | Feature packages do not import toastification directly. |

Some infrastructure packages are used by only one feature today. That is still
valid when the package boundary hides a platform/backend/lifecycle concern that
must remain replaceable.

### Feature Packages

| Package | UI surface | Direct local dependencies |
|---------|------------|---------------------------|
| `library_feature` (`packages/features/library`) | Main Library screen, source search/filter/list/grid, collection management. | `article_repository`, `book_repository`, `collection_repository`, `component_library`, `domain_models`, `preferences_service`, `readflex_localizations`, `toast_service` |
| `import_flow` | Import bottom sheet for books/articles. | `book_repository`, `component_library`, `domain_models`, `monitoring`, `reader_webview`, `readflex_localizations` |
| `reader` | Full-screen reader route and reader UI state. | `article_repository`, `book_repository`, `component_library`, `domain_models`, `highlight_repository`, `preferences_service`, `reader_webview`, `readflex_localizations`, `screen_control_service`, `shared` |
| `highlight` | Reader text action and highlight bottom sheet. | `component_library`, `domain_models`, `highlight_repository`, `readflex_localizations`, `shared` |
| `translate` | Reader text action and contextual translation bottom sheet. | `component_library`, `contextual_translation_service`, `preferences_service`, `readflex_localizations`, `shared` |
| `dictionary` | Reader Define action and monolingual definition bottom sheet with system-first fallback. | `component_library`, `dictionary_service`, `readflex_localizations`, `shared` |

`library_feature` is the Dart package name because `library` is a Dart language
keyword in source syntax. The user-facing label remains "Library".

## Feature Package Structure

A typical feature package contains:

```text
lib/<feature>.dart          public barrel/export
lib/src/<feature>_screen.dart or <feature>_sheet.dart
lib/src/<feature>_bloc.dart or <feature>_cubit.dart
lib/src/<feature>_state.dart / event files when needed
lib/src/private_widgets.dart
test/
```

Public exports should be narrow:

- Export screens/sheets/actions that other packages are allowed to compose.
- Keep bloc/cubit, state, private widgets, helper algorithms, and UI fragments
  under `src` unless tests or composition explicitly need them.
- Prefer `@visibleForTesting` over widening production APIs for tests.

Choose Cubit for simple command-style state changes and Bloc when the feature
needs event ordering, debouncing, restartable/droppable behavior, pagination,
streams, or several independent event types.

The root sequential Bloc transformer orders events within each `on<E>`
registration, not across event types. Related highlight edits/refreshes use one
explicitly sequential event bucket; independent Library loads use a generation
guard so a late result or failure cannot replace a newer snapshot. Deletion
feedback remains observable even when its accompanying snapshot is superseded.

## Reader Architecture

The reader is intentionally split across several packages:

| Package | Responsibility |
|---------|----------------|
| `reader_server` | Serves root-confined reader assets, book bytes, article HTML, and article-local assets through a token-scoped localhost URI. |
| `reader_webview` | Hosts foliate-js for books/comics, the vertical HTML shell for articles, JS bridge DTOs, asset extraction, metadata extraction. |
| `features/reader` | Reader screen, reader bloc/cubits, chrome, drawers, appearance, search, selection, brightness, keep-awake. |
| `shared` | `TextAction` plugin contract used by reader context-panel actions. |
| `features/highlight` | Implements `HighlightAction`. |
| `features/translate` | Implements `TranslateAction` and owns the translation sheet UI/cubit. |
| `features/dictionary` | Implements `DictionaryAction` and owns the remote definition sheet/cubit. |

The reader does not import the Highlight, Translate, or Dictionary feature
packages. `routing.dart` creates their `TextAction` implementations and passes
a list into `ReaderScreen`; the reader adds its UI-only `CopyTextAction`. The
selection popup renders colors and Highlight on the first row, then Copy,
Translate, and Define on the second row. Reader executes all feature actions
only through the `TextAction` contract.

Translation pronunciation/reading are optional fields of its own backend
response, obtained in the same provider call. The sheet displays them only when
the analyzed surface form matches the selected word. It does not call the
Dictionary service; offline translation remains usable without lexical metadata.
The same response can supply a larger `contextual_expression` grounded by the
backend in the selected occurrence. The sheet shows the general word meaning
directly under the word/phonetics, then names the expression and its translation
in a separate contextual section with the source sentence. Both answers remain
visible without expanding details; only explanations and alternatives collapse.
Phrase/full-text selections are not expanded, and no second provider request or
client-side expression search is introduced.

Translate/Dictionary cubits own per-operation cancellation signals; services
translate those into abortable HTTP requests and abort on their deadlines too.
Shared clients remain alive. Cancellation never initiates offline fallback.
Translation cache hits from the remote provider are immediate; cached offline
results are reused only after a fresh, eligible remote failure. Native work
already in progress may finish, but abandoned results are discarded.

Library state holds `LibrarySource` projections rather than full article bodies.
`ArticlesDao.libraryEntries` selects only metadata, and `ArticleRepository`
maps it into domain values. Reader/detail paths keep their full article reads.
Publisher EPUB/MOBI6/KF8 documents pass through the same sanitizer before Blob
navigation; the reader's iframe sandbox remains compatible with WebKit.

Dictionary lookup is deliberately distinct from translation:

```text
DictionaryAction
  -> SystemDictionaryService.showDefinition(term)
       -> iOS UIReferenceLibraryViewController / Android ACTION_DEFINE
  -> when the platform returns false only:
       DictionarySheet -> DictionaryCubit -> DictionaryLookupService
       -> POST /v1/dictionary/lookup
            -> Readflex Dictionary API -> DeepSeek
            -> validated response cache (memory + PostgreSQL)
```

Definitions remain in the language of the selected term. The backend receives
an optional source-language hint and sentence context, but no target language.
DeepSeek credentials and provider-specific prompting remain server-side; the
Flutter package depends only on the stable Readflex dictionary HTTP contract.

Reader-specific UI state is split by responsibility:

- `ReaderBloc` loads the source and persists reader position/highlight data.
- `ReaderUiCubit` owns chrome, drawer, tap-zone, and search-highlight UI state.
- `ReaderSearchCubit` owns in-reader search state and recent query callbacks.
  Streamed results/progress are batched at 16ms intervals, with an immediate
  terminal flush. Reset/replacement/close invalidate pending updates; renderer
  failures become UI error state, including synchronous failures.
- `ReaderSelectionCubit` owns active text selection payloads and the UI-only
  adjustment phase; it never performs pagination or DOM geometry work.
- `ReaderAppearanceCubit` owns reader appearance preferences.
- `ReaderBrightnessCubit` coordinates widget brightness, system brightness, and
  platform override behavior.

The WebView subtree is kept behind ready-state reader composition so routine
UI changes do not recreate the reader runtime unnecessarily. Books and comics
use the foliate WebView; articles use a separate vertical HTML WebView that
loads `content.html` and restores position through stable sentence anchors.

Comic gesture arbitration lives in `reader_webview` JS: edge taps are immediate,
centre taps distinguish chrome from double-tap zoom, and zoomed drags only pan.
Flutter owns chrome visibility and physical/logical page commands, with the
same tap-zone fraction passed to JS. The fixed-layout renderer serializes comic
navigation with one replaceable pending intent; other fixed-layout formats keep
their existing busy-input gate. The comic loader owns deduplicated image-blob
loads and bounded adjacent-page prefetch (8 MiB speculative encoded data), not
feature state or Flutter pointer-move callbacks.

Book selection navigation stays inside `reader_webview`'s JS runtime. A handle
drag never turns a page. A subsequent swipe or edge tap advances exactly one
page and moves the active endpoint just inside the new viewport. The opposite
DOM boundary stays fixed, including when navigation reverses or crosses it.
The paginator blocks WebView auto-scroll while paginated text is selected;
there are no edge-dwell timers. Selection cannot cross spine documents.
Continuous Scroll and fixed-layout books keep their navigation behavior.
iOS handles remain native; Android uses reader handles from the initial word
selection onward. A reader-only Android plugin setting consumes native long
press and dispatches normalized viewport coordinates to the JS selection start
module. Browser word-boundary operations create the range; the existing JS
controllers own handle movement and settling. No repository or feature bloc
participates in per-pointer work. Non-reader WebViews stay native. The DOM
Range remains the source of truth for text, CFI and annotations on both.
Geometry uses endpoints, not all selected line rectangles. Pointer updates
are coalesced per animation frame; full text/context is read only after the
gesture settles or on an explicit action. The Flutter menu hides without
disposal while adjusting and retains its chosen color. On iOS and Android the native
selection is not overpainted by the temporary SVG highlight preview.
The article reader applies the same single temporary tint rule on both iOS and
Android, for CSS and SVG previews. Clearing that preview leaves native selection
and persisted annotation renderers intact.
The article selection controller locks native handle auto-scroll. A separate
content swipe scrolls without changing the range; an offscreen endpoint gets
a temporary continuation control. Dragging that control preserves the opposite
DOM boundary, including reversal/crossing. iOS returns to visible native handles;
Android keeps the same controls before and after range updates. Touch
targets respect safe-area insets. Adjustment uses bounded endpoint geometry,
frame-coalesced pointer work and deferred text/context serialization; its UI
phase goes through the existing selection cubit. Book pagination is separate.
For Android articles the JS controller temporarily pins the content container,
preserving document height, to prevent native auto-scroll before JS events.
It restores normal layout before separate content gestures and while both
endpoints are offscreen. The guard does not move text nodes or rewrite
styles on every range change; cancellation/disposal restore original styles.
The Android WebView patch suppresses menu items without
finishing the native selection action mode for other consumers. Visible Android
readers opt into their own handles, retain Hybrid Composition and serialized pause/resume
handling. This requires device performance and background/foreground checks.
Browser tests do not substitute for native-handle checks on
physical devices; see `packages/reader_webview/README.md`.

Reader position writes are serialized and retain the 500ms trailing debounce.
Repositories update only CFI/progress; `markOpened` updates only the opened
timestamp. A delayed source refresh preserves live position and document
capabilities, and closing the bloc drains both queued and active writes.

Saved highlight edits use field-specific repository updates for color/note,
not full-object replacements from UI snapshots. Their event queue is separate
from position handling; annotation operations do not delay live page metrics.
Source reloads preserve newer annotation state. Typed mutation effects report
completion/failure through a listener without rebuilding the WebView subtree;
the context popup does not report success when merely enqueueing an edit.

The remote book byte cache is bounded by both 128 entries and 8 MiB of retained
buffers. Oversized reads are returned without admission to the cache, preserving
the working set. This is not a cap on total WebView memory or in-flight reads.
Selection navigation validates its document and gesture generation before
applying asynchronous results and disposes listeners when the chapter unloads.

Each reader WebView owns a bounded load session: one automatic replacement
after renderer termination, then a terminal failure exposed to `ReaderBloc`.
The replacement restores the last known position and ignores old bridge
callbacks. The feature shows its localized error/retry state on terminal load
failure; the WebView package does not access repositories or feature cubits.

Untrusted EPUB sections are sanitized before Blob creation when publisher
scripts are disabled (the application default). Article images are activated
only after the repository's guarded download succeeds; the article shell also
filters legacy saved fragments before insertion. These policies live in the
content-loading layers, separately from post-load typography normalization.

## Import and Article Flow

Book import:

```text
ImportFlowSheet
  -> pickBookFile callback from routing.dart
  -> importBookFile helper in import_flow
  -> BookRepository stores file/metadata
  -> reader_webview extracts metadata when needed
```

Article import:

```text
ImportFlowSheet
  -> ArticleExtractionService downloads/cleans article
  -> ArticleRepository stores article, assets, and content.html
  -> Reader opens content.html through ArticleHtmlReaderWebView
  -> ReaderBloc persists the same source progress model through repositories
```

Both the client-side extraction fallback and repository-owned image downloads
treat remote URLs as untrusted input. They validate every redirect target,
reject private/local address resolution, pin connections to validated IPs, and
enforce explicit request, byte, and asset-count limits before committing files
to article storage.

The import UI does not own storage details. It receives callbacks and reports
progress/result state back to the route that opened it.

Closing the import sheet does not cancel an already-started import.
`LibraryImportLauncher` separates sheet dismissal (its returned Future) from
successful persistence (`onImported`). The composition root invokes that
callback after book/article storage completes, even if the sheet is gone.
Library ignores completion after disposal. Cancellation/failure does not trigger
a redundant list read, and no database-wide subscription reloads Library on
every debounced reader-position write.

Library loads book metadata and a lightweight SQL projection of article metadata,
then caches its filtered/sorted visible items per state. Article body text and
reader anchors are not read for the list. SQL pagination and further Reader
controller decomposition remain separate work requiring behavioral/performance
baselines; the current projection keeps existing search/filter semantics.

## Data, Models, and Mapping

Use one domain model layer and source-specific storage/service models:

- `domain_models` contains stable app concepts such as `Book`, `Article`,
  `LibrarySource`, `Highlight`, `SourceType`, and domain exceptions. Dormant
  dictionary/flashcard/review models remain for storage compatibility.
- `local_storage` contains Drift tables, DAOs, migrations, and storage row
  shapes. File-backed migration fixtures cover historical schemas that require
  filesystem as well as SQL migration.
- Repositories map storage rows and filesystem/backend results into domain
  models.
- Feature blocs/cubits emit feature states built from domain models, not DAO
  rows or backend payloads.

When adding a new persistence-backed domain concept, prefer:

```text
domain_models        public domain type
local_storage        table/DAO/storage mapping
<thing>_repository   persistence orchestration and public operations
feature package      UI and state management
```

## Routing and Navigation

`lib/app/routing.dart` is the feature integration point:

- It imports all feature package public barrels.
- It passes repositories/services from `DependenciesContainer`.
- It creates navigation callbacks and result callbacks.
- It gates entry routes such as onboarding.
Features should express navigation needs through callbacks. They should not
call GoRouter to navigate to sibling features directly.

## Runtime Configuration

Configuration is read through `ApplicationConfig` and compile-time environment
values. Important development flags are documented in `README.md`.

Security boundary: static Readflex API credentials are development-only and
configuration validation rejects them in staging/production. Production must
use short-lived credentials issued by a backend authentication/attestation
flow. GlitchTip error reporting is enabled by
`GLITCHTIP_DSN` or the Sentry-compatible `SENTRY_DSN` fallback; performance
tracing is opt-in through `GLITCHTIP_TRACES_SAMPLE_RATE`.
Contextual translation and dictionary lookup default to the article cleaner
host. Development requests share the explicit `READFLEX_API_KEY`; the legacy
`ARTICLE_CLEANER_API_KEY` name remains accepted for local commands only.

`ReaderServer` exposes a process-local token-scoped base URI. Its book,
article, and asset routes resolve symlinks and enforce configured filesystem
roots. Files selected outside app storage receive a reference-counted grant
only for the metadata extraction operation.

## Known Non-Production Contracts

The project is not fully production-complete. These are intentional gaps unless
a task explicitly asks to implement them:

- Error reporting uses `GlitchTipErrorReporter` when a DSN is configured and
  falls back to `NoopErrorReporter` otherwise.
- `NoopAnalyticsReporter` does not send analytics telemetry.
- Production backend authentication/attestation and short-lived access tokens
  are not implemented; static build-time credentials are intentionally blocked.
- Flashcard, practice, profile, subscription, auth, AI, and notification
  packages are frozen outside the active package graph. Restore their legacy
  implementation from `189e2cc1` only if that product scope returns.

When replacing a remaining no-op with a production implementation, update this
document, the relevant package README, and tests around the public contract.

## Testing and Verification

Preferred checks:

```sh
make verify
make analyze
make test
```

`make verify` is the full local quality gate. It checks formatting without
rewriting files, analyzes the root app and every active package, then runs all
Dart, Flutter, and reader JavaScript tests.

Root UI flows in `test/ui/` mount the production root and router with real
repositories, isolated SQLite/preferences, and deterministic external services.
The same test-only composition serves `integration_test/`; it never invokes
production dependency composition or reads API keys. Native tests additionally
start the actual loopback reader server and load the bundled HTML/JS assets.
Views keep their normal bloc/cubit contracts; test fixtures do not introduce a
second production dependency path.

`make test-ui` runs these root flows and exact golden comparisons using bundled
fonts and explicit light/dark, compact/large-text, landscape, and RTL/tablet profiles.
`make update-goldens` is a separate, deliberate baseline update. Test fonts and
committed PNG baselines are not application assets. `make test-device DEVICE=<id>`
is opt-in and preserves the device's real viewport. It records screenshots under
`.local/ui-device/`, but does not replace native handle, OS lifecycle, GPU,
screen-reader, or live-backend checks. Coverage and limitations live in
[`test/ui/README.md`](test/ui/README.md).

`make coverage` runs the same suites with Dart VM line/branch instrumentation
and creates a fresh `.local/coverage/run-*/` report. The collector unions hits
from root and package tests, excludes generated/third-party code, and lists
unmeasured owned files explicitly. `COVERAGE=1 make test-device DEVICE=<id>`
collects native Dart line coverage after interaction tests. Combining reports
requires matching hashes of Dart sources, tests, pubspecs, lockfile, and SDK pin.
Native Swift/Kotlin and JS execution are not represented as Dart coverage.

Performance regressions have structural tests in the normal suite: Library
tile count stays bounded at 20,000 items and cached projections are reused;
bursty reader search bounds emissions and published result entries without
losing matches. `make test-performance` records workload timing separately in
`.local/performance/`. Timings are diagnostic, not machine-independent CI limits.

Browser regressions use pinned Playwright Chromium and WebKit against the real
bundled reader assets. Run `make reader-browser-setup` once after checkout (or
after updating its npm lockfile); Node.js 20+ and the browser engines are
required by `make test`. On Linux, install Playwright's host dependencies as
described in `packages/reader_webview/README.md`.

Focused package changes can use package-level `flutter test` or `dart test`.
Use broader checks when changing:

- shared contracts;
- repository behavior;
- package dependencies;
- reader WebView, reader server, or import flow behavior;
- app composition/routing.

Performance-sensitive reader/import changes should also be validated with the
existing logs, frame timing tracing, or benchmark harnesses under `benchmarks/`.

## Documentation and Comments

Documentation should explain contracts, responsibilities, and boundaries:

- Update `ARCHITECTURE.md` when package boundaries or dependency flow changes.
- Update package README files when public package APIs or responsibilities
  change.
- Add code comments only for intentional stubs, lifecycle/platform constraints,
  non-obvious algorithms, framework workarounds, or temporary contracts.
- Do not add comments that restate obvious code mechanics.

## Handoff Checklist

Before handing the project to another maintainer:

- Read `README.md`, `ARCHITECTURE.md`, and the README for each changed package.
- Confirm feature dependencies still flow through `routing.dart` -> `Screen` or
  `Sheet` -> `Bloc`/`Cubit` -> `View`.
- Confirm no feature package imports a sibling feature package.
- Confirm new shared code has a specialized package name and is not dumped into
  `shared`.
- Confirm generated files, vendor JS, and native bindings are not manually
  refactored unless the task is specifically about those assets.
- Run the appropriate checks and record any checks that could not be run.
