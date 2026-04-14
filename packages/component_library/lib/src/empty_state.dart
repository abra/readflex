import 'package:flutter/material.dart';

import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_spacing.dart';

/// Placeholder shown when a list or screen has no content.
///
/// Three levels of detail:
///   1. `EmptyState(message: '...')` — plain centered text.
///   2. Add [icon] — shows the icon inside a tinted circle above the message.
///   3. Add [subtitle] — secondary hint below the message.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.message,
    this.icon,
    this.subtitle,
    super.key,
  });

  final String message;
  final IconData? icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 24,
                color: colors.onSurfaceVariant,
              ),
            ),
          if (icon != null) const SizedBox(height: AppSpacing.md),
          Text(message, style: text.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle!,
              style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
