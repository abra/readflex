# component_library

Shared presentation package: design system, theme, and reusable UI widgets.

## Design System

Five-layer architecture following the token-to-theme pipeline:

```
Primitive tokens  -->  Semantic tokens  -->  ThemeData / Extensions  -->  Component themes  -->  UI
```

### File Structure

```
src/theme/
  tokens/
    primitive_colors.dart       # Raw color values (gray50, orange500, etc.)
    primitive_spacing.dart      # Raw spacing values (s2, s4, s8, s12, etc.)
    app_colors.dart             # Semantic palette: AppColorPalette, lightPalette, darkPalette
    app_spacing.dart            # Semantic spacing: AppSpacing (xxs, xs, sm, md, lg, xl, xxl)
    app_radius.dart             # Border radius scale: AppRadius (xs, sm, md, lg, xl, full)
    app_sizes.dart              # Control heights: AppSizes (buttonHeight, navBarHeight, etc.)
    app_elevation.dart          # Elevation levels: AppElevation (level0..level3)
    app_icon_size.dart          # Icon size scale
    app_motion.dart             # Motion durations: AppMotion (quick, short, medium)
    app_shadows.dart            # Shared shadow recipes
  extensions/
    app_colors_ext.dart         # ThemeExtension for colors beyond ColorScheme (AppColorsExt)
    build_context_ext.dart      # BuildContext convenience accessors
  components/
    app_button_themes.dart      # FilledButton, OutlinedButton, TextButton, IconButton
    app_card_theme.dart         # CardThemeData
    app_input_theme.dart        # InputDecorationTheme
    app_navigation_theme.dart   # NavigationBar, BottomSheet, Dialog
    app_selection_themes.dart   # SegmentedButton, Chip
  app_theme.dart                # Central assembly: AppTheme.light() / dark()
  app_text_theme.dart           # TextTheme construction helpers
  app_typography.dart           # AppTypography: textTheme, fontFamilySans/Serif, serif()/sans()
  book_layout.dart              # Reader book layout presets
  reader_appearance.dart        # Reader theme presets (Snow, Paper, Warm, Graphite, Night)
```

### Usage in UI

Access everything through `BuildContext` extensions:

```dart
// Colors
context.colors.primary            // ColorScheme
context.actionForeground          // readable accent text/icons on surfaces
context.appColors.warning         // AppColorsExt (ThemeExtension)
context.appColors.highlightYellow // highlight/rating/status colors

// Typography
context.text.bodyLarge            // TextTheme roles
context.text.headlineSmall        // serif headlines
AppTypography.serif(...)          // theme-level helper; UI code uses text roles

// Static constants (for const contexts and component themes)
const EdgeInsets.all(AppSpacing.lg)
BorderRadius.circular(AppRadius.md)
const Icon(Icons.search, size: AppIconSize.md)

// Motion: tokens resolve to Duration.zero under reduced motion
AnimatedOpacity(duration: context.motion(AppMotion.short), ...)
if (context.reduceMotion) controller.jumpTo(...) else controller.animateTo(...)
```

### AppColorsExt Fields

Colors that go beyond `ColorScheme`, delivered via `ThemeExtension`:

| Group        | Fields                                                                                   |
|--------------|------------------------------------------------------------------------------------------|
| Highlights   | `highlightYellow`, `highlightBlue`, `highlightGreen`, `highlightPink`, `highlightPurple` |
| FSRS ratings | `ratingAgain`, `ratingHard`, `ratingGood`, `ratingEasy`                                  |
| Status       | `warning`/`warningForeground`, `info`, `success`/`successForeground`, `successContainer`/`onSuccessContainer`, `successOnInverse`/`errorOnInverse` (glyphs on `inverseSurface`) |
| Pro badge    | `proBadge`, `proBadgeForeground`                                                         |
| Swatch inks  | `onLightSwatch`, `onDarkSwatch` — check/glyph drawn over a sample color                  |
| Other        | `divider`                                                                                |

### Token Fields

Spacing, radius, icon sizes, control sizes, elevation, and shadows are exposed
as static semantic token classes:

