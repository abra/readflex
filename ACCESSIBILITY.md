# Accessibility

Accessibility is part of the UI contract. It should stay close to widgets and
feature state, not in repositories, services, parsers, or domain models.

## Semantics Placement

- Prefer built-in Flutter, Material and Cupertino semantics first. Shared
  `AppTextField`, `AppIconButton`, buttons, sliders, switches, checkboxes and rows
  delegate to their platform controls and expose useful accessibility data
  when configured with labels, tooltips,
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

`AppThemeScope` exposes the same semantic color/text roles under either app
root. App chrome uses the platform's typography; reader document styles remain
independent. A Material theme compatibility adapter under `CupertinoApp` does
not make the app's visible controls Material or prove native accessibility.

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

Control readability follows the current window, not the device model. Windows
at least 600dp wide and 480dp tall use 24dp default utility glyphs and larger
existing text roles for important control captions. Explicit icon sizes and
system text scaling remain authoritative. Narrow windows retain compact roles.
Filter chips reserve at least 48dp in both hit-target dimensions, including
short labels; their visible pill can stay compact. Larger text may grow it.
Shared controls request a 48dp minimum target. The native Cupertino navigation
bar has a 44pt content height plus the top safe area; actions inside that bar
follow its constrained native height. Sheet, reader-toolbar and ordinary body
controls retain 48dp. Do not shrink them to match navigation chrome.

Reader brightness retains three 48dp targets in constrained windows. When the
vertical pill cannot fit above the dock, including 568×320 at 200% text, it uses
a horizontal 184×48dp arrangement. The title shares the top row without painting
behind the pill, and article progress remains visible below it. Safe-area
gutters and RTL placement apply to the whole arrangement; increasing,
decreasing, dragging and returning to system brightness remain available.
The layout changes chrome only and retains control state through rotation and
hide/show. `reader_floating_chrome_layout_test.dart` covers Android/iOS roots,
German and Arabic phone RTL, enlarged text and constrained asymmetric insets;
these are layout, interaction and semantics contracts rather than native
screen-reader evidence.

`AppIconButton` exposes one named button. Android uses Material's built-in
tooltip semantics; Cupertino puts the localized tooltip on the action's
semantics node and excludes decorative children to avoid duplicate names.
Cupertino press feedback does not open a Material tooltip bubble. Disabled
actions retain a name/state while removing the command tap action; loading
commands retain their label and stable geometry.

Sheet headings use a shared heading semantics node and a minimum 48dp title
row. Close and trailing actions must remain reachable with enlarged text.
Cupertino modal headers also name the route, centre short titles between
navigation slots, and wrap long titles below them. Localized Back and Close
remain separate actions in both directions. Modal results complete on pop;
`onFullyHidden` follows the exit so new controls are not exposed midway through
the outgoing modal. Scrim/drag policies preserve the existing draft guard.
Expanded settings/forms centre their surface; contextual controls use a trailing
panel. Both retain focused text, selection and the current step when resized.
There is no drag handle on expanded panels; Close remains an explicit action.
Confirmation alerts default to Cancel. Their iOS actions retain an explicit
enabled button/tap semantics node at enlarged text sizes, where the current
Cupertino action renderer omits those properties; native labels and gestures
remain intact. Destructive commands use the semantic error foreground.
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
On expanded windows the same content occupies a bounded trailing panel;
RTL mirrors its edge, resizing retains query/focus, and vertical list gestures
only scroll the list. Close and the dismissible scrim remain available.
The panel reaches the window edge, with the home-indicator inset inside its
opaque surface so the final action remains reachable above it.

The Library's bottom capsule keeps each control its own node: the collection
switcher merges into one button (label Choose collection, value the shown
collection), Search has a labelled 48dp target between the switcher and "+",
and "+" is a labelled filled icon button. The header title above it is a heading
that names the shown collection; it has no tap action. Browse captions scale to
200%; at 320dp and 200% the capsule remains within the gutters, truncating a long
collection name rather than clipping.
Opening Search moves the magnifier to the directional start and changes the
capsule into one editable field. The magnifier becomes decorative while editing.
The filled end button cross-fades from Add to a directional chevron labelled
Back. Back and Clear search are distinct labelled controls: Back clears the
query and leaves search; Clear retains editing and focus. The field follows
the user's text scale, using
a shorter visible hint when needed while retaining the full search description
in semantics. Outgoing controls leave input, focus and semantics during their
fade. While closing, the end button leaves input, focus and semantics until
it has returned to Add, preventing a second Close tap from importing.
Reduced motion settles the whole change immediately. Returning from a reader or
Practice preserves the query without automatically reopening the keyboard.
With little room above the keyboard, compact no-results feedback stays above
the field; its labelled Clear and Back controls remain available.

