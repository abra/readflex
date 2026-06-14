import 'package:component_library/component_library.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:shared/shared.dart';
import 'package:translation_service/translation_service.dart';

import 'translate_cubit.dart';
import 'translation_language_detection.dart';

/// Opens the [TranslateSheet] as a modal bottom sheet. Called by
/// [TranslateAction] from the reader's text-selection context panel.
Future<void> showTranslateSheet(
  BuildContext context, {
  required TranslationService translationService,
  required DictionaryRepository dictionaryRepository,
  required FsrsRepository fsrsRepository,
  required TextSelectionContext selection,
  String? sourceLanguageCode,
  String targetLanguageCode = defaultTranslationTargetLanguageCode,
}) {
  return showAppBottomSheet<void>(
    context,
    builder: (_) => TranslateSheet(
      translationService: translationService,
      dictionaryRepository: dictionaryRepository,
      fsrsRepository: fsrsRepository,
      selection: selection,
      sourceLanguageCode: sourceLanguageCode,
      targetLanguageCode: targetLanguageCode,
    ),
  );
}

/// Bottom sheet that translates selected reader text and offers to save
/// it to the dictionary.
///
/// Provides its own [TranslateCubit] and kicks off the translation
/// immediately on build. Usually launched via [showTranslateSheet],
/// not constructed directly.
class TranslateSheet extends StatelessWidget {
  const TranslateSheet({
    required this.translationService,
    required this.dictionaryRepository,
    required this.fsrsRepository,
    required this.selection,
    this.sourceLanguageCode,
    this.targetLanguageCode = defaultTranslationTargetLanguageCode,
    super.key,
  });

  final TranslationService translationService;
  final DictionaryRepository dictionaryRepository;
  final FsrsRepository fsrsRepository;
  final TextSelectionContext selection;
  final String? sourceLanguageCode;
  final String targetLanguageCode;

  @override
  Widget build(BuildContext context) {
    final textForTranslation = selection.textForTranslation;
    final resolvedSourceLanguageCode =
        sourceLanguageCode ??
        detectTranslationSourceLanguage(
          textForTranslation,
          contextText: selection.contextText,
        );

    return BlocProvider(
      create: (_) =>
          TranslateCubit(
            translationService: translationService,
            dictionaryRepository: dictionaryRepository,
            fsrsRepository: fsrsRepository,
          )..translate(
            text: textForTranslation,
            contextText: selection.contextText,
            markedContextText: selection.markedContextTextForTranslation,
            fromLang: resolvedSourceLanguageCode,
            toLang: targetLanguageCode,
          ),
      child: _TranslateSheetView(selection: selection),
    );
  }
}

/// Translation result sheet body bound to [TranslateCubit].
class _TranslateSheetView extends StatelessWidget {
  const _TranslateSheetView({required this.selection});

