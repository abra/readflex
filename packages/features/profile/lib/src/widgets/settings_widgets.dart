part of '../profile_screen.dart';

// ─── Section Label ─────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;

    return Text(
      label,
      style: context.text.labelSmall.copyWith(
        color: cs.onSurface.withValues(alpha: 0.55),
        letterSpacing: 1,
      ),
    );
  }
}

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

// ─── Settings Group / Row ──────────────────────────────────

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final cardColor = Theme.of(context).cardTheme.color ?? cs.surface;
    final divider = context.appColors.divider;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outline.withValues(alpha: 0.45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(height: 1, thickness: 1, color: divider),
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    this.detail,
    this.onTap,
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
            // Only show chevron when the row is actually navigable.
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