The separate Practice icon appears only when its destination is available and
at least one card is due; zero or unknown counts remove its button semantics.
It announces the full due count on its button node. Its decorative badge shows
at most "99+" visually; its soft aura is static and adds no semantics.
The number follows text scaling until it reaches the 48dp target's bounds,
then scales down to fit on one line; the row and Practice section retain the
full count with normal text scaling.

Practice word and highlight rows include the stored review date and time in
their composite semantics value. The visible schedule uses muted supporting
text on its own wrapping line; truncating a long source or chapter must not
truncate the timestamp. Word details expose the same localized date and local
time with the user's 12/24-hour preference and normal text scaling. Items with
no scheduled time retain the New or Due label.

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
VoiceOver/TalkBack device checks are explicitly deferred for the current native
UI follow-up. Existing widget semantics, native screenshots and the profile
harness do not verify spoken announcements, focus traversal or screen-reader
activation. `make profile-ui DEVICE=<physical-device-id>` verifies hardware
identity and collects Flutter frame timings; it does not close those
accessibility gaps. See the [profiling contract](test/ui/README.md#native-ui-frame-profiling)
for emulator handling and the limits of refresh-rate/compositor measurements.

`make test-ui-contracts` includes shared choice/action accessibility tests for
both mobile platform policies, LTR/RTL and normal/large text. Selection is
asserted in semantics, not inferred from color. Loading actions retain their
name but expose no tap action; disabling a choice retains its selected state.
Theme tests check named foreground/background pairs in light and dark mode;
they do not establish contrast over arbitrary images, overlays or book styles.
Cupertino small app captions retain the native secondary-label RGB at 80%
opacity through `onSurfaceVariant`; section headings use the same role.
Composited text contrast must reach 4.5:1 on grouped, sheet and container
surfaces in both themes. SDK press and disabled colors remain native defaults.
Portable widget/golden fallback fonts verify geometry; they do not establish
production San Francisco metrics or replace native screenshot inspection.
Custom selected rows use an accent wash with accent text and selected
semantics; selection rows also show a check. Cupertino segmented controls use
their native thumb presentation with selected/enabled state.
The [UI review checklist](test/ui/README.md#review-checklist) links these checks
to layout, navigation and performance contracts.

Collections exposes selected state and a check as well as the selection fill.
Reader active-result text and action icons use tested foreground/background
pairs in both themes. Quote direction, note direction and interface direction
are independent. Book/article text selection keeps Flutter's `SelectionArea`
for document geometry. The `native_text_selection` adapter supplies system
selection controls for supported layouts, while unsupported geometry retains
the Flutter fallback; application action menus stay in Flutter. Editable
fields keep their platform input/IME connection. See the
[native selection contract](packages/native_text_selection/README.md).
Widget semantics tests do not establish on-device handle behavior or
VoiceOver/TalkBack announcements.
Onboarding is one static screen: the app icon is decorative,
the heading is a header that shrinks rather than break a word at large text,
each feature row reads as one item, the rows mirror in RTL, nothing animates,
and both actions stay outside the scrolling content at large text on narrow
windows. Expanded windows pair the greeting/actions with a feature card and
scroll the whole workspace when height is constrained.
The reader's one-time selection tip is a live region with a 48dp "Got it"; its
inks keep 4.5:1 on the inverse plate, "Got it" moves below the message at
large text, and the tip appears without animation under reduced motion. Errors do not expire automatically
when accessible navigation is enabled; success notifications stay 4s, long
enough to read a book title. Toasts sit at the bottom above the screen's bottom
controls (`ToastAvoidArea`) and never cover them, so those controls stay
tappable while a toast shows.
Toasts expose the full message as a live region, separately from the localized
48dp Close action. Large-text suffixes wrap instead of leaving the viewport;
ordinary messages may be visually ellipsized without truncating semantics.
Reduced motion disables both the slide and the list-size animation. Widget
semantics assertions do not replace native VoiceOver/TalkBack announcement checks.
