# import_flow

Bottom sheet for adding content to the library: import a book file
(EPUB / PDF / FB2 / MOBI / AZW3 / CBZ). Opened from the Library tab's FAB
and used as the single import entry point for adding library content.

## Public API

Entry point is a function, not a screen — the sheet is presentation-only and
delegates work through callbacks.

```dart
Future<ImportFlowResult?> showImportFlowSheet(
  BuildContext context, {
  required PickBookFile onPickBookFile,
  required ImportBookFile onImportBook,
  required ImportArticleUrl onImportArticle,
  bool isOffline = false,
  Stream<bool>? isOfflineStream,
  IsBookImportTermsAccepted? isBookImportTermsAccepted,
  AcceptBookImportTerms? acceptBookImportTerms,
  Future<void> Function()? onOpenTerms,
  Future<void> Function()? onOpenPrivacy,
});
```

- `onPickBookFile` — opens the platform picker and returns a selected file or
  `null` on cancel. The default helper is `pickBookFile()`.
- `onImportBook` — called after a file is picked; returns the persisted
  `Book?`. The default helper is `importBookFile(...)`, which extracts
  metadata with `BookMetadataExtractor` from `reader_webview` (foliate-js via
  local HTTP server) and persists via `BookRepository`.
- `onImportArticle` — imports a cleaned article from a URL.
- `isOffline` / `isOfflineStream` — disable and live-update the article URL
  path when the app shell knows there is no network. Book uploads stay
  available because they are local.
- `isBookImportTermsAccepted` / `acceptBookImportTerms` — optional gate for
  book uploads; callers normally back this with persisted preferences.
- `onOpenTerms` / `onOpenPrivacy` — optional external legal-link callbacks.
- Sheet resolves with `ImportFlowResult.bookImported` or
  `ImportFlowResult.articleImported` when the user finishes a successful import
  so the caller (e.g. `library_screen`) can refresh.

Helpers exported from `import_flow.dart`:

| Symbol                | Purpose                                  |
|-----------------------|------------------------------------------|
| `showImportFlowSheet` | Shows the sheet                          |
| `pickBookFile`        | Default file-picker implementation       |
| `importBookFile`      | Default book-import implementation       |
| `bookExtensions`      | File-picker allowed extensions           |
| `ImportFlowResult`    | What got imported                        |

## Architecture

Multi-step animated sheet driven by `ImportFlowCubit` — menu → uploading →
done / failure. The body height is pinned so the sheet does not resize between
states.

## Dependencies

- `book_repository` — persistence
- `reader_webview` — `BookMetadataExtractor` for EPUB metadata
- `domain_models` — `BookFormat`
- `component_library` — `showAppBottomSheet`, `BottomSheetHeader`,
  `AppActionCard`, `AppIcons`, `AppSpacing`
- `monitoring` — non-fatal logging
- `file_picker` — file picker integration
