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
    return ActionBottomSheetLayout(
      title: l10n.libraryDisplayTitle,
      onClose: () => Navigator.of(context).pop(),
      closeLabel: l10n.commonClose,
      constrainBody: true,
      headerSpacing: AppSpacing.sm,
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
              const SizedBox(height: AppSpacing.sm),
              BlocBuilder<LibraryLayoutCubit, LibraryLayoutMode>(
                builder: (context, mode) => _DisplaySelector(
                  selected: mode,
                  onChanged: context.read<LibraryLayoutCubit>().setLayoutMode,
                  options: [
                    (
                      value: LibraryLayoutMode.list,
                      label: l10n.libraryDisplayList,
                      icon: AppIcons.viewList,
                    ),
                    (
                      value: LibraryLayoutMode.grid,
                      label: l10n.libraryDisplayGrid,
                      icon: AppIcons.viewGrid,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SheetSectionLabel(l10n.libraryDisplayAppearance),
              const SizedBox(height: AppSpacing.sm),
              BlocBuilder<LibraryThemeCubit, ThemeMode>(
                builder: (context, mode) => _DisplaySelector(
                  selected: mode,
                  onChanged: context.read<LibraryThemeCubit>().setThemeMode,
                  options: [
                    (
                      value: ThemeMode.system,
                      label: l10n.libraryThemeSystem,
                      icon: null,
                    ),
                    (
                      value: ThemeMode.light,
                      label: l10n.libraryThemeLight,
                      icon: null,
                    ),
                    (
                      value: ThemeMode.dark,
                      label: l10n.libraryThemeDark,
                      icon: null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _LanguagePickerRow(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Measure only the option labels. Stack rather than truncate localized
/// options or reduce the user's text scale.
class _DisplaySelector<T> extends StatelessWidget {
  const _DisplaySelector({
    required this.selected,
    required this.onChanged,
    required this.options,
  });

  final T selected;
  final ValueChanged<T> onChanged;
  final List<({T value, String label, IconData? icon})> options;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final style = context.text.bodyMedium;
      var widest = 0.0;
      for (final option in options) {
        final painter = TextPainter(
          text: TextSpan(text: option.label, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final width =
            painter.width +
            AppSpacing.lg * 2 +
            (option.icon == null ? 0 : AppIconSize.sm + AppSpacing.sm);
        if (width > widest) widest = width;
        painter.dispose();
      }
      if (widest * options.length > constraints.maxWidth) {
        return Column(
          children: [
            for (final option in options)
              ListTile(
                selected: selected == option.value,
                selectedColor: _selectedForeground(context),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                ),
                leading: option.icon == null
                    ? null
                    : Icon(option.icon, size: AppIconSize.sm),
                title: Text(option.label),
                trailing: selected == option.value
                    ? const Icon(AppIcons.check, size: AppIconSize.sm)
                    : null,
                onTap: () => onChanged(option.value),
              ),
          ],
        );
      }
      return SegmentedButton<T>(
        segments: [
          for (final option in options)
            ButtonSegment(
              value: option.value,
              label: Text(option.label),
              icon: option.icon == null
                  ? null
                  : Icon(option.icon, size: AppIconSize.sm),
            ),
        ],
        selected: {selected},
        onSelectionChanged: (values) => onChanged(values.single),
        showSelectedIcon: false,
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(style),
          minimumSize: const WidgetStatePropertyAll(
            Size(0, AppSizes.buttonHeight),
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
            ),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? _selectedForeground(context)
                : context.colors.onSurfaceVariant,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? context.colors.primary.withValues(alpha: 0.08)
                : context.colors.surface,
          ),
        ),
      );
    },
  );
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
            final labelStyle = DefaultTextStyle.of(context).style;
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
            final label = Text(context.l10n.libraryDisplayLanguage);
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

Color _selectedForeground(BuildContext context) => context.actionForeground;

class _SheetSectionLabel extends StatelessWidget {
  const _SheetSectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: context.text.labelLarge.copyWith(
      color: context.colors.onSurfaceVariant,
    ),
  );
}