  final TextSelectionContext selection;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranslateCubit, TranslateState>(
      builder: (context, state) {
        final isTranslating = state.status == TranslateStatus.translating;
        final saveCandidates = _dictionarySaveCandidates(state, selection);

        return ActionBottomSheetLayout(
          title: 'Translate',
          headerSpacing: AppSpacing.sm,
          bodyPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TranslationHeader(selection: selection, state: state),
              const SizedBox(height: AppSpacing.lg),
              if (isTranslating)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (state.translatedText.isNotEmpty) ...[
                _TranslationContextSection(state: state),
                _TranslationDetails(state: state),
                if (state.usageExamples.isNotEmpty)
                  _UsageExamplesBlock(state: state),
                if (saveCandidates.isNotEmpty)
                  _DictionarySaveOptions(
                    candidates: saveCandidates,
                    savingEntryKey: state.savingEntryKey,
                    savedEntryIds: state.savedEntryIds,
                    onSave: (candidate) {
                      context.read<TranslateCubit>().saveToDictionary(
                        word: candidate.word,
                        entryKey: candidate.key,
                        translation: candidate.translation,
                        pronunciation: candidate.pronunciation,
                        partOfSpeech: candidate.partOfSpeech,
                        context: candidate.context,
                        usageExamples: candidate.usageExamples,
                        sourceId: selection.sourceId,
                        sourceType: selection.sourceType,
                      );
                    },
                    onUndo: (candidate) {
                      context.read<TranslateCubit>().undoDictionarySave(
                        candidate.key,
                      );
                    },
                  ),
              ],
              if (state.status == TranslateStatus.failure)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    state.errorMessage ?? 'An error occurred',
                    style: context.text.bodyMedium.copyWith(
                      color: context.colors.error,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Top block: selected lexical text and optional translation metadata.
class _TranslationHeader extends StatelessWidget {
  const _TranslationHeader({required this.selection, required this.state});

  final TextSelectionContext selection;
  final TranslateState state;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;
    final muted = cs.onSurface.withValues(alpha: 0.55);
    final word = selection.textForTranslation.trim();
    final exactSelection = selection.selectedText.trim();
    final showExactSelection =
        exactSelection.isNotEmpty && exactSelection != word;
    final partOfSpeech =
        state.sense?.partOfSpeech ?? state.expression?.partOfSpeech;
    final pronunciation =
        state.sense?.transcription ?? state.sense?.lemmaTranscription;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          word.isEmpty ? exactSelection : word,
          style: text.headlineSmall.copyWith(
            fontFamily: AppTypography.fontFamilySerif,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
            height: 1.1,
          ),
        ),
        if (showExactSelection) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            exactSelection,
            style: text.labelSmall.copyWith(color: muted),
          ),
        ],
        if (partOfSpeech != null || pronunciation != null) ...[
          const SizedBox(height: AppSpacing.xs),
          _TranslationMetaLine(
            partOfSpeech: partOfSpeech,
            pronunciation: pronunciation,
            muted: muted,
          ),
        ],
      ],
    );
  }
}

/// "italic POS · pronunciation" row beneath the selected word.
class _TranslationMetaLine extends StatelessWidget {
  const _TranslationMetaLine({
    required this.partOfSpeech,
    required this.pronunciation,
    required this.muted,
  });

  final String? partOfSpeech;
  final String? pronunciation;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final dotColor = muted.withValues(alpha: 0.5);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (partOfSpeech != null)
          Text(
            partOfSpeech!,
            style: text.labelSmall.copyWith(
              fontStyle: FontStyle.italic,
              color: muted,
            ),
          ),
        if (partOfSpeech != null && pronunciation != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        if (pronunciation != null)
          Flexible(
            child: Text(
              pronunciation!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall.copyWith(color: muted),
            ),
          ),
      ],
    );
  }
}

/// Primary translated text, styled like Dictionary detail's context block.
class _TranslationContextSection extends StatelessWidget {
  const _TranslationContextSection({required this.state});

  final TranslateState state;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;
    final muted = cs.onSurface.withValues(alpha: 0.55);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'IN THIS CONTEXT',
          style: text.kicker.copyWith(color: muted),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          state.translatedText,
          style: text.titleLarge.copyWith(
            fontFamily: AppTypography.fontFamilySerif,
            color: cs.onSurface,
            height: 1.3,
          ),
        ),
        if (state.context != null && state.context!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            state.context!,
            style: text.bodyMedium.copyWith(
              fontFamily: AppTypography.fontFamilySerif,
              color: muted,
              height: 1.55,
            ),
          ),
        ],
      ],
    );
  }
}

/// Pull-quote for the sentence that came from the current reader context.
class _TranslationSourceQuote extends StatelessWidget {
  const _TranslationSourceQuote({required this.quote, this.footer});

  final String quote;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;
    final muted = cs.onSurface.withValues(alpha: 0.55);

