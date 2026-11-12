# component_library

Shared presentation package: design system, theme, and reusable UI widgets.

Uses Flutter 3.50 and the standalone `material_ui` / `cupertino_ui` libraries.
They supply platform controls and transitions through shared presentation
contracts. Layout-only components and painting tokens use Flutter core imports;
ordinary `Text`, `Row`, `Padding`, rendering and gesture primitives do not need
app wrappers.

## Platform Presentation

`ReadflexPlatformApp` in the root package mounts `CupertinoApp.router` on
iOS/macOS and `MaterialApp.router` on other platforms. `AppScaffold` and
`AppNavigationBar` render Cupertino page/navigation chrome or Material
scaffold/app-bar chrome. Features retain one state tree and their existing
Screen/Sheet → Bloc/Cubit → View dependency flow.

Use the public `App*` controls below for app actions, fields and settings.
Their owners select the appropriate Cupertino or Material widget through
`context.isCupertino`. A feature-specific platform interaction belongs in its
own UI component, such as the translation language picker; it does not require
a second feature, repository, cubit or domain model. These are Flutter platform
design widgets; system text selection is a separate native bridge.

`AppPlatformTheme` installs an `AppThemeScope` containing platform-neutral
`AppThemeData`, `AppThemeColors`, `AppTextTheme` and `AppStatusColors`.
`AppTheme.forPlatform` caches the platform/brightness adapters. iOS uses
Cupertino grouped backgrounds, system label/separator colors and system UI
typography; Android retains the Material palette and Geist/Literata app roles.
Reader content keeps its own appearance and document typography.
Android semantic text roles are read below the Material theme after its
locale/script geometry is resolved, preserving letter spacing and baselines;
Cupertino roles remain explicitly defined by the native adapter.

The Android app root opts into `AppPlatformTheme.inheritMaterialTheme`, reading
MaterialApp's animated theme so semantic, Material and legacy-bridge colors
interpolate together. Standalone hosts keep the default explicit platform and
brightness adapter; Cupertino presentation is unchanged.

An inherited Material `Theme` intentionally remains inside `AppPlatformTheme`
on iOS for Pagecraft's adaptive `SelectionArea` and legacy dependencies.
The root also installs `MaterialUiCompatibilityBridge` for third-party theme
and localization readers such as toastification. These compatibility adapters
do not choose the visible app controls. New shared UI reads semantic context
roles rather than `Theme.of(context)`; routes capture both semantic and native
inherited themes.

## Design System

Five-layer architecture following the token-to-theme pipeline:

```
Primitive tokens  -->  Semantic roles  -->  AppThemeData / platform adapters  -->  App* components  -->  UI
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
  app_theme.dart                # Cached Material/Cupertino adapters and semantic assembly
  app_theme_data.dart           # Platform-neutral colors, text and status contracts
  app_theme_scope.dart          # Capturable inherited semantic theme
  app_platform_theme.dart       # Installs semantics, native theme and compatibility adapter
  app_text_theme.dart           # Non-null app typography roles
  app_typography.dart           # AppTypography: textTheme, fontFamilySans/Serif, serif()/sans()
  book_layout.dart              # Reader book layout presets
  reader_appearance.dart        # Reader theme presets (Snow, Paper, Warm, Graphite, Night)
```

### Usage in UI

Access everything through `BuildContext` extensions:

```dart
// Colors
context.colors.primary            // AppThemeColors semantic role
context.actionForeground          // readable accent text/icons on surfaces
context.appColors.warning         // AppStatusColors semantic role
context.appColors.highlightYellow // highlight/rating/status colors

// Typography
context.text.bodyLarge            // AppTextTheme roles
context.text.headlineSmall        // platform app heading
AppTypography.serif(...)          // theme-level helper; UI code uses text roles

// Static constants (for const contexts and component themes)
const EdgeInsets.all(AppSpacing.lg)
BorderRadius.circular(AppRadius.md)
const Icon(Icons.search, size: AppIconSize.md)

// Motion: tokens resolve to Duration.zero under reduced motion
AnimatedOpacity(duration: context.motion(AppMotion.short), ...)
if (context.reduceMotion) controller.jumpTo(...) else controller.animateTo(...)
```

