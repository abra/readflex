# highlight

Bottom sheet for creating a highlight from a text selection: five-color
picker, optional note, save. Surfaced from the reader's context panel as a
`TextAction` plug-in — the reader feature itself knows nothing about
highlights.

## Public API

Two exported symbols:

```dart
class HighlightAction extends TextAction { ... }   // reader plug-in

Future<void> showHighlightSheet(
  BuildContext context, {
  required HighlightRepository highlightRepository,
  required FsrsRepository fsrsRepository,
  required TextSelectionContext selection,
});
```

`HighlightAction` is wired into the reader's `List<TextAction>` in the
composition root (`routing.dart`). It carries its own repository
dependencies so the reader stays source-agnostic. `label` is `Highlight`,
`icon` is `AppIcons.highlight`.

`showHighlightSheet` is used directly by non-reader flows (e.g. editing a
highlight from the Practice or Highlights list).

## Architecture

Single `HighlightCubit` (state in `highlight_state.dart`, `part of`).

- Status machine: `idle → saving → success | failure`
- Fields tracked: `selectedColor` (defaults to `HighlightColor.yellow`),
  `note`
- On `save()` the cubit calls `HighlightRepository.addHighlight(...)`, then
  registers the new highlight in `FsrsRepository.createReviewItem(...)` so
  it shows up in the review queue. The FSRS call is wrapped in its own
  try/catch and treated as non-fatal: the highlight is already saved, a
  missing FSRS row just means the highlight won't surface in review until
  re-registered.
- Sheet uses `BlocConsumer` to auto-pop on `success`; `failure` renders an
  inline error line above the save button.

The sheet is stateless UI over the cubit, plus a `SelectionPreviewCard`
tinted with the currently selected highlight color (from `AppColorsExt`).

## Dependencies

- `highlight_repository` — persistence
- `fsrs_repository` — review-item registration
- `shared` — `TextAction`, `TextSelectionContext`
- `domain_models` — `HighlightColor`, `SourceType`, `ReviewableType`
- `component_library` — `ActionBottomSheetLayout`, `SelectionPreviewCard`,
  `ButtonLoadingIndicator`, `showAppBottomSheet`, `AppColorsExt`
- `flutter_bloc`, `equatable`
