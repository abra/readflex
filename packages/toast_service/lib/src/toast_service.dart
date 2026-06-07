import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

enum NotificationType { success, error }

/// Shows a top-anchored toast that slides down from the status bar and
/// auto-dismisses after 3 seconds. Type-driven coloring/icon comes from
/// `ToastificationStyle.flat` so a feature package only chooses success
/// vs error and never touches presentation.
///
/// Corner radius matches `AppRadius.lg` (the rounded-card scale used in
/// elevated UI). The horizontal inset is set on [ToastWrapper] via
/// `ToastificationConfig.itemWidth` so it lines up with the rest of the
/// app's body padding regardless of screen size.
///
/// Pass [messageSuffix] when the message has a fixed verb at the end
/// that must always remain visible (e.g. `"long title" deleted`): the
/// [message] then ellipsises within the available width while the
/// suffix is rendered intact.
void showToast(
  BuildContext context, {
  required NotificationType type,
  required String message,
  String? messageSuffix,
}) {
  toastification.show(
    context: context,
    type: switch (type) {
      NotificationType.success => ToastificationType.success,
      NotificationType.error => ToastificationType.error,
    },
    // `fillColored` paints the whole pill in the type's accent (green
    // for success, red for error) instead of the flat-style off-white
    // with a thin colored stripe — reads more decisively as feedback
    // on top of varied library content.
    style: ToastificationStyle.fillColored,
    title: messageSuffix == null
        ? Text(message)
        : _SplitToastTitle(message: message, suffix: messageSuffix),
    autoCloseDuration: const Duration(seconds: 3),
    alignment: Alignment.topCenter,
    borderRadius: BorderRadius.circular(AppRadius.lg),
    margin: EdgeInsets.zero,
    // Soft Material 3-ish elevation: small ambient layer + a longer
    // directional layer below. Alpha is kept conservative so it reads
    // as "lifted" in light mode without painting a black halo on dark.
    boxShadow: const [
      BoxShadow(
        color: Color(0x14000000),
        blurRadius: 4,
        offset: Offset(0, 2),
      ),
      BoxShadow(
        color: Color(0x1F000000),
        blurRadius: 16,
        offset: Offset(0, 8),
      ),
    ],
    animationBuilder: (context, animation, alignment, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      );
    },
  );
}

/// Title widget for toasts whose message has a fixed verb tail. The
/// flexible body ellipsises within the toast width while the suffix is
/// rendered as-is, so phrases like `"<long title>" deleted` never lose
/// the verb to a mid-sentence ellipsis.
class _SplitToastTitle extends StatelessWidget {
  const _SplitToastTitle({required this.message, required this.suffix});

  final String message;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            message,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
        Text(suffix, maxLines: 1, softWrap: false),
      ],
    );
  }
}
