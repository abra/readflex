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
    app_radius.dart             # Border radius scale: AppRadius (xs, sm, md, lg, xl, pill)
    app_sizes.dart              # Control heights: AppSizes (buttonHeight, navBarHeight, etc.)
    app_elevation.dart          # Elevation levels: AppElevation (level0..level3)
  extensions/
    app_colors_ext.dart         # ThemeExtension for colors beyond ColorScheme (AppColorsExt)
    app_dimens_ext.dart         # ThemeExtension for spacing, radius, sizes (AppDimensExt)
    build_context_ext.dart      # BuildContext convenience accessors
  components/
    app_button_themes.dart      # FilledButton, OutlinedButton, TextButton, IconButton
    app_card_theme.dart         # CardThemeData
    app_input_theme.dart        # InputDecorationTheme
    app_navigation_theme.dart   # NavigationBar, BottomSheet, Dialog
    app_selection_themes.dart   # SegmentedButton, Chip
  app_theme.dart                # Central assembly: AppTheme.light() / dark()
  app_typography.dart           # AppTypography: textTheme, fontFamilySans/Serif, serif()/sans()
  reader_appearance.dart        # Reader-specific theme presets (Paper, Warm, Mist, Night)
```

### Usage in UI

Access everything through `BuildContext` extensions:

```dart
// Colors
context.colors.primary            // ColorScheme
context.appColors.warning         // AppColorsExt (ThemeExtension)
context.appColors.highlightYellow // highlight/rating/status colors

// Typography
context.text.bodyLarge            // TextTheme roles
context.text.headlineSmall        // serif headlines
AppTypography.serif(fontSize: 18) // one-off serif style

// Dimensions (ThemeExtension)
context.dimens.spacingLg          // 16
context.dimens.radiusMd           // 12
context.dimens.buttonHeight       // 50

// Static constants (for const contexts and component themes)
const EdgeInsets.all(AppSpacing.lg)
BorderRadius.circular(AppRadius.md)
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

### AppDimensExt Fields

Spacing, radius, and control sizes delivered via `ThemeExtension`:

| Group   | Fields                                                                                                                                                               |
|---------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Spacing | `spacingXxs` (2), `spacingXs` (4), `spacingSm` (8), `spacingMd` (12), `spacingLg` (16), `spacingXl` (20), `spacingXxl` (24), `spacingXxxl` (48), `spacingXxxxl` (64) |
| Radius  | `radiusXs` (4), `radiusSm` (8), `radiusMd` (12), `radiusLg` (16), `radiusXl` (20), `radiusXxl` (999)                                                                 |
| Sizes   | `buttonHeight` (50), `inputHeight` (52), `iconButtonSize` (40)                                                                                                       |

### Typography

`AppTypography` is the single source of truth for text:

- `AppTypography.textTheme` -- `TextTheme` with all 15 Material roles; display/headline
  use Source Serif 4, body/title/label use Inter
- `AppTypography.fontFamilySans` / `fontFamilySerif` -- font family constants
- `AppTypography.serif(...)` / `sans(...)` -- factory methods for one-off styles

### Rules

- **Screens use roles, not values** -- never write `Color(0xFF...)` or `fontSize: 14` in
  UI code.
- **Use context extensions** -- `context.text.bodyMedium`, not
  `Theme.of(context).textTheme.bodyMedium`.
- **Primitives feed semantics** -- `PrimitiveColors` / `PrimitiveSpacing` are raw values;
  `AppColorPalette` / `AppSpacing` assign meaning.
- **ColorScheme** for Material-native roles (primary, surface, error, etc.).
- **ThemeExtension** for everything else (AppColorsExt for extra colors, AppDimensExt for
  dimensions).
- **Static constants** are OK for spacing/radius in `const` contexts and component theme
  assembly.
- **Component themes** read from palette and static tokens (no BuildContext available).
- **No ternary operators in theme assembly** -- separate `_buildLight()` / `_buildDark()`
  functions.

## Widgets

Reusable presentation-only widgets used across features:

| Widget                              | Purpose                                        |
|-------------------------------------|------------------------------------------------|
| `ActionBottomSheetLayout`           | Bottom sheet shell with header and content     |
| `BottomSheetHeader`                 | Title + close button row                       |
| `ButtonLoadingIndicator`            | Compact circular progress for buttons          |
| `CenteredCircularProgressIndicator` | Centered loading spinner                       |
| `DestructiveDismissBackground`      | Red swipe-to-delete background                 |
| `EmptyState`                        | Centered empty state message                   |
| `ErrorState`                        | Error message with retry button                |
| `FadeGradientOverlay`               | Bottom fade gradient for scrollable content    |
| `MediaCollectionCard`               | Card with media area, metadata, optional badge |
| `SelectionPreviewCard`              | Compact preview of selected text               |

## What Belongs Here

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
