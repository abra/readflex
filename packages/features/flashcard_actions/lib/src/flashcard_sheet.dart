import 'package:component_library/component_library.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';

import 'flashcard_cubit.dart';

void showFlashcardSheet(
  BuildContext context, {
  required FlashcardRepository flashcardRepository,
  required TextSelectionContext selection,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _FlashcardSheet(
      flashcardRepository: flashcardRepository,
      selection: selection,
    ),
  );
}

class _FlashcardSheet extends StatelessWidget {
  const _FlashcardSheet({
    required this.flashcardRepository,
    required this.selection,
  });

  final FlashcardRepository flashcardRepository;
  final TextSelectionContext selection;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FlashcardCubit(
        flashcardRepository: flashcardRepository,
      ),
      child: _FlashcardSheetView(selection: selection),
    );
  }
}

class _FlashcardSheetView extends StatelessWidget {
  const _FlashcardSheetView({required this.selection});

  final TextSelectionContext selection;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FlashcardCubit, FlashcardState>(
      listener: (context, state) {
        if (state.status == FlashcardStatus.success) {
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        final isSaving = state.status == FlashcardStatus.saving;

        return ActionBottomSheetLayout(
          title: 'Create Flashcard',
          onClose: () => Navigator.of(context).pop(),
          headerSpacing: Spacing.small,
          bodyPadding: const EdgeInsets.all(Spacing.large),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Selected text preview
              SelectionPreviewCard(text: selection.selectedText),
              const SizedBox(height: Spacing.medium),
              // Front field
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Front',
                  hintText: 'Question or term',
                  isDense: true,
                ),
                maxLines: 2,
                enabled: !isSaving,
                onChanged: (v) => context.read<FlashcardCubit>().setFront(v),
              ),
              const SizedBox(height: Spacing.small),
              // Back field
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Back',
                  hintText: 'Answer or definition',
                  isDense: true,
                ),
                maxLines: 2,
                enabled: !isSaving,
                onChanged: (v) => context.read<FlashcardCubit>().setBack(v),
              ),
              const SizedBox(height: Spacing.small),
              // Hint field
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Hint (optional)',
                  isDense: true,
                ),
                enabled: !isSaving,
                onChanged: (v) => context.read<FlashcardCubit>().setHint(v),
              ),
              const SizedBox(height: Spacing.medium),
              if (state.status == FlashcardStatus.failure)
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.small),
                  child: Text(
                    'Failed to save flashcard',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              FilledButton(
                onPressed: isSaving || !state.canSave
                    ? null
                    : () => context.read<FlashcardCubit>().save(
                        sourceId: selection.sourceId,
                        sourceType: selection.sourceType,
                      ),
                child: isSaving
                    ? const ButtonLoadingIndicator()
                    : const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }
}
