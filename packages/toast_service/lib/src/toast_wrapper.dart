import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

/// Default-clamped horizontal inset between the toast and the screen
/// edge. Matches `AppSpacing.lg` (the library/list horizontal padding)
/// so a toast lines up with the rest of the chrome.
const double _kHorizontalInset = AppSpacing.lg;

/// Min/max toast width. Floor keeps the message readable on narrow
/// devices; cap stops it from stretching across a tablet screen.
const double _kMinWidth = 280;
const double _kMaxWidth = 520;

/// Wraps the app shell so [showToast] has an Overlay to anchor against.
/// Mount once above MaterialApp's body in the composition root.
///
/// Provides a [ToastificationConfig] whose `itemWidth` is recomputed on
/// every layout pass — toastification otherwise clamps the toast to a
/// fixed 400dp regardless of the screen, which on phones reads as a
/// floating pill that ignores the app's edge inset and on tablets as a
/// half-empty band.
class ToastWrapper extends StatelessWidget {
  const ToastWrapper({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 2 * _kHorizontalInset).clamp(
          _kMinWidth,
          _kMaxWidth,
        );
        return ToastificationWrapper(
          config: ToastificationConfig(itemWidth: width),
          child: child,
        );
      },
    );
  }
}
