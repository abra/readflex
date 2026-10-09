import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

import 'toast_lift.dart';

/// Wraps the app shell so [showToast] has an Overlay to anchor against.
/// Mount once above MaterialApp's body in the composition root.
///
/// The overlay constrains the 520dp cap to the available width. Its margins
/// account for safe areas and keyboard insets, including after rotation, and
/// lift the toasts above the bottom controls marked with [ToastAvoidArea].
class ToastWrapper extends StatelessWidget {
  const ToastWrapper({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => ToastLiftScope(
    notifier: toastLift,
    child: ToastificationWrapper(
      config: const ToastificationConfig(
        itemWidth: 520,
        marginBuilder: _margin,
      ),
      child: child,
    ),
  );
}

// Safe-area and keyboard insets are added by toastification; do not add them
// here again. The context is the overlay entry's, below [ToastLiftScope].
EdgeInsetsGeometry _margin(BuildContext context, AlignmentGeometry alignment) =>
    EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.md,
      AppSpacing.lg,
      toastBottomMargin + ToastLiftScope.of(context),
    );
