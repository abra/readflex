import 'dart:math' as math;
import 'dart:ui' show FlutterView;

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

import 'toast_avoid_area.dart';
import 'toast_lift.dart';

enum NotificationType { success, error }

/// How long a success toast stays: long enough to read a book title, as a
/// Material snackbar.
const Duration toastSuccessDuration = Duration(seconds: 4);

/// How long an error stays unless accessible navigation keeps it until
/// dismissed.
const Duration toastErrorDuration = Duration(seconds: 6);

/// Shows bottom-anchored feedback on a neutral plate with a 48dp Close
/// action, above the bottom controls marked with [ToastAvoidArea], where the
/// thumb already is. Success lasts [toastSuccessDuration]; errors last
/// [toastErrorDuration] or require explicit dismissal with accessible
/// navigation. The overlay owns safe areas and width constraints.
///
/// [messageSuffix] keeps a fixed verb/tail visible after an ellipsized title.
/// It moves to another line when necessary, without reducing the text scale.
void showToast(
  BuildContext context, {
  required NotificationType type,
  required String message,
  String? messageSuffix,
}) {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  toastLift.value = _liftAboveBottomControls(View.of(context));
  toastification.showCustom(
    context: context,
    autoCloseDuration: type == NotificationType.error
        ? (MediaQuery.accessibleNavigationOf(context)
              ? null
              : toastErrorDuration)
        : toastSuccessDuration,
    alignment: Alignment.bottomCenter,
    animationDuration: reduceMotion ? Duration.zero : null,
    animationBuilder: (context, animation, alignment, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      );
    },
    // Keep the library's timer, swipe and hover behavior, not its 30dp Close slot.
    builder: (context, item) => BuiltInContainer(
      item: item,
      margin: EdgeInsets.zero,
      closeOnClick: false,
      pauseOnHover: true,
      dragToClose: true,
      callbacks: const ToastificationCallbacks(),
      child: _ToastContent(
        type: type,
        message: message,
        suffix: messageSuffix,
        onClose: () => toastification.dismiss(item),
      ),
    ),
  );
  // showCustom queues insertion after a frame but does not request one when
  // its overlay already exists (for example after an idle, persistent error).
  WidgetsBinding.instance.ensureVisualUpdate();
}

/// The overlay margin beyond its own [toastBottomMargin] that keeps the
/// lowest toast [toastAvoidGap] above the highest marked bottom control. The
/// overlay already adds the view padding and the keyboard inset, which the
/// controls' positions include.
double _liftAboveBottomControls(FlutterView view) {
  final clearance = toastAvoidClearance(view);
  if (clearance == 0) return 0;
  final media = MediaQueryData.fromView(view);
  final applied =
      toastBottomMargin + media.viewPadding.bottom + media.viewInsets.bottom;
  return math.max(0, clearance + toastAvoidGap - applied);
}

class _ToastContent extends StatelessWidget {
  const _ToastContent({
    required this.type,
    required this.message,
    required this.suffix,
    required this.onClose,
  });

  final NotificationType type;
  final String message;
  final String? suffix;
  final VoidCallback onClose;

  // Align the glyph with the 16dp content inset without shrinking its target.
  static const _actionEndInset =
      AppSpacing.lg - (AppSizes.buttonHeight - AppIconSize.sm) / 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final appColors =
        theme.extension<AppColorsExt>() ??
        (theme.brightness == Brightness.dark
            ? AppTheme.dark().ext
            : AppTheme.light().ext);
    // A neutral plate in both types: only the glyph carries the status, so a
    // confirmation does not flash a saturated banner over the page.
    final background = colors.inverseSurface;
    final foreground = colors.onInverseSurface;
    final (icon, iconColor) = switch (type) {
      NotificationType.success => (AppIcons.check, appColors.successOnInverse),
      NotificationType.error => (AppIcons.error, appColors.errorOnInverse),
    };
    final radius = BorderRadius.circular(AppRadius.lg);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: AppShadows.popover,
      ),
      child: Material(
        color: background,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            AppSpacing.sm,
            _actionEndInset,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(icon, size: AppIconSize.md, color: iconColor),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Semantics(
                  container: true,
                  liveRegion: true,
                  label: '$message${suffix ?? ''}',
                  excludeSemantics: true,
                  child: DefaultTextStyle(
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: foreground,
                    ),
                    child: suffix == null
                        ? Text(
                            message,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          )
                        : _SplitToastTitle(message: message, suffix: suffix!),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              AppPlainIconButton(
                icon: AppIcons.close,
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                color: foreground,
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplitToastTitle extends StatelessWidget {
  const _SplitToastTitle({required this.message, required this.suffix});

  final String message;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final tail = suffix.trimLeft();
    return Wrap(
      spacing: tail == suffix ? 0 : AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
        Text(tail),
      ],
    );
  }
}
