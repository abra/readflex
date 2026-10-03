import 'package:flutter/material.dart';

import 'app_button_label.dart';
import 'button_loading_indicator.dart';
import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_spacing.dart';

/// A primary command and a secondary exit, stacked when labels need more room.
/// Measures only two labels; never performs intrinsic layout on sheet content.
class AppSheetActions extends StatelessWidget {
  const AppSheetActions({
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
    this.destructive = false,
    this.busy = false,
    super.key,
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String secondaryLabel;
  final VoidCallback? onSecondary;
  final bool destructive;
  final bool busy;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final labelWidth =
          (constraints.maxWidth - AppSpacing.md) / 2 - AppSpacing.lg * 2;
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
      final primary = FilledButton(
        onPressed: busy ? null : onPrimary,
        style: destructive
            ? FilledButton.styleFrom(
                backgroundColor: context.colors.error,
                foregroundColor: context.colors.onError,
              )
            : null,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Visibility(
              visible: !busy,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: AppButtonLabel(primaryLabel),
            ),
            if (busy)
              Semantics(
                label: primaryLabel,
                liveRegion: true,
                child: const ButtonLoadingIndicator(),
              ),
          ],
        ),
      );
      final secondary = OutlinedButton(
        onPressed: busy ? null : onSecondary,
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
