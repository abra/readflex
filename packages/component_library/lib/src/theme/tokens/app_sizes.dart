import 'app_icon_size.dart';

/// Standard component sizes for consistent sizing across the app.
abstract final class AppSizes {
  /// Minimum tap target for primary controls. 48dp matches Material's
  /// accessibility floor and gives thumb-first controls enough room.
  static const double buttonHeight = 48;
  static const double inputHeight = 52;
  static const double appBarHeight = 52;
  static const double navBarHeight = 70;
  static const double iconButtonSize = 40;

  /// Compact control height: Material 3 filter/assist chip height. Also
  /// used as the side length of small square toggle buttons that sit in
  /// a chip row so their heights align.
  static const double chipHeight = 32;

  /// Tap-target height for [chipHeight]-sized controls. The visible chip
  /// stays at 32 (Material standard, compact); this expands the touchable
  /// area to the 48dp accessibility floor (Apple HIG / Material a11y).
  /// Use this for the row/box that wraps a chip strip; the chip itself
  /// sits centered inside.
  static const double chipTapTarget = 48;

  /// Tinted circle behind the icon of an empty or error state.
  static const double stateIconFrame = 56;

  /// Material's regular floating action button.
  static const double floatingActionButton = 56;

  /// How far a 48dp icon action extends past the content gutter so its 20dp
  /// glyph lands on the gutter. Surfaces subtract this from their edge
  /// padding instead of shrinking the target.
  static const double iconActionOutset = (buttonHeight - AppIconSize.sm) / 2;

  /// Edge of Material's checkbox glyph, which sits centered in its 48dp
  /// target.
  static const double checkboxEdge = 18;

  /// Outset that puts a [Checkbox] glyph on the content gutter.
  static const double checkboxOutset = (buttonHeight - checkboxEdge) / 2;
}