    return Container(
      padding: const EdgeInsets.only(left: AppSpacing.md),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: cs.primary.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarkedText(
            text: quote,
            style: text.bodyMedium.copyWith(
              fontFamily: AppTypography.fontFamilySerif,
              fontStyle: FontStyle.italic,
              color: cs.onSurface.withValues(alpha: 0.9),
              height: 1.55,
            ),
            highlightStyle: text.bodyMedium.copyWith(
              fontFamily: AppTypography.fontFamilySerif,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w700,
              color: cs.primary,
              height: 1.55,
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              footer!,
              style: text.labelSmall.copyWith(color: muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Usage examples block that separates the original reader context
/// from additional model-provided examples.
class _UsageExamplesBlock extends StatelessWidget {
  const _UsageExamplesBlock({required this.state});

  final TranslateState state;

  @override
  Widget build(BuildContext context) {
    final hasOriginalExample =
        state.selectionContextText != null &&
        state.selectionContextText!.trim().isNotEmpty;
    final originalExample = hasOriginalExample
        ? state.usageExamples.first
        : null;
    final additionalExamples = hasOriginalExample
        ? state.usageExamples.skip(1).toList(growable: false)
        : state.usageExamples;
    final muted = context.colors.onSurface.withValues(alpha: 0.55);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Examples',
            style: context.text.kicker.copyWith(color: muted),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (originalExample != null)
            _TranslationSourceQuote(
              quote: originalExample,
              footer: 'In this text',
            ),
          if (additionalExamples.isNotEmpty)
            _AdditionalUsageExamples(
              examples: additionalExamples,
              topSpacing: originalExample == null ? 0 : AppSpacing.md,
            ),
        ],
      ),
    );
  }
}

/// Additional model-provided examples, without per-row labels.
class _AdditionalUsageExamples extends StatelessWidget {
  const _AdditionalUsageExamples({
    required this.examples,
    required this.topSpacing,
  });

  final List<String> examples;
  final double topSpacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (topSpacing > 0) SizedBox(height: topSpacing),
        for (final example in examples) ...[
          _TranslationSourceQuote(quote: example),
          if (example != examples.last) const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _DictionarySaveCandidate {
  const _DictionarySaveCandidate({
    required this.key,
    required this.label,
    required this.icon,
    required this.word,
    required this.translation,
    required this.context,
    required this.usageExamples,
    this.pronunciation,
    this.partOfSpeech,
  });

  final String key;
  final String label;
  final IconData icon;
  final String word;
  final String translation;
  final String? pronunciation;
  final String? partOfSpeech;
  final String? context;
  final List<String> usageExamples;
}

class _DictionarySaveOptions extends StatelessWidget {
  const _DictionarySaveOptions({
    required this.candidates,
    required this.savingEntryKey,
    required this.savedEntryIds,
    required this.onSave,
    required this.onUndo,
  });

  final List<_DictionarySaveCandidate> candidates;
  final String? savingEntryKey;
  final Map<String, String> savedEntryIds;
  final ValueChanged<_DictionarySaveCandidate> onSave;
  final ValueChanged<_DictionarySaveCandidate> onUndo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Save to Dictionary',
            style: context.text.labelLarge.copyWith(
              color: context.colors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...candidates.expand(
            (candidate) => [
              _DictionarySaveOptionRow(
                candidate: candidate,
                saving: savingEntryKey == candidate.key,
                saved: savedEntryIds.containsKey(candidate.key),
                onSave: () => onSave(candidate),
                onUndo: () => onUndo(candidate),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ],
      ),
    );
  }
}

class _DictionarySaveOptionRow extends StatelessWidget {
  const _DictionarySaveOptionRow({
    required this.candidate,
    required this.saving,
    required this.saved,
    required this.onSave,
    required this.onUndo,
  });

  final _DictionarySaveCandidate candidate;
  final bool saving;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;
    final actionColor = saved ? cs.primary : cs.onSurfaceVariant;

    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.54),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(candidate.icon, size: 18, color: cs.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    candidate.label,
                    style: text.labelSmall.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    candidate.word,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    candidate.translation,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall.copyWith(color: cs.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: saving
                  ? const SizedBox(
                      key: ValueKey('saving'),
                      width: 40,
                      height: 40,
                      child: Center(
                        child: ButtonLoadingIndicator(size: AppIconSize.sm),
                      ),
                    )
                  : saved
                  ? _UndoSaveButton(color: actionColor, onPressed: onUndo)
                  : TextButton.icon(
                      key: const ValueKey('save'),
                      onPressed: onSave,
                      icon: const Icon(
                        AppIcons.bookmarkAdd,
                        size: AppIconSize.sm,
                      ),
                      label: const Text('Save'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UndoSaveButton extends StatelessWidget {
  const _UndoSaveButton({
    required this.color,
    required this.onPressed,
  });

  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: const ValueKey('saved'),
      onPressed: onPressed,
      icon: Icon(AppIcons.check, size: AppIconSize.sm, color: color),
      label: Text(
        'Undo',
        style: context.text.labelMedium.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Optional explanatory rows below the main translation result.
///
/// Keeps model-specific metadata display decisions out of the sheet shell.
class _TranslationDetails extends StatelessWidget {
  const _TranslationDetails({required this.state});

  final TranslateState state;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    final notes = _pairSummary(state.notes);
    final contextMarker = _contextMarkerSummary(state.expression);

    if (_shouldShowLiteral(state)) {
      rows.add(
        _TranslationDetailLine(
          label: 'Literal',
          value: state.literalTranslation!,
        ),
      );
    }
    if (state.answerType == TranslationAnswerType.ambiguous ||
        state.confidence == TranslationConfidence.low) {
      rows.add(
        Text(
          'Low confidence',
          style: context.text.labelSmall.copyWith(
            color: context.colors.error,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    if (contextMarker != null) {
      rows.add(
        _TranslationDetailLine(label: 'In context', value: contextMarker),
      );
    }
    rows.addAll(_senseRows(state.sense));
    if (state.naturalEquivalents.isNotEmpty) {
      rows.add(
        _TranslationDetailLine(
          label: 'Related',
          value: state.naturalEquivalents.join(', '),
        ),
      );
    }
    if (notes != null) {
      rows.add(_TranslationDetailLine(label: 'Note', value: notes));
    }

    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...rows.expand(
            (row) => [
              row,
              const SizedBox(height: AppSpacing.xs),
            ],
          ),
        ],
      ),
    );
  }

  static bool _shouldShowLiteral(TranslateState state) {
    final literal = state.literalTranslation?.trim();
    if (literal == null || literal.isEmpty) return false;
    return _normalizeForComparison(literal) !=
        _normalizeForComparison(state.translatedText);
  }

  static String _normalizeForComparison(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static List<Widget> _senseRows(TranslationSense? sense) {
    if (sense == null || sense.isEmpty) return const [];
    final lemmaValue = _lemmaValue(sense);
    return [
      if (sense.partOfSpeech != null)
        _TranslationDetailLine(
          label: 'Part of speech',
          value: sense.partOfSpeech!,
        ),
      if (sense.transcription != null)
        _TranslationDetailLine(
          label: 'Transcription',
          value: sense.transcription!,
        ),
      if (lemmaValue != null)
        _TranslationDetailLine(
          label: _lemmaLabel(sense.grammaticalForm),
          value: lemmaValue,
        ),
      if (sense.sourceDefinition != null || sense.targetDefinition != null)
        _TranslationDefinitionsBlock(
          sourceDefinition: sense.sourceDefinition,
          targetDefinition: sense.targetDefinition,
        ),
      if (sense.sourceContextNote != null)
        _TranslationDetailLine(
          label: 'Source context',
          value: sense.sourceContextNote!,
        ),
      if (sense.targetContextNote != null)
        _TranslationDetailLine(
          label: 'Target context',
          value: sense.targetContextNote!,
        ),
    ];
  }

  static String? _contextMarkerSummary(TranslationExpression? expression) {
    if (expression == null || expression.isEmpty) return null;
    final selected = expression.term?.trim();
    final head = _expressionDisplayHead(expression);
    if (selected == null || selected.isEmpty || head == null) return null;
    if (!_isLargerThanTerm(head, selected)) return null;

    final typeName = _expressionTypeName(expression.expressionType);
    final lexicalUnit = expression.lexicalUnit?.trim();
    final surface = expression.surface?.trim();
    if (_isPhrasalExpression(expression.expressionType) &&
        lexicalUnit != null &&
        lexicalUnit.isNotEmpty &&
        _isDistinctExpressionText(lexicalUnit, head) &&
        surface != null &&
        surface.isNotEmpty &&
        _isDistinctExpressionText(surface, lexicalUnit)) {
      return '"$selected" is used in the $typeName "$lexicalUnit" here as "$surface".';
    }

    if (_isPhrasalExpression(expression.expressionType)) {
      return '"$selected" appears in the phrasal-verb construction "$head" in this sentence.';
    }

    return '"$selected" is part of the $typeName "$head" in this sentence.';
  }

  static String? _expressionDisplayHead(TranslationExpression expression) {
    for (final value in [
      expression.surface,
      expression.normalizedExpression,
      expression.lexicalUnit,
    ]) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  static String _expressionTypeName(String? value) {
    final normalized = value?.trim().toLowerCase().replaceAll('_', ' ') ?? '';
    if (normalized.contains('phrasal verb')) return 'phrasal verb';
    if (normalized.contains('idiom')) return 'idiom';
    if (normalized.contains('collocation')) return 'collocation';
    if (normalized.contains('technical')) return 'technical term';
    if (normalized.contains('discourse')) return 'discourse marker';
    if (normalized.contains('prepositional')) return 'prepositional phrase';
    if (normalized.contains('adjectival')) return 'adjectival phrase';
    if (normalized.contains('fixed')) return 'fixed expression';
    return 'expression';
  }

  static bool _isPhrasalExpression(String? value) {
    final normalized = value?.trim().toLowerCase().replaceAll('_', ' ') ?? '';
    return normalized.contains('phrasal verb');
  }

  static bool _isDistinctExpressionText(String first, String second) {
    return _normalizeForComparison(first) != _normalizeForComparison(second);
  }

  static bool _isLargerThanTerm(String? value, String? term) {
    if (value == null || value.trim().isEmpty) return false;
    if (term == null || term.trim().isEmpty) return true;
    final normalizedValue = _normalizeForComparison(value);
    final normalizedTerm = _normalizeForComparison(term);
    if (normalizedValue == normalizedTerm) return false;
    return normalizedValue.contains(' ') ||
        normalizedValue.length > normalizedTerm.length;
  }

  static String? _lemmaValue(TranslationSense sense) {
    final lemma = sense.lemma?.trim();
    if (lemma == null || lemma.isEmpty) return null;
    final transcription = sense.lemmaTranscription?.trim();
    if (transcription == null || transcription.isEmpty) return lemma;
    return '$lemma $transcription';
  }

  static String _lemmaLabel(String? grammaticalForm) {
    final normalized = grammaticalForm?.trim().toLowerCase();
    if (normalized == 'plural') return 'Singular';
    if (normalized == null || normalized.isEmpty) return 'Lemma';
    return 'Base form';
  }

  static String? _pairSummary(TranslationTextPair? pair) {
    if (pair == null || pair.isEmpty) return null;
    final parts = <String>[
      if (pair.source != null) pair.source!,
      if (pair.target != null) pair.target!,
    ];
    return parts.join(' / ');
  }
}

/// Source/target definitions grouped under one semantic heading.
class _TranslationDefinitionsBlock extends StatelessWidget {
  const _TranslationDefinitionsBlock({
    required this.sourceDefinition,
    required this.targetDefinition,
  });

  final String? sourceDefinition;
  final String? targetDefinition;

  @override
  Widget build(BuildContext context) {
    final muted = context.colors.onSurface.withValues(alpha: 0.55);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'DEFINITIONS',
          style: context.text.kicker.copyWith(color: muted),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (sourceDefinition != null)
          _TranslationDetailLine(label: 'Source', value: sourceDefinition!),
        if (sourceDefinition != null && targetDefinition != null)
          const SizedBox(height: AppSpacing.xs),
        if (targetDefinition != null)
          _TranslationDetailLine(label: 'Target', value: targetDefinition!),
      ],
    );
  }
}

/// Single label/value row in the translation details block.
class _TranslationDetailLine extends StatelessWidget {
  const _TranslationDetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: context.text.bodySmall.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

List<_DictionarySaveCandidate> _dictionarySaveCandidates(
  TranslateState state,
  TextSelectionContext selection,
) {
  final selectedWord = _nonEmpty(selection.textForTranslation);
  final selectedTranslation = _nonEmpty(state.translatedText);
  if (selectedWord == null || selectedTranslation == null) return const [];

  final selectedCandidate = _DictionarySaveCandidate(
    key: 'selection:${_normalizeForComparison(selectedWord)}',
    label: selection.selectionKind == 'partial_word'
        ? 'Complete word'
        : 'Selected word',
    icon: AppIcons.bookmarkAdd,
    word: selectedWord,
    translation: selectedTranslation,
    pronunciation:
        state.sense?.transcription ?? state.sense?.lemmaTranscription,
    partOfSpeech: state.sense?.partOfSpeech ?? state.expression?.partOfSpeech,
    context: state.selectionContextText ?? state.context,
    usageExamples: state.usageExamples,
  );

  final expressionCandidate = _expressionSaveCandidate(
    state,
    selectedWord: selectedWord,
  );

  return [
    selectedCandidate,
    ?expressionCandidate,
  ];
}

_DictionarySaveCandidate? _expressionSaveCandidate(
  TranslateState state, {
  required String selectedWord,
}) {
  final expression = state.expression;
  if (expression == null || expression.isEmpty) return null;

  final expressionSource =
      _nonEmpty(state.suggestedFullPhrase?.source) ??
      _expressionDisplayHead(expression);
  if (!_isLargerThanTerm(expressionSource, selectedWord)) return null;

  final expressionTranslation =
      _nonEmpty(state.suggestedFullPhrase?.target) ??
      _nonEmpty(state.sense?.targetContextNote) ??
      _nonEmpty(state.sense?.targetDefinition);
  if (expressionTranslation == null) return null;

  final expressionType = _TranslationDetails._expressionTypeName(
    expression.expressionType,
  );
  final expressionLabel = _capitalize(expressionType);

  return _DictionarySaveCandidate(
    key: 'expression:${_normalizeForComparison(expressionSource!)}',
    label: expressionLabel,
    icon: AppIcons.translate,
    word: expressionSource,
    translation: expressionTranslation,
    partOfSpeech: expressionType,
    context: state.selectionContextText ?? state.context,
    usageExamples: state.usageExamples,
  );
}

String? _expressionDisplayHead(TranslationExpression expression) {
  for (final value in [
    expression.surface,
    expression.normalizedExpression,
    expression.lexicalUnit,
  ]) {
    final trimmed = _nonEmpty(value);
    if (trimmed != null) return trimmed;
  }
  return null;
}

bool _isLargerThanTerm(String? value, String term) {
  final normalizedValue = _nonEmpty(value);
  if (normalizedValue == null) return false;
  final valueKey = _normalizeForComparison(normalizedValue);
  final termKey = _normalizeForComparison(term);
  if (valueKey == termKey) return false;
  return valueKey.contains(' ') || valueKey.length > termKey.length;
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _normalizeForComparison(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

String _capitalize(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return 'Expression';
  return normalized[0].toUpperCase() + normalized.substring(1);
}
