import 'package:component_library/component_library.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart' show DictionaryAnchorKind;
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
        final selectedCandidate = saveCandidates.isEmpty
            ? null
            : saveCandidates.first;
        final expressionCandidate = saveCandidates.length < 2
            ? null
            : saveCandidates[1];
        final expressionSource = expressionCandidate == null
            ? null
            : _expressionSourceExplanation(state, expressionCandidate);
        final verbForms = _verbFormsForTranslation(state, selection);
        Future<void> saveCandidate(_DictionarySaveCandidate candidate) async {
          await context.read<TranslateCubit>().saveToDictionary(
            word: candidate.word,
            entryKey: candidate.key,
            translation: candidate.translation,
            pronunciation: candidate.pronunciation,
            partOfSpeech: candidate.partOfSpeech,
            context: candidate.context,
            usageExamples: candidate.usageExamples,
            sourceId: selection.sourceId,
            sourceType: selection.sourceType,
            anchorText: candidate.anchorText,
            anchorContext: candidate.anchorContext,
            anchorCfiRange: candidate.anchorCfiRange,
            anchorKind: candidate.anchorKind,
          );
        }

        Future<void> undoCandidate(_DictionarySaveCandidate candidate) async {
          await context.read<TranslateCubit>().undoDictionarySave(
            candidate.key,
          );
        }

        return _ScrollableTranslateSheetLayout(
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
              if (isTranslating) ...[
                _PendingTranslationHeader(selection: selection),
                const SizedBox(height: AppSpacing.lg),
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ] else if (state.translatedText.isNotEmpty) ...[
                _SelectedTranslationSection(
                  selection: selection,
                  state: state,
                  candidate: selectedCandidate,
                  saving:
                      selectedCandidate != null &&
                      state.savingEntryKey == selectedCandidate.key,
                  saved:
                      selectedCandidate != null &&
                      state.savedEntryIds.containsKey(selectedCandidate.key),
                  onSave: selectedCandidate == null
                      ? null
                      : () => saveCandidate(selectedCandidate),
                  onUndo: selectedCandidate == null
                      ? null
                      : () => undoCandidate(selectedCandidate),
                  verbForms: verbForms,
                  showFallbackExamples: expressionCandidate == null,
                  includeSenseExplanations: expressionSource == null,
                ),
                if (expressionCandidate != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _ExpressionTranslationSection(
                    state: state,
                    candidate: expressionCandidate,
                    source: expressionSource,
                    saving: state.savingEntryKey == expressionCandidate.key,
                    saved: state.savedEntryIds.containsKey(
                      expressionCandidate.key,
                    ),
                    onSave: () => saveCandidate(expressionCandidate),
                    onUndo: () => undoCandidate(expressionCandidate),
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
            ],
          ),
        );
      },
    );
  }
}

class _ScrollableTranslateSheetLayout extends StatelessWidget {
  const _ScrollableTranslateSheetLayout({
    required this.title,
    required this.child,
    required this.bodyPadding,
    this.headerSpacing = AppSpacing.lg,
  });

  final String title;
  final Widget child;
  final EdgeInsetsGeometry bodyPadding;
  final double headerSpacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final body = SingleChildScrollView(
          padding: bodyPadding,
          child: child,
        );
        final bodyWidget = constraints.hasBoundedHeight
            ? Flexible(child: body)
            : body;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                0,
              ),
              child: BottomSheetHeader(title: title),
            ),
            if (headerSpacing > 0) SizedBox(height: headerSpacing),
            bodyWidget,
          ],
        );
      },
    );
  }
}

class _PendingTranslationHeader extends StatelessWidget {
  const _PendingTranslationHeader({required this.selection});

  final TextSelectionContext selection;

  @override
  Widget build(BuildContext context) {
    final word = selection.textForTranslation.trim();
    final exactSelection = selection.selectedText.trim();
    final showExactSelection =
        exactSelection.isNotEmpty && exactSelection != word;

    return _TermHeader(
      word: word.isEmpty ? exactSelection : word,
      exactSelection: showExactSelection ? exactSelection : null,
      saving: false,
      saved: false,
      onSave: null,
      onUndo: null,
    );
  }
}

