/// Standard component sizes for consistent sizing across the app.
abstract final class AppSizes {
  /// Minimum tap target for primary controls. 44dp matches Apple's
  /// HIG floor and the Material 3 "comfortable" density — anything
  /// smaller is hard to tap reliably.
  static const double buttonHeight = 44;
  static const double inputHeight = 52;
  static const double appBarHeight = 52;
  static const double navBarHeight = 70;
  static const double iconButtonSize = 40;

  /// Compact control height: Material 3 filter/assist chip height. Also
  /// used as the side length of small square toggle buttons that sit in
  /// a chip row so their heights align.
  static const double chipHeight = 32;
}
