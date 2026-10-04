import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

enum NotificationType { success, error }

/// Shows top-anchored feedback using app tokens and a 48dp Close action.
/// Success lasts 1 second; errors last 6 seconds or require explicit dismissal
/// with accessible navigation. The overlay owns safe areas and width constraints.
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
  toastification.showCustom(
    context: context,
    autoCloseDuration: type == NotificationType.error
        ? (MediaQuery.accessibleNavigationOf(context)
              ? null
              : const Duration(seconds: 6))
        : const Duration(seconds: 1),
    alignment: Alignment.topCenter,
    animationDuration: reduceMotion ? Duration.zero : null,
    animationBuilder: (context, animation, alignment, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1),
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
    final (background, foreground, icon) = switch (type) {
      NotificationType.success => (
        appColors.successContainer,
        appColors.onSuccessContainer,
        AppIcons.check,
      ),
      NotificationType.error => (colors.error, colors.onError, AppIcons.error),
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
              Icon(icon, size: AppIconSize.md, color: foreground),
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
        Text(
          message,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
        Text(tail),
      ],
    );
  }
}
