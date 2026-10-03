import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'library_language_sheet.dart';
import 'library_layout_cubit.dart';
import 'library_locale_cubit.dart';
import 'library_theme_cubit.dart';

Future<void> showLibraryDisplaySheet({
  required BuildContext context,
  required LibraryLayoutCubit layoutCubit,
  required LibraryLocaleCubit localeCubit,
  required LibraryThemeCubit themeCubit,
}) => showAppBottomSheet<void>(
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

class _LibraryDisplaySheet extends StatelessWidget {
  const _LibraryDisplaySheet();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ActionBottomSheetLayout.scrollable(
      title: l10n.libraryDisplayTitle,
      onClose: () => Navigator.of(context).pop(),
      closeLabel: l10n.commonClose,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSettingsSection(
            title: l10n.libraryDisplayView,
            child: BlocBuilder<LibraryLayoutCubit, LibraryLayoutMode>(
              builder: (context, mode) => AppChoiceControl(
                selected: mode,
                onChanged: context.read<LibraryLayoutCubit>().setLayoutMode,
                options: [
                  AppChoiceOption(
                    value: LibraryLayoutMode.list,
                    label: l10n.libraryDisplayList,
                    icon: AppIcons.viewList,
                  ),
                  AppChoiceOption(
                    value: LibraryLayoutMode.grid,
                    label: l10n.libraryDisplayGrid,
                    icon: AppIcons.viewGrid,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSettingsSection(
            title: l10n.libraryDisplayAppearance,
            child: BlocBuilder<LibraryThemeCubit, ThemeMode>(
              builder: (context, mode) => AppChoiceControl(
                selected: mode,
                onChanged: context.read<LibraryThemeCubit>().setThemeMode,
                options: [
                  AppChoiceOption(
                    value: ThemeMode.system,
                    label: l10n.libraryThemeSystem,
                  ),
                  AppChoiceOption(
                    value: ThemeMode.light,
                    label: l10n.libraryThemeLight,
                  ),
                  AppChoiceOption(
                    value: ThemeMode.dark,
                    label: l10n.libraryThemeDark,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _LanguagePickerRow(),
        ],
      ),
    );
  }
}

class _LanguagePickerRow extends StatelessWidget {
  const _LanguagePickerRow();

  @override
  Widget build(BuildContext context) => BlocBuilder<LibraryLocaleCubit, Locale>(
    builder: (context, locale) {
      final language = ReadflexSupportedLocales.languages.firstWhere(
        (item) => item.code == locale.languageCode,
      );
      return ListTile(
        key: const ValueKey('libraryLanguagePicker'),
        contentPadding: EdgeInsets.zero,
        title: LayoutBuilder(
          builder: (context, constraints) {
            final direction = Directionality.of(context);
            final labelStyle = context.text.bodyMedium;
            final valueStyle = context.text.bodyMedium.copyWith(
              color: context.colors.onSurfaceVariant,
            );
            var width = AppSpacing.md + AppSpacing.sm + AppIconSize.sm;
            for (final (text, style) in [
              (context.l10n.libraryDisplayLanguage, labelStyle),
              (language.name, valueStyle),
            ]) {
              final painter = TextPainter(
                text: TextSpan(text: text, style: style),
                textDirection: direction,
                textScaler: MediaQuery.textScalerOf(context),
              )..layout();
              width += painter.width;
              painter.dispose();
            }
            final label = Text(
              context.l10n.libraryDisplayLanguage,
              style: labelStyle,
            );
            final value = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(language.name, style: valueStyle)),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  direction == TextDirection.rtl
                      ? AppIcons.chevronLeft
                      : AppIcons.chevronRight,
                  size: AppIconSize.sm,
                ),
              ],
            );
            if (width > constraints.maxWidth) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  label,
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: value,
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: label),
                const SizedBox(width: AppSpacing.md),
                value,
              ],
            );
          },
        ),
        onTap: () async {
          final cubit = context.read<LibraryLocaleCubit>();
          final selected = await showAppBottomSheet<Locale>(
            context,
            builder: (context) => LibraryLanguageSheet(
              selectedLocale: locale,
              onSelected: (value) => Navigator.of(context).pop(value),
              onClose: () => Navigator.of(context).pop(),
            ),
          );
          if (selected != null && context.mounted) cubit.setLocale(selected);
        },
      );
    },
  );
}
