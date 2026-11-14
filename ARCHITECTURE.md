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
- A named specialized package such as `component_library` or `pagecraft`
  when the responsibility is neither a feature nor a
  repository/service.

Do not create a broad `common` package. If code is reusable, name the actual
responsibility. The existing `packages/shared` package is intentionally narrow:
it contains cross-feature UI and action contracts, their payloads, and shared
presentation statuses such as `WordSaveStatus`. Domain entities stay in
`domain_models`, and service interfaces stay with their owning service packages.
Do not add unrelated helpers, widgets, or business logic there.

## Dependency Workspace

The root `pubspec.yaml` explicitly lists 34 workspace members: the 32 packages
under `packages/` and the two maintained vendored forks under `third_party/`.
Together with the app, they share one root `pubspec.lock` and
`.dart_tool/package_config.json`. Member manifests use `resolution: workspace`.
Production and development dependencies resolve together, so incompatible
constraints must be reconciled when changing a package.

`make get` runs one `flutter pub get`. Use
`make get PUB_GET_FLAGS=--enforce-lockfile` for a locked restore, as CI does.
Running Pub or tests from a member directory uses the same workspace resolution;
it does not require a separate package lockfile. Pub removes old member lockfiles
and package configurations on the first restore after migration.

Dependency sharing does not grant import access: every package still declares
its own dependencies and follows the production rules checked by
`check_architecture.dart`. Keep local path declarations explicit. Package tests
still run from their owning directories, preserving fixtures, fonts, native
manifests and coverage labels. `make analyze` checks all active roots in one
invocation while respecting their analysis options.

`benchmarks/mobi_rust` and `benchmarks/reader_native` are outside the workspace,
with independent Pub/Cargo locks and package configurations. Their path
dependencies may consume Pagecraft without joining its development workspace.
Keep their opt-in setup/check commands separate. Benchmark fingerprints use the
root workspace lock for repository provenance and the experiment's own lock for
its actual resolution; there is no Pagecraft-specific Pub lockfile now.
Rust/Cargo toolchain pins and build hooks stay owned by their native packages.
`test/tooling/workspace_test.dart` guards membership, shared resolution and the
experiments' independent pins. It also keeps Drift's generator on the runtime's
API family. This metadata guard does not run generation; regenerate and compile
the outputs when changing the schema or generator pins, as the storage README
describes.

## Root App Package

The root package (`readflex`) is the composition and integration layer.

| Path | Responsibility |
|------|----------------|
| `lib/main.dart` | Calls `starter()` only. |
| `lib/app/starter.dart` | Flutter binding and `runApp` in the same error zone, bloc observer, build/frame tracing, recovery screen. |
| `lib/app/app_bootstrap.dart` | Validates configuration before monitoring, retains monitoring across retries, transfers ownership to the running app. |
| `lib/app/config` | Compile-time/runtime configuration via `ApplicationConfig` and environment helpers. |
| `lib/app/composition.dart` | Creates the database, repositories, services, filesystem directories, and app-wide dependencies. |
| `lib/app/dependency_container.dart` | Dependency holder plus ordered, idempotent resource disposal and bootstrap rollback. |
| `lib/app/resource_disposer.dart` | Reverse-order cleanup registry; retains externally owned monitoring during rollback. |
| `lib/app/dependency_scope.dart` | Inherited scope for app-wide dependencies. |
| `lib/app/app_scopes.dart` | Mounts dependency, preference, connectivity, and lifecycle scopes. |
| `lib/app/readflex_app.dart` | Retains the router across preference changes and resolves saved brightness/locale preferences. |
| `lib/app/readflex_platform_app.dart` | Cupertino/Material application root, platform theme and compatibility context; owns no feature state or dependencies. |
| `lib/app/app_lifecycle.dart` | Best-effort resource disposal on detach, not pause or widget unmount. |
| `lib/app/routing.dart` | GoRouter route table, route guards, navigation callbacks, feature wiring. |
| `lib/app/screens` | Recovery screen for a failed bootstrap, shown before dependencies and the router exist. |

There is no global service locator. App-wide objects are created once in
`composition.dart`, stored in `DependenciesContainer`, mounted in the widget
tree, and passed explicitly into feature entry points from `routing.dart`.
Owned resources register cleanup as they are created and close in reverse
order. A partially failed bootstrap rolls back only resources created by that
attempt; the logger and error reporter remain available for retry diagnostics.

`AppBootstrap.run` owns each attempt until its synchronous `onReady` callback
returns. Dependency construction rolls back its partial resources internally;
a synchronous `onReady` failure rolls back the completed container. Later Flutter build errors use the installed error handlers; they
are not caught as a failed bootstrap attempt.
Configuration and monitoring failures use the same recovery path. The running
container closes monitoring on final disposal. Composition timing stays in logs,
not in the widget tree. Tests substitute bootstrap factories rather than opening
production storage or contacting a backend.

Detach closes resources once and is terminal for the runtime; an embedding
that reattaches a disposed runtime would need a fresh bootstrap. Pause and
resume keep everything open.

Reader navigation uses `ReaderRouteArguments` for both a preloaded book and the
post-open callback. The URL source ID is authoritative; a mismatched preloaded
book is ignored, and deep links need no payload. Route builders wire features;
the import-sheet adapter deletes the picker's temporary copy (only inside the
app's temp/cache) once the import finishes.

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
- Imports between owned packages use public libraries, rather than another
  package's `src/` files or relative paths into its implementation.
- Production Dart library sources stay inside their package's `lib/` tree;
  imports, exports and parts must not pull in test, tool or build-hook sources.
- Feature `View` widgets must not receive repositories, services, parsers,
  DAOs, or backend clients directly.
- Small UI-only state may use a feature-local UI cubit.
- Feature widgets can use `context.read<T>()` for their own bloc/cubit. Prefer
  assigning it near the top of `build()` or the callback scope when that makes
  callbacks easier to read.
- The root app/router chooses destinations, pushes or replaces routes, and
  connects features through callbacks such as `onSourcePressed`, `onReadPressed`,
  or `onArticleTitlePressed`.
- Features may handle local Back/Close by dismissing their own screen or sheet
  with `Navigator.pop`/`maybePop`. Use the supplied UI callback when the parent
  owns closing the surface, including a step inside a retained modal route.

This keeps feature UI testable and prevents accidental coupling between
features.

## Platform UI Libraries

Flutter 3.50 separates the Material and Cupertino design libraries from the
framework. Owned UI imports `material_ui` and, where needed, `cupertino_ui`.
Use Flutter core `widgets`, `painting` and `rendering` imports for code that
does not need design-library widgets or themes. Do not re-export the SDK or
wrap every framework widget in `component_library`.

The application root is platform-specific: `ReadflexPlatformApp` mounts
`CupertinoApp.router` on iOS/macOS and `MaterialApp.router` elsewhere.
`AppScaffold` and `AppNavigationBar` select Cupertino page/navigation chrome
or Material scaffold/app-bar chrome. Shared `AppButton`, `AppIconButton`,
`AppTextField`, settings inputs and surfaces own the corresponding platform
controls and feedback. These are Flutter platform design widgets; the OS text
selection bridge is a separate capability.

The semantic contract remains in `component_library`: `AppThemeScope` provides
`AppThemeData`, `AppThemeColors`, `AppTextTheme` and `AppStatusColors` through
`context.appTheme`, `.colors`, `.text` and `.appColors`. Platform decisions use
`context.isCupertino` inside the owning UI component, including feature-local
pickers. They do not introduce platform-specific repositories, domain models,
blocs or separate feature state. Screens retain
routing → Screen/Sheet → Bloc/Cubit → View boundaries.

