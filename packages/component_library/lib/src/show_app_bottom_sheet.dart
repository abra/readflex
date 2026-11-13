import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoLocalizations, CupertinoModalPopupRoute, CupertinoTheme;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'app_bottom_safe_area.dart';
import 'app_cupertino_sheet_surface.dart';
import 'app_sheet_dismiss_guard.dart';
import 'app_sheet_drag_handle.dart';
import 'app_surface.dart';
import 'app_surface_appearance.dart';
import 'app_window_size.dart';
import 'theme/tokens/app_sizes.dart';
import 'theme/extensions/build_context_ext.dart';

part 'cupertino_app_bottom_sheet.dart';
part 'expanded_app_sheet.dart';

/// The purpose of a modal determines its expanded-window placement.
enum AppSheetPresentation {
  /// Immediate settings, centred in an expanded window.
  settings,

  /// A draft with explicit save/cancel actions, centred in an expanded window.
  form,

  /// A short action list, near the trailing bottom edge in an expanded window.
  actions,

  /// Controls for the visible document, in an expanded trailing panel.
  contextual,
}

/// Shows a modal bottom sheet using the app's standard configuration.
///
/// All sheets are shown via the root navigator (above tab bar),
/// scroll-controlled (height fits content), and respect safe area.
/// Narrow windows use a Material sheet or opaque Cupertino popup with native
/// spring motion. Expanded windows place settings/forms in a centred modal,
/// actions at the trailing bottom edge and contextual controls in a side panel.
/// Resizing retains the body, including its draft, focus and current step.
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
/// while the guard is enabled, scrim tap calls the guard and drag-down is
/// ignored. The drag handle gives way to a same-height spacer. Steps
/// without a draft keep the route's normal dismissal.
///
/// The route owns the bottom safe area for every step, including nested forms.
/// Content adds its visual bottom gap but must not consume system insets again.
/// The returned future completes on pop; [onFullyHidden] runs after the exit.
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
  bool scrimClosesFlow = false,
  AppSheetPresentation presentation = AppSheetPresentation.settings,
  VoidCallback? onFullyHidden,
}) {
  if (context.isCupertino) {
    return _showCupertinoAppBottomSheet<T>(
      context,
      builder: builder,
      dismissible: dismissible,
      scrimClosesFlow: scrimClosesFlow,
      presentation: presentation,
      onFullyHidden: onFullyHidden,
    );
  }
  final navigator = Navigator.of(context, rootNavigator: true);
  final controller = BottomSheet.createAnimationController(
    navigator.overlay!,
    sheetAnimationStyle: context.reduceMotion
        ? AnimationStyle.noAnimation
        : null,
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
  final contentKey = GlobalKey();
  final route = _AppBottomSheetRoute<T>(
    presentation: presentation,
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
      final body = Flexible(child: Builder(builder: builder));
      final sheetContent = ValueListenableBuilder<VoidCallback?>(
        valueListenable: dismissRegistry,
        child: body,
        builder: (context, guard, body) {
          final wide = AppWindowSize.isWide(context);
          final draggable = dismissible && guard == null && !wide;
          final column = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (draggable)
                const AppSheetDragHandle()
              else
                // Keep the title position without suggesting a disabled drag.
                SizedBox(height: wide ? 12 : kAppSheetDragHandleExtent),
              body!,
            ],
          );
          // ModalBottomSheetRoute's drag-to-dismiss recognizer cannot be
          // toggled after construction. A child vertical-drag recognizer
          // wins the arena (as scrollables inside sheets already do), so a
          // guarded step swallows the drag instead of popping the route.
          // The detector is always present so toggling the guard never
          // re-inflates the body and loses its state.
          final swallowDrag = dismissible && (guard != null || wide);
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
        padding: EdgeInsets.only(
          bottom: AppWindowSize.isWide(ctx)
              ? 0
              : MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: MediaQuery.removeViewInsets(
          context: ctx,
          removeBottom: true,
          child: AppBottomSafeArea(
            child: AppSheetDismissScope(
              key: contentKey,
              registry: dismissRegistry,
              child: sheetContent,
            ),
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
    required this.presentation,
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
  final AppSheetPresentation presentation;
  final AppSheetDismissRegistry dismissRegistry;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => LayoutBuilder(
    builder: (context, _) {
      if (!AppWindowSize.isWide(context)) {
        return super.buildPage(context, animation, secondaryAnimation);
      }
      final sheet = _ExpandedAppSheet(
        presentation: presentation,
        animation: animation,
        child: Builder(builder: builder),
      );
      return capturedThemes?.wrap(sheet) ?? sheet;
    },
  );

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
