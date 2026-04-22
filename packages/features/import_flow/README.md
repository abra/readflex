# import_flow

Bottom sheet for adding content to the library: import a book file
(EPUB / PDF / FB2 / MOBI / AZW3 / CBZ / TXT) or save a web article by URL.
Opened from the Library tab's FAB and from the post-onboarding
`FirstImportScreen`.

## Public API

Entry point is a function, not a screen — the sheet is presentation-only and
delegates work through callbacks.

```dart
Future<ImportFlowResult?> showImportFlowSheet(
  BuildContext context, {
  required Future<bool> Function() onImportBook,
  required Future<ArticleImportOutcome> Function(String url) onImportArticle,
});
```

- `onImportBook` — called when the user taps "Import book file"; returns
  `true` on success. The default implementation lives here as `importBook()`
  and calls `FilePicker`, extracts metadata with `BookMetadataExtractor` from
  `reader_webview` (foliate-js via local HTTP server), and persists via
  `BookRepository`.
- `onImportArticle(url)` — returns a typed `ArticleImportOutcome` so the sheet
  can render reason-specific error messages (`invalidUrl`, `network`,
  `httpError`, `noReadableContent`, `storage`, `unknown`). The default
  implementation lives here as `importArticle()` and runs `ArticleParser` →
  `ArticleRepository`.
- Sheet resolves with `ImportFlowResult.{bookImported, articleImported}` so
  the caller (e.g. `catalog_screen`) can refresh.

Helpers exported from `import_flow.dart`:

| Symbol                         | Purpose                                                    |
|--------------------------------|------------------------------------------------------------|
| `showImportFlowSheet`          | Shows the sheet                                            |
| `importBook`                   | Default book-import implementation                         |
| `importArticle`                | Default article-import implementation                      |
| `bookExtensions`               | File-picker allowed extensions                             |
| `ImportFlowResult`             | What got imported                                          |
| `ArticleImportOutcome`         | Sealed `success` / `failure(reason)` result                |
| `ArticleImportFailureReason`   | Enum of user-facing failure categories                     |

## Architecture

Intentionally no Cubit yet — the flow is short (pick action → execute → pop)
and uses local `setState`. Documented in-code: once the sheet grows into a
multi-step animated flow (see `memory/project_import_flow_evolution.md`), an
`ImportFlowCubit` will take over step transitions while keeping the same
callback contract.

Two inner widgets:

- `_ImportFlowSheet` — root with two list tiles (book file / article URL).
- `_ArticleUrlInput` — shown after tapping the article tile; submits the URL
  and maps failure reasons to messages.

## Dependencies

- `book_repository`, `article_repository` — persistence
- `article_parser` — fetches and cleans article HTML
- `reader_webview` — `BookMetadataExtractor` for EPUB metadata
- `domain_models` — `BookFormat`
- `component_library` — `ActionBottomSheetLayout`, `ButtonLoadingIndicator`,
  `showAppBottomSheet`, `AppIcons`, `AppSpacing`
- `monitoring` — non-fatal logging
- `file_picker` — file picker integration
