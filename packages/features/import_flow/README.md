# import_flow

Bottom sheet for adding content to the library: import a book file
(EPUB / PDF / FB2 / MOBI / AZW3 / CBZ) or save an article URL. Opened from the Library screen's FAB
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
  while the sheet remains open. Dismissal is not an import-completion signal.

An already-started import may finish after the sheet/cubit closes. The routing
callbacks notify Library through `LibraryImportLauncher.onImported` after
persistence succeeds, independently of this sheet's result. A closed cubit
does not emit progress/results, but closing it does not cancel the storage work.

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
done / failure. Steps share a stable preferred body height (264dp at normal text
scale), with more space for larger system text. Menu and URL forms scroll when
content exceeds the viewport or the keyboard leaves less room. The menu uses
two full-width flat action rows with book/link icons and directional chevrons;
their divider spans the full row width within the sheet padding. The close
action stays in the header while the rows scroll.
Divider color and thickness come from the shared `DividerTheme`, as in Library.
The rows use 24dp vertical padding and share any unused body space equally
above and below the group. Long content scrolls instead of stretching the sheet;
the menu and URL form retain the same height on forward/back navigation.
Offline article import remains disabled, with a warning icon and no navigation
chevron, while local books remain available. The URL form uses its validation
area as the gap above hints, balanced by 24dp below them before the actions.
The input reserves space for its localized validation messages so showing or
clearing an error does not move the hints or buttons. The reserved area follows
the available width and text scale and is excluded from accessibility until
an error is shown.
It uses finite minimum height without intrinsic measurement or unbounded flex
children. Status content also scrolls
when necessary. Clipboard access is still explicit: Paste has a full 52x48px
target and never reads on sheet open.

Invalid or empty clipboard text produces an inline URL error without replacing
the current input. Clipboard access failures have a separate inline message.
Late clipboard replies are ignored after editing, navigation, dismissal, or a
newer paste. The cubit owns URL normalization and validation; the form only
reads the platform clipboard and keeps its controller aligned with cubit state.

After failure, **Choose file** reopens the book picker; cancelling the picker
leaves the failure visible. For articles, **Edit link** returns to the previously
submitted URL without making another request. Saving again remains explicit.
Failure actions stack only when their localized labels cannot fit side by side.
The book percentage label grows with text scaling and keeps the same space
between indeterminate and determinate progress. Progress emission is still
coalesced to visible one-percent changes.

## Verification

Package tests cover balanced menu/hint spacing and stable step height in English,
Russian, and Arabic, menu hit targets and disabled semantics, RTL/large-text
header access, validation, clipboard races/failures, retry state, picker
cancellation, progress layout, and keyboard access with enlarged text.
Real-font goldens check spacing from the visible input border, not the field's
invisible validation area. Validation geometry and error semantics are checked
in all supported languages at normal and 200% text scale.
`test/ui/import_flow_golden_test.dart` exercises the production sheet over an
isolated Library: online/offline menu, book progress/failure, invalid Paste,
article failure, and URL restoration. Its profiles include Russian and Arabic
**phone-sized** layouts, dark mode, 200% German text, and landscape. Native
library-controls tests cover menu dismissal, connectivity changes, and
navigation to both import paths. Native pickers, real clipboard permissions,
and live extraction require separate device checks.

## Dependencies

- `book_repository` — persistence
- `reader_webview` — `BookMetadataExtractor` for supported document metadata
- `domain_models` — `BookFormat`
- `component_library` — `showAppBottomSheet`, `BottomSheetHeader`,
  `ActionBottomSheetLayout`, `AppIcons`, `AppSpacing`
- `monitoring` — non-fatal logging
- `file_picker` — file picker integration
