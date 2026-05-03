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
  required ImportBookFile onImportBook,
});
```

- `onImportBook` — called when the user taps "Import book file"; returns
  `true` on success. The default implementation lives here as `importBook()`
  and calls `FilePicker`, extracts metadata with `BookMetadataExtractor` from
  `reader_webview` (foliate-js via local HTTP server), and persists via
  `BookRepository`.
- Sheet resolves with `ImportFlowResult.bookImported` when the user
  finishes a successful import so the caller (e.g. `catalog_screen`) can
  refresh.

Helpers exported from `import_flow.dart`:

| Symbol                | Purpose                                  |
|-----------------------|------------------------------------------|
| `showImportFlowSheet` | Shows the sheet                          |
| `importBook`          | Default book-import implementation       |
| `bookExtensions`      | File-picker allowed extensions           |
| `ImportFlowResult`    | What got imported                        |

## Architecture

Multi-step animated sheet driven by `ImportFlowCubit` — picker → loading →
success / failure. See `memory/project_import_flow_evolution.md` for the
animated-transition design.

## Dependencies

- `book_repository` — persistence
- `reader_webview` — `BookMetadataExtractor` for EPUB metadata
- `domain_models` — `BookFormat`
- `component_library` — `ActionBottomSheetLayout`, `ButtonLoadingIndicator`,
  `showAppBottomSheet`, `AppIcons`, `AppSpacing`
- `monitoring` — non-fatal logging
- `file_picker` — file picker integration
