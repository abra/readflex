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
/// the sheet down or tapping the scrim. Feature content may additionally
/// provide an explicit close action through [BottomSheetHeader].
///
/// Pass `dismissible: false` to disable the drag handle, drag-down,
/// and scrim tap at once. Note the system back gesture still pops
/// the sheet — wrap the body in `PopScope(canPop: false, ...)` if
/// you want a truly must-complete flow.
///
/// For unguarded multi-step flows, [scrimClosesFlow] makes a scrim tap close
/// the route instead of invoking the step's system-Back handler. Do not enable
/// it for forms whose [PopScope] protects unsaved changes.
///
/// The route owns the bottom safe area for every step, including nested forms.
/// Content adds its visual bottom gap but must not consume system insets again.
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
  bool scrimClosesFlow = false,
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

  final localizations = MaterialLocalizations.of(context);
  final route = _AppBottomSheetRoute<T>(
    scrimClosesFlow: scrimClosesFlow,
    capturedThemes: InheritedTheme.capture(
      from: context,
      to: navigator.context,
    ),
    barrierLabel: localizations.scrimLabel,
    barrierOnTapHint: localizations.scrimOnTapHint(
      localizations.bottomSheetLabel,
    ),
    modalBarrierColor: Theme.of(context).bottomSheetTheme.modalBarrierColor,
    isScrollControlled: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    useSafeArea: true,
    transitionAnimationController: controller,
    builder: (ctx) {
      final sheetContent = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dismissible)
            const _SheetDragHandle()
          else
            // Keep the title position without suggesting a disabled drag.
            const SizedBox(height: AppSpacing.sm * 2 + 4),
          Flexible(child: builder(ctx)),
        ],
      );

      return Padding(
        // Lift the sheet above the keyboard. Done once here so every
        // sheet body gets it, regardless of whether it has form fields.
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: AppBottomSafeArea(child: sheetContent),
      );
    },
  );
  final sheetFuture = navigator.push(route);

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

class _AppBottomSheetRoute<T> extends ModalBottomSheetRoute<T> {
  _AppBottomSheetRoute({
    required this.scrimClosesFlow,
    required super.builder,
    required super.isScrollControlled,
    required super.capturedThemes,
    required super.barrierLabel,
    required super.barrierOnTapHint,
    required super.modalBarrierColor,
    required super.isDismissible,
    required super.enableDrag,
    required super.useSafeArea,
    required super.transitionAnimationController,
  });

  final bool scrimClosesFlow;

  void _closeFlow() {
    if (isCurrent) navigator?.pop();
  }

  @override
  Widget buildModalBarrier() {
    final barrier = super.buildModalBarrier();
    if (!scrimClosesFlow) return barrier;
    // Preserve Flutter's animation and accessibility clipping. Only separate
    // explicit scrim dismissal from maybePop's nested step navigation.
    return switch (barrier) {
      AnimatedModalBarrier() => AnimatedModalBarrier(
        color: barrier.color,
        dismissible: barrier.dismissible,
        onDismiss: _closeFlow,
        semanticsLabel: barrier.semanticsLabel,
        barrierSemanticsDismissible: barrier.barrierSemanticsDismissible,
        clipDetailsNotifier: barrier.clipDetailsNotifier,
        semanticsOnTapHint: barrier.semanticsOnTapHint,
      ),
      ModalBarrier() => ModalBarrier(
        color: barrier.color,
        dismissible: barrier.dismissible,
        onDismiss: _closeFlow,
        semanticsLabel: barrier.semanticsLabel,
        barrierSemanticsDismissible: barrier.barrierSemanticsDismissible,
        clipDetailsNotifier: barrier.clipDetailsNotifier,
        semanticsOnTapHint: barrier.semanticsOnTapHint,
      ),
      _ => barrier,
    };
  }
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