| Token class | Purpose |
|-------------|---------|
| `AppSpacing` | Layout gaps and insets (`xxs` … `xxl`) |
| `AppRadius` | Shape scale (`xs`, `sm`, `md`, `lg`, `xl`, `full`) |
| `AppSizes` | Control heights and tap targets |
| `AppIconSize` | Standard icon sizes |
| `AppMotion` | Implicit-animation durations (`quick` 120ms, `short` 200ms, `medium` 300ms) |
| `AppElevation` / `AppShadows` | Shared depth language |

### Typography

`AppTypography` is the single source of truth for text:

- `AppTypography.textTheme` -- `TextTheme` with all 15 Material roles; display
  and headline roles use Literata, title/body/label roles use Geist
- `AppTypography.fontFamilySans` / `fontFamilySerif` -- `Geist` / `Literata`
- `AppTypography.fontFamilyPhonetic` -- bundled Noto Sans phonetic subset used
  for IPA; see `fonts/README.md` for provenance, reproduction and license
- `AppTypography.fontFamilySymbols` -- bundled Noto Sans Symbols regular font
  for imported text symbols, including U+267E (permanent paper sign)
- `AppTypography.fontFamilyFallback` -- bundled symbols, then named Arabic,
  Devanagari, Japanese and Chinese fallbacks before the operating system
  fallback; the language fonts are not bundled
- `AppTypography.serif(...)` / `sans(...)` -- factory methods for one-off styles
- `context.text.screenCounter`, `sourceMetadata`, `readerChromeLabel`, etc. --
  semantic styles for repeated compact UI surfaces

Button theme and generated cover text styles explicitly select Geist and the
same fallbacks; passing an unresolved typography role into a button style would
otherwise lose the theme's font family. Cover styles retain `inherit: false`
for route/Hero isolation without losing their font family. Root golden tests
register deterministic test-only fallback fonts; see `test/fonts/README.md`
in the repository root.

Symbol fallback does not rewrite selection or translation text and requires
no runtime download. `test/ui/symbol_fallback_test.dart` compares rendered
glyph pixels and checks that Latin/Cyrillic typography remains unchanged.
`integration_test/translation_sheet_test.dart` includes symbols in both the
source quote and translated sentence for native screenshot inspection.

### Rules

- **Screens use roles, not values** -- never write `Color(0xFF...)` or `fontSize: 14` in
  UI code.
- **Use context extensions** -- `context.text.bodyMedium`, not
  `Theme.of(context).textTheme.bodyMedium`.
- **Platform differences are centralized** -- iOS/Android adjustments belong in
  theme/component helpers, not in feature widgets.
- **Primitives feed semantics** -- `PrimitiveColors` / `PrimitiveSpacing` are raw values;
  `AppColorPalette` / `AppSpacing` assign meaning.
- **ColorScheme** for Material-native roles (primary, surface, error, etc.).
- **ThemeExtension** for extra theme colors (`AppColorsExt`). Spacing, radius,
  sizes, icons, elevation, and shadows are static semantic tokens.
- **Static constants** are OK for spacing/radius in `const` contexts and component theme
  assembly.
- **Component themes** read from palette and static tokens (no BuildContext available).
- **Global tile shape is rectangular.** `listTileTheme` sets colours and a 4dp
  content padding only; rows that want a radius (inset sheet options) draw it
  themselves. Full-bleed panel rows never inherit a radius. `MenuAnchor` menus
  use `AppRadius.sm` through `menuTheme`.
- **Buttons own their spinner colour.** `ButtonLoadingIndicator` reads
  `IconTheme.of(context).color`, which every Material button sets to its
  resolved foreground, so a busy filled button shows an `onPrimary` spinner.
- **No ternary operators in theme assembly** -- separate `_buildLight()` / `_buildDark()`
  functions.
- **Motion goes through `context.motion(AppMotion.x)`** -- never pass a literal
  `Duration` to an implicit animation or transition in UI code. The helper returns
  `Duration.zero` when the platform reduces motion, so one call site serves both
  settings; explicit controllers check `context.reduceMotion` and jump instead.