### Status and Highlight Colors

`context.appColors` exposes `AppStatusColors`. `AppColorsExt` supplies these
roles to the Material adapter through a `ThemeExtension`:

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
| `AppSizes` | Control heights and tap targets; `centeredColumnMaxWidth` (480) bounds narrow welcome and empty-state columns |
| `AppSizes.pageContentMaxWidth` / `sidePanelWidth` | Shared workspace maximum (1200dp) and expanded reader navigation panel (420dp) |
| `AppIconSize` | Standard icon sizes |
| `AppMotion` | Implicit-animation durations (`quick` 120ms, `short` 200ms, `medium` 300ms) |
| `AppElevation` / `AppShadows` | Shared depth language |

### Typography

`context.text` is the app UI typography contract. `AppTypography` defines the
Material roles and explicit content fonts; iOS app roles use the Cupertino
system font through the platform adapter:

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

Material button themes and generated cover text styles explicitly select Geist
and the same fallbacks. Cupertino controls inherit the system app roles.
Cover styles retain `inherit: false`
for route/Hero isolation without losing their font family. Root golden tests
register deterministic test-only fallback fonts; see `test/fonts/README.md`
in the repository root. These portable fonts verify layout contracts, not
production San Francisco glyph metrics; native screenshots remain required.

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
- **Semantic context roles** for app colors and text; `ColorScheme` and
  `AppColorsExt` remain Material adapter details. Spacing, radius,
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
  resolved foreground. Cupertino buttons also provide that foreground through
  `IconTheme`; busy indicators follow the owning platform button.
- **Cache platform themes** -- assemble brightness/platform adapters once so
  theme identity stays stable across unrelated widget rebuilds.
- **Motion goes through `context.motion(AppMotion.x)`** -- never pass a literal
  `Duration` to an implicit animation or transition in UI code. The helper returns
  `Duration.zero` for Android's Remove animations or iOS's separate Reduce Motion
  flag; explicit controllers check `context.reduceMotion` and jump instead.
- **Swatch inks come from `context.appColors`** -- a check drawn over a highlight or
  theme sample picks whichever of `onLightSwatch`/`onDarkSwatch` has the higher
  contrast against the sample;
  raw `Colors.black`/`Colors.white` are not allowed in feature code.