`AppTheme.forPlatform` caches theme adapters by platform and brightness.
iOS app chrome uses Cupertino system typography and opaque grouped surfaces;
Android retains the Material palette and Geist/Literata app roles. Reader
document typography, page appearance and pagination remain independent of app
chrome. Android semantic text comes from the localized Material theme, so
script-dependent geometry, letter spacing and baselines are preserved;
Cupertino typography stays explicitly defined by its adapter.
`AppSurfaceRole` describes content/review cards, floating toolbars, menus,
modals, fields and side panels. `AppSurfaceAppearance` resolves shape, fill and
depth against the existing semantic theme. Cupertino cards use continuous
corners without elevation; bounded toolbar blur and a soft shadow belong to
floating controls. Material retains its surface-container fills and painted
elevation. Feature Views choose the surface purpose, not a platform palette.
Pagecraft depends directly on the design libraries for selection
presentation and stays independent of Readflex's components and preferences;
the native selection bridge takes geometry/colors from its host.

`preferences_service` owns `AppThemeMode`. The app resolves it to a brightness
or follows the system; stored `system`, `light` and `dark` names are unchanged.
`AppPlatformTheme` intentionally installs a Material `Theme` compatibility
adapter even under Cupertino: Pagecraft's adaptive `SelectionArea` and legacy
dependencies still consume it. The root's `MaterialUiCompatibilityBridge`
also supplies legacy theme/localization context for third-party UI such as
toastification. These adapters do not select visible app controls. New shared
UI consumes semantic roles; `context.theme` is reserved for compatibility
code. `AppThemeScope` is an `InheritedTheme`, so modal routes capture semantic
and native themes together.

App-owned motion resolves both `MediaQuery.reduceMotion` and `disableAnimations`;
direct manipulation remains responsive. Shared UI uses
`context.reduceMotion`/`context.motion`; Pagecraft owns the equivalent policy
without depending on `component_library`.

## Accessibility

Accessibility is a UI contract in this codebase. Prefer built-in Flutter,
Material and Cupertino semantics first, then add explicit `Semantics` to
custom controls whose role, state, value or gesture would otherwise be unclear.

Reusable component semantics belong in `component_library`; feature-specific
labels and values belong inside the feature package that owns the UI. Do not
pass repositories, services, parsers, or storage objects into Views for
accessibility. Derive labels and values from the existing bloc/cubit state and
UI callbacks.

Keep the detailed rules in `ACCESSIBILITY.md` aligned with real code and tests.

## Shared Sheet Design

Sheet presentation belongs to `component_library`, not individual feature Views.
Short confirmations use `showAppConfirmationDialog`: native Cupertino alert
actions or a Material alert, with a safe default Cancel and caller-owned text.
The helper returns only `true`, `false` or null; the feature maps explicit
confirmation to its domain command. Library item deletion uses this alert;
collection draft guards keep their existing multi-step flow.
`showAppBottomSheet` owns modal presentation, handle, safe area and keyboard lift;
`ActionBottomSheetLayout` owns header geometry, gutters and pinned actions.
Android retains `ModalBottomSheetRoute`. iOS uses a content-fit
`CupertinoModalPopupRoute` with a native spring, opaque grouped surface and no
backdrop blur. In narrow windows the popup has an 8dp minimum safe gap and a
540dp maximum width. `AppSheetPresentation` distinguishes immediate settings,
saved forms, action lists and contextual controls: at 840×480dp, settings/forms
become centred 540dp modals, action lists use the trailing bottom edge and
contextual controls use a flush 420dp trailing panel. Window changes keep the
same route and reparent the keyed content, preserving drafts, steps and focus.
Both paths use the root navigator and preserve results, guards and reduced
motion. Mixed-step flows keep one presentation rather than changing routes.
Routed Cupertino sheets and narrow retained `AppInlineSheet` panels share the
internal `AppCupertinoSheetSurface`: the same opaque card, clipping, maximum
width, safe gaps and brightness-resolved scrim. Contents (including comic Pages)
and Search reuse `BottomSheetHeader` on these narrow iOS surfaces. Their retained
state and expandable heights remain owned by `AppInlineSheet`; expanded trailing
panels use the shared `sidePanel` surface, with their bottom safe area inside
the opaque panel. Appearance and Font fill the contextual panel's available
height through `ActionBottomSheetLayout.scrollable(expandBody: true)`.
The result resolves on pop; `onFullyHidden` follows the exit/removal. A guarded
step intercepts scrim dismissal and swallows downward drag without remounting
its body. System Back stays with the step's `PopScope`.

Cupertino sheet headers centre the title between native Back/Close slots and
move an overflowing title below navigation at full width. Material keeps its
existing title/action layout. Both use 48dp sheet controls and preserve
localized actions at large text. Cupertino's 44pt native navigation-bar content
height is a separate screen-chrome contract, not a reduction of shared targets.
`ActionBottomSheetLayout.scrollable` owns the single viewport for finite-content sheets
(Display, Appearance, Language, Translation and Definition). Forms and lazy lists
retain the default constructor, without duplicating headers or nesting viewports.
`AppSettingsSection` and `AppChoiceControl` supply common settings roles; features
provide localized options, state and callbacks. Appearance still commits through
its Cubit; collection drafts still require Save. Unifying visual roles must not
unify away these different persistence contracts. See the component-library
README for dimensions and cross-sheet regression tests.

Library Display and Language share one modal route and a common bounded height.
Display sizes to its content; Language's compact grid fits that space without
scrolling at standard phone text sizes. Scrolling remains a fallback for large
text or constrained viewports, without enlarging Display. The hidden parent
retains layout size, not input or semantics, so navigation needs no post-frame
measurement or intrinsic sizing.
Their slide/navigation state is local UI state; language persistence stays in
`LibraryLocaleCubit`. Language selection applies immediately without navigating;
Back returns to Display and Close dismisses the flow, retaining the selection.
The shared header supplies separate Back and Close actions.
Reader Appearance follows the same in-sheet navigation contract for its Font
sample picker: the parent determines height, selection stays on the child step,
and persistence remains in `ReaderAppearanceCubit`. Page-turn controls keep
their existing compact row and are absent for vertically scrolling articles.
Import forms and collection confirmations use the same header navigation:
Back unwinds a step, Close exits the flow subject to its draft guard. Footer
commands are not navigation controls. `showAppBottomSheet` keeps dismissal at
the presentation boundary; unguarded flows opt into `scrimClosesFlow` to separate
scrim dismissal from their `PopScope` system-Back handler. Guarded collection
forms retain explicit dismissal and never bypass their discard decision.
The import cubit retains URL drafts across menu navigation, not across closing
the sheet; closing still does not cancel an already-started import.

## Wide Windows

Layouts follow the window, never the device. `AppWindowSize.isWide` in
`component_library` is the one rule: a window at least 840 wide (Material
expanded) and 480 tall (medium). Phones in either orientation and narrow iPad
Split View windows keep the phone layout; full-screen iPads and large windows
get the wide one. It reads `MediaQuery.sizeOf`, so callers rebuild only when
the window is resized or rotated. Features decide with it or with their own
`LayoutBuilder` constraints, and keep one widget tree per surface: a number
(columns, a width cap) is a parameter of the existing widget, a different
structure is its own widget chosen in one place. `AppContentFrame` keeps
headers and scrolling workspaces aligned within a shared 1200dp maximum;
it preserves bounded height and does not measure intrinsic content.

Control readability has a separate medium-window threshold in `AppWindowSize`:
600dp wide and 480dp tall. Shared utility actions and filter captions use
existing icon/text tokens at this size, including portrait tablets and medium
Split View windows. This does not change the 840dp expanded-layout threshold
or scale the reading engine's text. Resizing is driven by the window's
`MediaQuery`, without device classification, services or stored preferences.

- Library: the lazy cover-only grid adds columns once covers would pass 160dp;
  generated artwork keeps its title and author/site text on the cover.
  Lists show two columns on expanded windows.
  Continue Reading is an inset panel, paired with Practice when there is room;
  full titles keep their bounded fit and the bottom collection/search/add
  capsule remains in thumb reach. The screen owns search mode, controller and
  focus; its presentation-only capsule changes to an editable field above the
  keyboard. Back clears the query and leaves search without changing the scope;
  Clear only empties the query. Empty states stop at 480dp.