- **Swatch inks come from `AppColorsExt`** -- a check drawn over a highlight or
  theme sample picks `onLightSwatch`/`onDarkSwatch` by the sample's luminance;
  raw `Colors.black`/`Colors.white` are not allowed in feature code.
- **Content sits on the gutter; interactive surfaces extend into it.** A row,
  option tile or swatch keeps the inner inset its ink or selection pill needs
  (4/8/12dp), and the owning surface subtracts that inset from its own edge
  padding, so text and icons land exactly on the 16dp screen/drawer or 24dp
  sheet gutter while the pill bleeds into the gutter. The same rule places
  icon actions: a 48dp target is outset by `AppSizes.iconActionOutset` so its
  20dp glyph meets the gutter, and a Material `Checkbox` by
  `AppSizes.checkboxOutset`. Never shrink a target, and never fake an outset
  with negative padding, `Transform` or `OverflowBox`; move the padding to the
  widget that owns the surface. Text buttons inside a content column follow
  the same rule: the column stops padding the button and the button's own
  16dp padding becomes the ink bleed, so the label aligns with the text above.
- **Busy commands keep their size.** `AppBusyButtonLabel` replaces a button's
  label with the spinner while a write is in flight; `AppSheetActions(busy:)`
  and `ErrorState(busy:)` use it, and single `FilledButton`s pass it as their
  child instead of swapping children.
- **Icon glyph colour follows the action's role, not the surface.** Inline
  delete/remove in a row: `onSurfaceVariant`; undo: `context.actionForeground`;
  overflow "more": `onSurfaceVariant`, or `selectedControlForeground` on a
  selected row; a bulk destructive command in a selection bar: `error`.
- **Floating action buttons are themed.** `floatingActionButtonTheme` provides
  the primary circular style; call sites pass only `onPressed`, `tooltip`,
  `heroTag` and the child.

## Reusable UI API

Reusable presentation-only widgets used across features:

