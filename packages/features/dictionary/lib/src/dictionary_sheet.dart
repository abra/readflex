import 'package:component_library/component_library.dart';
import 'package:dictionary_service/dictionary_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
      child: _DictionarySheetView(selection: selection),
    );
  }
}

class _DictionarySheetView extends StatelessWidget {
  const _DictionarySheetView({required this.selection});

  final TextSelectionContext selection;

  @override
  Widget build(BuildContext context) {
    return ActionBottomSheetLayout(
      title: context.l10n.dictionaryTitle,
      headerSpacing: AppSpacing.sm,
      bodyPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: BlocBuilder<DictionaryCubit, DictionarySheetState>(
        builder: (context, state) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectionPreviewCard(text: selection.effectiveSelectedText),
              const SizedBox(height: AppSpacing.lg),
              _DictionaryBody(selection: selection, state: state),
            ],
          );
        },
      ),
    );
  }
}

class _DictionaryBody extends StatelessWidget {
  const _DictionaryBody({required this.selection, required this.state});

  final TextSelectionContext selection;
  final DictionarySheetState state;

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
  const _DictionaryResultView({required this.result});

  final DictionaryLookupResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < result.entries.length; index++) ...[
          if (index > 0) ...[
            const SizedBox(height: AppSpacing.lg),
            Divider(color: context.colors.outlineVariant),
            const SizedBox(height: AppSpacing.md),
          ],
          _DictionaryEntryView(entry: result.entries[index]),
        ],
      ],
    );
  }
}

class _DictionaryEntryView extends StatelessWidget {
  const _DictionaryEntryView({required this.entry});

  final DictionaryLexicalEntry entry;

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
        SelectableText(entry.lemma, style: context.text.headlineSmall),
        if (metadata.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            metadata.join(' · '),
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

class _DefinitionView extends StatelessWidget {
  const _DefinitionView({required this.number, required this.definition});

  final int number;
  final DictionaryDefinition definition;

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}

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