- Practice: the expanded hub pairs the review overview with supporting lists;
  enlarged text returns it to one column. Review content and controls share a
  bounded workspace, with a 640dp study card and 480dp completion summary.
- Onboarding: narrow windows keep a 480dp column and pinned actions. Expanded
  windows place the greeting/actions beside the feature card; constrained
  height scrolls the workspace instead of clipping it.
- Reader: a measure of 32em of body text reaches pagecraft's page settings in
  every window (phone pages in portrait are narrower than it); wide windows
  add the Auto / One / Two Columns choice. pagecraft lays out one column or a
  landscape spread, and articles keep one centred column. Status, seeking
  and actions share one bounded bottom dock; expanded windows expose labels
  when text fits. `ReaderFloatingChromeLayout` measures the title, article
  progress, brightness controls and dock together without resizing the page.
  Constrained height moves brightness into a horizontal row and lets dock
  metadata share a row; both retain their existing state and action targets.
  This geometry stays in presentation, outside Reader services and pagecraft.
  See the reader and pagecraft READMEs.

Reading text size has a separate renderer rule: a tablet-sized window, at least
600dp on its shortest side, adds a 1.125 multiplier to book and article text
(`readerDeviceFontScale`). Android also applies a platform correction, ranging
from 1.12 at 360dp or less to 1.04 at 600dp or more, interpolated between them.
These multipliers compose; the tablet multiplier alone is a 12.5% increase.
The shortest side ignores orientation, so rotation never resizes the text, phones
stay phones in landscape, and a narrow Split View window reads like a phone.
The reader's own text size stays at 100%; the multiplier only reaches the
book style pagecraft lays out with.

In narrow windows, modal utility sheets use a 640dp Material width cap on
Android and a 540dp Cupertino popup cap on iOS. Expanded settings/forms use
the shared centred 540dp modal on both platforms. Reader
Contents and Search use the same `AppInlineSheet` instance as narrow windows,
presented as a flush 420dp panel at the trailing edge, with safe insets consumed
inside its content. Its
body, search query, focus and scroll state survive resizing between panel and
bottom sheet. Expanded panels have an explicit Close action and do not turn
vertical scrolling into sheet expansion or dismissal. Anchored popovers are
not implemented.

## Localization

`readflex_localizations` is the single source of truth for supported locales,
generated Flutter localization delegates, and user-facing UI copy. The root app
wires `readflexLocalizationsDelegates`,
`ReadflexSupportedLocales.locales`, and the current locale from
`PreferencesScope.localeOf(context)` into the selected `MaterialApp` or
`CupertinoApp` root.
The hand-maintained delegate list combines generated app strings with
standalone UI delegates. Do not edit generated files to replace the legacy
delegates that the SDK localization generator still emits.
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
| `local_storage` | Single Drift database (`readflex.db`, write-ahead log), tables, DAOs, migrations, storage rows. | none |
| `component_library` | Semantic theme contracts, platform adapters and App* controls, design tokens, modal/inline sheet shells and shared visual primitives. | `native_text_selection` |
| `readflex_localizations` | Generated Flutter localizations, ARB files, supported locale metadata, and `BuildContext` localization helpers. | none |
| `shared` | Narrow cross-feature UI/action contracts, selection payloads, and saved-word presentation status (`WordSaveStatus`). | `domain_models` |

Domain models are the neutral contract between repositories, services, blocs,
and UI. Storage rows and DAO types should remain behind repositories.

### Repositories

| Package | Responsibility | Local dependencies |
|---------|----------------|--------------------|
| `book_repository` | Imported books, cover metadata, source bookmark/progress, filesystem ownership for books. | `domain_models`, `local_storage`, `monitoring` |
| `article_repository` | Extracted articles, bounded remote assets, and vertical HTML reader content. | `domain_models`, `local_storage`, `monitoring`, `remote_content_policy` |
| `collection_repository` | Manual library collections and built-in favorite membership. | `domain_models`, `local_storage` |
| `highlight_repository` | Highlight persistence and domain mapping; a new text highlight registers its review row. | `domain_models`, `local_storage` |
| `dictionary_repository` | Saved words (`DictionaryEntry`) with their source anchors; saving a word registers its review row. | `domain_models`, `local_storage` |
| `fsrs_repository` | One FSRS review store over `review_items`/`review_logs`: due queue, narrow due/deadline snapshots (`ReviewQueueStatus`), per-type stats and streaks (`ReviewStats`), rating previews, backfill of untracked highlights. | `domain_models`, `local_storage`, `review_scheduler` |

Repositories orchestrate data sources and return domain models/exceptions.
Feature blocs/cubits talk to repositories; feature UI should not import DAOs.

Saved words and highlights share one review store. `dictionary_repository`
and `highlight_repository` register a `review_items` row when content is
saved (`insertOrIgnore`, so re-saving never resets scheduling);
`fsrs_repository` serves the due queue and stats and records ratings through
`review_scheduler`. User exclusion is stored on the review row separately from
its FSRS schedule; active queries omit it, while content deletion and Undo
preserve or remove the complete snapshot. The Dictionary feature's lookup is
monolingual; its Save writes the word with the definition as its meaning. Legacy flashcard tables
remain for migration compatibility only (last revision `189e2cc1`).

Review actions carry the displayed item's ID and presentation revision. One
sequential event queue covers ratings, removal, reveal and restarts; stale taps
cannot mutate the next card. Controls stay mounted but disabled while saving.
Vocabulary and session hydration batch first-anchor reads in groups of up to
500 entry IDs, selecting the earliest anchor with insertion-order timestamp
ties instead of issuing one request per word.

### Services and Infrastructure

