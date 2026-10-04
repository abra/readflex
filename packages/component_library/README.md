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
    app_spacing.dart            # Semantic spacing: AppSpacing (xxs, xs, sm, md, lg, xl, xxl, xxxl, xxxxl)
    app_radius.dart             # Border radius scale: AppRadius (xs, sm, md, lg, xl, full)
    app_sizes.dart              # Control heights: AppSizes (buttonHeight, navBarHeight, etc.)
    app_elevation.dart          # Elevation levels: AppElevation (level0..level3)
    app_icon_size.dart          # Icon size scale
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
AppTypography.serif(fontSize: 18) // one-off serif style

// Static constants (for const contexts and component themes)
const EdgeInsets.all(AppSpacing.lg)
BorderRadius.circular(AppRadius.md)
const Icon(Icons.search, size: AppIconSize.md)
```

### AppColorsExt Fields

Colors that go beyond `ColorScheme`, delivered via `ThemeExtension`:

| Group        | Fields                                                                                   |
|--------------|------------------------------------------------------------------------------------------|
| Reading      | `readingSurface`, `readingText`                                                          |
| Highlights   | `highlightYellow`, `highlightBlue`, `highlightGreen`, `highlightPink`, `highlightPurple` |
| FSRS ratings | `ratingAgain`, `ratingHard`, `ratingGood`, `ratingEasy`                                  |
| Status       | `warning`/`warningForeground`, `info`/`infoForeground`, `success`/`successForeground`    |
| Pro badge    | `proBadge`, `proBadgeForeground`                                                         |
| Navigation   | `tabActive`, `tabInactive`                                                               |
| Other        | `divider`, `aiAccent`                                                                    |

### Token Fields

Spacing, radius, icon sizes, control sizes, elevation, and shadows are exposed
as static semantic token classes:

| Token class | Purpose |
|-------------|---------|
| `AppSpacing` | Layout gaps and insets (`xxs` … `xxxxl`) |
| `AppRadius` | Shape scale (`xs`, `sm`, `md`, `lg`, `xl`, `full`) |
| `AppSizes` | Control heights and tap targets |
| `AppIconSize` | Standard icon sizes |
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
- **No ternary operators in theme assembly** -- separate `_buildLight()` / `_buildDark()`
  functions.

## Reusable UI API

Reusable presentation-only widgets used across features:

| Widget                              | Purpose                                        |
|-------------------------------------|------------------------------------------------|
| `ActionBottomSheetLayout`           | Bottom sheet shell; optional constrained scroll body and wrapping header actions |
| `AppPlainIconButton`                | Labeled 48dp utility action with transparent background and circular press feedback |
| `AppActionCard`                     | Reusable command card for action pickers       |
| `AppBottomSafeArea`                 | Bottom inset handling for app-owned surfaces   |
| `AppButtonLabel`                    | Bounded label for localized button text        |
| `AppSheetActions`                   | Primary/secondary sheet commands with adaptive stacking and stable busy geometry |
| `AppSettingsSection`                | Shared settings heading and label/control spacing |
| `AppChoiceControl` / `AppChoiceOption` | Single-choice settings, with the same themed states for text, icons and font previews |
| `AppCopyButton`                     | 48px copy command with local success/error feedback |
| `AppFilterChip`                     | App-styled filter chip with stable tap target  |
| `BottomSheetHeader`                 | Bottom sheet title row                         |
| `ButtonLoadingIndicator`            | Compact circular progress for buttons          |
| `CenteredCircularProgressIndicator` | Centered loading spinner                       |
| `EmptyState`                        | Centered empty state with optional recovery action |
| `ErrorState`                        | Error message with retry button                |
| `AppSourceCover` / `AppSourceCoverFrame` | Shared source cover rendering and frame |
| `appSourceCoverImageFromPath`       | Resolves an optional local cover image path    |
| `SearchField`                       | App search field with an adaptive primary-tone clear action and circular press feedback |
| `ScrollEdgeFadeStack`               | Scroll-edge fade/scrim wrapper                 |
| `ScrollEdgeFade`                    | Individual top/bottom scroll-edge fade         |
| `SelectionPreviewCard`              | Compact preview of selected text               |
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
the accessible name through Flutter's `IconButton` semantics.
For standalone trailing list actions, align the glyph with the content gutter
and the surface header, not the outer edge of the target. Allow the target's
inner inset to occupy the gutter without clipping its hit area; mirror this
with directional padding. Do not shrink targets or globally remove padding
from grouped controls to achieve alignment.

Screen/drawer content uses a 16dp gutter; sheet content uses 24dp. The owning
surface applies each outer gutter once. `AppSheetActionRow` accepts a full-width
sheet row and aligns a 20dp utility glyph with `BottomSheetHeader`, preserving
the full 48dp target. Definition/Translation use it for Copy; other body sections
retain their 24dp padding. `AppCopyButton` delegates appearance to
`AppPlainIconButton`, including circular feedback and disabled hit semantics.

Filled success notifications use `AppColorsExt.successContainer` with
`onSuccessContainer`; `successForeground` remains the text/icon role on ordinary
surfaces. Error notifications use the existing `ColorScheme.error` / `onError`
pair. The toast service owns notification layout and lifecycle, not this package.

Selected controls use the paired `selectedControlBackground/Foreground` colors.
Opaque `selectionMarkerBackground/Foreground` is for small checks on cover art;
normal multi-selection must not use the destructive error color. Custom rows
also expose `Semantics(selected: ...)`; color is not their only selection cue.

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
| Footer commands | 16dp visual space below the last command, plus the route's `max(16dp, bottom safe inset)`; keyboard lift is applied once |

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
sheet, input and filled-control pairs in both themes. These are bounded
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
