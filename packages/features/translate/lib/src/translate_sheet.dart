import 'package:component_library/component_library.dart';
import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared/shared.dart';

import 'translate_cubit.dart';
import 'translation_details.dart';
import 'translation_language_direction.dart';
import 'translation_lexical_header.dart';
import 'translation_selection_preview.dart';
import 'translation_text_direction.dart';

Future<void> showTranslateSheet(
  BuildContext context, {
  required TextSelectionContext selection,
  required ContextualTranslationService translationService,
  required PreferencesService preferencesService,
}) {
  return showAppBottomSheet<void>(
    context,
    builder: (_) => TranslateSheet(
      selection: selection,
      translationService: translationService,
      preferencesService: preferencesService,
    ),
  );
}

class TranslateSheet extends StatelessWidget {
  const TranslateSheet({
    required this.selection,
    required this.translationService,
    required this.preferencesService,
    super.key,
  });

  final TextSelectionContext selection;
  final ContextualTranslationService translationService;
  final PreferencesService preferencesService;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TranslateCubit(
        translationService: translationService,
        preferencesService: preferencesService,
      )..translate(selection),
      child: _TranslateSheetView(
        selection: selection,
        onCopy: (text) => Clipboard.setData(ClipboardData(text: text)),
      ),
    );
  }
}

class _TranslateSheetView extends StatefulWidget {
  const _TranslateSheetView({required this.selection, required this.onCopy});

  final TextSelectionContext selection;
  final Future<void> Function(String) onCopy;

  @override
  State<_TranslateSheetView> createState() => _TranslateSheetViewState();
}

class _TranslateSheetViewState extends State<_TranslateSheetView> {
  final _sourceMenu = MenuController();
  final _sourcePickerKey = GlobalKey();

  Future<void> _chooseSourceLanguage() async {
    final pickerContext = _sourcePickerKey.currentContext;
    if (pickerContext == null) return;
    await Scrollable.ensureVisible(pickerContext);
    if (!mounted || context.read<TranslateCubit>().state.isBusy) return;
    _sourceMenu.open();
  }

