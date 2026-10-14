import 'package:flutter/widgets.dart';

/// When a surface switches to its wide layout.
///
/// The decision follows the window, never the device: an iPad in Split View
/// or Stage Manager can be as narrow as a phone, and windows resize while the
/// app runs. A window is wide from Material's expanded width class (840) when
/// it is also at least medium height (480), so a phone held in landscape
/// (844 × 390) keeps the phone layout.
abstract final class AppWindowSize {
  /// Narrowest wide window: Material's expanded width class.
  static const double wideMinWidth = 840;

  /// Shortest wide window: Material's medium height class.
  static const double wideMinHeight = 480;

  /// Whether the window around [context] is wide.
  ///
  /// Depends on the window size only, so the caller rebuilds when the window
  /// is resized or rotated, not for keyboard or padding changes.
  static bool isWide(BuildContext context) =>
      isWideSize(MediaQuery.sizeOf(context));

  /// Whether a window of [size] logical pixels is wide.
  static bool isWideSize(Size size) =>
      size.width >= wideMinWidth && size.height >= wideMinHeight;
}
