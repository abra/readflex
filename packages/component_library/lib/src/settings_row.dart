import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_icon_size.dart';
import 'theme/tokens/app_spacing.dart';

/// Single row inside a [SettingsGroup]: icon, label, optional detail
/// text, and a chevron when tappable.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    required this.icon,
    required this.label,
    this.detail,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final String? detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;

    final enabled = onTap != null;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: AppIconSize.sm,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: text.bodyMedium.copyWith(color: cs.onSurface),
              ),
            ),
            if (detail != null) ...[
              Text(
                detail!,
                style: text.labelSmall.copyWith(
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            if (enabled)
              Icon(
                AppIcons.chevronRight,
                size: AppIconSize.sm,
                color: cs.onSurface.withValues(alpha: 0.3),
              ),
          ],
        ),
      ),
    );
  }
}
