import 'package:component_library/component_library.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';

import 'flashcard_editor_cubit.dart';

void showFlashcardEditorSheet(
  BuildContext context, {
  required FlashcardRepository flashcardRepository,
  required TextSelectionContext selection,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _FlashcardEditorSheet(
      flashcardRepository: flashcardRepository,
      selection: selection,
    ),
  );
}

class _FlashcardEditorSheet extends StatelessWidget {
  const _FlashcardEditorSheet({
    required this.flashcardRepository,
    required this.selection,
  });

  final FlashcardRepository flashcardRepository;
  final TextSelectionContext selection;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FlashcardEditorCubit(
        flashcardRepository: flashcardRepository,
      ),
      child: _FlashcardEditorSheetView(selection: selection),
    );
  }
}

class _FlashcardEditorSheetView extends StatelessWidget {
  const _FlashcardEditorSheetView({required this.selection});

  final TextSelectionContext selection;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FlashcardEditorCubit, FlashcardEditorState>(
      listener: (context, state) {
        if (state.status == FlashcardEditorStatus.success) {
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        final isSaving = state.status == FlashcardEditorStatus.saving;

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
                    title: 'Create Flashcard',
                    onClose: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: Spacing.small),
                  // Selected text preview
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
                  // Front field
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Front',
                      hintText: 'Question or term',
                      isDense: true,
                    ),
                    maxLines: 2,
                    enabled: !isSaving,
                    onChanged: (v) =>
                        context.read<FlashcardEditorCubit>().setFront(v),
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
                    onChanged: (v) =>
                        context.read<FlashcardEditorCubit>().setBack(v),
                  ),
                  const SizedBox(height: Spacing.small),
                  // Hint field
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Hint (optional)',
                      isDense: true,
                    ),
                    enabled: !isSaving,
                    onChanged: (v) =>
                        context.read<FlashcardEditorCubit>().setHint(v),
                  ),
                  const SizedBox(height: Spacing.medium),
                  if (state.status == FlashcardEditorStatus.failure)
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
                        : () => context.read<FlashcardEditorCubit>().save(
                            sourceId: selection.sourceId,
                            sourceType: selection.sourceType,
                          ),
                    child: isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
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
