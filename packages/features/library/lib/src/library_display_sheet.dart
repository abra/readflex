import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'library_layout_cubit.dart';
import 'library_theme_cubit.dart';

Future<void> showLibraryDisplaySheet({
  required BuildContext context,
  required LibraryLayoutCubit layoutCubit,
  required LibraryThemeCubit themeCubit,
}) {
  return showAppBottomSheet<void>(
    context,
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: layoutCubit),
        BlocProvider.value(value: themeCubit),
      ],
      child: const _LibraryDisplaySheet(),
    ),
  );
}

class _LibraryDisplaySheet extends StatelessWidget {
  const _LibraryDisplaySheet();

  @override
  Widget build(BuildContext context) {
    return ActionBottomSheetLayout(
      title: 'Display',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          _SheetSectionLabel('View'),
          SizedBox(height: AppSpacing.xs),
          _LayoutModeSelector(),
          SizedBox(height: AppSpacing.lg),
          _SheetSectionLabel('Appearance'),
          SizedBox(height: AppSpacing.xs),
          _ThemeModeSelector(),
        ],
      ),
    );
  }
}

class _LayoutModeSelector extends StatelessWidget {
  const _LayoutModeSelector();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryLayoutCubit, LibraryLayoutMode>(
      builder: (context, mode) {
        final cubit = context.read<LibraryLayoutCubit>();
        return Row(
          children: [
            Expanded(
              child: _DisplayOption(
                icon: AppIcons.viewList,
                title: 'List',
                selected: mode == LibraryLayoutMode.list,
                onTap: () => cubit.setLayoutMode(LibraryLayoutMode.list),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _DisplayOption(
                icon: AppIcons.viewGrid,
                title: 'Grid',
                selected: mode == LibraryLayoutMode.grid,
                onTap: () => cubit.setLayoutMode(LibraryLayoutMode.grid),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryThemeCubit, ThemeMode>(
      builder: (context, mode) {
        final cubit = context.read<LibraryThemeCubit>();
        return Column(
          children: [
            _DisplayOption(
              icon: AppIcons.deviceMode,
              title: 'System',
              subtitle: 'Follow device setting',
              selected: mode == ThemeMode.system,
              onTap: () => cubit.setThemeMode(ThemeMode.system),
            ),
            const SizedBox(height: AppSpacing.xs),
            _DisplayOption(
              icon: AppIcons.lightMode,
              title: 'Light',
              subtitle: 'Use light appearance',
              selected: mode == ThemeMode.light,
              onTap: () => cubit.setThemeMode(ThemeMode.light),
            ),
            const SizedBox(height: AppSpacing.xs),
            _DisplayOption(
              icon: AppIcons.darkMode,
              title: 'Dark',
              subtitle: 'Use dark appearance',
              selected: mode == ThemeMode.dark,
              onTap: () => cubit.setThemeMode(ThemeMode.dark),
            ),
          ],
        );
      },
    );
  }
}

class _SheetSectionLabel extends StatelessWidget {
  const _SheetSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.text.labelSmall.copyWith(
        color: context.colors.onSurface.withValues(alpha: 0.55),
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _DisplayOption extends StatelessWidget {
  const _DisplayOption({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
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
