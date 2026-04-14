part of '../profile_screen.dart';

// ─── Theme Row ─────────────────────────────────────────────

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({required this.themeMode, required this.onChanged});

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ThemeButton(
          label: 'Light',
          icon: AppIcons.lightMode,
          active: themeMode == ThemeMode.light,
          onTap: () => onChanged(ThemeMode.light),
        ),
        const SizedBox(width: AppSpacing.sm),
        _ThemeButton(
          label: 'Dark',
          icon: AppIcons.darkMode,
          active: themeMode == ThemeMode.dark,
          onTap: () => onChanged(ThemeMode.dark),
        ),
        const SizedBox(width: AppSpacing.sm),
        _ThemeButton(
          label: 'Auto',
          icon: AppIcons.systemMode,
          active: themeMode == ThemeMode.system,
          onTap: () => onChanged(ThemeMode.system),
        ),
      ],
    );
  }
}

class _ThemeButton extends StatelessWidget {
  const _ThemeButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;

    return Expanded(
      child: Material(
        color: active ? cs.onSurface : cs.secondary.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: AppIconSize.sm,
                  color: active
                      ? cs.surface
                      : cs.onSurface.withValues(alpha: 0.55),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  label,
                  style: context.text.labelSmall.copyWith(
                    fontWeight: FontWeight.w500,
                    color: active
                        ? cs.surface
                        : cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
