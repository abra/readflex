import 'package:component_library/component_library.dart';
import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared/shared.dart';

import 'translate_cubit.dart';
import 'translation_language_direction.dart';
import 'translate_sheet_outcome.dart';
import 'translation_selection_mode.dart';
import 'translation_text_direction.dart';

part 'translation_answer_style.dart';
part 'translation_details.dart';
part 'translation_grammar_line.dart';
part 'translation_lexical_header.dart';
part 'translation_selection_preview.dart';

/// Shows the translation sheet for [selection]. Completes with
/// [TranslateSheetOutcome.define] when the reader asked for the definition
/// instead, or `null` when the sheet was dismissed.
Future<TranslateSheetOutcome?> showTranslateSheet(
  BuildContext context, {
  required TextSelectionContext selection,
  required ContextualTranslationService translationService,
  required PreferencesService preferencesService,
  bool canDefine = false,
}) {
  return showAppBottomSheet<TranslateSheetOutcome>(
    context,
    builder: (_) => TranslateSheet(
      selection: selection,
      translationService: translationService,
      preferencesService: preferencesService,
      canDefine: canDefine,
    ),
  );
}

class TranslateSheet extends StatelessWidget {
  const TranslateSheet({
    required this.selection,
    required this.translationService,
    required this.preferencesService,
    this.canDefine = false,
    super.key,
  });

  final TextSelectionContext selection;
  final ContextualTranslationService translationService;
  final PreferencesService preferencesService;

  /// Whether the caller can open a definition, offered when a word is
  /// already in the target language.
  final bool canDefine;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TranslateCubit(
        translationService: translationService,
        preferencesService: preferencesService,
      )..translate(selection),
      child: _TranslateSheetView(
        selection: selection,
        canDefine: canDefine,
        onCopy: (text) => Clipboard.setData(ClipboardData(text: text)),
      ),
    );
  }
}

class _TranslateSheetView extends StatefulWidget {
  const _TranslateSheetView({
    required this.selection,
    required this.canDefine,
    required this.onCopy,
  });

  final TextSelectionContext selection;
  final bool canDefine;
  final Future<void> Function(String) onCopy;

  @override
  State<_TranslateSheetView> createState() => _TranslateSheetViewState();
}

class _TranslateSheetViewState extends State<_TranslateSheetView> {
  final _sourceMenu = MenuController();
  final _targetMenu = MenuController();

  void _chooseSourceLanguage() {
    if (context.read<TranslateCubit>().state.isBusy) return;
    _sourceMenu.open();
  }

  void _chooseTargetLanguage() {
    if (context.read<TranslateCubit>().state.isBusy) return;
    _targetMenu.open();
  }

  /// Closes the sheet so the action that opened it shows the definition,
  /// from a context that outlives this sheet.
  void _define() => Navigator.of(context).pop(TranslateSheetOutcome.define);

