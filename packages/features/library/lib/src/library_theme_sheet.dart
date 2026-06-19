import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'library_theme_cubit.dart';

Future<void> showLibraryThemeSheet({
  required BuildContext context,
  required LibraryThemeCubit cubit,
}) {
  return showAppBottomSheet<void>(
    context,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: const _LibraryThemeSheet(),
    ),
  );
}

class _LibraryThemeSheet extends StatelessWidget {
  const _LibraryThemeSheet();

  Future<void> _select(BuildContext context, ThemeMode mode) async {
    final cubit = context.read<LibraryThemeCubit>();
    await cubit.setThemeMode(mode);
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ActionBottomSheetLayout(
      title: 'Appearance',
      child: BlocBuilder<LibraryThemeCubit, ThemeMode>(
        builder: (context, mode) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ThemeModeOption(
                icon: AppIcons.deviceMode,
                title: 'System',
                subtitle: 'Follow device setting',
                selected: mode == ThemeMode.system,
                onTap: () => _select(context, ThemeMode.system),
              ),
              const SizedBox(height: AppSpacing.xs),
              _ThemeModeOption(
                icon: AppIcons.lightMode,
                title: 'Light',
                subtitle: 'Use light appearance',
                selected: mode == ThemeMode.light,
                onTap: () => _select(context, ThemeMode.light),
              ),
              const SizedBox(height: AppSpacing.xs),
              _ThemeModeOption(
                icon: AppIcons.darkMode,
                title: 'Dark',
                subtitle: 'Use dark appearance',
                selected: mode == ThemeMode.dark,
                onTap: () => _select(context, ThemeMode.dark),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ThemeModeOption extends StatelessWidget {
  const _ThemeModeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = selected ? colors.primary : colors.onSurface;
    final background = selected
        ? colors.primary.withValues(alpha: 0.08)
        : colors.surfaceContainerHighest.withValues(alpha: 0.4);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(icon, size: AppIconSize.md, color: foreground),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.text.titleSmall.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      style: context.text.bodySmall.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(AppIcons.check, size: AppIconSize.sm, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}
