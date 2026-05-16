import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_bottom_safe_area.dart';
import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_radius.dart';
import 'theme/tokens/app_spacing.dart';

/// Shows a modal bottom sheet using the app's standard configuration.
///
/// All sheets are shown via the root navigator (above tab bar),
/// scroll-controlled (height fits content), and respect safe area.
///
/// By default the sheet is fully dismissible — the wrapper draws a
/// drag handle at the top, and the user can also dismiss by dragging
/// the sheet down or tapping the scrim. There's no per-feature
/// close-X: closing is owned entirely by this wrapper, and feature
/// content uses [BottomSheetHeader] only for the title.
///
/// Pass `dismissible: false` to disable the drag handle, drag-down,
/// and scrim tap at once. Note the system back gesture still pops
/// the sheet — wrap the body in `PopScope(canPop: false, ...)` if
/// you want a truly must-complete flow.
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
  VoidCallback? onFullyHidden,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final controller = BottomSheet.createAnimationController(
    navigator.overlay!,
  );
  var wasVisible = false;
  final dismissedCompleter = Completer<void>();

  void restoreSystemUiOverlays() {
    unawaited(SystemChrome.restoreSystemUIOverlays());
  }

  void statusListener(AnimationStatus status) {
    if (status == AnimationStatus.forward ||
        status == AnimationStatus.completed) {
      wasVisible = true;
      restoreSystemUiOverlays();
    }
    if (wasVisible &&
        status == AnimationStatus.dismissed &&
        !dismissedCompleter.isCompleted) {
      restoreSystemUiOverlays();
      onFullyHidden?.call();
      dismissedCompleter.complete();
    }
  }

  controller.addStatusListener(statusListener);

  final sheetFuture = showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    transitionAnimationController: controller,
    builder: (ctx) => Padding(
      // Lift the sheet above the keyboard. Done once here so every
      // sheet body gets it, regardless of whether it has form fields.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: AppBottomSafeArea(
        // Android immersive mode can report a zero bottom inset. Keep
        // sheet actions off the physical screen edge in that case.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dismissible) const _SheetDragHandle(),
            Flexible(child: builder(ctx)),
          ],
        ),
      ),
    ),
  );

  unawaited(
    sheetFuture.whenComplete(() async {
      if (!dismissedCompleter.isCompleted) {
        if (controller.status == AnimationStatus.dismissed) {
          if (wasVisible) onFullyHidden?.call();
          dismissedCompleter.complete();
        } else {
          await dismissedCompleter.future;
        }
      }
      controller.removeStatusListener(statusListener);
      controller.dispose();
    }),
  );

  return sheetFuture;
}

/// 32×4 grab handle pill rendered at the very top of a dismissible
/// sheet. Vertical spacing balances the iOS feel: a noticeable gap
/// above the bar so the handle doesn't hug the rounded top edge,
/// and a matching gap below before the title.
class _SheetDragHandle extends StatelessWidget {
  const _SheetDragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: AppSpacing.sm,
      ),
      child: Center(
        child: Container(
          width: 32,
          height: 4,
          decoration: BoxDecoration(
            color: context.colors.onSurfaceVariant.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        ),
      ),
    );
  }
}