  @override
  Widget build(BuildContext context) {
    final selection = widget.selection;
    final maxBodyHeight = MediaQuery.sizeOf(context).height * 0.68;
    return ActionBottomSheetLayout(
      title: context.l10n.translationTitle,
      headerSpacing: AppSpacing.sm,
      constrainBody: true,
      bodyPadding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxBodyHeight),
        child: ScrollEdgeFadeStack(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: BlocBuilder<TranslateCubit, TranslateSheetState>(
              builder: (context, state) {
                final cubit = context.read<TranslateCubit>();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TranslationLanguageDirection(
                      sourceLanguageCode: state.sourceLanguageCode,
                      targetLanguageCode: state.targetLanguageCode,
                      detectedSourceLanguage:
                          state.result?.detectedSourceLanguage,
                      enabled: !state.isBusy,
                      sourceMenu: _sourceMenu,
                      sourcePickerKey: _sourcePickerKey,
                      onSourceChanged: (value) =>
                          cubit.setSourceLanguage(selection, value),
                      onTargetChanged: (value) =>
                          cubit.setTargetLanguage(selection, value),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (state.status != TranslateSheetStatus.success) ...[
                      TranslationSelectionPreview(
                        selection: selection,
                        showContext: false,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    _TranslateBody(
                      selection: selection,
                      state: state,
                      onChooseSourceLanguage: _chooseSourceLanguage,
                      onCopy: widget.onCopy,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TranslateBody extends StatelessWidget {
  const _TranslateBody({
    required this.selection,
    required this.state,
    required this.onChooseSourceLanguage,
    required this.onCopy,
  });

  final TextSelectionContext selection;
  final TranslateSheetState state;
  final VoidCallback onChooseSourceLanguage;
  final Future<void> Function(String) onCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<TranslateCubit>();
    return switch (state.status) {
      TranslateSheetStatus.initial ||
      TranslateSheetStatus.loading => const _LoadingTranslation(),
      TranslateSheetStatus.downloadingOfflineModel => _MessageWithAction(
        title: l10n.translationDownloadingModels,
        body: l10n.translationDownloadingModelsBody,
        loading: true,
      ),
      TranslateSheetStatus.success => _TranslationResultView(
        selection: selection,
        result: state.result!,
        onCopy: onCopy,
      ),
      TranslateSheetStatus.sourceLanguageRequired => _MessageWithAction(
        title: l10n.translationSourceRequiredTitle,
        body: l10n.translationSourceRequiredBody,
        actionLabel: l10n.translationSelectLanguage,
        onPressed: onChooseSourceLanguage,
      ),
      TranslateSheetStatus.offlineModelRequired => _MessageWithAction(
        title: l10n.translationOfflineModelTitle,
        body: l10n.translationOfflineModelBody(
          translationLanguageName(state.failure?.sourceLanguage) ?? '?',
          translationLanguageName(state.failure?.targetLanguage) ?? '?',
        ),
        actionLabel: l10n.translationDownloadModels,
        onPressed: () =>
            cubit.translate(selection, allowOfflineModelDownload: true),
      ),
      TranslateSheetStatus.failure => _MessageWithAction(
        title: l10n.translationFailureTitle,
        body: l10n.translationFailureBody,
        actionLabel: l10n.commonRetry,
        onPressed: () => cubit.translate(selection),
      ),
    };
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
    final explanation = _nonEmptyText(result.explanation);
    final alternatives = result.alternatives
        .map((alternative) => alternative.translation.trim())
        .where((translation) => translation.isNotEmpty)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isTextTranslation) ...[
          TranslationLexicalHeader(
            selectedText: selectedText,
            isSingleWord: isSingleWord,
            analysis: result.analysis,
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        if (result.reliability == ContextualTranslationReliability.offline) ...[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: _OfflineBadge(label: context.l10n.translationOffline),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (showWordAnswer)
          _TranslationAnswer(id: 'base', text: base, onCopy: onCopy),
        if (showContextSection) ...[
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: context.colors.outlineVariant),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            header: true,
            child: Text(
              context.l10n.translationInContext,
              style: context.text.labelMedium.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (expression != null)
          SelectableText(
            expression.text,
            key: const ValueKey('translation-contextual-expression'),
            textDirection: translationTextDirection(expression.text),
            style: context.text.titleMedium.copyWith(letterSpacing: 0),
          ),
        if (primary != null)
          _TranslationAnswer(id: 'primary', text: primary, onCopy: onCopy),
        if (!showContextSection) ...[
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: context.colors.outlineVariant),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            header: true,
            child: Text(
              isTextTranslation
                  ? context.l10n.translationOriginal
                  : context.l10n.translationSentence,
              style: context.text.labelMedium.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        TranslationSelectionPreview(
          selection: selection,
          showContext: !isTextTranslation,
        ),
        if (!isTextTranslation &&
            sentenceTranslation != null &&
            _normalizedAnswer(sentenceTranslation) !=
                _normalizedAnswer(primary ?? '')) ...[
          const SizedBox(height: AppSpacing.sm),
          SelectableText(
            sentenceTranslation,
            key: const ValueKey('translation-sentence-result'),
            textDirection: translationTextDirection(sentenceTranslation),
            style: context.text.bodyMedium,
          ),
        ],
        if (!isTextTranslation &&
            (explanation != null || alternatives.isNotEmpty)) ...[
          const SizedBox(height: AppSpacing.md),
          TranslationDetails(
            key: ValueKey(result.requestId),
            explanation: explanation,
            alternatives: alternatives,
          ),
        ],
      ],
    );
  }
}

final _selectionWhitespacePattern = RegExp(r'\s');

String _normalizedAnswer(String value) =>
    value.replaceAll(_answerWhitespacePattern, ' ').trim().toLowerCase();

final _answerWhitespacePattern = RegExp(r'\s+');

class _TranslationAnswer extends StatelessWidget {
  const _TranslationAnswer({
    required this.id,
    required this.text,
    required this.onCopy,
  });

  final String id;
  final String text;
  final Future<void> Function(String) onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: SelectableText(
              text,
              key: ValueKey('translation-$id-result'),
              textDirection: translationTextDirection(text),
              style: context.text.bodyLarge.copyWith(letterSpacing: 0),
            ),
          ),
        ),
        KeyedSubtree(
          key: ValueKey('translation-$id-copy'),
          child: AppCopyButton(
            key: ValueKey(text),
            onCopy: () => onCopy(text),
            copyLabel: context.l10n.commonCopy,
            copiedLabel: context.l10n.commonCopied,
            failureLabel: context.l10n.commonCopyFailed,
          ),
        ),
      ],
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

class _LoadingTranslation extends StatelessWidget {
  const _LoadingTranslation();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _MessageWithAction extends StatelessWidget {
  const _MessageWithAction({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onPressed,
    this.loading = false,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: context.text.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          body,
          style: context.text.bodyMedium.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        if (loading) ...[
          const SizedBox(height: AppSpacing.md),
          const LinearProgressIndicator(),
        ],
        if (actionLabel != null) ...[
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: onPressed,
            child: AppButtonLabel(actionLabel!),
          ),
        ],
      ],
    );
  }
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
