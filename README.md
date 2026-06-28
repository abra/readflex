<h1 align="center">
  <img width="120" height="120" alt="Logo" src="assets/logo.png">
  <br/>Readflex
</h1>

<p align="center">Mobile reading app for books, articles, and highlights.</p>

## Overview

Readflex is a Flutter reading app for books, articles, and highlights. The
codebase is split into small local packages instead of one large `lib/` tree.

Start here:

- [ARCHITECTURE.md](ARCHITECTURE.md) — project shape, package boundaries, and
  handoff rules.
- [C4_MODEL.md](C4_MODEL.md) — system context, container, component, and
  code-level architecture views.
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
  --dart-define=ARTICLE_CLEANER_BASE_URL=https://your-cleaner.example
```

Common dart-defines:

| Flag | Purpose |
|------|---------|
| `ARTICLE_CLEANER_BASE_URL` | Article extraction backend base URL |
| `ARTICLE_CLEANER_API_KEY` | Optional article cleaner API key |

Do not ship public builds with client-side API keys. Backend-backed production
integrations should keep provider credentials server-side.

Feature wiring follows `routing.dart -> Screen/Sheet -> Bloc/Cubit -> View`.
See [ARCHITECTURE.md](ARCHITECTURE.md) for the full convention.

## Current Production Gaps

Some contracts are intentionally incomplete while the app is still being built:

- Error reporting is represented by a no-op reporter until a production
  provider is wired.
- The translation, dictionary, flashcard, practice, profile, subscription, auth,
  AI, and notification surfaces are frozen and removed from the active package
  graph. The last revision containing them is `189e2cc1`.
