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
- `AppTypography.serif(...)` / `sans(...)` -- factory methods for one-off styles

### Rules

- **Screens use roles, not values** -- never write `Color(0xFF...)` or `fontSize: 14` in
  UI code.
- **Use context extensions** -- `context.text.bodyMedium`, not
  `Theme.of(context).textTheme.bodyMedium`.
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

## Widgets

Reusable presentation-only widgets used across features:

| Widget                              | Purpose                                        |
|-------------------------------------|------------------------------------------------|
| `AppBottomActionBar`                | Thumb-friendly route-level action bar          |
| `ActionBottomSheetLayout`           | Bottom sheet shell with header and content     |
| `BottomSheetHeader`                 | Bottom sheet title row                         |
| `ButtonLoadingIndicator`            | Compact circular progress for buttons          |
| `CenteredCircularProgressIndicator` | Centered loading spinner                       |
| `EmptyState`                        | Centered empty state message                   |
| `ErrorState`                        | Error message with retry button                |
| `MediaCollectionCard`               | Card with media area, metadata, optional badge |
| `AppSourceCover` / `AppSourceCoverFrame` | Shared source cover rendering and frame |
| `SourceCoverHero`                   | Stable Hero wrapper for covers                 |
| `SearchField`                       | App search field                               |
| `SettingsGroup` / `SettingsRow`     | Settings list primitives                       |
| `ScrollEdgeFadeStack`               | Scroll-edge fade/scrim wrapper                 |
| `SelectionPreviewCard`              | Compact preview of selected text               |
| `StatCard`                          | Small metric card                              |

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
