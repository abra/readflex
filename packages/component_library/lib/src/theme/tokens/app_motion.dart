/// Motion duration tokens for implicit animations and transitions.
///
/// Call sites resolve them through `context.motion(...)`, which collapses
/// every token to [Duration.zero] when the platform asks to reduce motion.
abstract final class AppMotion {
  /// Press feedback, swatch rings, small state flips.
  static const Duration quick = Duration(milliseconds: 120);

  /// Chrome show/hide, tile scale, scrims.
  static const Duration short = Duration(milliseconds: 200);

  /// Step transitions, page changes, drawer slides.
  static const Duration medium = Duration(milliseconds: 300);
}
