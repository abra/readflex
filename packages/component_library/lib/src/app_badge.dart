import 'package:flutter/material.dart';

import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_radius.dart';
import 'theme/tokens/app_spacing.dart';

/// Small colored label badge (e.g. "Mastered", "PRO", "New").
///
/// Renders as a compact rounded container with tinted background and
/// foreground-colored text.
class AppBadge extends StatelessWidget {
  const AppBadge({
    required this.label,
    required this.foreground,
    required this.background,
    super.key,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        label,
        style: context.text.labelSmall.copyWith(
          fontWeight: FontWeight.w500,
          color: foreground,
        ),
      ),
    );
  }
}
