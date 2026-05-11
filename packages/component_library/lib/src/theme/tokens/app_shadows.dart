import 'package:flutter/painting.dart';

/// Shadow tokens for free-floating UI panels (top/bottom chrome,
/// future popovers, etc.). Distinct from [AppElevation] — that token
/// holds Material `elevation` levels (an `int`) that the framework
/// renders through `Theme.shadowColor` and is M3-tinted on iOS;
/// these constants paint a literal `BoxShadow` we control end-to-end.
///
/// Not used by `AppSourceCoverFrame` — covers run a tuned two-layer
/// shadow + binding shade that's specific to the Apple-Books look,
/// and would leak its specifics into a shared token.
abstract final class AppShadows {
  /// Cast a soft shadow downward — for a panel hugging the top of
  /// the screen so the page content beneath it gets a hint of depth.
  static const List<BoxShadow> panelDown = [
    BoxShadow(
      color: Color(0x1F000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  /// Mirror of [panelDown] for a panel anchored at the bottom — the
  /// shadow lifts upward over the content above it.
  static const List<BoxShadow> panelUp = [
    BoxShadow(
      color: Color(0x1F000000),
      blurRadius: 12,
      offset: Offset(0, -4),
    ),
  ];
}
