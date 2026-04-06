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
    builder: (_) => TranslateSheet(
      translationService: translationService,
      dictionaryRepository: dictionaryRepository,
      selection: selection,
    ),
  );
}

class TranslateSheet extends StatelessWidget {
  const TranslateSheet({
    required this.translationService,
    required this.dictionaryRepository,
    required this.selection,
    super.key,
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

        return ActionBottomSheetLayout(
          title: 'Translate',
          onClose: () => Navigator.of(context).pop(),
          headerSpacing: AppSpacing.sm,
          bodyPadding: const EdgeInsets.all(AppSpacing.xl),
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
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    state.translatedText,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                if (state.usageExamples.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  ...state.usageExamples.map(
                    (example) => Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppSpacing.xs,
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
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    state.errorMessage ?? 'An error occurred',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
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
                          word: selection.selectedText,
                          sourceId: selection.sourceId,
                          sourceType: selection.sourceType,
                        ),
                  icon: state.status == TranslateStatus.saving
                      ? const ButtonLoadingIndicator(size: 18)
                      : const Icon(Icons.bookmark_add),
                  label: const Text('Save to Dictionary'),
                ),
            ],
          ),
        );
      },
    );
  }
}