| Widget                              | Purpose                                        |
|-------------------------------------|------------------------------------------------|
| `ActionBottomSheetLayout`           | Bottom sheet shell; optional constrained scroll body and wrapping header actions |
| `AppPlainIconButton`                | Labeled 48dp utility action with transparent background and circular press feedback; `icon` or a custom `iconWidget` |
| `AppActionCard`                     | Reusable command card for action pickers       |
| `AppDrillInRow`                     | Row that opens a nested step: accent leading icon (or a caller-framed `leading` widget, e.g. the import menu's tinted tile), `bodyMedium` title, muted subtitle, directional chevron, 48dp minimum, muted and ripple-free when disabled |
| `AppBottomSafeArea`                 | Bottom inset handling for app-owned surfaces   |
| `AppButtonLabel`                    | Bounded label for localized button text        |
| `AppBusyButtonLabel`                | Button child that swaps the label for a live-region spinner without changing the button size |
| `AppSheetDismissGuard`              | Per-step scrim/drag guard inside `showAppBottomSheet` flows |
| `AppSheetActions`                   | Primary/secondary sheet commands with adaptive stacking and stable busy geometry; `destructiveSecondary` for confirmations; `stacks`/`stackedExtent` let a fixed-height step reserve the second row ahead of layout |
| `AppSourceQuote`                    | Quoted source phrase with a leading rule that follows the quote's own direction |
| `AppLexicalMetadataRow`             | Muted reading / IPA pronunciation / part-of-speech line under a headword; IPA stays LTR in the phonetic font, wraps when narrow |
| `AppColorSwatchButton`              | Round color sample in a 48dp circular-ink target; selected ring plus a check inked by swatch luminance |
| `AppStatusMessage`                  | Inline sheet status: start-aligned title/body, optional full-width filled action and progress |
| `AppSettingsSection`                | Shared settings heading and label/control spacing |
| `AppChoiceControl` / `AppChoiceOption` | Single-choice settings, with the same themed states for text, icons, painted `glyph`s and font previews; `reselectable` reports a tap on the selected option for nearest-match presets |
| `AppCopyButton`                     | 48px copy command with local success/error feedback |
| `AppFilterChip`                     | App-styled filter chip with stable tap target  |
| `AppFloatingCapsule`                | Stadium that floats a screen's bottom controls over content (reader chrome, Library collection switcher + "+"): `surface` at 92%, hairline `outlineVariant`, `AppShadows.popover`, radius from the caller's height; controls paint their own ink |
| `AppInlineSheet` / `AppInlineSheetGeometry` | Bottom sheet drawn in a screen's `Stack` instead of a route, retained offstage while hidden; half (60%) and full positions, header drag, list-driven grow/collapse, keyboard-aware |
| `BottomSheetHeader`                 | Bottom sheet title row                         |
| `ButtonLoadingIndicator`            | Compact circular progress for buttons; takes the button's own foreground via `IconTheme` |
| `CenteredCircularProgressIndicator` | Centered loading spinner                       |
| `EmptyState`                        | Centered empty state; `compact` for list/panel placeholders |
| `ErrorState`                        | Centered failure with filled Retry, optional title/icon/secondary exit and busy geometry |
| `AppSourceCover` / `AppSourceCoverFrame` | Shared source cover rendering and frame |
| `appSourceCoverImageFromPath`       | Resolves an optional local cover image path    |
| `SearchField`                       | App search field with an adaptive primary-tone clear action and circular press feedback |
| `ScrollEdgeFadeStack`               | Scroll-edge fade/scrim wrapper                 |
| `ScrollEdgeFade`                    | Scroll-edge fade: top/bottom darken (0.14 alpha in light mode); start/end dissolve a horizontal strip into `surfaceColor` (default scaffold background) |
| `SelectionPreviewCard`              | Compact preview of selected text with its own `textDirection` |
| `showAppBottomSheet`                | Shared modal bottom-sheet presentation helper  |

## What Belongs Here

### Search and Utility Actions

Use `AppIcons.delete` for deleting saved items and removing collection
memberships, including bookmarks and recent search entries. `AppIcons.close`
is for dismissing surfaces or canceling modes, not deleting records. Search
field clearing and filter reset retain the familiar non-destructive cross.
Keep localized tooltips specific to the action and preserve existing save,
confirmation and Undo behavior when changing an icon.
Use `AppIcons.undo` for reversing a deletion, not the refresh/retry icon.
Inline deletion/restoration actions use the same icon-only button and target;
do not replace an icon with a variable-width text label. The localized tooltip
names the action for both pointer users and assistive technology.

`AppPlainIconButton` keeps a minimum 48dp target independently of `iconSize`; the default
glyph is 20dp, while `SearchField` uses 16dp. Its resting background is
transparent and pressed/focus feedback follows the circular shape, not the
filled rectangular global icon-button theme. The localized `tooltip` supplies
the accessible name through Flutter's `IconButton` semantics. Pass `iconWidget`
for a custom-painted glyph (the reader bookmark) or a busy indicator; disabled
state dims the given `color` to 38% rather than swapping to `onSurface`, so
reader toolbars keep their page tone. It is the only primitive for standalone
utility icon actions: features do not style a bare `IconButton`, `InkWell` or
`GestureDetector` for that role.
For standalone trailing list actions, align the glyph with the content gutter
and the surface header, not the outer edge of the target. Allow the target's
inner inset to occupy the gutter without clipping its hit area; mirror this
with directional padding. Do not shrink targets or globally remove padding
from grouped controls to achieve alignment.

Screen/drawer content uses a 16dp gutter; sheet content uses 24dp. The owning
surface applies each outer gutter once. `AppSheetActionRow` accepts a full-width
sheet row and aligns a 20dp utility glyph with `BottomSheetHeader`, preserving
the full 48dp target; `textDirection` lets a Copy action trail LTR content in
an RTL interface. Definition/Translation use it for Copy; other body sections
retain their 24dp padding. `AppCopyButton` delegates appearance to
`AppPlainIconButton`, including circular feedback and disabled hit semantics.

Notifications sit on the neutral `ColorScheme.inverseSurface` /
`onInverseSurface` plate (gray900 on light, darkGray50 on dark, overriding the
seed's warm inverse roles); only their glyph is colored, with
`AppColorsExt.successOnInverse` / `errorOnInverse`, the other theme's success
and error tones. `successContainer` / `onSuccessContainer` remain the filled
success pair (the grid's finished badge) and `successForeground` the text/icon
role on ordinary surfaces. The toast service owns notification layout and
lifecycle, not this package.

Selected controls use the paired `selectedControlBackground/Foreground` colors:
in both themes a translucent wash of the accent (wine at 8% in light,
`primaryFixedDim` at 16% in dark) with the accent itself as text, at least
4.5:1 on every surface. Dark mode used to paint an opaque `primaryFixedDim`
block, the brightest thing on a dark screen; the 16% wash still separates the
selected option more than the light theme's 8% does. Disabled keeps the wash
and dims the text. Opaque `selectionMarkerBackground/Foreground` is for small
checks on cover art; normal multi-selection must not use the destructive error
color. Custom rows also expose `Semantics(selected: ...)`; color is not their
only selection cue.

Muted text and icons (`onSurfaceVariant`, `ListTile` icons) use the palette's
`mutedForeground` gray (gray650 #5B616D, darkGray300 #9AA0AA) instead of the
seed's wine-tinted variant: at least 4.5:1 on every surface, and at most 55% of
primary text's contrast, so it stays clearly secondary in dark mode.

Text fields share the search field's and buttons' `AppRadius.md` (12dp).

### Generic States

`EmptyState` and `ErrorState` are the only full-panel placeholders: Library,
reader drawers, reader search, reader load failure and collection lists use them
rather than a hand-rolled `Center(Text)`. Retry is always the filled primary
command; a secondary exit (reader "Go back") is outlined beside it, and when
the two labels do not fit side by side the filled Retry comes first in the
stack, like `AppSheetActions`. `busy`
keeps button geometry and blocks duplicate taps. `EmptyState(compact: true)`
renders a muted `bodyMedium` for short list/panel placeholders; screen-level
states keep `titleMedium`. Both share the 56dp tinted icon frame and
`AppIconSize.md` glyph. `CenteredCircularProgressIndicator` is the loading
counterpart; sheets do not build their own padded spinner.

`AppStatusMessage` is the inline variant for sheet bodies that keep other
content visible (Definition and Translation "no result", offline and failure
states under the source phrase). It is left-aligned to the sheet gutter and
can append a linear progress bar for a long-running action such as a model
download.

### Confirmations

`AppSheetActions` follows a safe-default model: the filled primary is the
non-destructive choice (Keep editing, Keep) and the destructive
command is the outlined secondary in the error color
(`destructiveSecondary: true`). Delete collection, delete items and
discard-changes confirmations all use this pairing, so the most prominent
button never destroys data. The safe action is named for what it keeps
("Keep", "Keep editing"), never "Cancel": that word is reserved
for leaving a surface, so one label never has two meanings.

### Command Footers

- A sheet step whose header has Close (or Back) shows **one** full-width
  filled command: Save, Continue, Create and add, Done, Retry. Leaving is the
  header's job, so no Cancel sits beside the command. A draft is still
  protected by `AppSheetDismissGuard`.
- A pair appears only for a confirmation (above) or a genuine alternative
  action with its own outcome, such as Skip beside Save when a new highlight
  can be kept without a note.
- Secondary commands are outlined on a transparent background; the
  destructive variant swaps in the error color. A disabled filled primary keeps
  Material's muted fill, so it never reads as an enabled secondary.

### Placement by Role

These are Readflex conventions, not a claim that platform guidelines prescribe
one padding value for every component. Android recommends a 16dp compact-screen
margin and 48dp touch targets; Apple recommends respecting layout margins/safe
areas and at least 44pt touch targets. Readflex keeps 48 logical pixels for its
utility buttons on both platforms. See [Android content structure](https://developer.android.com/design/ui/mobile/guides/layout-and-content/content-structure),
[Android accessibility](https://developer.android.com/guide/topics/ui/accessibility/apps),
[Apple layout](https://developer.apple.com/design/human-interface-guidelines/layout)
and [Apple touch guidance](https://developer.apple.com/design/tips/).

| Role | Alignment and spacing |
| --- | --- |
| Screen/drawer text and standalone row actions | 16dp content gutter, applied once by the surface |
| Sheet title, form, standalone row action and footer | 24dp content gutter; a 20dp glyph in a 48dp target ends its target 10dp from the edge |
| Nested chapter/row | Indent the leading content to convey hierarchy; keep trailing actions on the parent's trailing action line |
| Search suffix, stepper, segmented choice | Use the control's internal layout; do not move its buttons to the outer screen gutter |
| Reader toolbar group | Equal 48dp slots and circular feedback inside the toolbar gutter, including the custom bookmark glyph |
| Related text/control | Use the existing 4/8/12dp tokens for local relationships, with 16/24dp between groups; do not add blank space merely to match another sheet's height |
| Option rows and swatches (language, font, collection, theme) | Content on the gutter; the row's 4/8dp ink inset bleeds into the gutter (see Rules) |
| Text button in a content column (Read more, Delete collection) | Label on the content gutter; the button's 16dp padding is the ink bleed |
| Bottom context strip of the reader | Shares the toolbar's 24dp glyphs; it is part of the bottom chrome family |
| Footer commands | 24dp between the last body line and the commands (`defaultBodyPadding` bottom 16 + `defaultFooterPadding` top 8), 16dp below the last command, plus the route's `max(16dp, bottom safe inset)`; keyboard lift is applied once. Sheets that own their viewport reuse the same constants |

Measure glyph bounds, background bounds and hit bounds separately. Targets
must stay inside their parent and must not overlap a neighboring row action.
Mirror leading/trailing layout in RTL, not the direction of quoted book text.
The hierarchy of gaps matters more than choosing a new numeric scale:
[NN/G proximity guidance](https://www.nngroup.com/articles/gestalt-proximity/)
explains why related content should remain closer than unrelated groups.
Keep relevant actions near their content; the bottommost pixel is not inherently
the easiest place to tap. [NN/G bottom-sheet guidance](https://www.nngroup.com/articles/bottom-sheet/)
also recommends an explicit Close action and avoiding stacked sheets.

`SearchField` rebuilds only its suffix when the controller changes. Clearing
invokes `onChanged('')` once, retains field focus and keeps the suffix space
reserved so the text area and field bounds do not jump. Tests in
`test/search_field_test.dart` cover focus, keyboard visibility, geometry and
pressed states under iOS/Android widget policies, both themes and phone LTR/RTL
with large text. Root Library goldens check the painted press feedback.

### Bottom Sheet Contract

- `showAppBottomSheet` owns the 20dp handle area, keyboard lift and safe areas.
  A guarded form keeps the same top space without displaying a draggable handle.
  Bottom protection belongs to the route, including every nested step; callers
  cannot disable it. Child layouts add their visual bottom padding, not another
  system inset. The footer gap is 32dp with no system inset and 50dp with a 34dp
  inset; above the keyboard it is 32dp. This prevents nested collection forms
  from placing Save/Cancel against the home indicator or keyboard.
- `AppInlineSheet` is the in-place counterpart for panels whose content must
  survive closing (the reader's Contents and Search keep tab search text,
  scroll offsets and result snapshots). The owner passes `visible` and
  `onClose` and decides; the sheet only reports scrim taps, downward flings
  from half and pulls past a list's top through `onClose`, and settles back
  at half if the owner keeps it open. It shares the route's grab handle
  (`AppSheetDragHandle`), `AppRadius.xl` corners, background, barrier colour
  and 640dp width limit; side cutouts are padded only where the centered sheet
  actually reaches them. `AppInlineSheetGeometry` (unit-tested on its own)
  sets the positions: half is 60% of the height below the status bar and above
  the keyboard, scaled with the text and never under 320dp; when half would
  cover more than 75% of full (landscape phones, large text, small screens with
  the keyboard) there is one position and the sheet opens at full; full stops
  8dp below the status bar so the dimmed page stays visible. Opening and
  closing only slide the half-height sheet, so content is never squeezed;
  height changes only between half and full. The grip and `header` drag it;
  in `body`, scrolling a list forward from half grows it, and a 64dp pull past
  a list's top steps it down (bouncing and clamping physics both). A body with
  nothing to scroll drags like the header, because scrollables win the gesture
  arena only while they can scroll. The sheet sits on the keyboard and hands
  its children a `MediaQuery` without that inset; below 320dp the content
  scrolls as a whole and dragging is off. Its scroll wrapper is always present,
  so crossing that threshold never re-inflates a focused field. Children that
  reveal a row should scroll their own list (`ScrollPosition.ensureVisible`),
  not every ancestor. Tests: `test/app_inline_sheet_test.dart`.
- `AppSheetDismissGuard` registers with the route's `AppSheetDismissRegistry`;
  holders are ordered and the latest wins, so a step change that mounts the
  next guard before the previous one is disposed keeps the sheet guarded
  whichever post-frame callback runs first.
- `BottomSheetHeader` uses `titleMedium`, a minimum 48dp row and a heading
  semantics node. Adding Close does not change the title baseline. Long titles
  wrap; trailing actions wrap independently when needed.
  Pass gutters through its `padding`, not an outer `Padding`: the 20dp close
  icon aligns with the content edge while its 48dp hit target extends into the
  trailing gutter. With the standard 24dp gutter, the target ends 10dp from the
  sheet edge. This mirrors in RTL without changing title wrapping or moving
  other header actions. Small custom gutters keep the entire target inside the
  header. No translated painting or hit testing outside a parent is required.
  Optional `onBack`/`backLabel` add a leading, RTL-aware 48dp back button using
  the same icon gutters. Back navigates within a flow; Close dismisses it.
  If a localized word cannot fit between Back and Close at the current text
  scale, a header without trailing actions moves its title below the navigation
  row, retaining the full content width. Text scale and hit targets stay intact.
- Nested steps use header Back, mirrored in RTL; root steps have no Back button.
  System Back follows the same step navigation, then exits at the root. Footers
  contain commands, not a second navigation Back. Cancel on a destructive
  confirmation cancels that operation; it does not mean close the entire flow.
  Unguarded multi-step sheets opt into `scrimClosesFlow` so scrim dismissal
  closes the route just like Close/drag, rather than triggering step Back.
  The helper preserves Flutter's barrier animation, labels and accessibility
  clipping. The default still respects `PopScope` guards. Guarded collection
  forms disable drag/scrim; their explicit Close requests a discard decision.
  A flow whose guard depends on the step wraps that step in
  `AppSheetDismissGuard(enabled:, onDismissAttempt:)`: while enabled, scrim tap
  and drag-down run the callback (the same discard confirmation as Close) and
  the drag handle gives way to a same-height spacer; when disabled the route's
  normal dismissal, including `scrimClosesFlow`, applies. Guard changes publish
  after the frame; system Back stays with the step's `PopScope`. Create
  collection and Save Article use it so an unsaved draft survives a stray tap
  while an empty form still closes freely.
  Step transitions follow reading direction and respect reduced motion; import
  height changes bypass `AnimatedSize` when animations are disabled.
- `ActionBottomSheetLayout` supplies 24dp horizontal gutters and an 8dp
  header/body gap. Constrained sheets keep the header outside the scrolling body.
  Its optional `footer` pins actions below that group; a minimum-height form
  puts spare space above the footer, not below its buttons. Footer padding is
  independent of body padding; forms without a bottom body inset use the
  footer's default 8dp top and 16dp bottom spacing.
- Use `ActionBottomSheetLayout.scrollable` for finite content: Display,
  Appearance, Language, Definition and Translation share this composition.
  Pass content, not another scroll view. It owns one viewport, 24dp content
  gutters, default 16dp bottom padding and full-width edge fades. Its
  `bodyPadding` override supports grids whose padded tap targets already
  provide internal spacing: Language uses 8dp at the bottom, retaining the
  same header and horizontal gutters. The body grows with
  content up to 72% of screen height (78% with large text), including any pinned
  context row and further bounded by the modal's available space. The title
  never scrolls. Optional `headerBottom`
  keeps contextual controls such as translation direction fixed below it.
  Short content does not gain an empty fixed-height area or a scroll shadow.
- Settings use `AppSettingsSection`: `labelMedium` (13sp) in
  `onSurfaceVariant`, an 8dp label/control gap and 16dp between groups. Setting
  rows use `bodyMedium` (15sp), aligned to the same 24dp gutters. There is no
  additional inset for the lower half of Appearance.
- `AppChoiceControl` uses the shared segmented-button theme, 8dp corners,
  48dp minimum controls and the same selected/disabled states. Font previews
  retain their typefaces; theme swatches retain their sample colors. When
  labels do not fit, text choices become two equal columns or a vertical list;
  they do not shrink or ellipsize. Icon-only choices have localized tooltips.
  Fallback buttons merge their selected/group semantics with the named action,
  preserving one accessible control per option like the segmented variant.
- Selected settings and language options share the `AppSelectionColors` pair.
  Dark mode uses an opaque tonal accent with dark text/icons, not a nearly
  invisible translucent brand fill. Disabled choices remain muted; light-mode
  fills and reader theme previews stay unchanged. Tests check selected/background
  contrast of at least 3:1 and text/fill contrast of at least 4.5:1 in dark mode.
- Forms and lazy collection lists keep the default shell constructor: their
  Save/Cancel, staged edits, discard guards and import step sizing are separate
  interaction contracts, not reasons to fork header styling. Put horizontal
  padding inside their viewport so overflow fades span the whole sheet.
- `AppSheetActions` places a secondary outlined command beside a filled primary
  command. When localized labels do not fit, the primary command comes first
  in a vertical stack. Busy state preserves size and blocks duplicate actions.
- Heights follow content, not one global fixed height. Multi-step import and
  Display/Language retain flow-specific stable heights; very short keyboard
  layouts may scroll the whole form so the header and actions cannot make
  content unreachable.
- Use `context.actionForeground` for accent text/icons on surfaces, especially
  in dark mode. Keep `primary`/`onPrimary` for filled controls and background tints.

`test/sheet_contract_test.dart` covers header geometry, close-icon alignment in
LTR/RTL, taps at all four edges of the 48dp target, directional padding, label
scaling, action layout and foreground contrast. Feature tests own persistence
and dismiss guards.
`test/show_app_bottom_sheet_test.dart` checks default pop guards, opt-in scrim
dismissal, system Back, exit completion, and both transparent/animated barriers.
`test/app_choice_control_test.dart` and `test/action_bottom_sheet_layout_test.dart`
check adaptive choices, disabled states, viewport gutters and fixed context.
Root `test/ui/settings_consistency_test.dart` compares Display and Appearance
directly; goldens cover the resulting compositions in light/dark, large text,
landscape and RTL. Native Library/Reader flows verify persistence and WebView
identity, rather than treating a matching screenshot as functional proof.

`test/control_accessibility_contract_test.dart` checks named tap targets against
the iOS/Android policies, selected/disabled choice semantics and busy-action
labels with stable geometry in LTR/RTL at regular/large text sizes.
`test/app_theme_test.dart` checks normal-text contrast for the named surface,
sheet, input and filled-control pairs in both themes, muted text on every
surface and its step below primary text, and the shared field radius.
`test/app_selection_colors_test.dart` checks the selected-control wash and its
text on every surface. These are bounded
component contracts, not a complete screen-reader or rendered-pixel audit.
From the repository root, `make test-ui-contracts` runs these and the existing
shared/layout/representative-flow tests without updating visual baselines.
See [`test/ui/README.md`](../../test/ui/README.md) for the review checklist and
the separate golden, native and performance checks.

`AppCopyButton` receives a clipboard callback and localized labels from its
feature. It performs no service lookup, blocks duplicate in-flight taps, and
shows success only after the callback completes. Feedback rebuilds only the
button; its timer is cancelled on disposal. Clipboard failures remain retryable.

- Design tokens and theme primitives
- Reusable visual widgets used by multiple features
- Small layout shells for common presentation patterns
- Generic UI states (loading, empty, error)
- UI-only controls with no business logic

## What Does NOT Belong Here

- Feature-specific screens, sheets, or flows
- Repository, service, or routing logic
- Domain models or application orchestration
- Widgets used in only one place with no clear reuse path
