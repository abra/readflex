part of 'translate_sheet.dart';

/// What the reader selected, a quiet label above the translation sections.
///
/// The selected word or phrase in `titleMedium` with its reading and
/// pronunciation on one line; its part of speech and base form follow on a
/// second line, all on the source text's own edge. The translation, not the
/// source, is the sheet's only large text. A word too wide for the line at a
/// large text size shrinks instead of breaking.
class _TranslationLexicalHeader extends StatelessWidget {
  const _TranslationLexicalHeader({
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
        ? _nonEmptyText(analysis?.pronunciation)
        : null;
    final reading = matchesSelection && isSingleWord
        ? _nonEmptyText(analysis?.reading)
        : null;
    final partOfSpeech = matchesSelection && isSingleWord
        ? _partOfSpeechLabel(l10n, analysis?.partOfSpeech)
        : null;
    final lemma = _nonEmptyText(analysis?.lemma);
    final showLemma =
        lemma != null && _normalized(lemma) != _normalized(selectedText);
    final secondaryStyle = context.text.bodyMedium.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    // Identical reading/pronunciation is shown once; a reading equal to the
    // word itself adds nothing.
    final visibleReading =
        reading != null && _normalized(reading) != _normalized(selectedText)
        ? reading
        : null;
    final visiblePronunciation =
        pronunciation != null &&
            _normalized(pronunciation) != _normalized(reading)
        ? pronunciation
        : null;
    final hasPronunciation =
        visibleReading != null || visiblePronunciation != null;
    final hasGrammar = partOfSpeech != null || showLemma;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wordStyle = appFitSelectableText(
          context,
          context.text.titleMedium.copyWith(
            letterSpacing: 0,
            color: context.colors.onSurface,
          ),
          text: selectedText,
          boxWidth: constraints.maxWidth,
          textDirection: sourceDirection,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              textDirection: sourceDirection,
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xxs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Semantics(
                  header: true,
                  child: SelectableText(
                    selectedText,
                    key: const ValueKey('translation-selected-fragment'),
                    textDirection: sourceDirection,
                    style: wordStyle,
                  ),
                ),
                if (hasPronunciation)
                  AppLexicalMetadataRow(
                    reading: visibleReading,
                    pronunciation: visiblePronunciation,
                    textDirection: sourceDirection,
                  ),
              ],
            ),
            if (hasGrammar) ...[
              const SizedBox(height: AppSpacing.xxs),
              Wrap(
                textDirection: sourceDirection,
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xxs,
                children: [
                  if (partOfSpeech != null)
                    AppLexicalMetadataRow(
                      partOfSpeech: partOfSpeech,
                      textDirection: sourceDirection,
                    ),
                  if (showLemma)
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
              ),
            ],
          ],
        );
      },
    );
  }
}

String? _normalized(String? text) =>
    _nonEmptyText(text)?.replaceAll(_whitespaceRun, ' ').toLowerCase();

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
