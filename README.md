<h1 align="center">
  <img width="120" height="120" alt="Logo" src="assets/logo.png">
  <br/>Readflex
</h1>

<p align="center">Mobile reading app with highlights, flashcards, and translation.</p>

## Overview

Readflex is a Flutter app split into small local packages. The app shell in
`lib/app` owns startup, dependency composition, routing, and app-level scopes.
Feature packages under `packages/features/*` own screens, sheets, blocs/cubits,
and feature UI. Repository and service packages sit behind those features and
hide storage, platform, and network details.

Start with [ARCHITECTURE.md](ARCHITECTURE.md) for the project shape
and package boundaries. Package-level README files document individual public
APIs and implementation notes.

## Project Layout

| Path | Purpose |
|------|---------|
| `lib/app` | App bootstrap, dependency composition, GoRouter routes, root scopes |
| `packages/features/*` | Feature UI surfaces and feature state management |
| `packages/*_repository` | Domain repositories over local storage and files |
| `packages/*_service` | Platform, backend, or infrastructure service contracts |
| `packages/local_storage` | Drift database, DAOs, migrations, storage mappers |
| `packages/domain_models` | Pure domain models, enums, and exceptions |
| `packages/component_library` | Shared design system, tokens, and reusable widgets |
| `packages/reader_server` | Localhost HTTP server for reader assets and files |
| `packages/reader_webview` | Foliate WebView wrapper and reader bridge |
| `tool/translation_pack_builder` | Offline dictionary/translation pack tooling |
| `benchmarks` | Focused performance audit harnesses |

## Development

Install dependencies for the app and local packages:

```sh
make get
```

Run project-wide analysis:

```sh
make analyze
```

Run the package test suite:

```sh
make test
```

Run the app:

```sh
flutter run \
  --dart-define=ARTICLE_CLEANER_BASE_URL=https://your-cleaner.example \
  --dart-define=DEEPSEEK_API_KEY="$DEEPSEEK_API_KEY"
```

Useful development flags:

| Flag | Purpose |
|------|---------|
| `ARTICLE_CLEANER_BASE_URL` | Article extraction backend base URL |
| `ARTICLE_CLEANER_API_KEY` | Optional article cleaner API key |
| `DEEPSEEK_API_KEY` | Enables direct DeepSeek translation in development |
| `DEEPSEEK_BASE_URL` | Optional DeepSeek-compatible API endpoint |
| `DEEPSEEK_MODEL` | Optional DeepSeek-compatible model name |
| `READFLEX_TRACE_BUILDS` | Logs screen/widget build tracing hooks |
| `READFLEX_PROFILE_BUILDS` | Enables Flutter build profiling |
| `READFLEX_PROFILE_USER_BUILDS` | Enables user-widget build profiling |
| `READFLEX_TRACE_READER_BUILDS` | Logs focused reader rebuild tracing |
| `READFLEX_TRACE_FRAME_TIMINGS` | Logs frame timing over budget |
| `READFLEX_TRACE_FRAME_TIMING_BUDGET_MS` | Frame timing log threshold in ms |

Do not ship public builds with client-side API keys. Backend-backed production
integrations should replace direct development clients and no-op service stubs.

## Current Production Gaps

Some contracts are intentionally stubbed while the app shell, reader, and import
flows are being built. Do not treat these as broken behavior unless a task asks
to implement them:

- Auth, AI generation, subscription, notification, analytics, and error
  reporting are represented by no-op services in development composition.
- Home and Practice screens still have placeholder sections.
- `/design-system` is a development route and must be removed or gated before a
  production release.
- Direct DeepSeek translation is a development path; production should keep API
  keys server-side.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the handoff checklist and
the expected feature dependency pattern.
