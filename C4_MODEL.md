# Readflex C4 Model

This document describes the current Readflex architecture using the C4 model.
It complements `ARCHITECTURE.md`: that file defines package rules and
maintainer conventions, while this file shows the system from progressively
lower levels of abstraction.

The implementation is the source of truth. Update this model when package
boundaries, runtime containers, storage ownership, or integration points change.

## Level 1: System Context

Readflex is a mobile reading app for imported books, saved web articles, and
highlights. It runs on iOS and Android, stores user data locally, draws books
and articles with its own reader engine (`vellum`), and optionally calls
remote article cleaning, contextual translation, and dictionary backends.

```mermaid
flowchart LR
  user["Reader"]
  app["Readflex mobile app"]
  websites["Publisher websites"]
  cleaner["Article Cleaner API"]
  translation["Contextual Translation API"]
  dictionary["Readflex Dictionary API"]
  platform["iOS / Android platform services"]

  user -->|"Imports books, saves articles, reads, highlights"| app
  app -->|"Fetches article URLs or downloaded HTML for extraction"| cleaner
  app -->|"Translates selected text in context"| translation
  app -->|"Looks up definitions when system lookup is unavailable"| dictionary
  cleaner -->|"May fetch original article URL"| websites
  app -->|"Can fallback-download article HTML"| websites
  app -->|"Files, brightness, wakelock, connectivity, system dictionary"| platform
```

### External Systems

| System | Responsibility | Current integration |
|--------|----------------|---------------------|
| Article Cleaner API | Extracts readable article content from URLs or downloaded HTML. | `article_extraction_service` via HTTP. |
| Publisher websites | Original article pages and assets. | Article cleaner server fetches first; app can fallback-download HTML. |
| Contextual Translation API | Resolves selected text using surrounding reading context. | `contextual_translation_service` via HTTP. |
| Readflex Dictionary API | Returns validated, cached monolingual lexical definitions. | `dictionary_service` via HTTP after native lookup fallback. |
| iOS / Android platform services | Files, image codecs, brightness, wakelock, connectivity, native dictionary UI. | Flutter plugins, app runner channels, and local packages. |

The backend implementations are outside this checkout. Their provider calls,
server-side caches and deployment details are not client-owned contracts.
PDFium and the Rust MOBI library are bundled reader dependencies, not system
PDF or dictionary services.

## Level 2: Containers

Readflex is shipped as one Flutter mobile app, but internally it has clear
runtime containers: the Flutter UI/runtime with its reader engine, a local
Drift database, and app-owned files.

```mermaid
flowchart TB
  user["Reader"]

  subgraph mobile["Readflex mobile app"]
    appShell["Flutter app shell\nlib/app"]
    features["Feature packages\nlibrary, practice, import_flow, reader, highlight, translate, dictionary, onboarding"]
    repos["Repositories and services\ncontent, preferences, connectivity, translation, dictionary, screen control"]
    db["Drift SQLite database\nreadflex.db"]
    files["App documents files\nbooks, articles"]
    engine["vellum reader engine\nDart formats/layout, PDFium, Rust MOBI backend"]
  end

  cleaner["Article Cleaner API"]
  remoteApis["Translation / Dictionary APIs"]
  platform["iOS / Android platform APIs"]

  user --> appShell
  appShell --> features
  features --> repos
  repos --> db
  repos --> files
  features --> engine
  engine --> files
  repos --> cleaner
  repos --> remoteApis
  repos --> platform
  engine --> platform
```

### Container Responsibilities

| Container | Code location | Responsibility |
|-----------|---------------|----------------|
| Flutter app shell | `lib/app` | Bootstrap, dependency composition, scopes, GoRouter routes, app lifecycle, system UI mode. |
| Feature packages | `packages/features/*` | User-facing flows and feature state management. |
| Repositories/services | `packages/*_repository`, `packages/*_service`, specialized packages | Data source orchestration, platform/backend contracts, persistence boundaries. |
| Local database | `packages/local_storage` | Drift schema, DAOs, migrations, storage rows. |
| App files | App documents directory | Imported books, extracted article HTML and assets. |
| Reader engine | `packages/vellum` | Opens EPUB, FB2, MOBI/KF8, CBZ, PDF and saved articles from their files, lays them out and draws their pages; import metadata, search, selection, CFIs. |
| MOBI text backend | `packages/vellum_mobi_native` | Vellum's Rust record I/O and PalmDOC/HUFF-CDIC decoder over FRB; lazy KF8 reads and batched MOBI 6 text, built through Native Assets. Headers, chapters, document parsing and UI remain in Dart. |