- **Content sits on the gutter; interactive surfaces extend into it.** A row,
  option tile or swatch keeps the inner inset its ink or selection pill needs
  (4/8/12dp), and the owning surface subtracts that inset from its own edge
  padding, so text and icons land exactly on the 16dp screen/drawer or 24dp
  sheet gutter while the pill bleeds into the gutter. The same rule places
  icon actions: a 48dp target is outset by
  `AppPlainIconButton.defaultIconOutsetOf(context)` so its adaptive 20/24dp
  glyph meets the gutter (`AppSizes.iconActionOutset` remains the fixed 20dp
  glyph's outset), and a Material `Checkbox` by
  `AppSizes.checkboxOutset`. Never shrink a target, and never fake an outset
  with negative padding, `Transform` or `OverflowBox`; move the padding to the
  widget that owns the surface. Text buttons inside a content column follow
  the same rule: the column stops padding the button and the button's own
  16dp padding becomes the ink bleed, so the label aligns with the text above.
- **Busy commands keep their size.** `AppBusyButtonLabel` replaces a button's
  label with the spinner while a write is in flight; `AppSheetActions(busy:)`
  and `ErrorState(busy:)` use it, and single `AppButton`s pass it as their
  child instead of swapping children.
  Labels default to two lines; growing footers may pass `maxLines: null` to
  `AppButtonLabel` or `AppBusyButtonLabel` to display the full label.
- **Icon glyph colour follows the action's role, not the surface.** Inline
  delete/remove in a row: `onSurfaceVariant`; undo: `context.actionForeground`;
  overflow "more": `onSurfaceVariant`, or `selectedControlForeground` on a
  selected row. Bulk deletion in the Library selection capsule uses a filled
  `error` circle with an `onError` glyph, matching the size of the import "+".
- **Floating actions share semantic roles.** Library's filled circular actions
  use `AppIconButton` and `AppSurface`; Android's remaining Material FAB
  consumers use `floatingActionButtonTheme`.

## Reusable UI API

Reusable presentation-only widgets used across features:

| Widget                              | Purpose                                        |
|-------------------------------------|------------------------------------------------|
| `AppScaffold` / `AppNavigationBar`   | Platform page chrome with shared body, footer and floating-control geometry |
| `AppButton` / `AppIconButton`       | Named platform action controls; filled/tonal/outlined/text intent maps to the platform's presentation |
| `AppTextField`                      | Material/Cupertino editing field with one controller/IME connection; validation can tint a border without reserving a dummy error row |
| `AppSwitch` / `AppSlider` / `AppCheckbox` | Platform settings inputs with unchanged values and callbacks |
| `AppSurface` / `AppTappable`        | Shared surface and interaction primitives; Material ink or Cupertino press feedback |
| `AppProgressIndicator` / `AppLinearProgressIndicator` | Platform loading presentation; determinate progress retains its value |
| `ActionBottomSheetLayout`           | Bottom sheet shell; optional constrained scroll body and wrapping header actions |
| `AppPlainIconButton`                | Labeled 48dp utility action with transparent background and circular press feedback; `icon` or a custom `iconWidget` |
| `AppBackButton`                     | Navigation Back using a platform chevron and localized tooltip; pops the route unless `onPressed` is given |
| `AppActionCard`                     | Reusable command card for action pickers       |
| `AppDrillInRow`                     | Row that opens a nested step: accent leading icon (or a caller-framed `leading` widget, e.g. the import menu's tinted tile), `bodyMedium` title, muted subtitle, directional chevron, 48dp minimum, muted and ripple-free when disabled |
| `AppBottomSafeArea`                 | Bottom inset handling for app-owned surfaces   |
| `AppButtonLabel`                    | Localized button text with two-line or full wrapping |
| `AppBusyButtonLabel`                | Button child that swaps the label for a live-region spinner without changing the button size |
| `AppSheetDismissGuard`              | Per-step scrim/drag guard inside `showAppBottomSheet` flows |
| `AppSheetStep`                      | One step of a sheet flow that slides in place (Display/Language, Appearance/Font, Add to collection/New collection): an inactive step stops tickers and drops semantics, focus and input; hidden steps stay offstage or keep their size (`maintainSize`) |
| `AppSheetActions`                   | Primary/secondary sheet commands with adaptive stacking and stable busy geometry; `destructiveSecondary` for confirmations; `stacks`/`stackedExtent` let a fixed-height step reserve the second row ahead of layout |
| `AppSourceQuote`                    | Quoted source phrase with a leading rule that follows the quote's own direction |
| `AppLexicalMetadataRow`             | Muted reading / IPA pronunciation / part-of-speech line under a headword; starts on the headword's edge (`textDirection`), IPA stays LTR in the phonetic font, wraps when narrow |
| `AppSheetActionRow`                 | Sheet text with a trailing utility action (Copy) centered on its first line; optional lead (caption, source) above; `minTextRoom` keeps gaps at any text size |
| `AppSheetSection` / `AppSheetSectionTitle` | Full-width content over an Android outline or an opaque Cupertino grouped fill, with an optional semantic section heading |
| `appFitLongestWord` / `appFitSelectableText` | Largest font size, down to a minimum, at which a heading's longest word fits; `appFitSelectableText` applies the sheet rule (box width less `appSelectableTextCaretMargin`, metadata-size floor) |
| `AppColorSwatchButton`              | Round color sample in a 48dp circular-ink target; selected ring plus a check using the higher-contrast swatch ink |
| `AppStatusMessage`                  | Inline sheet status: start-aligned title/body, optional full-width filled action and progress |
| `AppSettingsSection`                | Shared settings heading and label/control spacing |
| `AppChoiceControl` / `AppChoiceOption` | Single-choice settings, with the same themed states for text, icons, painted `glyph`s and font previews; `reselectable` reports a tap on the selected option for nearest-match presets |
| `AppContentFrame` | Centered bounded workspace with optional directional padding; preserves height constraints for Expanded lazy lists without intrinsic measurement |
| `AppCopyButton`                     | 48px copy command with local success/error feedback |
| `AppSaveToggleButton`               | Save / Saved bookmark toggle for a sheet row (Translation and Definition word headers); the tooltip names the next tap, a state change is announced through a live region, `failed` shows the error glyph until the next tap |
| `AppFilterChip`                     | Compact visual body (32dp minimum) in a target of at least 48×48dp; labels use `labelSmall` on narrow windows and `labelLarge` on medium windows; bounded long labels wrap and large text can grow the control |
| `AppFloatingCapsule`                | Stadium for compact floating controls (reader search navigation, Library collection switcher + "+"): `surface` at 92%, hairline `outlineVariant`, `AppShadows.popover`, radius from the caller's height; controls paint their own ink |
| `AppInlineSheet` / `AppInlineSheetGeometry` | Retained modal surface in a screen's Stack: narrow windows use a keyboard-aware 60%/full bottom sheet; expanded windows use a full-height trailing 420dp panel. RTL mirrors the panel, resizing preserves its body/focus, and list gestures stay scrolling gestures on wide windows. |
| `BottomSheetHeader`                 | Android title/action row or centred Cupertino title with slotted Back/Close; adapts to long labels |
| `ButtonLoadingIndicator`            | Compact circular progress for buttons; takes the button's own foreground via `IconTheme` |
| `CenteredCircularProgressIndicator` | Centered loading spinner                       |
| `AppFirstRunState`                  | A screen's first-run state: accent glyph, serif title, optional stretched commands |
| `EmptyState`                        | Centered empty state; `compact` for list/panel placeholders |
| `ErrorState`                        | Centered failure with filled Retry, optional title/icon/secondary exit and busy geometry |
| `AppSourceCover` / `AppSourceCoverFrame` | Shared source cover rendering and frame |
| `appSourceCoverImageFromPath`       | Resolves an optional local cover image path    |
| `SearchField`                       | App search field with an adaptive primary-tone clear action and circular press feedback; optional `compactHintText` replaces a hint that would be cut |
| `SearchFieldHint`                   | Adaptive hint for custom search inputs, with full semantics and support for input-decorator intrinsic layout |
| `ScrollEdgeFadeStack`               | Scroll-edge fade/scrim wrapper; `axis: Axis.horizontal` fades the start/end of a scrolling strip (tab bar), `enabled` turns the fades off when the child stops scrolling |
| `ScrollEdgeFade`                    | Scroll-edge fade: top/bottom darken (0.14 alpha in light mode); start/end dissolve a horizontal strip into `surfaceColor` (default scaffold background) |
| `SelectionPreviewCard`              | Compact preview of selected text with its own `textDirection` |
| `showAppBottomSheet`                | Shared modal bottom-sheet presentation helper  |
| `AppWindowSize`                     | `isMedium(context)` selects larger controls at 600×480dp; `isWide(context)` keeps the existing expanded layout threshold of 840×480dp. Short landscape phones keep narrow controls, while 600dp Split View and 800dp portrait tablets use medium controls. Both depend only on window size, never padding, keyboard insets or device type |

`AppSurface` does not provide a Material ancestor on iOS. Decorations inside a
Cupertino surface use core painting widgets; Android-only `Ink` remains under
its Material surface. Theme compatibility is not an ink-painting ancestor.

## What Belongs Here

### Search and Utility Actions

Use `AppIcons.delete` for deleting saved items and removing collection
memberships, including bookmarks and recent search entries. `AppIcons.close`
is for dismissing surfaces or canceling modes, not deleting records. Search
field clearing and filter reset retain the familiar non-destructive cross.
Keep localized tooltips specific to the action and preserve existing save,
confirmation and Undo behavior when changing an icon.
Use `AppIcons.undo` for reversing a deletion, not the refresh/retry icon.
`AppIcons.practice` is Lucide's `playing-cards-fan`, the review deck, wherever
Practice is named: the Library row, Start review, the empty hub.
The separate 32dp floating action uses `AppFloatingPracticeIcon`: opaque
surface-coloured cards beneath `AppIcons.practiceFloating`, the same glyph at
weight 300 so its strokes stay close to the usual 2dp thickness. Its silhouette
uses `AppShadows.popover`, with an optional soft primary-colour aura. The aura
is static, including with reduced motion; the surrounding button area stays
transparent.
Icons come from `lucide_icons_flutter` 4 (Lucide 1.56+); regular glyphs and
their `Dir` variants keep the 3.x API, weighted variants live in separate
libraries. A Lucide bump can refine glyphs, so compare every
golden diff against an icon-sized box before updating baselines.
Inline deletion/restoration actions use the same icon-only button and target;
do not replace an icon with a variable-width text label. The localized tooltip
names the action for both pointer users and assistive technology.

Pushed screens use `AppNavigationBar` with `AppBackButton` for explicit Back.
Cupertino chrome uses its native navigation chevron and localized Back label;
Android retains the app's chevron and Material localization. App bar text
uses the platform typography adapter.

`AppPlainIconButton` requests a minimum 48dp target independently of `iconSize`.
Ordinary body, reader and sheet controls retain that size. The native
Cupertino navigation bar has a 44pt content height (plus top safe area), so
controls constrained inside it use that native height; this is not a global
reduction of `AppSizes.buttonHeight`.
Its default glyph is 20dp in narrow windows and 24dp in medium windows
(`AppWindowSize.isMedium`); explicit sizes keep their value, and `iconWidget`
keeps the caller's own geometry. `SearchField` uses 16dp. Its resting background is
transparent. Android uses circular ink/focus feedback; iOS uses Cupertino
pressed opacity and avoids a Material long-press tooltip bubble. The localized
`tooltip` supplies the accessible action name once, through platform semantics.
Pass `iconWidget`
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
sheet row and aligns its adaptive 20/24dp utility glyph with `BottomSheetHeader`, preserving
the full 48dp target; `textDirection` lets a Copy action trail LTR content in
an RTL interface. The action is centered on the first line of the text
(`firstLineStyle`) by a single-pass render object, not by padding guesses: a
`lead` above the text (a caption, a source expression) spans both content edges
in the ambient direction and lets the action move down to the text instead of
pushing it down. `minTextRoom` is the least room above the first line and below
the last; at least half the target's excess over the line keeps gaps unchanged
when text wraps and at large text sizes, where a line is taller than the
target. Definition/Translation use it for Copy; other body sections retain
their 24dp padding. `AppCopyButton` delegates appearance to
`AppPlainIconButton`, including circular feedback and disabled hit semantics.

When measuring text before building a row, pass
`AppPlainIconButton.defaultIconSizeOf(context)` as `childWidthFor`'s `iconSize`
so the measurement uses the same action gutter as the rendered row.

`AppSheetSection` separates the parts of a sheet body that readers must tell
apart (Translation and Definition results). Android paints an outline;
iOS paints an opaque `secondarySystemGroupedBackground` with no border.
The decoration sits behind content, 10dp from either sheet edge in narrow windows and 12dp in medium
windows (`outlineInsetFor(context)`, the 24dp gutter less a 48dp target's
outset), so content keeps the sheet's geometry: text stays on the gutter under
the sheet title and an `AppSheetActionRow` target reaches exactly to the
outline. The section pads its content 12dp above and below; content that keeps
its own room, such as an action row with `minTextRoom`, takes
`EdgeInsets.zero` and puts the `AppSheetSectionTitle` in the row's lead so the
action stays centered on the text.

Large headings use `appFitLongestWord` so a word never breaks in the middle at
large text sizes: one measurement when the word fits, a short binary search on
the font size only when it does not, with the user's (also nonlinear) text
scale. `appFitSelectableText` is the sheet rule in one call: a `SelectableText`
box width (the caret margin is taken off), the context's text scale and locale,
and never below metadata size. `AppLexicalMetadataRow.isEmpty` tells callers
when the row renders nothing, so they can drop the spacing around it.

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

Android muted text and icons (`onSurfaceVariant`, `ListTile` icons) use the palette's
`mutedForeground` gray (gray650 #5B616D, darkGray300 #9AA0AA) instead of the
seed's wine-tinted variant: at least 4.5:1 on every surface, and at most 55% of
primary text's contrast, so it stays clearly secondary in dark mode.

Cupertino `onSurfaceVariant` keeps `secondaryLabel` RGB at 80% opacity so
small app captions and sheet-section headings meet 4.5:1 against grouped,
sheet and container surfaces in both themes. Contrast tests composite both
the foreground and translucent fills. Native control press/disabled colors
retain their SDK defaults. Inverse plates use `inversePrimary` for Cupertino
actions, independently of the filled-button primary pair.

Text fields share the search field's and buttons' `AppRadius.md` (12dp).

### Generic States

`AppFirstRunState` is a screen's first-run state, the one a reader sees before
saving anything: the glyph in a 72dp circle tinted with the accent, a serif
`headlineSmall` title, a muted hint, then any commands stretched to a 480dp
column (the first filled) and an optional caption. The empty Library and the
empty Practice section both draw it, so the app's first screens read as one.
`EmptyState` and `ErrorState` are the only other full-panel placeholders:
reader drawers, reader search, reader load failure, collection lists and
Practice's Vocabulary and Highlights lists use them rather than a hand-rolled
`Center(Text)`. Retry is always the filled primary
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
- Secondary commands use an Android outline or a Cupertino tinted button;
  destructive commands use the error foreground. Disabled primary/secondary
  controls use their platform's muted state and have no command tap action.

### Placement by Role

These are Readflex conventions, not a claim that platform guidelines prescribe
one padding value for every component. Android recommends a 16dp compact-screen
margin and 48dp touch targets; Apple recommends respecting layout margins/safe
areas and at least 44pt touch targets. Readflex requests 48 logical pixels for
shared controls; native Cupertino navigation chrome constrains its actions to
the bar's 44pt content height. Sheet and reader controls keep 48dp. See [Android content structure](https://developer.android.com/design/ui/mobile/guides/layout-and-content/content-structure),
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
| Footer commands | 24dp between body and commands (`defaultBodyPadding` bottom 16 + `defaultFooterPadding` top 8), then 16dp visual bottom padding; the route owns safe areas/keyboard. Android adds `max(16dp, bottom safe inset)`; the Cupertino popup sits above `max(8dp, bottom safe inset)` |

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

With `compactHintText`, a hint that would be ellipsized on one line is replaced
by the short one (Contents: "Search chapters" becomes "Search" on a 320dp phone
at 2x text); the short hint ellipsizes only if it does not fit either. Screen
readers always hear the full hint. `SearchFieldHint` is a render object, not a
`LayoutBuilder`, because the input decorator asks its hint for intrinsics, dry
layout and baselines. It resolves the decorator's `hintText` style chain itself
and lays out at the minimum width like a paragraph, so a hint that fits paints
pixel-identically to a plain `hintText` in LTR and RTL
(`test/search_field_hint_test.dart`).

A horizontal `ScrollEdgeFadeStack` places its fades by reading direction: the
end fade marks hidden content after the visible part, on the right in LTR and
the left in RTL. `fadeInsets` keeps a divider under the strip whole. A child
that stops scrolling sends no notification, so its owner passes
`enabled: false`; the wrapper itself stays in the tree, keeping the child's
state (a `TabBar` stays mounted when it switches to scrolling).

### Bottom Sheet Contract

- `showAppBottomSheet` owns the 20dp handle area, keyboard lift and safe areas.
  Android retains `ModalBottomSheetRoute`. iOS uses a content-sized
  `CupertinoModalPopupRoute`, native spring motion and an opaque Cupertino
  surface without backdrop blur. Its internal `AppCupertinoSheetSurface` is
  also used by retained bottom sheets: the SDK's 13dp superellipse corners,
  opaque semantic sheet color and resolved light/dark Cupertino scrim are
  shared. It stays bottom-centred with an 8dp minimum
  outer safe gap and a 540dp maximum width on tablets; it does not turn a short
  settings sheet into a nearly full-screen page. Both paths use the root
  navigator and capture inherited app/platform themes.
  Cupertino drag movement follows the finger; its slow-drag dismissal threshold
  is half the visible card height. Keyboard/safe-area gaps do not increase it.
  Its opening and closing transitions settle in one frame for either Android's
  Remove animations or iOS's Reduce Motion flag. Results, dismiss guards and the
  single `onFullyHidden` callback keep the same lifecycle.
  A guarded form keeps the same top space without displaying a draggable handle.
  Bottom protection belongs to the route, including every nested step; callers
  cannot disable it. Child layouts add their visual bottom padding, not another
  system inset. With the standard footer, Android's outer button gap is 32dp
  without an inset and 50dp with a 34dp inset; the Cupertino popup's corresponding
  gaps are 24dp and 50dp, including its outer safe gap. Keyboard lift is consumed
  once. The result future completes on pop; `onFullyHidden` follows the exit,
  so callers can wait before exposing controls behind the modal.
- `AppInlineSheet` is the in-place counterpart for panels whose content must
  survive closing (the reader's Contents and Search keep tab search text,
  scroll offsets and result snapshots). The owner passes `visible` and
  `onClose` and decides. On narrow windows the sheet reports scrim taps, downward flings
  from half and pulls past a list's top through `onClose`, and settles back
  at half if the owner keeps it open. It shares the route's grab handle
  (`AppSheetDragHandle`). Android retains `AppRadius.xl` top corners, its
  Material background/barrier and a 640dp width limit; side cutouts are padded
  only where the centered sheet actually reaches them. Cupertino uses the
  same inset 540dp card, opaque background and native scrim as the routed
  popup. Its outer sides/bottom consume `max(8dp, safe inset)` once; lists
  receive zero consumed bottom/keyboard padding and add their visual gutter.
  `AppInlineSheetGeometry` (unit-tested on its own)
  sets the positions: half is 60% of the available height below the status bar
  and above the keyboard/outer safe gap, scaled with the text and never under
  320dp; when half would
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
  not every ancestor. Inline detents keep the existing duration-based motion;
  routed Cupertino popups use the native spring. Both honor reduced motion.
  Tests: `test/app_inline_sheet_test.dart`,
  `test/cupertino_inline_sheet_test.dart`.
  Expanded windows use a 420dp trailing panel with a physical-pixel outline,
  24dp gutters and full available height above the keyboard. The panel has no
  grip or vertical dismiss gesture; Close and the scrim remain available.
  It slides fully beyond the trailing gutter in LTR/RTL, consumes its safe
  insets once, and keeps the same child slots while the window resizes.
- `AppSheetDismissGuard` registers with the route's `AppSheetDismissRegistry`;
  holders are ordered and the latest wins, so a step change that mounts the
  next guard before the previous one is disposed keeps the sheet guarded
  whichever post-frame callback runs first.
- `BottomSheetHeader` uses `titleMedium`, a minimum 48dp row and a heading
  semantics node. Adding Close does not change the title baseline. Long titles
  wrap. Android keeps its leading title/action layout. Cupertino centres the
  title over the full header between symmetric action slots, with a native
  directional Back and a subtle circular Close. When it cannot fit at the
  permitted scale, the title wraps below the navigation row at full width.
  A title too long to keep its `trailing` action beside it first shrinks,
  down to `BottomSheetHeader.minTitleScale` (0.8), scaled when painted like a
  scale-down `FittedBox` because the room depends on the action's laid-out
  width. Below that, an optional `compactTrailing` (the same action in less
  width, such as an icon button for a labeled one) takes its place under the
  same rule; past that, Android wraps `trailing` below the title while Cupertino
  keeps navigation above the title. Only the action on
  screen is painted, hit tested and announced; the hidden one also leaves focus
  traversal once the frame that swapped them is done.
  `ActionBottomSheetLayout` passes it as `headerCompactTrailing`. The layout is
  `BottomSheetTitleBar` (internal), which answers intrinsics, dry layout and
  baselines. Tests: `test/bottom_sheet_title_bar_test.dart`,
  `test/cupertino_sheet_header_test.dart`.
  Pass gutters through its `padding`, not an outer `Padding`: Android's 20dp
  close glyph aligns with the content edge while its 48dp target extends into the
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
  runs the callback (the same discard confirmation as Close), drag-down is
  swallowed without moving the route, and
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
- `AppSlider` keeps native Cupertino thumb dragging. Navigation controls can
  opt into `tapToSeek` to seek directly along the track; a tap emits
  `onChangeStart`, `onChanged`, then `onChangeEnd` once. Thumb drags stay with
  the native recognizer. Cupertino accessibility adjustments call only
  `onChanged`, so consumers that distinguish preview from commit must also
  commit changes received outside a drag.
- `AppChoiceControl` uses Material segmented buttons or a Cupertino sliding
  segmented control when labels fit, with 48dp shared targets and matching
  selected/disabled semantics. `proportionalWidth` lets Cupertino segments share
  space according to their label widths while retaining 48dp targets; Material
  and the default equal-width policy stay unchanged. Font previews
  retain their typefaces; theme swatches retain their sample colors. When
  labels do not fit, text choices become two equal columns or a vertical list;
  they do not shrink or ellipsize. Icon-only choices have localized tooltips.
  Fallback buttons merge their selected/group semantics with the named action,
  preserving one accessible control per option like the segmented variant.
- Custom selected rows use the semantic `selectedControlBackground` accent
  wash and `selectedControlForeground` with a check and selected semantics.
  Material adapter consumers use the equivalent `AppSelectionColors` pair;
  Cupertino segmented controls retain their native thumb presentation.
  Disabled choices keep their selected state. Theme tests verify named
  foreground/background pairs; they do not establish contrast over arbitrary
  reader images or preview colors.
- Forms and lazy collection lists keep the default shell constructor: their
  Save/Cancel, staged edits, discard guards and import step sizing are separate
  interaction contracts, not reasons to fork header styling. Put horizontal
  padding inside their viewport so overflow fades span the whole sheet.
- `AppSheetActions` places a platform secondary command beside a filled primary
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
landscape and RTL. Native Library/Reader flows verify persistence and the
reader page's identity, rather than treating a matching screenshot as functional proof.

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

`AppTextSelectionHost` adapts an existing read-only `SelectableText` to
`native_text_selection`. The inner widget keeps its layout, key, semantics and
callbacks. System handles use the supplied Flutter geometry; the existing
Flutter action toolbar remains. Editable fields retain their current keyboard
and IME connection. See the [adapter contract](../native_text_selection/README.md)
for platform/layout fallbacks and the distinction between channel tests and
native gesture verification.

## What Does NOT Belong Here

- Feature-specific screens, sheets, or flows
- Repository, service, or routing logic
- Domain models or application orchestration
- Widgets used in only one place with no clear reuse path