/// Selected-term block: save action, contextual translation, source quote,
/// definitions, and language-specific forms.
class _SelectedTranslationSection extends StatelessWidget {
  const _SelectedTranslationSection({
    required this.selection,
    required this.state,
    required this.candidate,
    required this.saving,
    required this.saved,
    required this.onSave,
    required this.onUndo,
    required this.verbForms,
    required this.showFallbackExamples,
    required this.includeSenseExplanations,
  });

  final TextSelectionContext selection;
  final TranslateState state;
  final _DictionarySaveCandidate? candidate;
  final bool saving;
  final bool saved;
  final Future<void> Function()? onSave;
  final Future<void> Function()? onUndo;
  final IrregularVerbForms? verbForms;
  final bool showFallbackExamples;
  final bool includeSenseExplanations;

  @override
  Widget build(BuildContext context) {
    final word = selection.textForTranslation.trim();
    final exactSelection = selection.selectedText.trim();
    final showExactSelection =
        exactSelection.isNotEmpty && exactSelection != word;
    final partOfSpeech = _selectedTermPartOfSpeech(state);
    final pronunciation = state.sense?.transcription;
    final quote = _readerQuoteForCandidate(state, candidate);
    final fallbackExamples = _selectedFallbackExamples(
      state,
      hasReaderQuote: quote != null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TermHeader(
          word: word.isEmpty ? exactSelection : word,
          exactSelection: showExactSelection ? exactSelection : null,
          partOfSpeech: partOfSpeech,
          pronunciation: pronunciation,
          saving: saving,
          saved: saved,
          onSave: onSave,
          onUndo: onUndo,
        ),
        const SizedBox(height: AppSpacing.lg),
        _TranslationContextSection(state: state),
        if (quote != null) ...[
          const SizedBox(height: AppSpacing.md),
          _TranslationSourceQuote(quote: quote, footer: 'In this text'),
        ],
        _TranslationDetails(
          state: state,
          includeSenseExplanations: includeSenseExplanations,
        ),
        if (verbForms != null) _IrregularVerbFormsBlock(forms: verbForms!),
        if (showFallbackExamples && fallbackExamples.isNotEmpty)
          _ExamplesList(examples: fallbackExamples),
      ],
    );
  }
}

/// Phrase/expression block shown when the selected word belongs to a larger
/// lexical unit.
class _ExpressionTranslationSection extends StatelessWidget {
  const _ExpressionTranslationSection({
    required this.state,
    required this.candidate,
    required this.source,
    required this.saving,
    required this.saved,
    required this.onSave,
    required this.onUndo,
  });

  final TranslateState state;
  final _DictionarySaveCandidate candidate;
  final String? source;
  final bool saving;
  final bool saved;
  final Future<void> Function() onSave;
  final Future<void> Function() onUndo;

