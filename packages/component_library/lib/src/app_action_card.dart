import 'package:flutter/material.dart';

import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_icon_size.dart';
import 'theme/tokens/app_radius.dart';
import 'theme/tokens/app_sizes.dart';
import 'theme/tokens/app_spacing.dart';

/// Large tappable action row used in sheets and detail screens.
class AppActionCard extends StatelessWidget {
  const AppActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;
    final enabled = onTap != null;
    final foreground = enabled
        ? cs.onSurface
        : cs.onSurface.withValues(alpha: 0.42);
    final muted = enabled
        ? cs.onSurface.withValues(alpha: 0.55)
        : cs.onSurface.withValues(alpha: 0.36);
    final primary = enabled ? cs.primary : cs.onSurface.withValues(alpha: 0.28);

    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: enabled ? 0.6 : 0.36),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: enabled ? 0.10 : 0.08),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: text.bodyMedium.copyWith(
                        fontWeight: FontWeight.w500,
                        color: foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: text.labelSmall.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.md),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact vertical action tile for horizontal action groups.
class AppActionTile extends StatelessWidget {
  const AppActionTile({
    required this.icon,
    required this.title,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;
    final enabled = onTap != null;
    final foreground = enabled
        ? cs.onSurface
        : cs.onSurface.withValues(alpha: 0.42);
    final primary = enabled ? cs.primary : cs.onSurface.withValues(alpha: 0.28);

    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: enabled ? 0.6 : 0.36),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: AppSizes.iconButtonSize,
                height: AppSizes.iconButtonSize,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: enabled ? 0.10 : 0.08),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: AppIconSize.xs, color: primary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelMedium.copyWith(
                  fontWeight: FontWeight.w500,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
