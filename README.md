<h1 align="center">
  <img width="120" height="120" alt="Logo" src="assets/logo.png">
  <br/>Readflex
</h1>

<p align="center">Mobile reading app with highlights, flashcards, and translation.</p>

## Overview

Readflex is a Flutter reading app for books, articles, highlights, flashcards,
and contextual translation. The codebase is split into small local packages
instead of one large `lib/` tree.

Start here:

- [ARCHITECTURE.md](ARCHITECTURE.md) — project shape, package boundaries, and
  handoff rules.
- `packages/*/README.md` — public APIs and implementation notes for each
  package.
- [benchmarks/README.md](benchmarks/README.md) — opt-in performance checks.

## Project Layout

| Path | Purpose |
|------|---------|
| `lib/app` | App bootstrap, dependency composition, GoRouter routes, root scopes |
| `packages/features/*` | Feature UI surfaces and feature state management |
| `packages/*_repository` | Domain repositories over storage and files |
| `packages/*_service` | Platform, backend, and infrastructure contracts |
| `packages/local_storage` | Drift database, DAOs, migrations, storage mappers |
| `packages/domain_models` | Pure domain models, enums, and exceptions |
| `packages/component_library` | Theme, design tokens, and reusable widgets |
| `packages/reader_server` / `packages/reader_webview` | Local reader server and Foliate WebView bridge |

## Development

Install dependencies:

```sh
make get
```

Analyze:

```sh
make analyze
```

Test:

```sh
make test
```

Run the app:

```sh
flutter run \
  --dart-define=ARTICLE_CLEANER_BASE_URL=https://your-cleaner.example \
  --dart-define=DEEPSEEK_API_KEY="$DEEPSEEK_API_KEY"
```

Common dart-defines:

| Flag | Purpose |
|------|---------|
| `ARTICLE_CLEANER_BASE_URL` | Article extraction backend base URL |
| `ARTICLE_CLEANER_API_KEY` | Optional article cleaner API key |
| `DEEPSEEK_API_KEY` | Enables direct DeepSeek translation in development |
| `DEEPSEEK_BASE_URL` | Optional DeepSeek-compatible API endpoint |
| `DEEPSEEK_MODEL` | Optional DeepSeek-compatible model name |

Do not ship public builds with client-side API keys. Backend-backed production
integrations should replace direct development clients and no-op service stubs.

Feature wiring follows `routing.dart -> Screen/Sheet -> Bloc/Cubit -> View`.
See [ARCHITECTURE.md](ARCHITECTURE.md) for the full convention.

## Current Production Gaps

Some contracts are intentionally stubbed while the app is still being built:

- Auth, AI generation, subscription, notification, analytics, and error
  reporting are represented by no-op services in development composition.
- Home and Practice screens still have placeholder sections.
- Direct DeepSeek translation is a development path; production should keep API
  keys server-side.
