import 'package:flutter/material.dart';

import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_radius.dart';
import 'theme/tokens/app_spacing.dart';

/// Compact stat display: value + label, with optional icon and tap.
///
/// Two visual modes:
///   - With [icon] and [color] — icon sits above the value (home dashboard).
///   - Without — plain value/label in a bordered container (profile stats).
class StatCard extends StatelessWidget {
  const StatCard({
    required this.value,
    required this.label,
    this.icon,
    this.color,
    this.onTap,
    super.key,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;
    final accentColor = color ?? cs.onSurface;

    if (icon != null) {
      return Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.md,
              horizontal: AppSpacing.sm,
            ),
            child: Column(
              children: [
                Icon(icon, color: accentColor),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  value,
                  style: text.headlineSmall.copyWith(color: accentColor),
                ),
                Text(label, style: text.bodySmall),
              ],
            ),
          ),
        ),
      );
    }

    final cardColor = Theme.of(context).cardTheme.color ?? cs.surface;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outline.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: text.titleMedium.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: text.labelSmall.copyWith(
              fontWeight: FontWeight.w400,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}
