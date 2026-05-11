# import_flow

Bottom sheet for adding content to the library: import a book file
(EPUB / PDF / FB2 / MOBI / AZW3 / CBZ). Opened from the Library tab's FAB
and from the post-onboarding `FirstImportScreen`.

## Public API

Entry point is a function, not a screen — the sheet is presentation-only and
delegates work through callbacks.

```dart
Future<ImportFlowResult?> showImportFlowSheet(
  BuildContext context, {
  required PickBookFile onPickBookFile,
  required ImportBookFile onImportBook,
});
```

- `onPickBookFile` — opens the platform picker and returns a selected file or
  `null` on cancel. The default helper is `pickBookFile()`.
- `onImportBook` — called after a file is picked; returns the persisted
  `Book?`. The default helper is `importBookFile(...)`, which extracts
  metadata with `BookMetadataExtractor` from `reader_webview` (foliate-js via
  local HTTP server) and persists via `BookRepository`.
- Sheet resolves with `ImportFlowResult.bookImported` when the user
  finishes a successful import so the caller (e.g. `catalog_screen`) can
  refresh.

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
