import 'package:component_library/component_library.dart';
import 'package:dictionary_service/dictionary_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' show Bidi;
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared/shared.dart';

import 'dictionary_cubit.dart';

Future<void> showDictionarySheet(
  BuildContext context, {
  required TextSelectionContext selection,
  required DictionaryLookupService dictionaryService,
}) {
  return showAppBottomSheet<void>(
    context,
    builder: (_) => DictionarySheet(
      selection: selection,
      dictionaryService: dictionaryService,
    ),
  );
}

class DictionarySheet extends StatelessWidget {
  const DictionarySheet({
    required this.selection,
    required this.dictionaryService,
    super.key,
  });

  final TextSelectionContext selection;
  final DictionaryLookupService dictionaryService;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          DictionaryCubit(dictionaryService: dictionaryService)
            ..lookup(selection),
      child: _DictionarySheetView(
        selection: selection,
        onCopy: (text) => Clipboard.setData(ClipboardData(text: text)),
      ),
    );
  }
}

class _DictionarySheetView extends StatelessWidget {
  const _DictionarySheetView({required this.selection, required this.onCopy});

  final TextSelectionContext selection;
  final Future<void> Function(String) onCopy;

  @override
  Widget build(BuildContext context) {
    final maxBodyHeight = MediaQuery.sizeOf(context).height * 0.68;
    return ActionBottomSheetLayout(
      title: context.l10n.dictionaryTitle,
      headerSpacing: AppSpacing.sm,
      constrainBody: true,
      bodyPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxBodyHeight),
        child: SingleChildScrollView(
          child: BlocBuilder<DictionaryCubit, DictionarySheetState>(
            builder: (context, state) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.status != DictionarySheetStatus.success) ...[
                    Text(
                      selection.effectiveSelectedText,
                      textDirection: _contentDirection(
                        selection.effectiveSelectedText,
                      ),
                      style: context.text.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  _DictionaryBody(
                    selection: selection,
                    state: state,
                    onCopy: onCopy,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DictionaryBody extends StatelessWidget {
  const _DictionaryBody({
    required this.selection,
    required this.state,
    required this.onCopy,
  });

  final TextSelectionContext selection;
  final DictionarySheetState state;
  final Future<void> Function(String) onCopy;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DictionaryCubit>();
    return switch (state.status) {
      DictionarySheetStatus.initial ||
      DictionarySheetStatus.loading => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: CircularProgressIndicator(),
        ),
      ),
      DictionarySheetStatus.success => _DictionaryResultView(
        result: state.result!,
        selectedText: selection.effectiveSelectedText,
        onCopy: onCopy,
      ),
      DictionarySheetStatus.notFound => _DictionaryMessage(
        title: context.l10n.dictionaryNotFoundTitle,
        body: context.l10n.dictionaryNotFoundBody,
      ),
      DictionarySheetStatus.unsupportedLanguage => _DictionaryMessage(
        title: context.l10n.dictionaryUnsupportedLanguageTitle,
        body: context.l10n.dictionaryUnsupportedLanguageBody,
      ),
      DictionarySheetStatus.failure => _DictionaryMessage(
        title: context.l10n.dictionaryFailureTitle,
        body: context.l10n.dictionaryFailureBody,
        actionLabel: context.l10n.commonRetry,
        onPressed: () => cubit.lookup(selection),
      ),
    };
  }
}

class _DictionaryResultView extends StatelessWidget {
  const _DictionaryResultView({
    required this.result,
    required this.selectedText,
    required this.onCopy,
  });

  final DictionaryLookupResult result;
  final String selectedText;
  final Future<void> Function(String) onCopy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < result.entries.length; index++) ...[
          if (index > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Divider(height: 1, color: context.colors.outlineVariant),
            const SizedBox(height: AppSpacing.md),
            if (index == 1) ...[
              Semantics(
                header: true,
                child: Text(
                  context.l10n.dictionaryInContext,
                  style: context.text.labelMedium.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
          _DictionaryEntryView(
            entry: result.entries[index],
            selectedText: index == 0 ? selectedText : null,
            onCopy: onCopy,
          ),
        ],
      ],
    );
  }
}

class _DictionaryEntryView extends StatelessWidget {
  const _DictionaryEntryView({
    required this.entry,
    required this.selectedText,
    required this.onCopy,
  });

  final DictionaryLexicalEntry entry;
  final String? selectedText;
  final Future<void> Function(String) onCopy;

  @override
  Widget build(BuildContext context) {
    final metadata = [
      entry.reading,
      entry.pronunciation,
      entry.partOfSpeech,
    ].whereType<String>().where((value) => value.isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: _DictionaryLemma(
                  lemma: entry.lemma,
                  selectedText: selectedText,
                ),
              ),
            ),
            AppCopyButton(
              key: ValueKey(entry),
              onCopy: () => onCopy(
                [
                  entry.lemma,
                  for (var i = 0; i < entry.definitions.length; i++)
                    '${i + 1}. ${entry.definitions[i].text}',
                ].join('\n'),
              ),
              copyLabel: context.l10n.commonCopy,
              copiedLabel: context.l10n.commonCopied,
              failureLabel: context.l10n.commonCopyFailed,
            ),
          ],
        ),
        if (metadata.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            metadata.join(' · '),
            textDirection: _contentDirection(metadata.join(' ')),
            style: context.text.bodyMedium.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        for (var index = 0; index < entry.definitions.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _DefinitionView(
              number: index + 1,
              definition: entry.definitions[index],
            ),
          ),
      ],
    );
  }
}

class _DictionaryLemma extends StatelessWidget {
  const _DictionaryLemma({required this.lemma, required this.selectedText});

  final String lemma;
  final String? selectedText;

  @override
  Widget build(BuildContext context) {
    final selected = selectedText?.trim();
    final hasDifferentForm =
        selected != null &&
        selected.isNotEmpty &&
        selected.toLowerCase() != lemma.trim().toLowerCase();
    final direction = _contentDirection(lemma);
    return Directionality(
      textDirection: direction,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (hasDifferentForm) ...[
            Text(
              selected,
              style: context.text.bodyMedium.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            ExcludeSemantics(
              child: Transform.flip(
                flipX: direction == TextDirection.rtl,
                child: Icon(
                  AppIcons.arrowRight,
                  size: AppIconSize.xs,
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
          Semantics(
            header: true,
            child: SelectableText(lemma, style: context.text.titleLarge),
          ),
        ],
      ),
    );
  }
}

class _DefinitionView extends StatelessWidget {
  const _DefinitionView({required this.number, required this.definition});

  final int number;
  final DictionaryDefinition definition;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _contentDirection(definition.text),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$number.',
              style: context.text.bodyMedium.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SelectableText(definition.text, style: context.text.bodyMedium),
                for (final example in definition.examples) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    example,
                    textDirection: _contentDirection(example),
                    style: context.text.bodySmall.copyWith(
                      color: context.colors.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

TextDirection _contentDirection(String text) =>
    Bidi.detectRtlDirectionality(text) ? TextDirection.rtl : TextDirection.ltr;

class _DictionaryMessage extends StatelessWidget {
  const _DictionaryMessage({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onPressed,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onPressed;

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
