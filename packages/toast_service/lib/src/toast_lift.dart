import 'package:component_library/component_library.dart';
import 'package:flutter/widgets.dart';

/// Gap between the screen edge (above system insets) and the lowest toast.
const double toastBottomMargin = AppSpacing.lg;

/// Gap between a toast and the control it floats above.
const double toastAvoidGap = AppSpacing.sm;

/// Extra bottom margin of the toast overlay, set by [showToast] from the
/// bottom controls on screen. One value for the app: toasts share one
/// overlay, and the latest toast decides where the stack sits.
final ValueNotifier<double> toastLift = ValueNotifier<double>(0);

/// Exposes [toastLift] to the toast overlay's margin builder, which runs
/// inside the app's Navigator overlay, so a new lift re-lays the overlay out
/// instead of padding each toast (padding would leave the toast list's hit
/// area over the controls it is meant to clear).
class ToastLiftScope extends InheritedNotifier<ValueNotifier<double>> {
  const ToastLiftScope({
    required ValueNotifier<double> super.notifier,
    required super.child,
    super.key,
  });

  /// The current lift, or 0 outside a [ToastLiftScope].
  static double of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ToastLiftScope>()
          ?.notifier
          ?.value ??
      0;
}