  @override
  Widget build(BuildContext context) {
    final selection = widget.selection;
    return BlocBuilder<TranslateCubit, TranslateSheetState>(
      builder: (context, state) {
        final cubit = context.read<TranslateCubit>();
        return ActionBottomSheetLayout.scrollable(
          bodyPadding: state.status == TranslateSheetStatus.success
              ? const EdgeInsets.only(bottom: AppSpacing.lg)
              : const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.lg,
                ),
          title: context.l10n.translationTitle,
          onClose: () => Navigator.of(context).pop(),
          closeLabel: context.l10n.commonClose,
          headerBottom: TranslationLanguageDirection(
            sourceLanguageCode: state.sourceLanguageCode,
            targetLanguageCode: state.targetLanguageCode,
            detectedSourceLanguage: state.detectedSourceLanguage,
            enabled: !state.isBusy,
            sourceMenu: _sourceMenu,
            targetMenu: _targetMenu,
            onSourceChanged: (value) =>
                cubit.setSourceLanguage(selection, value),
            onTargetChanged: (value) =>
                cubit.setTargetLanguage(selection, value),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.status != TranslateSheetStatus.success) ...[
                _TranslationSelectionPreview.quote(selection: selection),
                const SizedBox(height: AppSpacing.md),
              ],
              _TranslateBody(
                selection: selection,
                state: state,
                onChooseSourceLanguage: _chooseSourceLanguage,
                onChooseTargetLanguage: _chooseTargetLanguage,
                onDefine: widget.canDefine ? _define : null,
                onCopy: widget.onCopy,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TranslateBody extends StatelessWidget {
  const _TranslateBody({
    required this.selection,
    required this.state,
    required this.onChooseSourceLanguage,
    required this.onChooseTargetLanguage,
    required this.onDefine,
    required this.onCopy,
  });

  final TextSelectionContext selection;
  final TranslateSheetState state;
  final VoidCallback onChooseSourceLanguage;
  final VoidCallback onChooseTargetLanguage;
  final VoidCallback? onDefine;
  final Future<void> Function(String) onCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<TranslateCubit>();
    return switch (state.status) {
      TranslateSheetStatus.initial ||
      TranslateSheetStatus.loading => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: CenteredCircularProgressIndicator(),
      ),
      TranslateSheetStatus.downloadingOfflineModel => AppStatusMessage(
        title: l10n.translationDownloadingModels,
        body: l10n.translationDownloadingModelsBody,
        busy: true,
      ),
      TranslateSheetStatus.success => _TranslationResultView(
        selection: selection,
        result: state.result!,
        onCopy: onCopy,
      ),
      TranslateSheetStatus.sourceLanguageRequired => AppStatusMessage(
        title: l10n.translationSourceRequiredTitle,
        body: l10n.translationSourceRequiredBody,
        actionLabel: l10n.translationSelectLanguage,
        onAction: onChooseSourceLanguage,
      ),
      TranslateSheetStatus.offlineModelRequired => AppStatusMessage(
        title: l10n.translationOfflineModelTitle,
        body: l10n.translationOfflineModelBody(
          translationLanguageName(state.failure?.sourceLanguage) ??
              l10n.translationUnknownLanguage,
          translationLanguageName(state.failure?.targetLanguage) ??
              l10n.translationUnknownLanguage,
        ),
        actionLabel: l10n.translationDownloadModels,
        onAction: () =>
            cubit.translate(selection, allowOfflineModelDownload: true),
      ),
      TranslateSheetStatus.failure => AppStatusMessage(
        title: l10n.translationFailureTitle,
        body: l10n.translationFailureBody,
        actionLabel: l10n.commonRetry,
        onAction: () => cubit.translate(selection),
      ),
      TranslateSheetStatus.sameLanguage => _SameLanguageMessage(
        selection: selection,
        targetLanguageCode: state.targetLanguageCode,
        onDefine: onDefine,
        onChooseTargetLanguage: onChooseTargetLanguage,
      ),
    };
  }
}

/// The text is already in the target language, so nothing is translated.
///
/// A word or phrase offers its definition: in the language it is written in,
/// a definition is what an English to English request means. Longer text, or
/// a caller without a dictionary, points to the target language menu.
class _SameLanguageMessage extends StatelessWidget {
  const _SameLanguageMessage({
    required this.selection,
    required this.targetLanguageCode,
    required this.onDefine,
    required this.onChooseTargetLanguage,
  });

  final TextSelectionContext selection;
  final String targetLanguageCode;
  final VoidCallback? onDefine;
  final VoidCallback onChooseTargetLanguage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final language =
        translationLanguageName(targetLanguageCode) ??
        l10n.translationUnknownLanguage;
    final onDefine = this.onDefine;
    final define =
        onDefine != null &&
            translationModeForSelection(selection) == contextualTranslationMode
        ? onDefine
        : null;
    return AppStatusMessage(
      key: const ValueKey('translation-same-language'),
      title: l10n.translationSameLanguageTitle,
      body: define != null
          ? l10n.translationSameLanguageDefineBody(
              language,
              l10n.dictionaryAction,
            )
          : l10n.translationSameLanguageBody(language),
      actionLabel: define != null
          ? l10n.dictionaryAction
          : l10n.translationSelectLanguage,
      onAction: define ?? onChooseTargetLanguage,
    );
  }
}

class _TranslationResultView extends StatelessWidget {
  const _TranslationResultView({
    required this.selection,
    required this.result,
    required this.onCopy,
  });

  final TextSelectionContext selection;
  final ContextualTranslationResult result;
  final Future<void> Function(String) onCopy;

  @override
  Widget build(BuildContext context) {
    final isTextTranslation = result.mode == selectedTextTranslationMode;
    final selectedText = selection.effectiveSelectedText.trim();
    final analysis = result.analysis;
    // Expression metadata may describe more tokens than the selected word.
    final isWordWithinExpression =
        analysis != null &&
        analysis.selectedTokenIds.length == 1 &&
        analysis.expressionTokenIds.length > 1 &&
        analysis.expressionTokenIds.contains(analysis.selectedTokenIds.single);
    final isSingleWord =
        !isTextTranslation &&
        selectedText.isNotEmpty &&
        !_selectionWhitespacePattern.hasMatch(selectedText) &&
        (isWordWithinExpression ||
            !const {
              'phrase',
              'phrasal_verb',
              'idiom',
              'expression',
            }.contains(analysis?.expressionType?.trim().toLowerCase()));
    final base = _nonEmptyText(result.translation.baseTranslation);
    // The backend grounds this optional expression in the selected occurrence.
    final expression = isSingleWord ? result.contextualExpression : null;
    final primary = _firstNonEmptyText([
      expression?.translation,
      result.translation.contextualTranslation,
      result.translation.translatedFragment,
      result.translation.baseTranslation,
      result.translation.sentenceTranslation,
    ]);
    // Equal answers are redundant only when they describe the same source span.
    final showWordAnswer =
        isSingleWord &&
        base != null &&
        (expression != null ||
            _normalizedAnswer(base) != _normalizedAnswer(primary ?? ''));
    final showContextSection = expression != null || showWordAnswer;
    final sentenceTranslation = _nonEmptyText(
      result.translation.sentenceTranslation,
    );
    // A sentence translation equal to the answer adds nothing.
    final visibleSentenceTranslation =
        !isTextTranslation &&
            sentenceTranslation != null &&
            _normalizedAnswer(sentenceTranslation) !=
                _normalizedAnswer(primary ?? '')
        ? sentenceTranslation
        : null;
    final explanation = _nonEmptyText(result.explanation);
    final alternatives = result.alternatives
        .map((alternative) => alternative.translation.trim())
        .where((translation) => translation.isNotEmpty)
        .toList(growable: false);
    final l10n = context.l10n;
    final offline =
        result.reliability == ContextualTranslationReliability.offline;
    // The selection on top as a quiet label, then one outlined section per
    // answer, the sentence and the details. The translation is the only
    // large text.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isTextTranslation)
          _Gutter(
            child: _TranslationLexicalHeader(
              key: const ValueKey('translation-lexical-header'),
              selectedText: selectedText,
              isSingleWord: isSingleWord,
              analysis: result.analysis,
            ),
          ),
        if (offline) ...[
          if (!isTextTranslation) const SizedBox(height: AppSpacing.sm),
          _Gutter(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: _OfflineBadge(label: l10n.translationOffline),
            ),
          ),
        ],
        if (!isTextTranslation || offline)
          const SizedBox(height: AppSpacing.lg),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.md,
          children: [
            // Answer rows keep the section's room themselves, so Copy is
            // centered on the answer rather than pushed below the title.
            if (primary != null)
              AppSheetSection(
                padding: EdgeInsets.zero,
                child: _TranslationAnswer(
                  id: 'primary',
                  text: primary,
                  onCopy: onCopy,
                  emphasized: !isTextTranslation,
                  title: showContextSection ? l10n.translationInContext : null,
                  expression: expression?.text,
                ),
              ),
            if (showWordAnswer)
              AppSheetSection(
                padding: EdgeInsets.zero,
                child: _TranslationAnswer(
                  id: 'base',
                  text: base,
                  onCopy: onCopy,
                  title: l10n.translationWordMeaning,
                ),
              ),
            _SentenceSection(
              selection: selection,
              isTextTranslation: isTextTranslation,
              translation: visibleSentenceTranslation,
            ),
            if (!isTextTranslation &&
                (explanation != null || alternatives.isNotEmpty))
              AppSheetSection(
                padding: EdgeInsets.zero,
                child: _Gutter(
                  child: _TranslationDetails(
                    key: ValueKey(result.requestId),
                    explanation: explanation,
                    alternatives: alternatives,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Gutter extends StatelessWidget {
  const _Gutter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
    child: child,
  );
}

/// The selection's sentence, or for text translation the original, in its
/// section: the source muted, its [translation] below when there is one.
class _SentenceSection extends StatelessWidget {
  const _SentenceSection({
    required this.selection,
    required this.isTextTranslation,
    required this.translation,
  });

  final TextSelectionContext selection;
  final bool isTextTranslation;

  /// The sentence translation to show, `null` when absent or redundant.
  final String? translation;

  @override
  Widget build(BuildContext context) {
    final translation = this.translation;
    return AppSheetSection(
      title: isTextTranslation
          ? context.l10n.translationOriginal
          : context.l10n.translationSentence,
      child: _Gutter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TranslationSelectionPreview.source(
              selection: selection,
              showContext: !isTextTranslation,
            ),
            if (translation != null) ...[
              const SizedBox(height: AppSpacing.sm),
              SelectableText(
                translation,
                key: const ValueKey('translation-sentence-result'),
                textDirection: translationTextDirection(translation),
                style: context.text.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final _selectionWhitespacePattern = RegExp(r'\s');

String _normalizedAnswer(String value) =>
    value.replaceAll(_whitespaceRun, ' ').trim().toLowerCase();

final _whitespaceRun = RegExp(r'\s+');

/// An answer with its Copy action on its first line, under its section
/// [title] and the source [expression] it translates. The row keeps 12dp of
/// room inside its section's outline at any text size.
///
/// An [emphasized] answer uses the heading style when it is short.
class _TranslationAnswer extends StatelessWidget {
  const _TranslationAnswer({
    required this.id,
    required this.text,
    required this.onCopy,
    this.emphasized = false,
    this.title,
    this.expression,
  });

  final String id;
  final String text;
  final Future<void> Function(String) onCopy;
  final bool emphasized;
  final String? title;
  final String? expression;

  @override
  Widget build(BuildContext context) {
    final direction = translationTextDirection(text);
    final title = this.title;
    final expression = this.expression;
    final source = expression == null
        ? null
        : SelectableText(
            expression,
            key: const ValueKey('translation-contextual-expression'),
            textDirection: translationTextDirection(expression),
            // Regular weight: the section title above is the bold line.
            style: context.text.titleMedium.copyWith(
              letterSpacing: 0,
              fontWeight: FontWeight.w400,
            ),
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        final style = emphasized
            ? _answerHeadingStyle(
                context,
                text,
                AppSheetActionRow.childWidthFor(constraints.maxWidth),
              )
            : _answerBodyStyle(context);
        return AppSheetActionRow(
          // An LTR answer in an RTL UI keeps Copy trailing the text it copies.
          textDirection: direction,
          firstLineStyle: style,
          lead: switch ((title, source)) {
            (final title?, final source?) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSheetSectionTitle(title),
                const SizedBox(height: AppSpacing.sm),
                source,
              ],
            ),
            (final title?, null) => AppSheetSectionTitle(title),
            (null, final source?) => source,
            (null, null) => null,
          },
          // A title is as far from its answer as from any section content;
          // a source expression sits close to its translation.
          leadSpacing: source == null ? AppSpacing.sm : AppSpacing.xs,
          minTextRoom: AppSpacing.md,
          action: KeyedSubtree(
            key: ValueKey('translation-$id-copy'),
            child: AppCopyButton(
              key: ValueKey(text),
              onCopy: () => onCopy(text),
              copyLabel: context.l10n.commonCopy,
              copiedLabel: context.l10n.commonCopied,
              failureLabel: context.l10n.commonCopyFailed,
            ),
          ),
          child: SelectableText(
            text,
            key: ValueKey('translation-$id-result'),
            textDirection: direction,
            style: style,
          ),
        );
      },
    );
  }
}

String? _firstNonEmptyText(Iterable<String?> values) {
  for (final value in values) {
    final text = _nonEmptyText(value);
    if (text != null) return text;
  }
  return null;
}

String? _nonEmptyText(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? null : text;
}

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(label, style: context.text.labelSmall),
      ),
    );
  }
}