## Level 3: Components

### App Shell Components

```mermaid
flowchart TB
  main["main.dart"]
  starter["starter.dart"]
  bootstrap["AppBootstrap"]
  composition["composition.dart"]
  container["DependenciesContainer"]
  scopes["AppScopes\ndependencies, preferences, connectivity, lifecycle"]
  app["ReadflexApp\nMaterial app, theme, locale"]
  router["routing.dart"]

  main --> starter
  starter --> bootstrap
  bootstrap --> composition
  composition --> container
  starter --> scopes
  scopes --> app
  app --> router
  router -->|"Injects dependencies into Screen/Sheet entry points"| features["Feature entry points"]
```

| Component | Responsibility |
|-----------|----------------|
| `starter.dart` | Flutter binding, error zone, logging, bloc observer, tracing, app mounting and recovery screen. |
| `app_bootstrap.dart` | Configuration validation, monitoring initialization/reuse, dependency creation and failed-attempt cleanup. |
| `composition.dart` | Creates database, repositories, services and document directories. |
| `dependency_container.dart` / `resource_disposer.dart` | Explicit dependency holder and reverse-order, idempotent cleanup; rollback retains monitoring for retry. |
| `app_scopes.dart` / `readflex_app.dart` / `app_lifecycle.dart` | Root scopes, Material app, retained router, service lifecycle handling. |
| `routing.dart` | Navigation table, entry redirects, feature wiring, app-level callbacks. |

### Feature Components

```mermaid
flowchart LR
  routing["routing.dart"]
  screen["Screen / Sheet"]
  bloc["Bloc / Cubit"]
  view["View widgets"]
  repo["Repository / Service"]

  routing -->|"passes repositories, services, callbacks"| screen
  screen -->|"creates and provides"| bloc
  view -->|"reads state, dispatches events, calls UI callbacks"| bloc
  bloc --> repo
```

| Feature | Entry point | State owner | Main dependencies |
|---------|-------------|-------------|-------------------|
| Library | `LibraryScreen` | `LibraryBloc`, layout/theme/locale/page-animation/selection cubits | Book, article, collection and FSRS repositories, preferences, toast wrapper. |
| Practice | `PracticeScreen`, `ReviewSessionScreen`, `PracticeWordsScreen`, `PracticeHighlightsScreen` | `PracticeBloc`, `ReviewSessionBloc`, words/highlights/settings cubits | FSRS, dictionary, highlight, book and article repositories, preferences, toast wrapper. |
| Import Flow | `showImportFlowSheet` | `ImportFlowCubit` | File picker/import callbacks, article import callback, vellum metadata extraction. |
| Reader | `ReaderScreen` | `ReaderBloc` plus reader UI cubits | Book/article/highlight repositories, preferences, vellum, screen control, text actions. |
| Highlight | `HighlightAction`, `HighlightSheet` | Immediate action plus `HighlightCubit` for the standalone sheet | Highlight repository, shared text action contract. |
| Translate | `TranslateAction`, `TranslateSheet` | `TranslateCubit` | Contextual translation service, preferences, shared text action contract. |
| Dictionary | `DictionaryAction`, `DictionarySheet` | `DictionaryCubit` | Native system dictionary bridge, remote dictionary service, shared text action contract. |
| Onboarding | `OnboardingScreen` | Router-owned completion callback | Shared components and localizations; the router persists completion. |

### Reader Components

```mermaid
flowchart TB
  readerScreen["ReaderScreen"]
  readerBloc["ReaderBloc\nsource, position, bookmarks, highlights"]
  uiCubit["ReaderUiCubit\nchrome, drawers, overlays"]
  appearance["ReaderAppearanceCubit"]
  brightness["ReaderBrightnessCubit / KeepAwakeCubit"]
  pageBody["Page body\ntext, comic, PDF or article"]
  surface["ReaderSurface\ncommands to the page"]
  vellum["vellum package"]
  repos["Book / Article / Highlight repositories"]
  prefs["PreferencesService"]
  screenControl["ScreenControlService"]

  readerScreen --> readerBloc
  readerScreen --> uiCubit
  readerScreen --> appearance
  readerScreen --> brightness
  readerScreen --> pageBody
  readerScreen --> surface
  surface --> vellum
  pageBody --> vellum
  pageBody -->|"positions, selections, taps"| readerBloc
  readerBloc --> repos
  appearance --> prefs
  brightness --> prefs
  brightness --> screenControl
```

