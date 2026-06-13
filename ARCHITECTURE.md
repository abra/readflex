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

- `packages/features/<feature>` for a screen, tab, bottom sheet, or user-facing
  flow.
- `packages/<name>_repository` for domain persistence and data-source
  orchestration.
- `packages/<name>_service` for platform, backend, or infrastructure contracts.
- A named specialized package such as `component_library`, `reader_webview`, or
  `review_scheduler` when the responsibility is neither a feature nor a
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
| `lib/app/starter.dart` | Flutter binding, error zone, bloc observer, build/frame tracing, asset extraction, reader server startup, dev seed data, `runApp`. |
| `lib/app/config` | Compile-time/runtime configuration via `ApplicationConfig` and environment helpers. |
| `lib/app/composition.dart` | Creates the database, repositories, services, filesystem directories, and app-wide dependencies. |
| `lib/app/dependency_container.dart` | Plain dependency holder plus best-effort shutdown/dispose. |
| `lib/app/dependency_scope.dart` | Inherited scope for app-wide dependencies. |
| `lib/app/root_context.dart` | Mounts dependency, connectivity, auth, preference, and material contexts. |
| `lib/app/material_context.dart` | Material app setup and reader-server lifecycle handling on resume. |
| `lib/app/routing.dart` | GoRouter route table, route guards, navigation callbacks, feature wiring. |
| `lib/app/screens` | App-only screens that are not reusable feature packages. |

There is no global service locator. App-wide objects are created once in
`composition.dart`, stored in `DependenciesContainer`, mounted in the widget
tree, and passed explicitly into feature entry points from `routing.dart`.

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
  such as `onSourcePressed`, `onSignInPressed`, or `onStartMiniReview`.

This keeps feature UI testable and prevents accidental coupling between
features.

## Package Map

### Core Contracts and Storage

| Package | Responsibility | Local dependencies |
|---------|----------------|--------------------|
| `domain_models` | Pure domain models, enums, value objects, and app/domain exceptions. No Flutter, storage, or service dependencies. | none |
| `local_storage` | Single Drift database (`readflex.db`), tables, DAOs, migrations, storage rows. | none |
| `component_library` | Design tokens, theme extensions, reusable UI components, bottom-sheet shell, shared visual primitives. | none |
| `shared` | Narrow cross-feature contracts. Currently `TextAction` and `TextSelectionContext`. | `domain_models` |

Domain models are the neutral contract between repositories, services, blocs,
and UI. Storage rows and DAO types should remain behind repositories.

### Repositories

| Package | Responsibility | Local dependencies |
|---------|----------------|--------------------|
| `book_repository` | Imported books, cover metadata, source bookmark/progress, filesystem ownership for books. | `domain_models`, `local_storage`, `monitoring` |
| `article_repository` | Extracted articles, article assets, generated reader EPUB adapter. | `domain_models`, `local_storage`, `monitoring` |
| `collection_repository` | Manual library collections and built-in favorite membership. | `domain_models`, `local_storage` |
| `dictionary_repository` | Saved dictionary entries and mappings to domain models. | `domain_models`, `local_storage` |
| `flashcard_repository` | Flashcard persistence and domain mapping. | `domain_models`, `local_storage` |
| `highlight_repository` | Highlight persistence and domain mapping. | `domain_models`, `local_storage` |
| `fsrs_repository` | Central FSRS review state storage and scheduling integration. | `domain_models`, `local_storage`, `review_scheduler` |

Repositories orchestrate data sources and return domain models/exceptions.
Feature blocs/cubits talk to repositories; feature UI should not import DAOs.

`fsrs_repository` has dev/test dependencies on reviewable repositories for
cross-package integration tests. That does not make those repositories part of
its production API.

### Services and Infrastructure

| Package | Responsibility | Notes |
|---------|----------------|-------|
| `auth_service` | Auth state contract and no-op development implementation. | Used by Profile and app composition. |
| `ai_service` | AI backend contract. Currently no-op in app composition. | Kept separate to protect future backend integration. |
| `article_extraction_service` | Remote article cleaner client and fallback extraction contract. | Returns `ExtractedArticle` domain data. |
| `connectivity_service` | Reactive connectivity status and UI scope. | UI signal only; services still handle their own failures. |
| `device_screen_brightness` | Native/plugin brightness access. | Low-level platform package used by `screen_control_service`. |
| `monitoring` | Logger, log observers, analytics/error reporter contracts and no-op implementations. | Production reporters are not implemented yet. |
| `notification_service` | Notification contract for review reminders. | Currently no-op in composition. |
| `preferences_service` | Preferences model, storage, repository, service, and scope. | Used by Library, Profile, Reader, app composition. |
| `reader_server` | Localhost HTTP server for reader assets and book/article files. | Supports range requests for WebView readers. |
| `reader_webview` | Foliate WebView wrapper, JS bridge, asset extraction, metadata extraction. | Used by Reader and Import Flow. |
| `review_scheduler` | Pure-Dart FSRS v6 scheduling calculation. | No Flutter, storage, or I/O. |
| `screen_control_service` | Keep-awake and brightness coordination for active reading sessions. | Wraps low-level brightness plugin. |
| `subscription_service` | Premium subscription status and purchase contract. | Currently no-op in composition. |
| `toast_service` | Thin toastification wrapper. | Feature packages do not import toastification directly. |
| `translation_service` | Translation, pronunciation lookup, bundled SQLite assets, optional direct DeepSeek client. | Public builds should not ship client-side model API keys. |

Some infrastructure packages are used by only one feature today. That is still
valid when the package boundary hides a platform/backend/lifecycle concern that
must remain replaceable.

### Feature Packages

