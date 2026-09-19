import 'package:component_library/component_library.dart';
import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'translation_source_quote.dart';
import 'translation_text_direction.dart';

class TranslationLexicalHeader extends StatelessWidget {
  const TranslationLexicalHeader({
    required this.selectedText,
    required this.isSingleWord,
    this.analysis,
    super.key,
  });

  final String selectedText;
  final bool isSingleWord;
  final ContextualTranslationAnalysis? analysis;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sourceDirection = translationTextDirection(selectedText);
    // Older providers can analyze a whole expression instead of the selection.
    final matchesSelection =
        _normalized(analysis?.surfaceForm) == _normalized(selectedText);
    final pronunciation = matchesSelection && isSingleWord
        ? _nonBlank(analysis?.pronunciation)
        : null;
    final reading = matchesSelection && isSingleWord
        ? _nonBlank(analysis?.reading)
        : null;
    final partOfSpeech = matchesSelection && isSingleWord
        ? _partOfSpeechLabel(l10n, analysis?.partOfSpeech)
        : null;
    final lemma = _nonBlank(analysis?.lemma);
    final showLemma =
        lemma != null && _normalized(lemma) != _normalized(selectedText);
    final secondaryStyle = context.text.bodyMedium.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    final selected = Text(
      selectedText,
      key: const ValueKey('translation-selected-fragment'),
      textDirection: sourceDirection,
      style: (isSingleWord ? context.text.titleLarge : context.text.bodyMedium)
          .copyWith(color: context.colors.onSurface),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isSingleWord)
          Semantics(header: true, child: selected)
        else
          TranslationSourceQuote(
            textDirection: sourceDirection,
            child: selected,
          ),
        if (pronunciation != null ||
            reading != null ||
            partOfSpeech != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            textDirection: sourceDirection,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              if (reading != null &&
                  _normalized(reading) != _normalized(selectedText))
                Text(
                  reading,
                  key: const ValueKey('translation-reading'),
                  textDirection: translationTextDirection(reading),
                  style: secondaryStyle,
                ),
              if (pronunciation != null &&
                  _normalized(pronunciation) != _normalized(reading))
                Text(
                  pronunciation,
                  key: const ValueKey('translation-pronunciation'),
                  textDirection: TextDirection.ltr,
                  style: secondaryStyle.copyWith(
                    fontFamily: AppTypography.fontFamilyPhonetic,
                  ),
                ),
              if (partOfSpeech != null)
                Text(partOfSpeech, style: secondaryStyle),
            ],
          ),
        ],
        if (showLemma) ...[
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            textDirection: sourceDirection,
            spacing: AppSpacing.xs,
            children: [
              Text(l10n.translationBaseForm, style: secondaryStyle),
              Text(
                lemma,
                key: const ValueKey('translation-lemma'),
                textDirection: translationTextDirection(lemma),
                style: secondaryStyle,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

String? _nonBlank(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? null : text;
}

final _whitespace = RegExp(r'\s+');
String? _normalized(String? text) =>
    _nonBlank(text)?.replaceAll(_whitespace, ' ').toLowerCase();

String? _partOfSpeechLabel(ReadflexLocalizations l10n, String? value) =>
    switch (value?.trim().toLowerCase()) {
      'noun' => l10n.translationPosNoun,
      'verb' => l10n.translationPosVerb,
      'adjective' => l10n.translationPosAdjective,
      'adverb' => l10n.translationPosAdverb,
      'pronoun' => l10n.translationPosPronoun,
      'preposition' => l10n.translationPosPreposition,
      'conjunction' => l10n.translationPosConjunction,
      'interjection' => l10n.translationPosInterjection,
      'determiner' => l10n.translationPosDeterminer,
      'numeral' => l10n.translationPosNumeral,
      'particle' => l10n.translationPosParticle,
      'auxiliary' => l10n.translationPosAuxiliary,
      _ => null,
    };