  @override
  Widget build(BuildContext context) {
    final intro = _TranslationDetails._contextMarkerSummary(state.expression);
    final source = this.source;
    final target = _expressionTargetExplanation(
      state,
      candidate,
      hasSourceExplanation: source != null,
    );
    final examples = _expressionExamples(state, candidate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (intro != null) ...[
          Text(
            intro,
            style: context.text.bodySmall.copyWith(
              color: context.colors.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        _TermHeader(
          word: candidate.word,
          partOfSpeech: candidate.partOfSpeech,
          saving: saving,
          saved: saved,
          onSave: onSave,
          onUndo: onUndo,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (source != null) ...[
          _TranslationDetailLine(label: 'Source', value: source),
          const SizedBox(height: AppSpacing.xs),
        ],
        _TranslationDetailLine(label: 'Target', value: target),
        if (examples.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _ExamplesList(examples: examples),
        ],
      ],
    );
  }
}

class _TermHeader extends StatelessWidget {
  const _TermHeader({
    required this.word,
    required this.saving,
    required this.saved,
    required this.onSave,
    required this.onUndo,
    this.exactSelection,
    this.partOfSpeech,
    this.pronunciation,
  });

  final String word;
  final String? exactSelection;
  final String? partOfSpeech;
  final String? pronunciation;
  final bool saving;
  final bool saved;
  final Future<void> Function()? onSave;
  final Future<void> Function()? onUndo;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;
    final muted = cs.onSurface.withValues(alpha: 0.55);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                word,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: text.headlineSmall.copyWith(
                  fontFamily: AppTypography.fontFamilySerif,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  height: 1.1,
                ),
              ),
            ),
            if (onSave != null && onUndo != null) ...[
              const SizedBox(width: AppSpacing.md),
              _TermSaveActions(
                saving: saving,
                saved: saved,
                onSave: onSave!,
                onUndo: onUndo!,
              ),
            ],
          ],
        ),
        if (exactSelection != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            exactSelection!,
            style: text.labelSmall.copyWith(color: muted),
          ),
        ],
        if (partOfSpeech != null || pronunciation != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: _TranslationMetaLine(
              partOfSpeech: partOfSpeech,
              pronunciation: pronunciation,
              muted: muted,
            ),
          ),
      ],
    );
  }
}

class _TermSaveActions extends StatelessWidget {
  const _TermSaveActions({
    required this.saving,
    required this.saved,
    required this.onSave,
    required this.onUndo,
  });

  final bool saving;
  final bool saved;
  final Future<void> Function() onSave;
  final Future<void> Function() onUndo;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final actionColor = cs.primary;

    return SizedBox.fromSize(
      size: _termSaveActionSize,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 120),
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.center,
            children: [
              ...previousChildren,
              ?currentChild,
            ],
          );
        },
        child: saving
            ? SizedBox.fromSize(
                key: ValueKey('saving'),
                size: _termSaveActionSize,
                child: Center(
                  child: ButtonLoadingIndicator(size: AppIconSize.sm),
                ),
              )
            : saved
            ? _UndoSaveButton(color: actionColor, onPressed: onUndo)
            : TextButton.icon(
                key: const ValueKey('save'),
                onPressed: onSave,
                style: _termSaveButtonStyle(actionColor),
                icon: const Icon(
                  AppIcons.bookmarkAdd,
                  size: AppIconSize.sm,
                ),
                label: const Text('Save'),
              ),
      ),
    );
  }
}

const _termSaveActionSize = Size(88, 32);

