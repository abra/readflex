import 'package:component_library/component_library.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:shared/shared.dart';
import 'package:translation_service/translation_service.dart';

import 'translate_cubit.dart';

/// Opens the [TranslateSheet] as a modal bottom sheet. Called by
/// [TranslateAction] from the reader's text-selection context panel.
Future<void> showTranslateSheet(
  BuildContext context, {
  required TranslationService translationService,
  required DictionaryRepository dictionaryRepository,
  required FsrsRepository fsrsRepository,
  required TextSelectionContext selection,
}) {
  return showAppBottomSheet<void>(
    context,
    builder: (_) => TranslateSheet(
      translationService: translationService,
      dictionaryRepository: dictionaryRepository,
      fsrsRepository: fsrsRepository,
      selection: selection,
    ),
  );
}

/// Bottom sheet that translates selected reader text and offers to save
/// it to the dictionary.
///
/// Provides its own [TranslateCubit] and kicks off the translation
/// immediately on build. Closes itself once the entry is saved.
/// Usually launched via [showTranslateSheet], not constructed directly.
class TranslateSheet extends StatelessWidget {
  const TranslateSheet({
    required this.translationService,
    required this.dictionaryRepository,
    required this.fsrsRepository,
    required this.selection,
    super.key,
  });

  final TranslationService translationService;
  final DictionaryRepository dictionaryRepository;
  final FsrsRepository fsrsRepository;
  final TextSelectionContext selection;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          TranslateCubit(
            translationService: translationService,
            dictionaryRepository: dictionaryRepository,
            fsrsRepository: fsrsRepository,
          )..translate(
            text: selection.textForTranslation,
            contextText: selection.contextText,
            markedContextText: selection.markedContextTextForTranslation,
            fromLang: 'en',
            toLang: 'ru',
          ),
      child: _TranslateSheetView(selection: selection),
    );
  }
}

class _TranslateSheetView extends StatelessWidget {
  const _TranslateSheetView({required this.selection});

  final TextSelectionContext selection;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TranslateCubit, TranslateState>(
      listener: (context, state) {
        if (state.status == TranslateStatus.saved) {
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        final isWorking =
            state.status == TranslateStatus.translating ||
            state.status == TranslateStatus.saving;

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
              // Original text
              SelectionPreviewCard(text: selection.selectedText),
              const SizedBox(height: AppSpacing.md),
              // Translation result
              if (state.status == TranslateStatus.translating)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (state.translatedText.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: context.colors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    state.translatedText,
                    style: context.text.bodyLarge,
                  ),
                ),
                _TranslationDetails(state: state),
                if (state.context != null && state.context!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    state.context!,
                    style: context.text.bodySmall.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
                if (state.usageExamples.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  ...state.usageExamples.map(
                    (example) => Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppSpacing.xs,
                      ),
                      child: MarkedText(
                        text: example,
                        style: context.text.bodySmall,
                        highlightStyle: context.text.bodySmall.copyWith(
                          color: context.colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
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
              const SizedBox(height: AppSpacing.md),
              if (state.status == TranslateStatus.translated ||
                  state.status == TranslateStatus.failure)
                FilledButton.icon(
                  onPressed: isWorking
                      ? null
                      : () => context.read<TranslateCubit>().saveToDictionary(
                          word: selection.textForTranslation,
                          sourceId: selection.sourceId,
                          sourceType: selection.sourceType,
                        ),
                  icon: state.status == TranslateStatus.saving
                      ? const ButtonLoadingIndicator(size: AppIconSize.sm)
                      : const Icon(AppIcons.bookmarkAdd),
                  label: const Text('Save to Dictionary'),
                ),
            ],
          ),
        );
      },
    );
  }
}

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
      if (sense.sourceDefinition != null)
        _TranslationDetailLine(label: 'Source', value: sense.sourceDefinition!),
      if (sense.targetDefinition != null)
        _TranslationDetailLine(label: 'Target', value: sense.targetDefinition!),
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
