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
  required TextSelectionContext selection,
});
```

`HighlightAction` is wired into the reader's `List<TextAction>` in the
composition root (`routing.dart`). It carries its own repository
dependencies so the reader stays source-agnostic. `label` is `Highlight`,
`icon` is `AppIcons.highlight`.

`showHighlightSheet` can also be used directly by non-reader flows that need
the same highlight creation UI.

## Architecture

Single `HighlightCubit` (state in `highlight_state.dart`, `part of`).

- Status machine: `idle → saving → success | failure`
- Fields tracked: `selectedColor` (defaults to `HighlightColor.yellow`),
  `note`
- On `save()` the cubit calls `HighlightRepository.addHighlight(...)`.
- Sheet uses `BlocConsumer` to auto-pop on `success`; `failure` renders an
  inline error line above the save button.

The sheet is stateless UI over the cubit, plus a `SelectionPreviewCard`
tinted with the currently selected highlight color (from `AppColorsExt`).

## Dependencies

- `highlight_repository` — persistence
- `shared` — `TextAction`, `TextSelectionContext`
- `domain_models` — `HighlightColor`, `SourceType`
- `component_library` — `ActionBottomSheetLayout`, `SelectionPreviewCard`,
  `ButtonLoadingIndicator`, `showAppBottomSheet`, `AppColorsExt`
- `flutter_bloc`, `equatable`
