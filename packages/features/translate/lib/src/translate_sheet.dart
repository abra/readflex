import 'package:component_library/component_library.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';
import 'package:translation_service/translation_service.dart';

import 'translate_cubit.dart';

void showTranslateSheet(
  BuildContext context, {
  required TranslationService translationService,
  required DictionaryRepository dictionaryRepository,
  required TextSelectionContext selection,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _TranslateSheet(
      translationService: translationService,
      dictionaryRepository: dictionaryRepository,
      selection: selection,
    ),
  );
}

class _TranslateSheet extends StatelessWidget {
  const _TranslateSheet({
    required this.translationService,
    required this.dictionaryRepository,
    required this.selection,
  });

  final TranslationService translationService;
  final DictionaryRepository dictionaryRepository;
  final TextSelectionContext selection;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          TranslateCubit(
            translationService: translationService,
            dictionaryRepository: dictionaryRepository,
          )..translate(
            text: selection.selectedText,
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

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.large),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BottomSheetHeader(
                    title: 'Translate',
                    onClose: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: Spacing.small),
                  // Original text
                  Container(
                    padding: const EdgeInsets.all(Spacing.medium),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                    child: Text(
                      selection.selectedText,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: Spacing.medium),
                  // Translation result
                  if (state.status == TranslateStatus.translating)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(Spacing.medium),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (state.translatedText.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(Spacing.medium),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: Text(
                        state.translatedText,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    if (state.usageExamples.isNotEmpty) ...[
                      const SizedBox(height: Spacing.small),
                      ...state.usageExamples.map(
                        (example) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: Spacing.xSmall,
                          ),
                          child: Text(
                            example,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ],
                  ],
                  if (state.status == TranslateStatus.failure)
                    Padding(
                      padding: const EdgeInsets.only(top: Spacing.small),
                      child: Text(
                        state.errorMessage ?? 'An error occurred',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: Spacing.medium),
                  if (state.status == TranslateStatus.translated ||
                      state.status == TranslateStatus.failure)
                    FilledButton.icon(
                      onPressed: isWorking
                          ? null
                          : () =>
                                context.read<TranslateCubit>().saveToDictionary(
                                  word: selection.selectedText,
                                  sourceId: selection.sourceId,
                                  sourceType: selection.sourceType,
                                ),
                      icon: const Icon(Icons.bookmark_add),
                      label: const Text('Save to Dictionary'),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
