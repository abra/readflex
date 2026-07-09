import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'library_layout_cubit.dart';
import 'library_locale_cubit.dart';
import 'library_theme_cubit.dart';

Future<void> showLibraryDisplaySheet({
  required BuildContext context,
  required LibraryLayoutCubit layoutCubit,
  required LibraryLocaleCubit localeCubit,
  required LibraryThemeCubit themeCubit,
}) {
  return showAppBottomSheet<void>(
    context,
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: layoutCubit),
        BlocProvider.value(value: localeCubit),
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
    final l10n = context.l10n;
    return ActionBottomSheetLayout(
      title: l10n.libraryDisplayTitle,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.64,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SheetSectionLabel(l10n.libraryDisplayView),
              const SizedBox(height: AppSpacing.xs),
              const _LayoutModeSelector(),
              const SizedBox(height: AppSpacing.lg),
              _SheetSectionLabel(l10n.libraryDisplayAppearance),
              const SizedBox(height: AppSpacing.xs),
              const _ThemeModeSelector(),
              const SizedBox(height: AppSpacing.lg),
              _SheetSectionLabel(l10n.libraryDisplayLanguage),
              const SizedBox(height: AppSpacing.xs),
              const _LanguageSelector(),
            ],
          ),
        ),
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
                title: context.l10n.libraryDisplayList,
                selected: mode == LibraryLayoutMode.list,
                onTap: () => cubit.setLayoutMode(LibraryLayoutMode.list),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _DisplayOption(
                icon: AppIcons.viewGrid,
                title: context.l10n.libraryDisplayGrid,
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
        final l10n = context.l10n;
        return Column(
          children: [
            _DisplayOption(
              icon: AppIcons.deviceMode,
              title: l10n.libraryThemeSystem,
              subtitle: l10n.libraryThemeSystemDescription,
              selected: mode == ThemeMode.system,
              onTap: () => cubit.setThemeMode(ThemeMode.system),
            ),
            const SizedBox(height: AppSpacing.xs),
            _DisplayOption(
              icon: AppIcons.lightMode,
              title: l10n.libraryThemeLight,
              subtitle: l10n.libraryThemeLightDescription,
              selected: mode == ThemeMode.light,
              onTap: () => cubit.setThemeMode(ThemeMode.light),
            ),
            const SizedBox(height: AppSpacing.xs),
            _DisplayOption(
              icon: AppIcons.darkMode,
              title: l10n.libraryThemeDark,
              subtitle: l10n.libraryThemeDarkDescription,
              selected: mode == ThemeMode.dark,
              onTap: () => cubit.setThemeMode(ThemeMode.dark),
            ),
          ],
        );
      },
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryLocaleCubit, Locale>(
      builder: (context, locale) {
        final cubit = context.read<LibraryLocaleCubit>();
        final languages = ReadflexSupportedLocales.languages;
        return Column(
          children: [
            for (var index = 0; index < languages.length; index += 2) ...[
              if (index > 0) const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: _LanguageOption(
                      language: languages[index],
                      selected: locale.languageCode == languages[index].code,
                      onTap: cubit.setLocale,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: index + 1 < languages.length
                        ? _LanguageOption(
                            language: languages[index + 1],
                            selected:
                                locale.languageCode ==
                                languages[index + 1].code,
                            onTap: cubit.setLocale,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final ReadflexSupportedLanguage language;
  final bool selected;
  final ValueChanged<Locale> onTap;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: ValueKey('libraryLanguageOption-${language.code}'),
      child: _DisplayOption(
        icon: AppIcons.language,
        title: language.name,
        selected: selected,
        onTap: () => onTap(Locale(language.code)),
      ),
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
