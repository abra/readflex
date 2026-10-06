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
  HighlightColorResolver? resolveColor, // defaults to the app palette
});

typedef HighlightColorResolver = Color Function(HighlightColor color);
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

`showHighlightSheet` has no caller yet; it is kept on the shared sheet
contract so it can be wired later as "highlight with note". A reader caller
passes `resolveColor` with its reader-theme palette so the swatches and the
preview tint match the page; without it the sheet uses `AppColorsExt`.

## Architecture

The immediate reader action persists through `HighlightRepository` directly.
The standalone sheet owns a `HighlightCubit` (state in `highlight_state.dart`,
`part of`) for its editable draft:

- Status machine: `idle → saving → success | failure`
- Fields tracked: `selectedColor` (defaults to `HighlightColor.yellow`),
  `note`
- On `save()` the cubit calls `HighlightRepository.addHighlight(...)`.
- Sheet uses `BlocConsumer` to auto-pop on `success`; `failure` renders an
  inline `bodyMedium` error line in the error color, announced as a live
  region, above the Save button. Save is the retry. There is no localized
  retry hint yet, so this is not an `AppStatusMessage`.

The sheet is stateless UI over the cubit. It uses `ActionBottomSheetLayout`
with the explicit Close action and the shared 8dp header/body gap, a
`SelectionPreviewCard` whose direction follows the selected text and whose
tint is the selected swatch, one `AppColorSwatchButton` per `HighlightColor`
(48dp target, selected ring and luminance-chosen check, disabled while
saving), the note field and a filled Save.

## Dependencies

- `highlight_repository` — persistence
- `shared` — `TextAction`, `TextSelectionContext`
- `domain_models` — `HighlightColor`, `SourceType`
- `component_library` — `ActionBottomSheetLayout`, `SelectionPreviewCard`,
  `AppColorSwatchButton`, `ButtonLoadingIndicator`, `showAppBottomSheet`,
  `AppColorsExt`
- `intl` — bidi detection for the preview direction
- `flutter_bloc`, `equatable`
