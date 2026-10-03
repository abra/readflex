import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

class LibraryLanguageSheet extends StatelessWidget {
  const LibraryLanguageSheet({
    required this.selectedLocale,
    required this.onSelected,
    required this.onClose,
    super.key,
  });

  final Locale selectedLocale;
  final ValueChanged<Locale> onSelected;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => ActionBottomSheetLayout.scrollable(
    title: context.l10n.libraryDisplayLanguage,
    onClose: onClose,
    closeLabel: context.l10n.commonClose,
    child: _LanguageOptions(
      selectedLocale: selectedLocale,
      onSelected: onSelected,
    ),
  );
}

const _optionPadding = EdgeInsets.all(AppSpacing.md);
const _checkmarkSpace = AppSpacing.sm + AppIconSize.sm;

class _LanguageOptions extends StatelessWidget {
  const _LanguageOptions({
    required this.selectedLocale,
    required this.onSelected,
  });

  final Locale selectedLocale;
  final ValueChanged<Locale> onSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final style = context.text.bodyMedium;
      final painter = TextPainter(
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.localeOf(context),
      );
      var widestLabel = 0.0;
      for (final language in ReadflexSupportedLocales.languages) {
        painter.text = TextSpan(text: language.name, style: style);
        painter.layout();
        if (painter.width > widestLabel) widestLabel = painter.width;
      }
      painter.dispose();
      final columnWidth = (constraints.maxWidth - AppSpacing.sm) / 2;
      final fitsTwoColumns =
          widestLabel + _optionPadding.horizontal + _checkmarkSpace <=
          columnWidth;
      final width = fitsTwoColumns ? columnWidth : constraints.maxWidth;

      // Ten fixed options can use natural heights without intrinsic layout or
      // aspect-ratio tiles that clip large text. Only one viewport scrolls.
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final language in ReadflexSupportedLocales.languages)
            SizedBox(
              width: width,
              child: _LanguageOption(
                key: ValueKey('libraryLanguageOption-${language.code}'),
                language: language,
                selected: language.code == selectedLocale.languageCode,
                onPressed: () => onSelected(Locale(language.code)),
              ),
            ),
        ],
      );
    },
  );
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.language,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final ReadflexSupportedLanguage language;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? context.actionForeground
        : context.colors.onSurface;
    const radius = BorderRadius.all(Radius.circular(AppRadius.sm));
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: Material(
        color: selected
            ? context.colors.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.buttonHeight),
            child: Padding(
              padding: _optionPadding,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      language.name,
                      style: context.text.bodyMedium.copyWith(
                        color: foreground,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox.square(
                    dimension: AppIconSize.sm,
                    child: selected
                        ? Icon(
                            AppIcons.check,
                            size: AppIconSize.sm,
                            color: foreground,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
