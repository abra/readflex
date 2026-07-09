# Accessibility

Accessibility is part of the UI contract. It should stay close to widgets and
feature state, not in repositories, services, parsers, or domain models.

## Semantics Placement

- Prefer built-in Flutter and Material semantics first: `TextField`,
  `IconButton`, buttons, sliders, switches, checkboxes, and list rows already
  expose useful accessibility data when configured with labels, tooltips,
  enabled state, and error text.
- Add `Semantics` manually for custom interactive surfaces such as source
  tiles, color swatches, custom action cards, custom chips, progress overlays,
  and bottom-sheet action icons.
- Keep reusable component semantics in `component_library`.
- Keep feature-specific labels and values in the feature package. A small
  feature-local helper is acceptable when the same semantic value is shared by
  multiple feature widgets.
- Do not add accessibility helpers to `shared` unless they are a real
  cross-feature contract. `shared` is not a general common package.

## Widget Contract

Custom controls should describe what the user can perceive and do:

- `label`: the object or command, for example `Save Article`.
- `value`: the current state or metadata, for example
  `Book, EPUB, 42 percent read`.
- `button`, `selected`, `enabled`, `slider`, `header`, `image`, or similar
  flags when the role or state is not already supplied by a built-in widget.
- `onTapHint` and `onLongPressHint` when a custom gesture is meaningful.

Do not put the role in the label. Prefer `label: 'Save Article'` with
`button: true` over `label: 'Save Article button'`.

Use `excludeSemantics: true` only for composite controls where the parent
semantics node fully replaces noisy child content. Source tiles and action
cards are examples: the visual subtree contains covers, badges, icons, and
metadata, while the accessibility node exposes one concise object.

## Architecture

Accessibility data must be derived from UI state already available to the
view:

```text
routing.dart -> Screen/Sheet -> Bloc/Cubit -> View -> Semantics
```

Do not pass repositories, services, parsers, or storage objects into Views for
accessibility. If a semantic label needs formatting, keep the formatter local
to the feature package unless it is genuinely reusable UI code.

## Tests

When behavior changes accessibility output, add focused tests:

- Use `tester.ensureSemantics()` and dispose the handle before the widget test
  ends.
- Use `matchesSemantics` for labels, values, roles, states, actions, and custom
  hints.
- Use guideline tests such as `labeledTapTargetGuideline`,
  `androidTapTargetGuideline`, `iOSTapTargetGuideline`, and
  `textContrastGuideline` for important screens or broad UI changes.

Manual checks should still be done for major flows with VoiceOver on iOS,
TalkBack on Android, Xcode Accessibility Inspector, or Android Accessibility
Scanner.