ButtonStyle _termSaveButtonStyle(Color color) {
  return TextButton.styleFrom(
    foregroundColor: color,
    fixedSize: _termSaveActionSize,
    minimumSize: _termSaveActionSize,
    maximumSize: _termSaveActionSize,
    padding: EdgeInsets.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
  );
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
      style: _termSaveButtonStyle(color),
      icon: const Icon(AppIcons.check, size: AppIconSize.sm),
      label: Text(
        'Undo',
        style: context.text.labelMedium.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String? _readerQuoteForCandidate(
  TranslateState state,
  _DictionarySaveCandidate? candidate,
) {
  final markedContext = _nonEmpty(state.selectionMarkedContextText);
  if (markedContext != null && markedContext.contains(MarkedText.startMarker)) {
    return _focusedMarkedContext(markedContext);
  }

  final context = _nonEmpty(state.selectionContextText);
  if (context == null) return null;

  final term = _nonEmpty(candidate?.word);
  if (term == null) return context;
  final marked = _markTermInContext(context, term);
  return marked == null ? context : _focusedMarkedContext(marked);
}

List<String> _selectedFallbackExamples(
  TranslateState state, {
  required bool hasReaderQuote,
}) {
  if (!hasReaderQuote) return state.usageExamples;
  if (state.selectionContextText == null || state.usageExamples.length < 2) {
    return const [];
  }
  return state.usageExamples.skip(1).toList(growable: false);
}

String? _expressionSourceExplanation(
  TranslateState state,
  _DictionarySaveCandidate candidate,
) {
  if (_nonEmpty(state.expressionTranslation?.source) == null) return null;
  final source = _nonEmpty(state.sense?.sourceDefinition);
  if (source == null) return null;

  final normalizedSource = _normalizeForComparison(source);
  final duplicates = [
    candidate.word,
    state.expressionTranslation?.source,
    state.suggestedFullPhrase?.source,
    state.expression?.surface,
    state.expression?.lexicalUnit,
    state.expression?.canonicalPattern,
    state.expression?.normalizedExpression,
  ];
  for (final duplicate in duplicates) {
    final value = _nonEmpty(duplicate);
    if (value != null && normalizedSource == _normalizeForComparison(value)) {
      return null;
    }
  }
  return source;
}

String _expressionTargetExplanation(
  TranslateState state,
  _DictionarySaveCandidate candidate, {
  required bool hasSourceExplanation,
}) {
  if (!hasSourceExplanation) return candidate.translation;
  return _nonEmpty(state.sense?.targetDefinition) ?? candidate.translation;
}

List<String> _expressionExamples(
  TranslateState state,
  _DictionarySaveCandidate candidate,
) {
  if (state.usageExamples.isNotEmpty) return state.usageExamples;
  final context = _nonEmpty(candidate.context);
  if (context == null) return const [];
  return [context];
}

class _ExamplesList extends StatelessWidget {
  const _ExamplesList({required this.examples});

  final List<String> examples;

  @override
  Widget build(BuildContext context) {
    final muted = context.colors.onSurface.withValues(alpha: 0.55);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EXAMPLES',
          style: context.text.kicker.copyWith(color: muted),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final example in examples) ...[
          _TranslationSourceQuote(quote: example),
          if (example != examples.last) const SizedBox(height: AppSpacing.md),
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
    final dotColor = muted.withValues(alpha: 0.5);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (partOfSpeech != null) _MetaText(value: partOfSpeech!, muted: muted),
        if (partOfSpeech != null && pronunciation != null)
          _MetaDot(color: dotColor),
        if (pronunciation != null)
          Flexible(
            child: _MetaText(
              value: pronunciation!,
              muted: muted,
            ),
          ),
      ],
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.value, required this.muted});

  final String value;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.text.labelSmall.copyWith(
        fontStyle: FontStyle.italic,
        color: muted,
      ),
    );
  }
}

class _MetaDot extends StatelessWidget {
  const _MetaDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Container(
        width: 3,
        height: 3,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

IrregularVerbForms? _verbFormsForTranslation(
  TranslateState state,
  TextSelectionContext selection,
) {
  final partOfSpeech = _selectedTermPartOfSpeech(state);
  final expressionType = state.expression?.expressionType;
  final shouldConsider =
      looksLikeVerbPartOfSpeech(partOfSpeech) ||
      looksLikeVerbPartOfSpeech(expressionType) ||
      _TranslationDetails._isPhrasalExpression(expressionType);
  final terms = [
    state.sense?.lemma,
    selection.textForTranslation,
    state.suggestedFullPhrase?.source,
    state.expression?.lexicalUnit,
    state.expression?.surface,
    state.expression?.normalizedExpression,
  ];

  for (final term in terms) {
    final trimmed = _nonEmpty(term);
    if (trimmed == null) continue;
    final forms = findEnglishIrregularVerbForms(trimmed);
    if (forms != null && shouldConsider) return forms;
  }
  return null;
}

String? _selectedTermPartOfSpeech(TranslateState state) {
  return _nonEmpty(state.sense?.partOfSpeech) ??
      _partOfSpeechFromGrammaticalForm(state.sense?.grammaticalForm) ??
      _posLikeRole(state.expression?.partOfSpeech) ??
      _posLikeRole(state.expression?.selectedRole);
}

String? _partOfSpeechFromGrammaticalForm(String? value) {
  final normalized = value?.trim().toLowerCase().replaceAll('_', ' ');
  if (normalized == null || normalized.isEmpty) return null;
  if (normalized == 'plural') return 'noun';
  const verbForms = {
    'gerund',
    'present participle',
    'present tense',
    'third person singular',
    'past',
    'past tense',
    'past participle',
  };
  if (verbForms.contains(normalized)) return 'verb';
  if (normalized == 'comparative' || normalized == 'superlative') {
    return 'adjective';
  }
  return null;
}

String? _posLikeRole(String? value) {
  final normalized = value?.trim().toLowerCase().replaceAll('_', ' ');
  if (normalized == null || normalized.isEmpty) return null;

  const allowed = {
    'noun',
    'verb',
    'adjective',
    'adverb',
    'pronoun',
    'preposition',
    'conjunction',
    'determiner',
    'article',
    'particle',
    'interjection',
    'auxiliary',
    'modal',
  };
  if (allowed.contains(normalized)) return normalized;

  final head = normalized.split(RegExp(r'\s+')).first;
  return allowed.contains(head) ? head : null;
}

class _IrregularVerbFormsBlock extends StatelessWidget {
  const _IrregularVerbFormsBlock({required this.forms});

  final IrregularVerbForms forms;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final muted = cs.onSurface.withValues(alpha: 0.55);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'IRREGULAR VERB',
            style: context.text.kicker.copyWith(color: muted),
          ),
          const SizedBox(height: AppSpacing.xs),
          _VerbFormsPill(forms: forms),
        ],
      ),
    );
  }
}

