# import_flow

Bottom sheet for adding content to the library: import a book file
(EPUB / PDF / FB2 / MOBI / AZW3 / CBZ) or save an article URL. Opened from the Library screen's FAB
and used as the single import entry point for adding library content; callers
that already know the path pass an `ImportFlowEntry` instead of a second sheet.

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
  ImportFlowEntry entry = ImportFlowEntry.menu,
});
```

- `onPickBookFile` — opens the platform picker and returns a selected file or
  `null` on cancel. The default helper is `pickBookFile()`.
  Provider exceptions become the localized book-import failure/retry state;
  cancellation remains silent and late picker errors do not emit after close.
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
- `entry` — where the sheet starts. `menu` shows the two rows. `file` runs
  the file row's action before the first frame: the consent step while terms
  are not accepted, otherwise the platform picker over the menu (cancel leaves
  the menu). `article` opens the URL step directly. Steps opened this way
  behave like steps opened from the menu: header/system Back returns to the
  menu and the URL draft is retained until the sheet closes. The article entry
  still opens offline; the form then shows the offline hint and keeps Save
  disabled.
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
| `ImportFlowEntry`     | Starting step: menu, file or article     |

## Architecture

Multi-step animated sheet driven by `ImportFlowCubit` — menu → uploading →
done / failure. Menu, URL entry and the status steps (uploading, done, failure) share one
preferred body height (272dp at normal text scale, more for larger system
text): starting an import never grows the sheet. Status content is the icon
block above an action row; while a book copies, that row holds the progress
bar and its phase label, and Done or Retry take the same row afterwards, so
the icon keeps one position across the three states and the status steps never
grow. Failure shows a single full-width Retry (Choose file / Edit link); leaving
is the header Close's job, so no Cancel sits beside it.
The **Before uploading** consent step uses that height as its minimum and grows
only when its content needs more room, up to the available viewport. Compact
consent and the menu keep the same top edge throughout forward/back transitions,
including wider phones where the legal paragraph wraps to fewer lines.
Legal links and the full confirmation stay visible without scrolling on a
normal phone. Its header and actions stay fixed when the body
needs to scroll; on very short viewports the complete form scrolls so all controls
remain reachable. Necessary height changes for longer localized text animate.
The shared form footer stays at the bottom without adding padding below buttons.
The confirmation row retains a 48dp checkbox target without extra vertical padding.
The paragraph and legal links sit on the 24dp sheet gutter; the checkbox row
extends into it by `AppSizes.checkboxOutset` so the 18dp glyph lands on the
same edge, and the label follows the target directly (the target's own inset
past the glyph is the visible gap). The row mirrors in RTL.
The drag handle dismisses the sheet downward; there is no collapsed consent
state that the user must expand to read. The legal sentence uses a single rich
text paragraph with independently tappable, underlined links and link semantics.
Links wrap with the surrounding text at the shared `bodySmall` line height;
button-sized widgets must not inflate the paragraph's line boxes. Recognizers
are owned and disposed by the consent widget. Menu and URL forms scroll when
content exceeds the viewport or the keyboard leaves less room. The menu uses
two full-width `AppDrillInRow`s (24dp vertical padding inside the ripple) and
directional chevrons: **File from device** ("Books, comics and PDF", upload
glyph) and **Article from a link** ("Saved for reading offline", link glyph).
Each leading glyph sits in a 40dp tile with a 12dp radius in the
`selectedControlBackground/Foreground` pair, on the 24dp gutter, with the labels
12dp after it. The tile goes in the row's `leading` slot, so the whole row
stays one tap target and one semantics node (label = title, value = subtitle). Other steps keep their titles (Save Article,
Before uploading). The divider spans the full row width within the sheet
padding. The close action stays in the header while the rows scroll.
Divider color and thickness come from the shared `DividerTheme`, as in Library.
The rows use 24dp vertical padding and share any unused body space equally
above and below the group. Long content scrolls instead of stretching the sheet;
the menu and URL form retain the same height on forward/back navigation.
Offline article import remains disabled, with a warning glyph on a neutral
`surfaceContainerHighest` tile, "Needs an internet connection" in place of the
subtitle and no navigation chevron, while local books remain available. The URL form uses the shared 48dp
header with Back and Close, and a single filled Save action. The input and hints
scroll between them. Hints sit 8dp above the footer; remaining body space stays
between the reserved validation area and the hints, with a minimum 8dp gap.
When a keyboard or large text leaves too little height for that layout, the
complete form scrolls instead.
Validation errors and the offline hint render 8dp below the field on the 24dp
gutter, in line with the hint bullets, not through the decorator's helper/error
slot; an error still turns the field border red through an empty
`InputDecoration.error`, which adds no subtext row, so the field height is the
same with and without an error. The area reserves space for every localized
message so showing or clearing one does not move the hints or buttons. It
follows the available width and text scale, is excluded from accessibility
until a message is shown, and announces errors (not the offline hint) as a
live region.
Clipboard errors use compact localized copy to avoid reserving a paragraph of
empty space at large text sizes. No validation message is clipped or ellipsized.
It uses finite minimum height without intrinsic measurement or unbounded flex
children. Status content also scrolls
when necessary, and on very short viewports the whole status step scrolls
like the URL form. Clipboard access is still explicit: Paste is an
`AppPlainIconButton` suffix with a labeled 48dp circular target and never
reads on sheet open.

URL entry and Before uploading use the shared leading header Back action,
not a footer Back/Cancel button. Header/system Back returns to Add to Library;
the consent footer contains only Continue. Close, scrim and handle dismissal
close the entire flow from either step while the URL field is empty. A typed
URL wraps the form in `AppSheetDismissGuard`: Close, scrim tap and drag-down
then show a Keep editing / Discard step (`commonDiscardChangesTitle`, filled
Keep editing, outlined error-colored Discard) at the same step height instead
of dismissing; Discard closes the flow, Keep editing or header/system Back
return to the form, and the handle gives way to a same-height spacer. Header
and system Back from the form remain a step back to the menu, which retains the
URL draft in the cubit until the sheet closes; it does not submit, open a picker
or accept consent. Import progress/result screens are not editable navigation steps:
system Back closes them and does not cancel already-started storage work.
They keep the flow header: Close is disabled while storage work is in flight
and enabled on done/failure, where it dismisses without reporting an import.

Invalid or empty clipboard text produces an inline URL error without replacing
the current input. Clipboard access failures have a separate inline message.
Late clipboard replies are ignored after editing, navigation, dismissal, or a
newer paste. The cubit owns URL normalization and validation; the form only
reads the platform clipboard and keeps its controller aligned with cubit state.

After failure, **Choose file** reopens the book picker; cancelling the picker
leaves the failure visible. For articles, **Edit link** returns to the previously
submitted URL without making another request. Saving again remains explicit.
Book import has one progress bar, a static book icon and a readable filename.
Preparing is indeterminate until copying starts; copying shows byte progress;
finishing returns to indeterminate while persistence completes. Reaching 100%
does not announce success or close the sheet. Phase labels reserve their largest
localized height, including text scale, so neither the icon nor the bar moves
between phases. Filename and status details use `bodySmall/onSurfaceVariant`.
Progress emission remains coalesced to visible one-percent changes; no timer,
artificial progress or new repository operation drives the presentation.

## Verification

Package tests cover menu copy, icon tiles (size, radius, colour pair in light
and dark, gutter and RTL mirroring), tile taps reaching the row, drill-in
semantics and 48dp targets, the offline row, every `ImportFlowEntry` (file with
and without accepted terms, a picked book, article online/offline) with
header/system Back returning to the menu, menu spacing, reachable hints and
stable step height in English, Russian, and Arabic, menu hit targets and
disabled semantics, RTL/large-text
header access, validation, clipboard races/failures, retry state, picker
cancellation, progress layout, and keyboard access with enlarged text. Regression
tests distinguish header/system Back from Close/scrim/drag and check draft retention.
Real-font goldens check spacing after the reserved validation area and before
the footer. Validation geometry and error semantics are checked
in all supported languages at normal and 200% text scale.
`test/ui/import_flow_golden_test.dart` exercises the production sheet over an
isolated Library: online/offline menu, book progress/failure, invalid Paste,
article failure, consent, and URL restoration. `test/ui/import_book_terms_test.dart`
checks all supported languages with real fonts at normal and 200% text scale:
no unnecessary scrolling/fades, natural legal-paragraph line height, inline-link
taps/semantics, acceptance gating, picker callbacks, and return geometry.
Separate real-font tests inspect every animation frame in both directions at
360, 390, 402, and 430dp widths to catch even temporary top-edge jumps.
The golden profiles include Russian and Arabic
**phone-sized** layouts, dark mode, 200% German text, and landscape. Native
library-controls tests cover menu dismissal, connectivity changes, and
navigation to both import paths, including fully visible consent before scrolling
and consistent header placement and compact step height. Native pickers, real clipboard permissions,
and live extraction require separate device checks.

## Dependencies

- `book_repository` — persistence
- `reader_webview` — `BookMetadataExtractor` for supported document metadata
- `domain_models` — `BookFormat`
- `component_library` — `showAppBottomSheet`, `BottomSheetHeader`,
  `ActionBottomSheetLayout`, `AppDrillInRow`, `AppPlainIconButton`,
  `AppSheetActions`, `AppIcons`, `AppSpacing`, `AppMotion`
- `monitoring` — non-fatal logging
- `file_picker` — file picker integration
