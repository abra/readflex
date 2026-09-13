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

UI flows and committed visual comparisons run without API keys:

```sh
make test-ui
make test-device DEVICE=<device-id>
make coverage
make test-performance
```

See [UI verification](test/ui/README.md) for coverage, native prerequisites,
baseline updates, and remaining manual checks. Native screenshots and failure
diagnostics go under `.local/`; `make verify` never updates visual baselines.
Coverage reports enumerate unmeasured files and uncovered executable lines and
branches instead of treating test counts as full coverage. For native Dart line
coverage, add `COVERAGE=1` to `make test-device`; see the UI guide for combining
matching runs. Benchmarks record elapsed time plus structural work counters,
not release-device FPS.

Run the app:

```sh
./run.sh
# Or: make run
```

On the first run the script creates `.local/run-defines.json` from
`config/run-defines.example.json` with owner-only permissions and exits without
launching Flutter. Set `READFLEX_API_KEY` and, optionally, `GLITCHTIP_DSN` in that
local file once; subsequent runs require no `export` commands. `.local/` is
ignored by version control. Do not commit or share this file.

The script uses the FVM-pinned SDK and passes the file to Flutter with
`--dart-define-from-file`, without printing its contents. Arguments are forwarded
unchanged, and the script also works when invoked from another directory:

```sh
./run.sh -d <device-id>
./run.sh --release -d <device-id>
make run ARGS='--profile'
```

The template explicitly selects `ENVIRONMENT=DEV`, including for `--release`:
this is a local device-testing setup, not a store-distribution configuration.
Build-time credentials are still embedded in the app and build artifacts. Do
not distribute builds made with this private file. Individual
`--dart-define=NAME=value` arguments override values from the file.

Common dart-defines:

| Flag | Purpose |
|------|---------|
| `ENVIRONMENT` | `DEV`, `STAGING`, or `PROD`; defaults to DEV in debug and PROD in release |
| `ARTICLE_CLEANER_BASE_URL` | Article extraction backend base URL; defaults to localhost in DEV and `https://api.readflex.app` in PROD |
| `READFLEX_API_KEY` | Development-only shared backend credential; rejected in STAGING/PROD builds |
| `ARTICLE_CLEANER_API_KEY` | Legacy development alias for `READFLEX_API_KEY` |
| `CONTEXTUAL_TRANSLATION_BASE_URL` | Contextual translation backend base URL; defaults to `ARTICLE_CLEANER_BASE_URL` |
| `DICTIONARY_BASE_URL` | Readflex Dictionary backend base URL; defaults to `ARTICLE_CLEANER_BASE_URL` |
| `GLITCHTIP_DSN` | Optional GlitchTip DSN for Sentry-compatible error reporting |
| `GLITCHTIP_TRACES_SAMPLE_RATE` | Optional GlitchTip performance trace sampling rate; defaults to `0` |

Static API credentials are allowed only in DEV. Production requests must use a
short-lived server-issued credential; implementing that backend authentication
contract remains a release blocker.

Android release builds require an upload keystore. Copy
`android/key.properties.example` to the ignored `android/key.properties`, or
provide the documented `READFLEX_ANDROID_*` variables in CI. `make build`
produces the signed AAB used by Google Play; `make build-apk` is available for
direct release-device testing.

GlitchTip uses the Sentry-compatible Dart SDK. Prefer `GLITCHTIP_DSN` for
Readflex builds; `SENTRY_DSN` is accepted as a fallback for compatibility with
GlitchTip's SDK docs.

Feature wiring follows `routing.dart -> Screen/Sheet -> Bloc/Cubit -> View`.
See [ARCHITECTURE.md](ARCHITECTURE.md) for the full convention.

## Current Production Gaps

Some contracts are intentionally incomplete while the app is still being built:

- Error reporting sends to GlitchTip when `GLITCHTIP_DSN` or `SENTRY_DSN` is
  provided. Without a DSN it intentionally falls back to `NoopErrorReporter`.
- The reader dictionary action is active and uses the platform dictionary
  first, with the Readflex Dictionary API as fallback. Flashcard, practice,
  profile, subscription, auth, AI, and notification surfaces remain frozen
  outside the active package graph; their last legacy revision is `189e2cc1`.