Reader-specific split:

- `ReaderBloc` owns source loading, persisted position, bookmarks, TOC,
  highlights, and article/book persistence.
- `ReaderUiCubit` owns chrome, drawer, tap-zone, and transient UI overlays.
- `ReaderSearchCubit`, `ReaderSelectionCubit`, `ReaderImageSelectionCubit`,
  and `ReaderImageHighlightCubit` keep narrower UI/interaction concerns out of
  `ReaderBloc`.
- `ReaderArticleProgressCubit` publishes live article scroll progress separately
  from throttled reading-position persistence.
- Reader observes the global page animation chosen through Library's
  `LibraryPageAnimationCubit`; Vellum resolves book progression from metadata
  and a bounded content sample, independently of the UI locale.
- The page bodies host vellum's views and translate their events into the
  blocs and cubits; `ReaderSurface` carries the screen's commands to the
  page. vellum owns formats, layout, search, selection and annotation
  drawing.

## Level 4: Code-Level Slices

### Library Source Open Flow

```mermaid
sequenceDiagram
  participant User
  participant LibraryView
  participant Router
  participant ReaderScreen
  participant ReaderBloc
  participant Repositories

  User->>LibraryView: Tap source
  LibraryView->>Router: onSourcePressed(source)
  Router->>ReaderScreen: push /reader/:sourceId with post-open callback
  ReaderScreen->>ReaderBloc: ReaderSourceLoadRequested
  ReaderBloc->>Repositories: load source, highlights, bookmarks
  Repositories-->>ReaderBloc: domain models
  ReaderBloc-->>ReaderScreen: ready state
  ReaderScreen-->>LibraryView: onSourceOpened callback eventually refreshes Library
```

### Article Import Flow

```mermaid
sequenceDiagram
  participant User
  participant ImportFlowSheet
  participant Routing
  participant ExtractionService
  participant ArticleRepository
  participant Storage

  User->>ImportFlowSheet: Enter article URL
  ImportFlowSheet->>Routing: onImportArticle(url)
  Routing->>ExtractionService: extract(url)
  ExtractionService->>ExtractionService: server extraction, optional client HTML fallback
  ExtractionService-->>Routing: ExtractedArticle
  Routing->>ArticleRepository: addExtractedArticle(article)
  ArticleRepository->>Storage: write DB row, content.html, metadata, assets
  ArticleRepository-->>ImportFlowSheet: Article
```

### Reader Position Persistence

```mermaid
sequenceDiagram
  participant Vellum as vellum controller
  participant PageBody as Page body
  participant ReaderBloc
  participant Repository

  Vellum->>PageBody: position changed
  PageBody->>ReaderBloc: ReaderBookPositionUpdated
  ReaderBloc->>ReaderBloc: normalize article/book progress and emit state
  ReaderBloc->>ReaderBloc: debounce pending persistence
  ReaderBloc->>Repository: updateReadingPosition(id, cfi, progress)
```

## Architectural Invariants

- `routing.dart` is the composition root for feature navigation and external
  callbacks.
- Screen/Sheet entry points may receive repositories/services.
- View/private widgets should use Bloc/Cubit state, events, and UI callbacks,
  not repositories, services, DAOs, or backend clients.
- Feature packages must not import sibling feature packages.
- Domain models remain storage-agnostic and Flutter-agnostic.
- Storage rows and DAOs remain behind repositories.
- Reader text actions use `shared.TextAction`; the reader does not import the
  Highlight, Translate, or Dictionary features directly.
- Connectivity is a UI signal; services still attempt work and map failures.

## Known Production Gaps

- Error reporting uses GlitchTip when configured; analytics remains a no-op.
- Production backend authentication/attestation and short-lived access tokens
  are not implemented. Static build-time API credentials are blocked outside
  development.
- Flashcard, profile, subscription, auth, AI, and notification
  surfaces are currently outside the active package graph.
- Saved dictionary words and highlights use the active FSRS review store.
  Legacy flashcard tables remain for migration compatibility only.
- Practice word cards have no Listen (TTS) action or daily reminder.
