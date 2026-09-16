# highlight

Reader plug-in for saving text highlights, plus a reusable bottom sheet with a
five-color picker, optional note, and save action. New text-highlight creation
uses the shared action contract; Reader separately owns saved-highlight edits
and image-area highlights through its injected repository.

## Public API

Primary exported symbols:

```dart
class HighlightAction extends ColorHighlightTextAction { ... } // reader plug-in

class HighlightSheet extends StatelessWidget { ... } // standalone form

Future<void> showHighlightSheet(
  BuildContext context, {
  required HighlightRepository highlightRepository,
  required TextSelectionContext selection,
});
```

`HighlightAction` is wired into the reader's `List<TextAction>` in the
composition root (`routing.dart`). It implements `ColorHighlightTextAction` so
the reader can show its compact color row without importing this feature.
For a new selection, choosing a color only changes the draft/preview. Pressing
Highlight calls `onExecuteWithColor` and persists the exact range with that
color, replacing fully contained highlights when supplied by the reader.
Dismissing the popup does not save. Direct `onExecute` calls default to yellow.
Changing the color of an already saved highlight is a separate Reader edit.
The localized label comes from `labelFor(context)` and the icon is
`AppIcons.highlight`.

`showHighlightSheet` can also be used directly by non-reader flows that need
the same highlight creation UI.

## Architecture

The immediate reader action persists through `HighlightRepository` directly.
The standalone sheet owns a `HighlightCubit` (state in `highlight_state.dart`,
`part of`) for its editable draft:

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
