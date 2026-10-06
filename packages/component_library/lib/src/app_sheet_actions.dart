import 'package:flutter/material.dart';

import 'app_busy_button_label.dart';
import 'app_button_label.dart';
import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_sizes.dart';
import 'theme/tokens/app_spacing.dart';

/// A primary command and a secondary exit, stacked when labels need more room.
/// Measures only two labels; never performs intrinsic layout on sheet content.
///
/// Confirmations follow a safe-default model: the filled [primaryLabel] is
/// the non-destructive choice (Cancel, Keep editing) and a destructive
/// command is the outlined [secondaryLabel] rendered in the error color via
/// [destructiveSecondary]. An accidental tap on the most prominent button
/// therefore never deletes or discards data.
class AppSheetActions extends StatelessWidget {
  const AppSheetActions({
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
    this.destructiveSecondary = false,
    this.busy = false,
    super.key,
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String secondaryLabel;
  final VoidCallback? onSecondary;
  final bool destructiveSecondary;
  final bool busy;

  /// Whether the pair stacks at [maxWidth]: a label wider than its half of
  /// the row minus the button padding. Sheets that size a step before layout
  /// (Manage collection) use the same rule to budget the second row.
  static bool stacks(
    BuildContext context, {
    required double maxWidth,
    required String primaryLabel,
    required String secondaryLabel,
  }) {
    final labelWidth = (maxWidth - AppSpacing.md) / 2 - AppSpacing.lg * 2;
    for (final label in [primaryLabel, secondaryLabel]) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: context.text.labelLarge),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final wide = painter.width > labelWidth;
      painter.dispose();
      if (wide) return true;
    }
    return false;
  }

  /// Height added by the second row when the pair stacks.
  static const double stackedExtent = AppSizes.buttonHeight + AppSpacing.sm;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stacked = stacks(
        context,
        maxWidth: constraints.maxWidth,
        primaryLabel: primaryLabel,
        secondaryLabel: secondaryLabel,
      );
      final primary = FilledButton(
        onPressed: busy ? null : onPrimary,
        child: AppBusyButtonLabel(primaryLabel, busy: busy),
      );
      final colors = context.colors;
      final secondary = OutlinedButton(
        onPressed: busy ? null : onSecondary,
        style: destructiveSecondary
            ? OutlinedButton.styleFrom(
                foregroundColor: colors.error,
                side: BorderSide(color: colors.error),
              )
            : null,
        child: AppButtonLabel(secondaryLabel),
      );
      return stacked
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                primary,
                const SizedBox(height: AppSpacing.sm),
                secondary,
              ],
            )
          : Row(
              children: [
                Expanded(child: secondary),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: primary),
              ],
            );
    },
  );
}
