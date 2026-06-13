# Readflex Architecture

This document describes the current codebase shape for maintainers. Treat the
code as the source of truth when this document and implementation diverge, then
update this file in the same change.

## High-Level Shape

Readflex is a Flutter app composed from local Dart/Flutter packages:

| Area | Responsibility |
|------|----------------|
| `lib/app` | App startup, dependency composition, root scopes, GoRouter routing, app-only screens |
| `packages/features/*` | User-facing feature surfaces: screens, sheets, blocs/cubits, and UI widgets |
| `packages/domain_models` | Pure domain models, enums, and app exceptions |
| `packages/local_storage` | Drift database, DAOs, migrations, and storage row types |
| `packages/*_repository` | Domain repositories over storage and filesystem concerns |
| `packages/*_service` | Platform, backend, and infrastructure service contracts |
| `packages/component_library` | Design tokens, theme extensions, shared UI components |
| `packages/shared` | Cross-feature contracts such as `TextAction` |
| `packages/reader_server` | Localhost-only HTTP server for reader files and assets |
| `packages/reader_webview` | Foliate WebView wrapper, asset extraction, and JS bridge |
| `tool/translation_pack_builder` | Separate dictionary/translation pack tooling |
| `benchmarks` | Focused performance checks and audit harnesses |

## Dependency Flow

App-wide dependencies are assembled once:

1. `starter.dart` initializes logging, error reporting, dependencies, and root
   app widgets.
2. `composition.dart` constructs databases, repositories, services, and
   infrastructure objects.
3. `dependency_container.dart` stores those app-wide dependencies and owns
   shutdown/dispose behavior.
4. `root_context.dart` mounts app-level scopes.
5. `routing.dart` injects dependencies into feature `Screen` and `Sheet`
   entry points.

Feature entry points follow this rule:

- `routing.dart` passes repositories/services into `Screen`/`Sheet`.
- `Screen`/`Sheet` creates the feature `Bloc`/`Cubit`.
- `View` widgets work only with bloc/cubit state, events, and UI callbacks.
- Repositories, services, parsers, and storage objects do not go directly into
  `View` widgets.
- Small UI-only state, such as list/grid layout or reader appearance, may live
  in a dedicated UI cubit.

This keeps package boundaries explicit and keeps UI widgets testable without
global service lookups.

## Feature Packages

Current feature packages:

| Package | UI Surface |
|---------|------------|
| `packages/features/library` (`library_feature`) | `Library` tab |
| `packages/features/import_flow` | Import bottom sheet |
| `packages/features/home` | `Home` tab |
| `packages/features/profile` | `Profile` tab |
| `packages/features/dictionary` | `Dictionary` tab and detail sheets |
| `packages/features/practice` | `Practice` tab and mini-review sheet |
| `packages/features/highlight` | Reader text action and highlight sheet |
| `packages/features/flashcard` | Reader text action and flashcard sheet |
| `packages/features/translate` | Reader text action and translation sheet |
| `packages/features/subscription_paywall` | Imperative paywall sheet |
| `packages/features/source_details` | Source details screen |
| `packages/features/reader` | Full-screen reader route |

The Dart package name for Library is `library_feature` because `library` is a
Dart keyword in source syntax.

## Reader Flow

The reader is intentionally split across packages:

- `reader_server` starts a localhost-only server on `127.0.0.1` and supports
  range requests for books and reader assets.
- `reader_webview` extracts bundled foliate-js assets, serves them through the
  server, hosts `BookReaderWebView`, and translates JS bridge events into Dart
  DTOs.
- `features/reader` owns reader UI, reader blocs/cubits, text selection state,
  appearance, search, review reminders, brightness, and keep-awake behavior.
- `shared.TextAction` is the plugin point for reader selection actions.
  Highlight, flashcard, and translation features implement actions outside the
  reader feature.

The reader should not learn feature-specific persistence details. New reader
actions should be implemented as `TextAction`s and injected in `routing.dart`.

## Data and Storage

`local_storage` owns the Drift database and migrations. Feature packages should
not import DAOs directly. Repositories map storage rows to domain models:

- `book_repository` manages imported books and book-related persistence.
- `article_repository` persists extracted articles, article assets, and a
  generated EPUB used by the reader.
- `collection_repository` persists manual collections and protected built-in
  favourite memberships.
- `highlight_repository`, `flashcard_repository`, `dictionary_repository`, and
  `fsrs_repository` own review-related domain persistence.

Filesystem ownership is also repository-scoped. `composition.dart` creates the
top-level app document folders (`books`, `articles`, `reader_assets`) and passes
them into the owning packages.

## Services

Services hide backend, platform, or infrastructure concerns from features:

- `auth_service`
- `ai_service`
- `article_extraction_service`
- `connectivity_service`
- `device_screen_brightness`
- `monitoring`
- `notification_service`
- `preferences_service`
- `screen_control_service`
- `subscription_service`
- `toast_service`
- `translation_service`

Production integrations should be swapped at composition boundaries. Feature
widgets should depend on contracts, not concrete backend clients.

## Known Non-Production Contracts

The project is not fully production-complete. These are intentional gaps, not
accidental breakages:

- `NoopAuthService` reports unauthenticated status.
- `NoopAiService` returns empty AI results.
- `NoopSubscriptionService` reports free tier.
- `NoopNotificationService` drops notification operations.
- `NoopErrorReporter` and `NoopAnalyticsReporter` do not send telemetry.
- `HomeView` and `PracticeView` still contain placeholder sections.
- `/design-system` is a development route and should be gated or removed before
  production release.
- Direct DeepSeek translation is a development path. Public builds should keep
  model API keys server-side.

When replacing one of these, update the relevant package README and this section.

## Documentation Rules

Use comments to explain contracts and reasons, not the mechanics of obvious
code. Good comment targets:

- an intentional no-op or stub;
- a lifecycle or platform constraint;
- a workaround for a framework, WebView, OS, or backend behavior;
- a non-obvious algorithmic choice.

Avoid comments that restate code line by line.

## Verification

Preferred project checks:

```sh
make analyze
make test
```

Focused package work can use package-level `flutter test` or `dart test`.
`test_all.sh` includes package tests plus the reader WebView JS tests. Benchmarks
under `benchmarks/` are separate audit tools and should be run when changing
performance-sensitive reader/import behavior.

## Handoff Checklist

Before handing work to another maintainer:

- Read `AGENTS.md`, this document, and the README for the changed package.
- Keep feature dependencies flowing through `routing.dart` -> `Screen`/`Sheet`
  -> `Bloc`/`Cubit` -> `View`.
- Keep generated files and vendor JS out of manual refactors unless the task is
  specifically about those assets.
- Update docs when adding packages, changing package responsibilities, replacing
  no-op services, or introducing new runtime flags.