| Package | UI surface | Direct local dependencies |
|---------|------------|---------------------------|
| `home` | Home tab/dashboard. | `book_repository`, `component_library`, `domain_models`, `fsrs_repository`, `highlight_repository` |
| `library_feature` (`packages/features/library`) | Library tab, source search/filter/list/grid, collection management. | `article_repository`, `book_repository`, `collection_repository`, `component_library`, `domain_models`, `preferences_service`, `toast_service` |
| `import_flow` | Import bottom sheet for books/articles. | `book_repository`, `component_library`, `domain_models`, `monitoring`, `reader_webview` |
| `source_details` | Details screen for books/articles/comics and review stats. | `article_repository`, `book_repository`, `component_library`, `dictionary_repository`, `domain_models`, `flashcard_repository`, `highlight_repository` |
| `reader` | Full-screen reader route and reader UI state. | `article_repository`, `book_repository`, `component_library`, `domain_models`, `highlight_repository`, `preferences_service`, `reader_webview`, `screen_control_service`, `shared` |
| `highlight` | Reader text action and highlight bottom sheet. | `component_library`, `domain_models`, `fsrs_repository`, `highlight_repository`, `shared` |
| `flashcard` | Reader text action and flashcard bottom sheet. | `component_library`, `domain_models`, `flashcard_repository`, `fsrs_repository`, `shared` |
| `translate` | Reader text action, translation sheet, dictionary save. | `component_library`, `dictionary_repository`, `domain_models`, `fsrs_repository`, `shared`, `translation_service` |
| `dictionary` | Dictionary tab and detail sheets. | `component_library`, `dictionary_repository`, `domain_models`, `fsrs_repository`, `toast_service` |
| `practice` | Practice tab and mini-review sheet. | `component_library`, `dictionary_repository`, `domain_models`, `flashcard_repository`, `fsrs_repository`, `highlight_repository` |
| `profile` | Profile tab, appearance settings, auth/subscription status. | `auth_service`, `component_library`, `preferences_service`, `subscription_service` |
| `subscription_paywall` | Premium upsell bottom sheet. | `component_library`, `subscription_service` |

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

## Reader Architecture

The reader is intentionally split across several packages:

| Package | Responsibility |
|---------|----------------|
| `reader_server` | Serves reader assets and book/article bytes from localhost. |
| `reader_webview` | Hosts foliate-js, JS bridge DTOs, asset extraction, metadata extraction. |
| `features/reader` | Reader screen, reader bloc/cubits, chrome, drawers, appearance, search, selection, brightness, keep-awake, review reminder. |
| `shared` | `TextAction` plugin contract used by reader context-panel actions. |
| `features/highlight` | Implements `HighlightAction`. |
| `features/flashcard` | Implements `FlashcardAction`. |
| `features/translate` | Implements `TranslateAction`. |

The reader does not import Highlight, Flashcard, or Translate packages.
`routing.dart` creates those `TextAction` implementations and passes a list into
`ReaderScreen`. The reader renders and executes actions only through the
`TextAction` contract.

Reader-specific UI state is split by responsibility:

- `ReaderBloc` loads the source and persists reader position/highlight data.
- `ReaderUiCubit` owns chrome, drawer, tap-zone, and search-highlight UI state.
- `ReaderSearchCubit` owns in-reader search state and recent query callbacks.
- `ReaderSelectionCubit` owns active text selection payloads.
- `ReaderAppearanceCubit` owns reader appearance preferences.
- `ReaderBrightnessCubit` coordinates widget brightness, system brightness, and
  platform override behavior.
- `ReaderReviewReminderCubit` checks for due review items and drives the
  reminder banner.

The WebView subtree is kept behind ready-state reader composition so routine
UI changes do not recreate the reader runtime unnecessarily.

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
  -> ArticleRepository stores article, assets, and reader EPUB adapter
  -> Library/Reader consume the saved source through repositories
```

The import UI does not own storage details. It receives callbacks and reports
progress/result state back to the route that opened it.

## Data, Models, and Mapping

Use one domain model layer and source-specific storage/service models:

- `domain_models` contains stable app concepts such as `Book`, `Article`,
  `LibrarySource`, `Highlight`, `Flashcard`, `DictionaryEntry`, `ReviewItem`,
  `SourceType`, and domain exceptions.
- `local_storage` contains Drift tables, DAOs, migrations, and storage row
  shapes.
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
- It gates entry routes such as onboarding and first import.
- It handles app-only utility routes such as `/design-system`.

Features should express navigation needs through callbacks. They should not
call GoRouter to navigate to sibling features directly.

## Runtime Configuration

Configuration is read through `ApplicationConfig` and compile-time environment
values. Important development flags are documented in `README.md`.

Security boundary:

- `DEEPSEEK_API_KEY` and direct DeepSeek translation are development paths.
- Public builds should keep model API keys server-side.
- Article cleaner API keys should be treated as backend credentials, not UI
  state.

## Known Non-Production Contracts

The project is not fully production-complete. These are intentional gaps unless
a task explicitly asks to implement them:

- `NoopAuthService` reports unauthenticated status.
- `NoopAiService` returns empty AI results.
- `NoopSubscriptionService` reports free tier.
- `NoopNotificationService` drops notification operations.
- `NoopErrorReporter` and `NoopAnalyticsReporter` do not send telemetry.
- Home and Practice still contain placeholder/dashboard sections.
- `/design-system` is a development route and should be removed or gated
  before production release.
- Direct DeepSeek translation is enabled only through development config.

When replacing a no-op with a production implementation, update this document,
the relevant package README, and tests around the public contract.

## Testing and Verification

Preferred checks:

```sh
make analyze
make test
```

Focused package changes can use package-level `flutter test` or `dart test`.
Use broader checks when changing:

- shared contracts;
- repository behavior;
- package dependencies;
- reader WebView, reader server, import flow, or translation behavior;
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