class _VerbFormsPill extends StatelessWidget {
  const _VerbFormsPill({required this.forms});

  final IrregularVerbForms forms;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          '${forms.base} / ${forms.pastSimpleLabel} / ${forms.pastParticipleLabel}',
          style: context.text.labelSmall.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
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

class _DictionarySaveCandidate {
  const _DictionarySaveCandidate({
    required this.key,
    required this.word,
    required this.translation,
    required this.context,
    required this.usageExamples,
    this.pronunciation,
    this.partOfSpeech,
    this.anchorText,
    this.anchorContext,
    this.anchorCfiRange,
    this.anchorKind,
  });

  final String key;
  final String word;
  final String translation;
  final String? pronunciation;
  final String? partOfSpeech;
  final String? context;
  final List<String> usageExamples;
  final String? anchorText;
  final String? anchorContext;
  final String? anchorCfiRange;
  final DictionaryAnchorKind? anchorKind;
}

/// Optional explanatory rows below the main translation result.
///
/// Keeps model-specific metadata display decisions out of the sheet shell.
class _TranslationDetails extends StatelessWidget {
  const _TranslationDetails({
    required this.state,
    required this.includeSenseExplanations,
  });

  final TranslateState state;
  final bool includeSenseExplanations;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    final notes = _pairSummary(state.notes);

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
    rows.addAll(
      _senseRows(
        state.sense,
        includeExplanations: includeSenseExplanations,
      ),
    );
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

