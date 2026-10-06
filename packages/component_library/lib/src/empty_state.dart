import 'package:flutter/material.dart';

import 'state_icon_frame.dart';
import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_spacing.dart';

/// Placeholder shown when a list or screen has no content.
///
/// Three levels of detail:
///   1. `EmptyState(message: '...')` — plain centered text.
///   2. Add [icon] — shows the icon inside a tinted circle above the message.
///   3. Add [subtitle] — secondary hint below the message.
///
/// [compact] uses `bodyMedium` in `onSurfaceVariant` for the message so a
/// short placeholder inside a sheet list or reader side panel reads as a
/// hint, not a heading. Screen-level empty states keep the default
/// `titleMedium`.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.message,
    this.icon,
    this.subtitle,
    this.action,
    this.compact = false,
    super.key,
  });

  final String message;
  final IconData? icon;
  final String? subtitle;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              StateIconFrame(icon: icon!, color: colors.onSurfaceVariant),
              const SizedBox(height: AppSpacing.md),
            ],
            Text(
              message,
              style: compact
                  ? text.bodyMedium.copyWith(color: colors.onSurfaceVariant)
                  : text.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle!,
                style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.md),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
