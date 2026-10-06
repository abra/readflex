import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

const _pickerPadding = AppSpacing.xxs;
const _pickerIconGap = AppSpacing.xs;

class TranslationLanguageDirection extends StatelessWidget {
  const TranslationLanguageDirection({
    required this.sourceLanguageCode,
    required this.targetLanguageCode,
    required this.detectedSourceLanguage,
    required this.enabled,
    required this.sourceMenu,
    required this.onSourceChanged,
    required this.onTargetChanged,
    super.key,
  });

  final String sourceLanguageCode;
  final String targetLanguageCode;
  final String? detectedSourceLanguage;
  final bool enabled;
  final MenuController sourceMenu;
  final ValueChanged<String> onSourceChanged;
  final ValueChanged<String> onTargetChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final detected = translationLanguageName(detectedSourceLanguage);
    final sourceLabel = sourceLanguageCode == autoSourceLanguageCode
        ? detected ?? l10n.translationAutoSource
        : translationLanguageName(sourceLanguageCode)!;
    final targetLabel = translationLanguageName(targetLanguageCode)!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final sourceWidth = _labelWidth(context, sourceLabel, flushStart: true);
        final targetWidth = _labelWidth(context, targetLabel);
        final stacked =
            sourceWidth + targetWidth + AppIconSize.sm + 2 * AppSpacing.xs >
            constraints.maxWidth;
        final source = SizedBox(
          width: math.min(sourceWidth, constraints.maxWidth),
          child: _LanguageMenu(
            buttonKey: const ValueKey('translation-source-language'),
            controller: sourceMenu,
            semanticsLabel: l10n.translationSourceLanguage,
            label: sourceLabel,
            semanticsValue:
                sourceLanguageCode == autoSourceLanguageCode && detected != null
                ? l10n.translationAutoDetectedSource(detected)
                : sourceLabel,
            selectedCode: sourceLanguageCode,
            enabled: enabled,
            includeAuto: true,
            flushStart: true,
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
                      horizontal: AppSpacing.xs,
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

double _labelWidth(
  BuildContext context,
  String label, {
  bool flushStart = false,
}) {
  // Measure only the two labels, including system scaling, to avoid clipped
  // language names or a stranded direction arrow when the controls wrap.
  final painter = TextPainter(
    text: TextSpan(text: label, style: context.text.bodySmall),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width =
      painter.width.ceilToDouble() +
      (flushStart ? 1 : 2) * _pickerPadding +
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
    this.flushStart = false,
    this.semanticsValue,
  });

  final Key buttonKey;
  final String semanticsLabel;
  final String label;
  final String selectedCode;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final MenuController? controller;
  final bool includeAuto;

  /// Drops the leading ink inset so the label starts on the row's edge; the
  /// trailing inset stays so the ink still clears the chevron.
  final bool flushStart;
  final String? semanticsValue;

  @override
  Widget build(BuildContext context) {
    const options = ReadflexSupportedLocales.languages;
    final menuWidth = math.min(
      360.0,
      MediaQuery.sizeOf(context).width - 2 * AppSpacing.xl,
    );
    final cellWidth = (menuWidth - AppSpacing.sm) / 2;
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.localeOf(context),
    );
    var widest = 0.0;
    for (final option in options) {
      painter.text = TextSpan(
        text: option.name,
        style: context.text.bodyMedium,
      );
      painter.layout();
      widest = math.max(widest, painter.width);
    }
    painter.dispose();
    final twoColumns =
        widest + 2 * AppSpacing.sm + AppIconSize.sm + AppSpacing.xs <=
        cellWidth;

    Widget item(String code, String name) => MenuItemButton(
      onPressed: enabled ? () => onChanged(code) : null,
      style: MenuItemButton.styleFrom(
        minimumSize: const Size(0, AppSizes.buttonHeight),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        textStyle: context.text.bodyMedium,
      ),
      trailingIcon: SizedBox.square(
        dimension: AppIconSize.sm,
        child: code == selectedCode
            ? const Icon(AppIcons.check, size: AppIconSize.sm)
            : null,
      ),
      child: Semantics(selected: code == selectedCode, child: Text(name)),
    );
    return MenuAnchor(
      controller: controller,
      style: MenuStyle(
        minimumSize: WidgetStatePropertyAll(Size(menuWidth, 0)),
        maximumSize: WidgetStatePropertyAll(Size(menuWidth, double.infinity)),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(AppSpacing.xs)),
      ),
      menuChildren: [
        if (includeAuto) ...[
          item(autoSourceLanguageCode, context.l10n.translationAutoSource),
          const Divider(height: 1),
        ],
        // A fixed small option set uses natural row heights. MenuAnchor owns
        // scrolling; large text falls back to one column without tiny targets.
        if (twoColumns)
          for (var i = 0; i < options.length; i += 2)
            Row(
              children: [
                Expanded(child: item(options[i].code, options[i].name)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: i + 1 < options.length
                      ? item(options[i + 1].code, options[i + 1].name)
                      : const SizedBox.shrink(),
                ),
              ],
            )
        else
          for (final option in options) item(option.code, option.name),
      ],
      builder: (context, menu, child) {
        void toggle() => menu.isOpen ? menu.close() : menu.open();
        return Semantics(
          label: semanticsLabel,
          value: semanticsValue ?? label,
          button: true,
          enabled: enabled,
          excludeSemantics: true,
          onTap: enabled ? toggle : null,
          child: TextButton(
            key: buttonKey,
            onPressed: enabled ? toggle : null,
            // Colours and shape come from the text-button theme; only the
            // compact label style, height and inset are picker-specific.
            style: TextButton.styleFrom(
              textStyle: context.text.bodySmall,
              minimumSize: const Size(0, AppSizes.buttonHeight),
              // Start-aligned content keeps the label on the edge when the
              // measured width rounds up; the symmetric picker stays centred.
              alignment: flushStart ? AlignmentDirectional.centerStart : null,
              padding: EdgeInsetsDirectional.only(
                start: flushStart ? 0 : _pickerPadding,
                end: _pickerPadding,
                top: AppSpacing.sm,
                bottom: AppSpacing.sm,
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
