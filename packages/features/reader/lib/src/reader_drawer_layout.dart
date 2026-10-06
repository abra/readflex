import 'package:component_library/component_library.dart';

/// Trailing inset for a 48dp icon action in a drawer row, so its 20dp glyph
/// sits on the 16dp content gutter while the full target stays tappable.
const readerDrawerActionEndPadding =
    AppSpacing.lg - (AppSizes.buttonHeight - AppIconSize.sm) / 2;
