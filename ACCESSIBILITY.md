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

Sheet headings use a shared heading semantics node and a minimum 48dp title
row. Close and trailing actions must remain reachable with enlarged text.
`AppSheetActions` stacks long localized labels rather than shrinking the font;
busy states keep geometry and disable both commands. Reserved URL error space
is excluded from semantics until a real error is present. Accent foregrounds
use `context.actionForeground`, not the dark theme's primary button fill.
Consent links inside a sentence are inline text links, not 48dp button widgets:
they preserve normal paragraph line spacing, underline, and independent link/tap
semantics. This follows the [inline exception for text links](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html#exceptions);
it does not reduce the touch targets of standalone buttons or the checkbox row.

`AppInlineSheet` (reader Contents and Search) behaves like a modal sheet for
assistive technology without being a route: it names itself like a route
(`scopesRoute`/`namesRoute` with the panel title), its scrim is a dismissible
`ModalBarrier` labelled with Material's scrim strings and blocks the page
behind it, and a hidden sheet is offstage, so it has no semantics or focus.
Explicit Close stays in the header: drag, fling and pull-to-close are
shortcuts, never the only way out. With large text the sheet opens at full
height, and on a screen too short for its content the content scrolls as a
whole instead of clipping.

The Library's bottom capsule keeps each control its own node: the collection
switcher merges into one button (label Choose collection, value the shown
collection) and keeps its enabled state, and "+" is a labelled filled icon
button. The header title above it is a heading that names the shown
collection; it has no tap action. The capsule's height is fixed, so its text
scales to 200% and no further; at 320dp and 200% it still fits within the
gutters, truncating a long collection name rather than clipping.

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

`make test-ui-contracts` includes shared choice/action accessibility tests for
both mobile platform policies, LTR/RTL and normal/large text. Selection is
asserted in semantics, not inferred from color. Loading actions retain their
name but expose no tap action; disabling a choice retains its selected state.
Theme tests check named foreground/background pairs in light and dark mode;
they do not establish contrast over arbitrary images, overlays or book styles.
Selected controls are an accent wash with accent text (at least 4.5:1 on every
surface) in both themes, together with selected semantics; rows that select
also show a check. Muted text keeps at least 4.5:1 and stays clearly quieter
than primary text.
The [UI review checklist](test/ui/README.md#review-checklist) links these checks
to layout, navigation and performance contracts.

Collections exposes selected state and a check as well as the selection fill.
Reader active-result text and action icons use tested foreground/background
pairs in both themes. Quote direction, note direction and interface direction
are independent. Onboarding is one static screen: its page preview tilt mirrors
in RTL, nothing animates, and both actions stay outside the scrolling content
at large text. Errors do not expire automatically
when accessible navigation is enabled; success notifications stay 4s, long
enough to read a book title. Toasts sit at the bottom above the screen's bottom
controls (`ToastAvoidArea`) and never cover them, so those controls stay
tappable while a toast shows.
Toasts expose the full message as a live region, separately from the localized
48dp Close action. Large-text suffixes wrap instead of leaving the viewport;
ordinary messages may be visually ellipsized without truncating semantics.
Reduced motion disables both the slide and the list-size animation. Widget
semantics assertions do not replace native VoiceOver/TalkBack announcement checks.