| Package | Responsibility | Notes |
|---------|----------------|-------|
| `bounded_http` | Bounded, abortable backend HTTP POST transport. | Pure Dart; enforces one total deadline and a streamed byte limit, cancels late responses, and never closes the caller's client. Used by article extraction, translation and dictionary services; separate from public-content URL/DNS policy. |
| `article_extraction_service` | Remote article cleaner client and guarded client-fetch fallback extraction contract. | Validates every URL and redirect hop, bounds response size/time, and returns `ExtractedArticle` domain data. |
| `connectivity_service` | Reactive connectivity status and UI scope. | UI signal only; services still handle their own failures. |
| `contextual_translation_service` | Contextual translation request/result contracts, remote client, cache, and ML Kit offline fallback coordinator. | Used by the `translate` feature. |
| `dictionary_service` | System definition UI bridge contract and typed HTTP client/models for monolingual dictionary lookup. | Used by the `dictionary` feature; native implementations live in the app runners. |
| `monitoring` | Logger, log observers, analytics/error reporter contracts, GlitchTip reporting, and no-op fallbacks. | GlitchTip is active when configured; analytics remains a no-op. |
| `native_text_selection` | System selection controls over supplied Flutter text geometry. | Used by `pagecraft` and `component_library`; no feature/domain dependencies. UIKit on iOS 17+, system `TextView` on Android, with Flutter fallback for unsupported layouts. Application menus stay in Flutter; editable fields keep their existing IME connection. See [the package README](packages/native_text_selection/README.md). |
| `preferences_service` | Preferences model, storage, repository, service, and scope. | Used by Library, Reader, Practice, and app composition. Practice limits (`practiceNewCardsPerDay`, `practiceReviewHighlights`, `practiceDesiredRetention`) are edited in the Practice settings sheet. |
| `review_scheduler` | FSRS-6 over the vendored `fsrs`: computes the next review state and log for a rating at the reader's desired retention, previews intervals. Study days start at 04:00; day-level intervals are at least a day, ordered by rating and capped at 365; one learning and one relearning step of 10 min because the step is not persisted; fuzzing off so previews match. Held to py-fsrs by a 118-history reference test. | Used by `fsrs_repository` only. |
| `remote_content_policy` | Shared outbound HTTP URL and DNS safety policy plus validated direct transport. | Rejects credentials, non-HTTP(S) schemes, private/local addresses, and unsafe or mixed DNS results; connects to the accepted address without a second DNS lookup. |
| `pagecraft` | Reader engine: Dart containers, document/CSS models, paged EPUB/FB2/MOBI, scrolling articles, comic pages, PDFium and DjVuLibre rendering, CFIs, progress, search, selection, highlights and import metadata. Rust handles MOBI text-record I/O/decompression; C++ DjVuLibre handles DjVu pages/hidden text through FFI. `package:pagecraft/testing.dart` builds fixtures. | Used by Reader through `ReaderSurface` and by `import_flow` for metadata; no domain, repository or bloc dependencies. Format libraries export the core `pagecraft.dart`; the core imports no format and formats never import each other (`test/library_boundaries_test.dart`). See [Pagecraft's README](packages/pagecraft/README.md) for capabilities, native bundling and licensing limits. |
| `screen_control_service` | Keep-awake and brightness coordination for active reading sessions. | Wraps low-level brightness plugin. |
| `toast_service` | Thin toastification wrapper: bottom-anchored toasts that float above controls marked with `ToastAvoidArea`; `ToastNavigatorObserver` on the root navigator clears them when a sheet or dialog opens. | Feature packages do not import toastification directly. |

Some infrastructure packages are used by only one feature today. That is still
valid when the package boundary hides a platform/backend/lifecycle concern that
must remain replaceable.

### Vendored Packages (`third_party/`)

Third-party packages Readflex patches live in `third_party/`, not `packages/`:
they keep their upstream license, structure and style, and each one's
`README.readflex.md` records the patch and how to recheck it when updating.

| Package | Upstream | Readflex patch | Used through |
|---------|----------|----------------|--------------|
| `device_screen_brightness` | 0.3.1 (MIT) | Linear Android window brightness. | Path dependency of `screen_control_service`. |
| `fsrs` | 2.0.1 (MIT) | Two FSRS-6 fixes as py-fsrs and fsrs-rs compute them: difficulty mean reversion targets the unclamped initial difficulty, and a same-day Hard never lowers stability; held to py-fsrs by `review_scheduler`'s reference test. | Path dependency of `review_scheduler`. |

### Feature Packages

| Package | UI surface | Direct local dependencies |
|---------|------------|---------------------------|
| `library_feature` (`packages/features/library`) | Main Library screen, source search/list/grid, collection scope/management, and entry into Practice through a separate icon above "+" with a due badge. | `article_repository`, `book_repository`, `collection_repository`, `component_library`, `domain_models`, `fsrs_repository`, `preferences_service`, `readflex_localizations`, `toast_service` |
| `practice` | Practice section pushed above the Library: hub (today, Vocabulary, Highlights, by book), Vocabulary and Highlights lists, full-screen review session. | `article_repository`, `book_repository`, `component_library`, `dictionary_repository`, `domain_models`, `fsrs_repository`, `highlight_repository`, `preferences_service`, `readflex_localizations`, `toast_service` |
| `import_flow` | Import bottom sheet for books/articles. | `book_repository`, `component_library`, `domain_models`, `monitoring`, `readflex_localizations`, `pagecraft` |
| `reader` | Full-screen reader route and reader UI state. | `article_repository`, `book_repository`, `component_library`, `domain_models`, `highlight_repository`, `preferences_service`, `readflex_localizations`, `screen_control_service`, `shared`, `toast_service`, `pagecraft` |
| `highlight` | Reader text action and highlight bottom sheet. | `component_library`, `domain_models`, `highlight_repository`, `readflex_localizations`, `shared` |
| `translate` | Reader text action and contextual translation bottom sheet; Save in the word header keeps the word for review. | `component_library`, `contextual_translation_service`, `dictionary_repository`, `domain_models`, `preferences_service`, `readflex_localizations`, `shared`, `toast_service` |
| `dictionary` | Reader Define action and monolingual definition bottom sheet with system-first fallback; Save in the word header keeps the word for review (only in the Readflex sheet, the native UI has none). | `component_library`, `dictionary_repository`, `dictionary_service`, `domain_models`, `readflex_localizations`, `shared`, `toast_service` |
| `onboarding` | First-launch welcome screen; the router persists completion and picks the destination. | `component_library`, `readflex_localizations` |

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
| `pagecraft` | The engine: `ComicBook` over its own ZIP reader, PDFium-backed PDF and DjVuLibre-backed DjVu on `FixedPagesView` (spreads, pinch/double-tap zoom, page animations); image-area and text overlays; reflowable EPUB/FB2/MOBI through `TextPagesView`; articles through `TextScrollView`. |
| `features/reader` | Reader screen, bloc/cubits, chrome, Contents/Search sheets, appearance, search, selection, screen controls and the page's types. Commands go through `ReaderSurface`: `ReaderTextSurface`, `ReaderComicSurface`, `ReaderPdfSurface`, `ReaderDjvuSurface` and `ReaderArticleSurface`; source type and format pick the body/surface. |
| `shared` | `TextAction` and its selection payloads; `WordSaveStatus` used by Translate and Dictionary. |
| `features/highlight` | Implements `HighlightAction`. |
| `features/translate` | Implements `TranslateAction` and owns the translation sheet UI/cubit. |
| `features/dictionary` | Implements `DictionaryAction` and owns the remote definition sheet/cubit. |

Pagecraft's `TextPagesController` resolves book page progression before displaying
the first spread, retaining Readflex's former foliate-js extension: declared
RTL or an RTL language, otherwise body-text majority across a bounded sample
of linear sections. Sampling reads at most 12 sections (512 KiB per section,
2 MiB total) and parses off the UI isolate. Reader reports `controller.rtl`
for its tap zones as well as using it for swipes and spread order. Paragraph
CSS direction and the app locale remain independent of book progression.

Page-turn animation is a UI preference independent of paging direction.
`preferences_service` persists `ReaderPageAnimation` globally.
`LibraryPageAnimationCubit` owns its choice in Library's Display sheet;
Reader appearance observes the global value without editing it. Legacy
per-source animation keys are ignored while retaining other overrides. Reader
maps it to Pagecraft's `PageTurnAnimation`, without passing preferences into the
engine. Text and fixed-layout viewers retain their input/controller logic and
feed one normalized `PageTurnFrame`; shared strategies, `PageTurnLayer` and
`PageTurnDecoration` own geometry, clipping and painting. Active turns freeze
their effect, and selecting another effect does not repaginate or reset zoom.
Future nonlinear effects belong at that rendering seam and own their temporary
GPU resources; Slide and Cover capture no page snapshots. Curl is not implemented.

The reader does not import the Highlight, Translate, or Dictionary feature
packages. `routing.dart` creates their `TextAction` implementations and passes
a list into `ReaderScreen`; the reader adds its UI-only `CopyTextAction`. The
selection popup renders colors and Highlight on the first row, then Copy,
Translate, and Define on the second row. Reader executes all feature actions
only through the `TextAction` contract. `routing.dart` also passes the
dictionary action's `onExecute` to `TranslateAction.onDefine`: a word already in
the target language closes the translation sheet and opens its definition,
without the two features importing each other.

Translation pronunciation/reading are optional fields of its own backend
response, obtained in the same provider call. The sheet displays them only when
the analyzed surface form matches the selected word. It does not call the
Dictionary service; offline translation remains usable without lexical metadata.
The same response can supply a larger `contextual_expression` grounded by the
backend in the selected occurrence. Under the selected word, a quiet label with
its phonetics, each part of the result is an outlined section: the expression
and its translation (the heading of the sheet) under **In this context**, then
the general word meaning, then the source sentence with its translation, then
the collapsed details. Both answers remain visible without expanding details; only
explanations and alternatives collapse. The Definition sheet uses the same
order and sections: headword, contextual expression, the word's own
definitions.
Phrase/full-text selections are not expanded, and no second provider request or
client-side expression search is introduced.

Translate/Dictionary cubits own per-operation cancellation signals; services
translate those into abortable HTTP requests and abort on their deadlines too.
Shared clients remain alive. Cancellation never initiates offline fallback.
Translation cache hits from the remote provider are immediate; cached offline
results are reused only after a fresh, eligible remote failure. Native work
already in progress may finish, but abandoned results are discarded.
Dictionary lookups use a matching in-memory cache (128 answers, 30 minutes,
keyed without the request ID); failures are never cached. The ML Kit adapter
keeps one native translator for the current language pair and closes it on a
pair change, after two idle minutes, after a failure, and on disposal, always
after the last request using it. The coordinator disposes both providers.

Library state holds `LibrarySource` projections rather than full article bodies.
`ArticlesDao.libraryEntries` selects only metadata, and `ArticleRepository`
maps it into domain values. Reader/detail paths keep their full article reads.
Publisher EPUB/MOBI6/KF8 markup is parsed into Pagecraft's `ContentDocument`.
`SectionPreparer` resolves its styles and builds layout boxes in an isolate;
publisher scripts are not executed. Saved article HTML uses the separate
article sanitizer described below.

Dictionary lookup is deliberately distinct from translation:

```text
DictionaryAction
  -> SystemDictionaryService.showDefinition(term)
       -> iOS UIReferenceLibraryViewController / Android ACTION_DEFINE
  -> when the platform returns false only:
       DictionarySheet -> DictionaryCubit -> DictionaryLookupService
       -> client memory cache, then POST /v1/dictionary/lookup
            -> Readflex Dictionary API
```

Definitions remain in the language of the selected term. The backend receives
an optional source-language hint and sentence context, but no target language.
Provider credentials, prompting and server-side caches belong to the separately
deployed backend. This checkout implements the Readflex dictionary HTTP client
contract and validates responses at that boundary.

Reader-specific UI state is split by responsibility:

- `ReaderBloc` loads the source and persists reader position/highlight data.
- `ReaderArticleProgressCubit` holds the live article scroll fraction once per
  frame. The article host updates it independently of throttled position
  reports, so the progress line follows scrolling without extra storage work.
- `ReaderUiCubit` owns chrome, Contents/Search sheet visibility (in-place `AppInlineSheet`s, retained while hidden), tap-zone, and search-highlight UI state.
- `ReaderSearchCubit` owns in-reader search state and recent query callbacks.
  Streamed results/progress are batched at 16ms intervals, with an immediate
  terminal flush. Reset/replacement/close invalidate pending updates; renderer
  failures become UI error state, including synchronous failures.
- `ReaderSelectionCubit` owns active text selection payloads and the UI-only
  adjustment phase; it never performs pagination or DOM geometry work.
- `ReaderAppearanceCubit` owns reader appearance preferences.
- `ReaderBrightnessCubit` coordinates widget brightness, system brightness, and
  platform override behavior. Platform targets are queued before preference
  writes; intent and lifecycle checks discard obsolete reads and adjustments.
- `ReaderPageThumbnailCubit` owns a tab-local queue and bounded preview
  cache for comic and PDF pages in Pages and Highlights. The reader host
  injects an async callback to the page surface; view widgets never receive
  a repository, archive parser or engine controller.
  Only visible tiles request previews, one at a time, independently of book
  startup and reading-position state. Closing the tab releases its cache.
- `ReaderSelectionTipCubit` owns the one-time "Press and hold a word" tip.
  `PreferencesService` stores its show count and dismissal; the cubit owns the
  policy (once per session, at most three sessions, "Got it" or a selection
  ends it, a page turn or the controls hide it until the next session). A
  driver in the content stack feeds it reader state and the content's
  position handler reports book page turns.

Reader screen composition and presentation are independent Dart libraries:

- `reader_screen.dart` injects repositories/services into blocs/cubits and
  mounts `ReaderView`; it imports no Pagecraft engine or format body.
- `reader_screen_content.dart` selects the format and composes the existing
  page/overlay stack. Each format body owns its Pagecraft source, controller,
  caches and attach/detach lifecycle, communicates through `ReaderSurface`,
  and never imports another body or the screen/chrome/drawers.
- Chrome, Cupertino action layout, Contents, selection panels and lifecycle
  scopes have explicit imports and library-local private state. Shared action
  data/buttons remove the platform layouts' former circular private coupling.
- `ReaderSearchNavigator` coordinates search jumps and return locations through
  the surface contract. Its host injects frame completion and panel callbacks;
  generation/disposal guards drop obsolete jumps without rebuilding the page
  or taking ownership of injected cubits/controllers.
- `ReaderDocument` is a source-neutral value contract independent of Flutter
  and blocs. Page input/location/turn policies and shared text style/annotation
  policies live outside format hosts; PDF and DjVu share those contracts rather
  than reaching into each other's implementation.

Screen UI no longer uses `part` files. `ReaderBloc` retains parts for its events,
state and annotation operations within that single state machine.

`reader_format_capabilities.dart` owns the static format policy for content
selection, actions, appearance, zoom/columns, progress, Contents, page gestures
and text-selection support. Its exhaustive `BookFormat` resolver returns shared
const profiles; `ReaderState.formatCapabilities` derives the profile without
new state emissions or per-frame collection allocation. Article source type
takes precedence over legacy format metadata. UI helpers consume this policy
instead of independently classifying PDF, DjVu or comics.

`ReaderDocumentFeatures` separately reports discovered outline, page count and
text. Page-count discovery adds PDF/DjVu page grids; positive text discovery
allows selection guidance. Search remains available during lazy probing, and
format lookup performs no I/O. The matrix preserves PDF's continuous percentage
progress alongside zoom, while CBZ/DjVu use discrete page progress. Controls,
progress indexing and page interaction are covered by the Reader matrix and
platform tests; renderer/controller lifetimes remain unchanged.

The page is kept behind ready-state reader composition so routine UI changes
do not recreate it. Every source is drawn by pagecraft; there is no WebView and
no local reader server (the last revision with them is
`fb4b4e5c`). Books open as pages: EPUB, FB2 and MOBI/AZW3 on `TextPagesView`,
CBZ, PDF and DjVu on `FixedPagesView`. Articles scroll: `ArticleTextSource` reads
`content.html` cleaned as the former article shell cleaned it
(`articleDocumentHtml`, the DOMPurify allow-list, inside
`<main id="article-content">`), and the reader keeps the shell's stored forms,
so positions, bookmarks and highlights saved in the WebView still resolve:
`readflex-html-position:` sentence anchors (`ArticleAnchor`, byte-identical to
the shell's JSON), the sentence at the middle of the view as the position,
minutes left at 1200 characters a minute, headings (or up to twelve blocks) as
contents with their start share. Search runs over the sentences and tints
every hit; the active hit hidden under the search bar is marked on the bar's
edge (`ReaderSearchOcclusionMarker`, shared with books).

New article imports preserve punctuation and whitespace across sentence spans.
Existing saved HTML is not regenerated, keeping persisted positions and
annotation anchors stable.

Link taps are resolved in Dart: in-document fragments and book links navigate
in place, a note reference opens over the page, everything else is reported
through one `onExternalLink` callback (a saved article's relative paths stay
inert). The reader feature asks first (`ReaderExternalLinkPrompt`, a sheet with
the real destination, Copy link and Open) and passes only confirmed links to
`ReaderScreen.onOpenExternalLink`; `routing.dart` opens web pages in the in-app
browser and `mailto:`/`tel:` in their apps. Highlight colours, search tints
and the symbol font fallback come from shared modules, so articles and books
render the same tokens alike.

Page zoom for comics and PDF lives in pagecraft's `FixedPagesView`: edge taps are
immediate, centre taps distinguish chrome from double-tap zoom, and zoomed
drags only pan. PDF pages keep text selection and link taps under zoom.
Flutter owns chrome visibility and physical/logical page commands
(`readerLeftTapZoneEnd`, 30% of the page per edge); PDF keeps text-book chrome
rules. A zoom decodes the page again, denser, up to a pixel budget; past it
the visible part is rendered as a sharp tile, planned over the page bitmap it
is drawn on (a bitmap of another size plans it again). Margin crops decode the
whole page at the density its visible part is shown at, again when a crop
arrives after the page. Comic pages are decoded from the archive on demand;
PDF pages, tiles and previews are rendered by pdfium.

Comic and scan-only DjVu area gestures stay in Pagecraft. A single pointer
owns each draft edit; visible corner grips have larger touch targets outside
the crop that adapt at page edges. Only adjustment boundaries and final geometry
reach `ReaderImageSelectionCubit`, avoiding per-pixel app rebuilds. Reader hides
the retained action popup during edits and places it clear of corner targets
after release. Cancel, outside taps and Back clear both the engine draft and
its app mirror; note sheets retain the engine draft directly.
Draft presentation IDs scope preview cleanup and save completion. Accepted
writes refresh annotations even after their popup is dismissed, without
clearing a newer selection or sending UI feedback to a disposed route.

Text selection in reflowable books and articles keeps Flutter's `SelectionArea`
and Pagecraft's exact source mapping. After the initial long press releases,
`native_text_selection` supplies system handles and selection interactions on
supported iOS/Android hosts. PDF and DjVu supply their existing text-layer
geometry to the same adapter; DjVu retains source-provided word precision.
The Reader's translation, dictionary and highlight action menu remains Flutter.
Unsupported native geometry retains the existing Flutter selection. Read-only
text in Dictionary, Translation and Practice uses `AppTextSelectionHost`;
editable fields preserve their existing Flutter input/IME contract.
Reflowable selection starts with a word on a
long press, word by word on a drag. `TextSelectionDetails` (books) and
`ArticleSelection` (articles) read it into the context panel's payload: the
exact and whole-word text and CFIs, the sentence as context, and the saved
highlights it merges. In paged books a selection follows the reader through
the section as it did in the WebView reader: a swipe or an edge tap turns by
one spread, the boundary behind stays and the other edge moves onto the new
page (to the end of its first line); a centre tap, a jump or another section
clears it. Tables wider than the column scroll sideways inside it (the
reader's sheet gives them `overflow-x: auto` and up to 40em of width), with
their words whole; a swipe on a table at its edge turns the page. No
repository or feature bloc participates in per-pointer work.

Reader position writes are serialized and retain the 500ms trailing debounce.
Repositories update only CFI/progress; `markOpened` updates only the opened
timestamp. Each saved write reports its progress to the Library, which updates
that one source in memory instead of reloading storage on every page. SQLite
runs in write-ahead mode with `synchronous = NORMAL`, so these commits need no
fsync. A delayed source refresh preserves live position and document
capabilities, and closing the bloc drains both queued and active writes. A
book reports its position once it shows the saved page, so a reopened book
keeps its place. When a CFI's section resolves but its node offset does not,
the text controller opens that section's first page. If the section itself
cannot resolve, initial navigation tries the saved fraction and then the first
linear section. Book bookmarks with an anchor version keep
the CFI of a word on their own page and survive repagination; older ones
navigate by their visual page anchor. CBZ page ordering is versioned in the
Book/ReaderDocument contract: existing rows keep legacy indices, while new
imports use filtered, natural filename order.

Source deletion and collection membership cleanup share one repository-owned
transaction. Library collection read errors preserve the last valid scopes and
selection, separately from successfully refreshed source metadata.

Saved highlight edits use field-specific repository updates for color/note,
not full-object replacements from UI snapshots. Their event queue is separate
from position handling; annotation operations do not delay live page metrics.
Source reloads preserve newer annotation state. Typed mutation effects report
completion/failure through a listener without rebuilding the page subtree;
the context popup does not report success when merely enqueueing an edit.

A page that cannot open or lay out its document reports `ReaderSurfaceFailed`
with the error; the feature shows its localized error/retry state. pagecraft does
not access repositories or feature cubits.

Publisher scripts never run: pagecraft lays out the document and executes no
script. Article images are activated only after the repository's guarded
download succeeds; pagecraft also cleans legacy saved fragments as the shell did
and reads only pictures under the article's `images/` folder. These policies
live in the content-loading layers, separately from typography.

## Import and Article Flow

Book import:

```text
ImportFlowSheet
  -> pickBookFile callback from routing.dart
  -> importBookFile helper in import_flow
  -> pagecraft reads the title, author and cover (every format)
  -> BookRepository stores file/metadata
  -> deletePickedBookFile removes the picker's temp/cache copy
```

Article import:

```text
ImportFlowSheet
  -> ArticleExtractionService downloads/cleans article
  -> ArticleRepository stores article, body images, and content.html
     (the og:image stays a remote imageUrl; it is not downloaded)
  -> Reader opens content.html on pagecraft (ArticleTextSource, TextScrollView)
  -> ReaderBloc persists the same source progress model through repositories
```

Both the client-side extraction fallback and repository-owned image downloads
treat remote URLs as untrusted input. They validate every redirect target,
reject private/local address resolution, pin connections to validated IPs, and
enforce explicit request, byte, and asset-count limits before committing files
to article storage.

The import UI does not own storage details. It receives callbacks and reports
progress/result state back to the route that opened it.

Entry points: the "+" at the outer end of the Library's bottom capsule (after the collection switcher) opens the menu; the empty Library's Upload
a file / Save an article buttons pass `LibraryImportEntry.file` / `.article`;
onboarding's Add your first book navigates to Library with `LibraryRouteArguments`
(`openImportOnStart`), which opens the file path once after the first frame.
`routing.dart` maps `LibraryImportEntry` to `ImportFlowEntry`, because the two
features never import each other. A file entry still shows the terms step
first when the current terms are not accepted; Back from an entered step
returns to the menu.

Closing the import sheet does not cancel an already-started import.
`LibraryImportLauncher` separates sheet dismissal (its returned Future) from
successful persistence (`onImported`). The composition root invokes that
callback after book/article storage completes, even if the sheet is gone.
Library ignores completion after disposal. Cancellation/failure does not trigger
a redundant list read, and no database-wide subscription reloads Library on
every debounced reader-position write.

Library loads book metadata and a lightweight SQL projection of article metadata,
then caches its filtered/sorted visible items per state. Article body text and
reader anchors are not read for the list. SQL pagination remains separate work
requiring behavioral/performance baselines; the current projection keeps existing
search/filter semantics.

## Data, Models, and Mapping

Use one domain model layer and source-specific storage/service models:

- `domain_models` contains stable app concepts such as `Book`, `Article`,
  `LibrarySource`, `Highlight`, `DictionaryEntry`, `ReviewItem`,
  `ReviewStats`, `SourceType`, and domain exceptions. Dormant flashcard
  models remain for storage compatibility.
- `local_storage` contains Drift tables, DAOs, migrations, and storage row
  shapes. File-backed migration fixtures cover historical schemas that require
  filesystem as well as SQL migration.
- Repositories map storage rows and filesystem/backend results into domain
  models.
- Feature blocs/cubits emit feature states built from domain models, not DAO
  rows or backend payloads.

Saved-word lookup uses `dictionary_table.word_key`, normalized in Dart on
inserts, word edits and schema v27 migration, so lookup uses the same Unicode
case conversion for both sides. Reader highlight Undo retains a domain-only
`HighlightDeletion` snapshot. The repository captures and restores the highlight
and optional review state transactionally with the original ID; review logs
remain connected, absent review rows stay absent, and deleted sources cannot
be recreated by Undo.

Book import progress is a synchronous observer, separate from persistence. A
throwing callback is disabled and logged once; it cannot fail the import or
delete committed files. Completion is reported outside the file-cleanup boundary
after the book row is inserted. Actual copy/cover/database failures still clean
the incomplete directory and return a storage error.

`FsrsRepository.recordReview` checks saved-word/text-highlight existence and
stored exclusion inside the transaction that reads the schedule, updates it and
appends the log. Deleted or excluded content produces `NotFoundException`
without recreating tracking; Practice drops the unavailable item without
counting a rating. Legacy flashcard storage remains
compatible and is excluded from active Practice queues.

Composition awaits a missing-only SQL repair of legacy text-highlight review
rows once during initialization. Practice hub and session loads do not backfill
or load all highlights for this repair. The feature's review-eligibility policy
keeps global and per-source due counts consistent with its session queues;
repository queries apply type/state selection before pagination. Sessions load
bounded new and already-reviewed candidates separately, so daily new-card limits
cannot hide due learning/review/relearning items. Saved-content totals
still include highlights when highlight review is disabled. Remove from review
uses `excludeReviewItem`, retaining the schedule and history with `isExcluded`
in schema v28. Backfill and insert-or-ignore saves cannot reactivate that row;
normal/ahead queues, state lookups, counts and deadlines exclude it. Physical
tracking deletion remains a separate cleanup operation. Previously deleted
tracking cannot reveal whether it represented a user exclusion or legacy data.

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
- It gates entry routes such as onboarding. Onboarding is one welcome screen
  (the `onboarding` feature): the app icon, "Welcome to Readflex" and four
  feature rows of equal weight. Selecting text is taught in the reader by its
  one-time tip, not drawn here. Both Add your first book and Not now mark it
  completed before going to Library.
- The route table is flat; there is no tab shell. `/library` is the home
  screen. `/practice` is pushed above it with a back button, its `words` and
  `highlights` lists nest under it, and `review` opens the session as a
  full-screen dialog page. The reader is a root route (`/reader/:sourceId`)
  that Library, Practice lists and the session all push; the session's
  "Open in book" passes `ReaderRouteArguments.initialCfi`, applied once the
  document is ready.
- The Library owns the way in: `LibraryScreen.onPracticePressed` pushes
  `/practice` and completes when it pops, and the Library reloads its
  sources and review counts (`LibraryState.practice`) then. The reader
  closing refreshes the same way, so a word saved in a Translation sheet
  shows in the Library's Practice row on return.
- `LibraryBloc` keeps one foreground timer for the next eligible review
  deadline. Its queue-only refresh uses `FsrsRepository.getReviewQueueStatus`
  without reloading the source list or activity statistics. It respects the
  highlight-review preference, cancels on background/disposal and refreshes
  on resume. Failed reads keep the last counts and retry after one minute
  while active; there is no periodic polling.
Features should express navigation needs through callbacks. They should not
call GoRouter to navigate to sibling features directly.

## Runtime Configuration

Configuration is read through `ApplicationConfig` and compile-time environment
values. Flag names, defaults and validation live in
[`lib/app/config/application_config.dart`](lib/app/config/application_config.dart);
`config/run-defines.example.json` supplies the local DEV template used by `run.sh`.
The root README keeps the minimal launch instructions.

Security boundary: static Readflex API credentials are development-only and
configuration validation rejects them in staging/production. Production must
use short-lived credentials issued by a backend authentication/attestation
flow. GlitchTip error reporting is enabled by
`GLITCHTIP_DSN` or the Sentry-compatible `SENTRY_DSN` fallback; performance
tracing is opt-in through `GLITCHTIP_TRACES_SAMPLE_RATE`.
Contextual translation and dictionary lookup default to the article cleaner
host. Development requests share the explicit `READFLEX_API_KEY`; the legacy
`ARTICLE_CLEANER_API_KEY` name remains accepted for local commands only.
Composition owns one HTTP client for the article cleaner, translation and
dictionary services, so their requests reuse connections. Its 10 s connect timeout turns an unreachable host into a
network failure (Translate then falls back offline); the default 15 s idle
timeout stays because the backend keep-alive is unknown. The client is
registered for disposal before the services and closes after them, also on
bootstrap rollback; services close only clients they created. Article page
downloads never use it: they keep the extraction service's own pinned client.

`bounded_http` limits actual streamed response bytes, including error responses
and decompressed bodies: 1 MiB for translation/dictionary, 16 MiB for cleaner
JSON. A deadline or byte-limit failure aborts that request and cancels its body
subscription, leaving the pool usable for subsequent requests.
Cleaner JSON and domain mapping run in an isolate for responses of 256 KiB or
more; smaller responses keep the direct path.

Every book and article is drawn by `pagecraft`; there is no engine switch.
`TextBookLayout` rejects vertical writing, and `TextPagesController` rejects
sources marked as fixed layout, including fixed-layout EPUB and KF8, with
`TextBookUnsupported`. Reader shows its open-error state; there is no alternate
renderer for these documents.
See Pagecraft's `text_book_support_test.dart` for the supported-layout boundary.

`pagecraft` delegates only MOBI/KF8 text-record I/O, trailing-entry removal and
PalmDOC/HUFF-CDIC decompression to its Rust crate in `packages/pagecraft/rust` over
`flutter_rust_bridge` 2.13.0. PDB/MOBI headers, combined-file selection,
metadata, resources, chapter reconstruction, document parsing and layout stay
in Dart. The crate and native library use the name `pagecraft_mobi_native`;
there is one Dart package, `pagecraft`. The wrapper, loader and generated Dart
bindings are private to `lib/src/formats/mobi/native/`. This backend has no
Flutter UI, domain or repository dependencies.
MOBI 6 requests its text in one batch; KF8 keeps record reads on demand and its
existing Dart range caches. The native session starts lazily, serializes reads
on the FRB pool and drains them before closing its file/dictionary/opaque handle.
Failed book opening closes both native and PDB resources. Native read errors
surface as `PagecraftException`; there is no silent backend retry.

DjVu uses the vendored DjVuLibre 3.5.30 C++ decoder under
`packages/pagecraft/native/djvu/`, called through a narrow C ABI and Dart FFI.
Each `DjvuBook` owns a worker isolate and native document; requests serialize
there, and close drains accepted work before releasing the handle. Page
headers/navigation load on open; bounded RGBA page images, zoom regions and
hidden text load on demand. `DjvuPages` implements `FixedPageSource`, retaining
the shared page animations, zoom and preview machinery. Word-zone text supports
search, selection and text actions; image-only pages use image-area selection
and have no OCR-derived text. The decoder rejects indirect multi-file sources
and standalone external includes; JPEG-in-DjVu is not enabled in this build.
Its GPLv2-or-later notices and distribution requirements remain separate from
the project's surrounding notices; review them before distributing linked builds.

Pagecraft's `hook/build.dart` compiles the locked Cargo crate in release mode
with its pinned rustup compiler and bundles it through Native Assets. Native
assets are built/bundled even for consumers importing another Pagecraft format.
PDFium is also bundled: native assets on Android, XCFramework on Apple.
The hook also compiles DjVuLibre with the target C++ toolchain. Its vendored
sources are built locally, without a system DjVuLibre installation or runtime
downloads. The decoder is bundled even when another format alone is imported.
Generated bindings and build lockfiles are versioned; development
requires rustup and the target platform toolchain. Host tests/CLI resolve the
build-hook asset, and packaged apps use FRB's platform loader. `make analyze`
includes Rust checks; `make test` includes Rust and bridge/session tests.
See [the native backend notes](packages/pagecraft/doc/mobi_native.md) for setup and regeneration.

The current Dart decoders remain the explicit parity reference through
`MobiContainer.open(..., useDartTextReader: true)` or the diagnostic build define
`PAGECRAFT_MOBI_USE_DART=true`; this is not a reader UI preference. The historical
`benchmarks/mobi_rust` prototype remains independent of the app graph, while
`benchmarks/reader_native` compares production MOBI containers with the Dart
reference. Other format/parser candidates remain experiments. Device packaging
checks live in `integration_test/mobi_native_test.dart`.

## Known Non-Production Contracts

The project is not fully production-complete. These are intentional gaps unless
a task explicitly asks to implement them:

- Error reporting uses `GlitchTipErrorReporter` when a DSN is configured and
  falls back to `NoopErrorReporter` otherwise.
- `NoopAnalyticsReporter` does not send analytics telemetry.
- Production backend authentication/attestation and short-lived access tokens
  are not implemented; static build-time credentials are intentionally blocked.
- Flashcard, subscription, auth, AI, and notification packages are frozen
  outside the active package graph. Restore their legacy implementation from
  `189e2cc1` only if that product scope returns. Practice was rebuilt in
  2026-10 on the restored `review_scheduler`, `fsrs_repository` and
  `dictionary_repository`; there is no Home or Profile tab.
- Practice has no Listen (TTS) on word cards and no daily reminder.

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
rewriting files, analyzes the root app and every active package, then runs
Rust, Dart and Flutter tests, including the Dart development-tool tests in
`test/tooling/`. `make test-tools` runs that subset separately. Rust formatting
and Clippy are part of `make analyze`.

`make check-architecture`, also part of `make analyze`, runs two static gates:

- `scripts/check_architecture.dart` checks production package declarations and
  Dart directives, including conditional imports/exports and cross-package
  relative paths. It rejects sibling-feature dependencies, infrastructure
  dependencies on features or the app, direct feature/storage coupling,
  non-public package imports, sources outside `lib/`, undeclared local production
  dependencies, local dependency cycles and local/Flutter dependencies in
  `domain_models`.
- `scripts/check_widget_helpers.dart` rejects widget-returning helpers and
  resolved infrastructure types in declared fields and constructor parameters
  of feature Widget classes ending in `View` and their `State` classes. Domain/service
  data models and UI callbacks remain valid; Screen/Sheet composition and
  documented renderer hosts keep their existing responsibilities.

These checks do not prove all dependency flow: dynamically typed objects,
closure captures, method-local service access and UI classes without the
`View` naming convention still need review. Pagecraft's
`library_boundaries_test.dart` additionally checks its internal format graph.
Reader's `reader_module_boundaries_test.dart` checks its acyclic import/export
graph, screen/renderer isolation and the standalone document contract.
`.github/workflows/quality.yml` runs formatting, `make analyze` and `make test`
for pull requests and pushes to `main`, with manual dispatch available. Actions
are pinned by commit, credentials are not retained in the checkout, and the job
needs only repository-read permission. Local success is separate from a remote
workflow result.

`make test-contracts` focuses on component interactions and shared repository
contracts. The same bookmark scenarios run against `BookRepository` over real
SQLite and the Reader fake; collection scenarios run against
`CollectionRepository` and the Library fake. They cover identities, reading
order, scoped deletion, idempotent Undo, membership counts, validation and
atomic bulk-add failure. These contracts cover the methods the feature fakes
implement, not the entire repository API. Partial doubles must still fail on
unexpected method access. Run these scenarios when changing either a covered
repository method or its fake.

Root workflow tests compose real repositories with Library, Reader, Practice
and review-session blocs. They check that a failing import observer leaves a
readable book, then exercise saved highlight → cached review card → Reader
deletion → rejected late rating → Undo → refreshed counts/session. Books and
articles run with highlight reviews enabled and disabled; image-area highlights
stay outside the text-review queue. Existing transaction-failure and controlled
delete/rating overlap tests remain part of this target and the full suite.
Synchronization uses committed operations and bloc states, not timing sleeps.

`make test-ui-contracts` is a focused subset for shared components, accessibility,
theme contrast, import/Display navigation and representative root layouts. It
does not modify goldens or replace feature, native or performance checks. These
tests remain in the normal package/root suites. The review checklist lives in
[`test/ui/README.md`](test/ui/README.md#review-checklist); component specifications
remain in `component_library`, not in a parallel generated design system.

Platform contracts use actual Cupertino/Material application roots, not only a
host-platform override. `packages/component_library/test_support/platform_test_app.dart`
mounts the semantic/platform theme and scaffold for feature tests. Shared
modal tests also use a pure Cupertino root to check inherited theme capture,
root-navigator results, guarded drag/scrim, keyboard/safe-area ownership,
reduced motion and retained state through resizing. Feature tests retain
draft, validation, loading and recovery assertions through the public App*
controls. These widget checks do not establish VoiceOver/TalkBack interaction,
physical selection gestures or device FPS.

Root UI flows in `test/ui/` mount the production root and router with real
repositories, isolated SQLite/preferences, and deterministic external services.
The same test-only composition serves `integration_test/`; it never invokes
production dependency composition or reads API keys. Views keep their normal bloc/cubit contracts; test fixtures do not introduce a
second production dependency path.

`make test-ui` runs these root flows and exact golden comparisons using bundled
fonts and explicit light/dark, compact/large-text, landscape, and RTL/tablet profiles.
Wide-window goldens (`tablet_layout_golden_test.dart`) render the changed
surfaces at 1032 × 1376 and 1376 × 1032 in the existing profiles' themes.
`make update-goldens` is a separate, deliberate baseline update. Test fonts and
committed PNG baselines are not application assets. `make test-device DEVICE=<id>`
is opt-in and preserves the device's real viewport. It records screenshots under
`.local/ui-device/`, but does not replace on-device handle, OS lifecycle, GPU,
screen-reader, or live-backend checks. Coverage and limitations live in
[`test/ui/README.md`](test/ui/README.md).

CI keeps the golden host on `macos-15` arm64, installs the exact Flutter version
from `.fvmrc`, and uses UTC/`en_US.UTF-8` with the committed test fonts. The root
workspace lockfile is enforced during dependency resolution and must remain
unchanged. This covers dependencies and dev dependencies of every workspace
member. Isolated benchmarks retain their own locked restores outside that graph.
Rust uses Pagecraft's existing `rust-toolchain.toml` and locked Cargo commands.
GitHub can update its macOS image within that label, so each run records the OS,
SDK and compiler versions and retains verification logs and golden differences
for seven days. CI never updates expected PNGs or runs native device/FPS checks.

`make coverage` runs the same suites with Dart VM line/branch instrumentation
and creates a fresh `.local/coverage/run-*/` report. The collector unions hits
from root and package tests, excludes generated/third-party code, and lists
unmeasured owned files explicitly. `COVERAGE=1 make test-device DEVICE=<id>`
collects native Dart line coverage after interaction tests. Combining reports
requires matching hashes of Dart sources, tests, pubspecs, lockfile, and SDK pin.
Native Swift/Kotlin execution is not represented as Dart coverage.

Performance regressions have structural tests in the normal suite: Library
tile count stays bounded at 20,000 items and cached projections are reused;
the Collections picker builds only on-screen rows with 2,000 authors, and
keyboard frames rebuild no grid tile; bursty reader search bounds emissions
and published result entries without losing matches. `make test-performance` records workload timing separately in
`.local/performance/`. Timings are diagnostic, not machine-independent CI limits.

The coverage, benchmark and corpus tools under `scripts/` use the pinned Dart
SDK. Their tests validate frozen
inputs, source/artifact hashes and worker evidence; benchmark raw samples and
median/p95 definitions are unchanged. Corpus files with equal sizes are ordered
by path code units, independent of the host locale, so a newly selected corpus
can differ from an older locale-collated selection. Preserve frozen datasets
for comparisons.

Node.js is optional maintenance tooling for Pagecraft's committed data:
`test/fixtures/icu_sentence_breaks.mjs`, `tool/search_fold_table.mjs` and
`tool/hyphenation_patterns.mjs`. Normal builds and tests use their committed
outputs and need no browser engine. Historical Foliate fixture recordings
describe compatibility provenance, not steps in the current test harness.

Focused package changes can use package-level `flutter test` or `dart test`.
Use broader checks when changing:

- shared contracts;
- repository behavior;
- package dependencies;
- reader, pagecraft, or import flow behavior;
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
- Create source subdirectories when code or maintained fixtures need them;
  do not retain empty placeholders. Generated caches and build outputs are
  owned by their tools, and local diagnostics belong under `.local/`.
