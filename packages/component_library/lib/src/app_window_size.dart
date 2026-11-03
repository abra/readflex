import 'package:flutter/widgets.dart';

/// Window breakpoints for control sizes and expanded layouts.
///
/// The decision follows the window, never the device: an iPad in Split View
/// or Stage Manager can be as narrow as a phone, and windows resize while the
/// app runs. Controls use medium sizes from 600dp wide; expanded layouts
/// start at 840dp. Both need 480dp height, so a phone held in landscape
/// (844 × 390) keeps its narrow controls and layout.
abstract final class AppWindowSize {
  /// Narrowest window using larger app controls, including tablet Split View.
  static const double mediumMinWidth = 600;

  /// Short landscape phones retain their compact controls.
  static const double mediumMinHeight = 480;

  /// Narrowest wide window: Material's expanded width class.
  static const double wideMinWidth = 840;

  /// Shortest wide window: Material's medium height class.
  static const double wideMinHeight = mediumMinHeight;

  /// Whether app controls have the medium window's extra room.
  /// Reads only window size, so keyboard and padding changes do not rebuild it.
  static bool isMedium(BuildContext context) =>
      isMediumSize(MediaQuery.sizeOf(context));

  /// Whether [size] has room for medium controls.
  static bool isMediumSize(Size size) =>
      size.width >= mediumMinWidth && size.height >= mediumMinHeight;

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
