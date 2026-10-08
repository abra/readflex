import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_bottom_safe_area.dart';
import 'app_sheet_dismiss_guard.dart';
import 'app_sheet_drag_handle.dart';

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
/// A step that holds an unsaved draft wraps itself in [AppSheetDismissGuard]:
/// while the guard is enabled, scrim tap and drag-down call the guard instead
/// of popping, and the drag handle gives way to a same-height spacer. Steps
/// without a draft keep the route's normal dismissal.
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
  final dismissRegistry = AppSheetDismissRegistry();
  final route = _AppBottomSheetRoute<T>(
    scrimClosesFlow: scrimClosesFlow,
    dismissRegistry: dismissRegistry,
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
      final body = Flexible(child: builder(ctx));
      final sheetContent = ValueListenableBuilder<VoidCallback?>(
        valueListenable: dismissRegistry,
        child: body,
        builder: (context, guard, body) {
          final draggable = dismissible && guard == null;
          final column = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (draggable)
                const AppSheetDragHandle()
              else
                // Keep the title position without suggesting a disabled drag.
                const SizedBox(height: kAppSheetDragHandleExtent),
              body!,
            ],
          );
          // ModalBottomSheetRoute's drag-to-dismiss recognizer cannot be
          // toggled after construction. A child vertical-drag recognizer
          // wins the arena (as scrollables inside sheets already do), so a
          // guarded step swallows the drag instead of popping the route.
          // The detector is always present so toggling the guard never
          // re-inflates the body and loses its state.
          final swallowDrag = dismissible && guard != null;
          return GestureDetector(
            onVerticalDragStart: swallowDrag ? _ignoreDragStart : null,
            onVerticalDragUpdate: swallowDrag ? _ignoreDragUpdate : null,
            onVerticalDragEnd: swallowDrag ? _ignoreDragEnd : null,
            behavior: HitTestBehavior.translucent,
            child: column,
          );
        },
      );

      return Padding(
        // Lift the sheet above the keyboard. Done once here so every
        // sheet body gets it, regardless of whether it has form fields.
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: AppBottomSafeArea(
          child: AppSheetDismissScope(
            registry: dismissRegistry,
            child: sheetContent,
          ),
        ),
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
      dismissRegistry.dispose();
    }),
  );

  return sheetFuture;
}

void _ignoreDragStart(DragStartDetails _) {}
void _ignoreDragUpdate(DragUpdateDetails _) {}
void _ignoreDragEnd(DragEndDetails _) {}

class _AppBottomSheetRoute<T> extends ModalBottomSheetRoute<T> {
  _AppBottomSheetRoute({
    required this.scrimClosesFlow,
    required this.dismissRegistry,
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
  final AppSheetDismissRegistry dismissRegistry;

  void _closeFlow() {
    if (isCurrent) navigator?.pop();
  }

  void _onScrimTap() {
    final guard = dismissRegistry.value;
    if (guard != null) {
      guard();
    } else if (scrimClosesFlow) {
      _closeFlow();
    } else if (isCurrent) {
      navigator?.maybePop();
    }
  }

  @override
  Widget buildModalBarrier() {
    final barrier = super.buildModalBarrier();
    // Preserve Flutter's animation and accessibility clipping. Only route the
    // tap through the dismiss guard and the explicit scrim policy.
    return switch (barrier) {
      AnimatedModalBarrier() => AnimatedModalBarrier(
        color: barrier.color,
        dismissible: barrier.dismissible,
        onDismiss: _onScrimTap,
        semanticsLabel: barrier.semanticsLabel,
        barrierSemanticsDismissible: barrier.barrierSemanticsDismissible,
        clipDetailsNotifier: barrier.clipDetailsNotifier,
        semanticsOnTapHint: barrier.semanticsOnTapHint,
      ),
      ModalBarrier() => ModalBarrier(
        color: barrier.color,
        dismissible: barrier.dismissible,
        onDismiss: _onScrimTap,
        semanticsLabel: barrier.semanticsLabel,
        barrierSemanticsDismissible: barrier.barrierSemanticsDismissible,
        clipDetailsNotifier: barrier.clipDetailsNotifier,
        semanticsOnTapHint: barrier.semanticsOnTapHint,
      ),
      _ => barrier,
    };
  }
}
