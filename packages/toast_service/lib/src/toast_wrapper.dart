import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

/// Wraps the app shell so [showToast] has an Overlay to anchor against.
/// Mount once above MaterialApp's body in the composition root.
///
/// The overlay constrains the 520dp cap to the available width. Its margins
/// account for safe areas and keyboard insets, including after rotation.
class ToastWrapper extends StatelessWidget {
  const ToastWrapper({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => ToastificationWrapper(
    config: const ToastificationConfig(itemWidth: 520, marginBuilder: _margin),
    child: child,
  );
}

// Safe-area padding is added by toastification; do not add it here again.
EdgeInsetsGeometry _margin(BuildContext context, AlignmentGeometry alignment) =>
    const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0);