  static List<Widget> _senseRows(
    TranslationSense? sense, {
    required bool includeExplanations,
  }) {
    if (sense == null || sense.isEmpty) return const [];
    final lemmaValue = _lemmaValue(sense);
    return [
      if (lemmaValue != null)
        _TranslationDetailLine(
          label: _lemmaLabel(sense.grammaticalForm),
          value: lemmaValue,
        ),
      if (includeExplanations &&
          (sense.sourceDefinition != null || sense.targetDefinition != null))
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
      expression.lexicalUnit,
      expression.canonicalPattern,
      expression.normalizedExpression,
      expression.surface,
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
    if (normalized.contains('light verb')) return 'light verb construction';
    if (normalized.contains('support verb')) {
      return 'support verb construction';
    }
    if (normalized.contains('collocation')) return 'collocation';
    if (normalized.contains('technical')) return 'technical term';
    if (normalized.contains('multiword preposition')) {
      return 'multiword preposition';
    }
    if (normalized.contains('multiword conjunction')) {
      return 'multiword conjunction';
    }
    if (normalized.contains('multiword adverbial')) {
      return 'multiword adverbial';
    }
    if (normalized.contains('compound')) return 'compound term';
    if (normalized.contains('named entity')) return 'named entity';
    if (normalized.contains('binomial')) return 'binomial';
    if (normalized.contains('proverb') || normalized.contains('saying')) {
      return 'proverb';
    }
    if (normalized.contains('discourse')) return 'discourse marker';
    if (normalized.contains('grammaticalized')) {
      return 'grammaticalized construction';
    }
    if (normalized.contains('verb pattern')) return 'verb pattern';
    if (normalized.contains('preposition pattern')) {
      return 'preposition pattern';
    }
    if (normalized.contains('sentence pattern')) return 'sentence pattern';
    if (normalized.contains('verbal periphrasis')) {
      return 'verbal periphrasis';
    }
    if (normalized.contains('separable verb')) return 'separable verb';
    if (normalized.contains('separable word')) return 'separable word';
    if (normalized.contains('pronominal verb')) return 'pronominal verb';
    if (normalized.contains('clitic')) return 'clitic construction';
    if (normalized.contains('resultative complement')) {
      return 'resultative complement';
    }
    if (normalized.contains('directional complement')) {
      return 'directional complement';
    }
    if (normalized.contains('verb object compound')) {
      return 'verb-object compound';
    }
    if (normalized.contains('suru verb')) return 'suru verb';
    if (normalized.contains('language specific')) {
      return 'language-specific construction';
    }
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
    word: selectedWord,
    translation: selectedTranslation,
    pronunciation:
        state.sense?.transcription ?? state.sense?.lemmaTranscription,
    partOfSpeech: _selectedTermPartOfSpeech(state),
    context: _dictionaryContextForTerm(state, selectedWord),
    usageExamples: state.usageExamples,
    anchorText: selectedWord,
    anchorContext: _dictionaryContextForTerm(state, selectedWord),
    anchorCfiRange: _selectionAnchorCfiRange(selection),
    anchorKind: _selectionAnchorKind(selection, selectedWord),
  );

  final expressionCandidate = _expressionSaveCandidate(
    state,
    selection: selection,
    selectedWord: selectedWord,
  );

  return [
    selectedCandidate,
    ?expressionCandidate,
  ];
}

_DictionarySaveCandidate? _expressionSaveCandidate(
  TranslateState state, {
  required TextSelectionContext selection,
  required String selectedWord,
}) {
  final expression = state.expression;
  if (expression == null || expression.isEmpty) return null;

  final expressionSource = _expressionDictionaryHeadForTerm(
    expression,
    selectedWord,
  );
  if (!_isLargerThanTerm(expressionSource, selectedWord)) return null;

  final expressionTranslation =
      _nonEmpty(state.expressionTranslation?.target) ??
      _nonEmpty(state.suggestedFullPhrase?.target);
  if (expressionTranslation == null) return null;
  final expressionSurface =
      _expressionSurfaceText(expression) ??
      _nonEmpty(state.suggestedFullPhrase?.source) ??
      expressionSource;
  final expressionContext =
      _dictionaryContextForTerm(state, expressionSurface!) ??
      _dictionaryContextForTerm(state, expressionSource!);

  final expressionType = _TranslationDetails._expressionTypeName(
    expression.expressionType,
  );

  return _DictionarySaveCandidate(
    key: 'expression:${_normalizeForComparison(expressionSource!)}',
    word: expressionSource,
    translation: expressionTranslation,
    partOfSpeech: expressionType,
    context: expressionContext,
    usageExamples: state.usageExamples,
    anchorText: expressionSurface,
    anchorContext: expressionContext,
    anchorCfiRange: _expressionAnchorCfiRange(selection, expressionSurface),
    anchorKind: _expressionAnchorKind(selection, expressionSurface),
  );
}

String? _anchorCfiRangeForTerm(
  TextSelectionContext selection,
  String term,
) {
  final normalizedTerm = _normalizeForComparison(term);
  final selectedText = _nonEmpty(selection.selectedText);
  final normalizedSelectedText = _nonEmpty(selection.normalizedSelectedText);
  if (normalizedSelectedText != null &&
      normalizedTerm == _normalizeForComparison(normalizedSelectedText)) {
    return _nonEmpty(selection.normalizedCfiRange) ??
        _nonEmpty(selection.cfiRange);
  }
  if (selectedText != null &&
      normalizedTerm == _normalizeForComparison(selectedText)) {
    return _nonEmpty(selection.cfiRange);
  }
  return null;
}

String? _expressionAnchorCfiRange(
  TextSelectionContext selection,
  String term,
) {
  return _anchorCfiRangeForTerm(selection, term) ??
      _selectionAnchorCfiRange(selection);
}

String? _selectionAnchorCfiRange(TextSelectionContext selection) {
  final selectedText = _nonEmpty(selection.selectedText);
  if (selectedText == null) return null;

  final normalizedSelectedText = _nonEmpty(selection.normalizedSelectedText);
  if (normalizedSelectedText != null &&
      _normalizeForComparison(normalizedSelectedText) !=
          _normalizeForComparison(selectedText)) {
    return _nonEmpty(selection.normalizedCfiRange) ??
        _nonEmpty(selection.cfiRange);
  }

  return _nonEmpty(selection.cfiRange) ??
      _nonEmpty(selection.normalizedCfiRange);
}

DictionaryAnchorKind? _selectionAnchorKind(
  TextSelectionContext selection,
  String term,
) {
  if (_selectionAnchorCfiRange(selection) == null) return null;

  final selectedText = _nonEmpty(selection.selectedText);
  final normalizedSelectedText = _nonEmpty(selection.normalizedSelectedText);
  if (selectedText != null &&
      normalizedSelectedText != null &&
      _normalizeForComparison(normalizedSelectedText) !=
          _normalizeForComparison(selectedText)) {
    return DictionaryAnchorKind.normalizedSelection;
  }
  if (term.trim().length > 120) return DictionaryAnchorKind.longSelection;
  return DictionaryAnchorKind.exactSelection;
}

DictionaryAnchorKind? _expressionAnchorKind(
  TextSelectionContext selection,
  String term,
) {
  final directKind = _anchorKindForTerm(selection, term);
  if (directKind != null) return directKind;
  if (_selectionAnchorCfiRange(selection) == null) return null;
  return DictionaryAnchorKind.expression;
}

DictionaryAnchorKind? _anchorKindForTerm(
  TextSelectionContext selection,
  String term,
) {
  if (_anchorCfiRangeForTerm(selection, term) == null) return null;

  final normalizedTerm = _normalizeForComparison(term);
  final selectedText = _nonEmpty(selection.selectedText);
  final normalizedSelectedText = _nonEmpty(selection.normalizedSelectedText);
  if (normalizedSelectedText != null &&
      selectedText != null &&
      _normalizeForComparison(normalizedSelectedText) == normalizedTerm &&
      _normalizeForComparison(selectedText) != normalizedTerm) {
    return DictionaryAnchorKind.normalizedSelection;
  }
  if (term.trim().length > 120) return DictionaryAnchorKind.longSelection;
  return DictionaryAnchorKind.exactSelection;
}

String? _dictionaryContextForTerm(TranslateState state, String term) {
  final plainContext = state.selectionContextText;
  if (plainContext != null && plainContext.trim().isNotEmpty) {
    final marked = _markTermInContext(plainContext, term);
    if (marked != null) return _focusedMarkedContext(marked);
  }
  return state.dictionaryContextText;
}

String? _markTermInContext(String context, String term) {
  final normalizedTerm = term.trim();
  if (normalizedTerm.isEmpty) return null;
  final index = _findTermIndex(context, normalizedTerm);
  if (index == null) return null;
  final end = index + normalizedTerm.length;
  return '${context.substring(0, index)}'
      '${MarkedText.startMarker}${context.substring(index, end)}'
      '${MarkedText.endMarker}${context.substring(end)}';
}

String _focusedMarkedContext(String context) {
  final markerIndex = context.indexOf(MarkedText.startMarker);
  if (markerIndex < 0) return context.trim();

  final start = _sentenceStartBefore(context, markerIndex);
  final end = _sentenceEndAfter(
    context,
    markerIndex + MarkedText.startMarker.length,
  );
  return context.substring(start, end).trim();
}

int _sentenceStartBefore(String text, int focusIndex) {
  var index = focusIndex - 1;
  while (index >= 0) {
    final unit = text.codeUnitAt(index);
    if (_isSentenceBoundary(unit) || unit == 0x0A || unit == 0x0D) {
      return _skipLeadingWhitespace(text, index + 1);
    }
    index -= 1;
  }
  return _skipLeadingWhitespace(text, 0);
}

int _sentenceEndAfter(String text, int focusIndex) {
  var index = focusIndex;
  while (index < text.length) {
    final unit = text.codeUnitAt(index);
    if (_isSentenceBoundary(unit) || unit == 0x0A || unit == 0x0D) {
      return _includeTrailingClosers(text, index + 1);
    }
    index += 1;
  }
  return _trimTrailingWhitespace(text, text.length);
}

int _skipLeadingWhitespace(String text, int index) {
  var next = index;
  while (next < text.length && text.codeUnitAt(next) <= 0x20) {
    next += 1;
  }
  return next;
}

int _trimTrailingWhitespace(String text, int index) {
  var next = index;
  while (next > 0 && text.codeUnitAt(next - 1) <= 0x20) {
    next -= 1;
  }
  return next;
}

int _includeTrailingClosers(String text, int index) {
  var next = index;
  while (next < text.length) {
    final unit = text.codeUnitAt(next);
    if (unit == 0x22 || // "
        unit == 0x27 || // '
        unit == 0x29 || // )
        unit == 0x5D || // ]
        unit == 0x7D) {
      next += 1;
      continue;
    }
    break;
  }
  return _trimTrailingWhitespace(text, next);
}

bool _isSentenceBoundary(int codeUnit) {
  return codeUnit == 0x2E || // .
      codeUnit == 0x21 || // !
      codeUnit == 0x3F || // ?
      codeUnit == 0x2026; // …
}

int? _findTermIndex(String context, String term) {
  final haystack = context.toLowerCase();
  final needle = term.toLowerCase();
  var index = haystack.indexOf(needle);
  while (index >= 0) {
    final end = index + needle.length;
    if (_hasTermBoundaries(context, index, end)) return index;
    index = haystack.indexOf(needle, index + 1);
  }
  return null;
}

bool _hasTermBoundaries(String value, int start, int end) {
  final before = start == 0 ? null : value.codeUnitAt(start - 1);
  final after = end >= value.length ? null : value.codeUnitAt(end);
  return !_isTermChar(before) && !_isTermChar(after);
}

bool _isTermChar(int? codeUnit) {
  if (codeUnit == null) return false;
  return (codeUnit >= 0x30 && codeUnit <= 0x39) ||
      (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
      (codeUnit >= 0x61 && codeUnit <= 0x7A) ||
      codeUnit == 0x27;
}

String? _expressionDictionaryHeadForTerm(
  TranslationExpression expression,
  String selectedWord,
) {
  for (final value in [
    expression.lexicalUnit,
    expression.canonicalPattern,
    expression.normalizedExpression,
    expression.surface,
  ]) {
    final trimmed = _nonEmpty(value);
    if (trimmed != null && _isLargerThanTerm(trimmed, selectedWord)) {
      return trimmed;
    }
  }
  return null;
}

String? _expressionSurfaceText(TranslationExpression expression) {
  for (final value in [
    expression.surface,
    expression.normalizedExpression,
    expression.lexicalUnit,
    expression.canonicalPattern,
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
