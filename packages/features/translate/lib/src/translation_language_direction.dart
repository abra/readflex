import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

const _pickerPadding = AppSpacing.sm;
const _pickerIconGap = AppSpacing.sm;

class TranslationLanguageDirection extends StatelessWidget {
  const TranslationLanguageDirection({
    required this.sourceLanguageCode,
    required this.targetLanguageCode,
    required this.detectedSourceLanguage,
    required this.enabled,
    required this.sourceMenu,
    required this.sourcePickerKey,
    required this.onSourceChanged,
    required this.onTargetChanged,
    super.key,
  });

  final String sourceLanguageCode;
  final String targetLanguageCode;
  final String? detectedSourceLanguage;
  final bool enabled;
  final MenuController sourceMenu;
  final GlobalKey sourcePickerKey;
  final ValueChanged<String> onSourceChanged;
  final ValueChanged<String> onTargetChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final detected = translationLanguageName(detectedSourceLanguage);
    final sourceLabel = sourceLanguageCode == autoSourceLanguageCode
        ? detected == null
              ? l10n.translationAutoSource
              : l10n.translationAutoDetectedSource(detected)
        : translationLanguageName(sourceLanguageCode)!;
    final targetLabel = translationLanguageName(targetLanguageCode)!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final sourceWidth = _labelWidth(context, sourceLabel);
        final targetWidth = _labelWidth(context, targetLabel);
        final stacked =
            sourceWidth + targetWidth + AppIconSize.sm + 2 * AppSpacing.sm >
            constraints.maxWidth;
        final source = SizedBox(
          width: math.min(sourceWidth, constraints.maxWidth),
          child: _LanguageMenu(
            key: sourcePickerKey,
            buttonKey: const ValueKey('translation-source-language'),
            controller: sourceMenu,
            semanticsLabel: l10n.translationSourceLanguage,
            label: sourceLabel,
            selectedCode: sourceLanguageCode,
            enabled: enabled,
            includeAuto: true,
            onChanged: onSourceChanged,
          ),
        );
        final target = SizedBox(
          width: math.min(targetWidth, constraints.maxWidth),
          child: _LanguageMenu(
            buttonKey: const ValueKey('translation-target-language'),
            semanticsLabel: l10n.translationTargetLanguage,
            label: targetLabel,
            selectedCode: targetLanguageCode,
            enabled: enabled,
            onChanged: onTargetChanged,
          ),
        );
        final arrow = ExcludeSemantics(
          child: Transform.flip(
            flipX: !stacked && Directionality.of(context) == TextDirection.rtl,
            child: Icon(
              stacked ? AppIcons.arrowDown : AppIcons.arrowRight,
              key: const ValueKey('translation-direction-arrow'),
              color: context.colors.onSurfaceVariant,
              size: AppIconSize.sm,
            ),
          ),
        );
        return stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  source,
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: arrow,
                  ),
                  target,
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  source,
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: arrow,
                  ),
                  target,
                ],
              );
      },
    );
  }
}

double _labelWidth(BuildContext context, String label) {
  // Measure only the two labels, including system scaling, to avoid clipped
  // language names or a stranded direction arrow when the controls wrap.
  final painter = TextPainter(
    text: TextSpan(text: label, style: context.text.bodyMedium),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width =
      painter.width.ceilToDouble() +
      2 * _pickerPadding +
      _pickerIconGap +
      AppIconSize.xs;
  painter.dispose();
  return math.max(AppSizes.buttonHeight, width);
}

class _LanguageMenu extends StatelessWidget {
  const _LanguageMenu({
    required this.buttonKey,
    required this.semanticsLabel,
    required this.label,
    required this.selectedCode,
    required this.enabled,
    required this.onChanged,
    this.controller,
    this.includeAuto = false,
    super.key,
  });

  final Key buttonKey;
  final String semanticsLabel;
  final String label;
  final String selectedCode;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final MenuController? controller;
  final bool includeAuto;

  @override
  Widget build(BuildContext context) {
    final options = [
      if (includeAuto)
        (
          code: autoSourceLanguageCode,
          name: context.l10n.translationAutoSource,
        ),
      ...ReadflexSupportedLocales.languages,
    ];
    return MenuAnchor(
      controller: controller,
      menuChildren: [
        for (final option in options)
          MenuItemButton(
            onPressed: enabled ? () => onChanged(option.code) : null,
            leadingIcon: SizedBox(
              width: AppIconSize.sm,
              child: option.code == selectedCode
                  ? const Icon(AppIcons.check, size: AppIconSize.sm)
                  : null,
            ),
            child: Semantics(
              selected: option.code == selectedCode,
              child: Text(option.name),
            ),
          ),
      ],
      builder: (context, menu, child) {
        void toggle() => menu.isOpen ? menu.close() : menu.open();
        return Semantics(
          label: semanticsLabel,
          value: label,
          button: true,
          enabled: enabled,
          excludeSemantics: true,
          onTap: enabled ? toggle : null,
          child: TextButton(
            key: buttonKey,
            onPressed: enabled ? toggle : null,
            style: TextButton.styleFrom(
              foregroundColor: context.colors.brightness == Brightness.dark
                  ? context.colors.onSurface
                  : context.colors.primary,
              backgroundColor: Colors.transparent,
              textStyle: context.text.bodyMedium,
              minimumSize: const Size(0, AppSizes.buttonHeight),
              padding: const EdgeInsets.symmetric(
                horizontal: _pickerPadding,
                vertical: AppSpacing.sm,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(label)),
                const SizedBox(width: _pickerIconGap),
                const Icon(AppIcons.chevronDown, size: AppIconSize.xs),
              ],
            ),
          ),
        );
      },
    );
  }
}

String? translationLanguageName(String? code) {
  if (code == null || code.isEmpty) return null;
  final normalized = code.toLowerCase().split(RegExp(r'[-_]')).first;
  for (final language in ReadflexSupportedLocales.languages) {
    if (language.code == normalized) return language.name;
  }
  return normalized.toUpperCase();
}
