import 'package:flutter/material.dart';

import 'app_busy_button_label.dart';
import 'app_button_label.dart';
import 'state_icon_frame.dart';
import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_spacing.dart';

/// Centered failure state for a screen, panel or list body.
///
/// Retry is always the filled primary command. An optional [secondaryLabel]
/// adds an outlined exit beside it (for example "Go back" when the reader
/// cannot open a source). [busy] keeps the button geometry while a retry is
/// in flight and blocks duplicate taps. Inline sheet messages that sit above
/// other content use `AppStatusMessage` instead.
class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    this.title,
    this.icon,
    this.secondaryLabel,
    this.onSecondary,
    this.busy = false,
    super.key,
  }) : assert(
         (secondaryLabel == null) == (onSecondary == null),
         'secondaryLabel and onSecondary must be provided together.',
       );

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;
  final String? title;
  final IconData? icon;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final retry = FilledButton(
      onPressed: busy ? null : onRetry,
      child: AppBusyButtonLabel(retryLabel, busy: busy),
    );
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              StateIconFrame(icon: icon!, color: colors.error),
              const SizedBox(height: AppSpacing.md),
            ],
            if (title != null) ...[
              Text(
                title!,
                style: text.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            Text(
              message,
              style: title == null
                  ? text.bodyMedium
                  : text.bodyMedium.copyWith(color: colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            if (secondaryLabel == null)
              retry
            else
              // Secondary leads in a row (like AppSheetActions); when the
              // pair wraps, the filled Retry comes first in the stack.
              LayoutBuilder(
                builder: (context, constraints) => _ErrorActions(
                  maxWidth: constraints.maxWidth,
                  primaryLabel: retryLabel,
                  secondaryLabel: secondaryLabel!,
                  primary: retry,
                  secondary: OutlinedButton(
                    onPressed: busy ? null : onSecondary,
                    child: AppButtonLabel(secondaryLabel!),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Lays the pair side by side when both labels fit, otherwise stacks them
/// primary-first. Measures only the two labels.
class _ErrorActions extends StatelessWidget {
  const _ErrorActions({
    required this.maxWidth,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.primary,
    required this.secondary,
  });

  final double maxWidth;
  final String primaryLabel;
  final String secondaryLabel;
  final Widget primary;
  final Widget secondary;

  @override
  Widget build(BuildContext context) {
    final labelWidth = (maxWidth - AppSpacing.md) / 2 - AppSpacing.lg * 2;
    var stacked = false;
    for (final label in [primaryLabel, secondaryLabel]) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: context.text.labelLarge),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      stacked |= painter.width > labelWidth;
      painter.dispose();
    }
    if (stacked) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          primary,
          const SizedBox(height: AppSpacing.sm),
          secondary,
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        secondary,
        const SizedBox(width: AppSpacing.md),
        primary,
      ],
    );
  }
}
