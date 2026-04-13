/// Icon size tokens aligned with Material Design 3.
///
/// Material uses two standard sizes: 20 (small) and 24 (default). We
/// additionally expose an [xs] tier at 16 — the readwell_demo uses it
/// in places where a Material "small" icon would feel chunky (search
/// prefix, filter toggle buttons, list meta row).
abstract final class AppIconSize {
  static const double xs = 16;
  static const double sm = 20;
  static const double md = 24;
}
