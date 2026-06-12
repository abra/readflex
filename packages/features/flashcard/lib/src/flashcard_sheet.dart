import 'package:component_library/component_library.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:shared/shared.dart';

import 'flashcard_cubit.dart';

/// Opens the [FlashcardSheet] as a modal bottom sheet. Called by
/// [FlashcardAction] from the reader's text-selection context panel.
Future<void> showFlashcardSheet(
  BuildContext context, {
  required FlashcardRepository flashcardRepository,
  required FsrsRepository fsrsRepository,
  required TextSelectionContext selection,
}) {
  return showAppBottomSheet<void>(
    context,
    builder: (_) => FlashcardSheet(
      flashcardRepository: flashcardRepository,
      fsrsRepository: fsrsRepository,
      selection: selection,
    ),
  );
}

/// Bottom sheet for composing a new flashcard from selected reader text.
///
/// Shows the selected passage plus front, back, and optional hint fields.
/// Provides its own [FlashcardCubit]; closes itself on successful save.
/// Usually launched via [showFlashcardSheet], not constructed directly.
class FlashcardSheet extends StatelessWidget {
  const FlashcardSheet({
    required this.flashcardRepository,
    required this.fsrsRepository,
    required this.selection,
    super.key,
  });

  final FlashcardRepository flashcardRepository;
  final FsrsRepository fsrsRepository;
  final TextSelectionContext selection;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FlashcardCubit(
        flashcardRepository: flashcardRepository,
        fsrsRepository: fsrsRepository,
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
    // Three TextFields (front / back / hint) push every keystroke into
    // the cubit. Without `buildWhen` the entire sheet rebuilds three
    // times per typed character — once per setter — re-mounting the
    // SelectionPreviewCard, all three TextFields, and the FilledButton.
    // That causes IME / cursor jitter on long inputs.
    //
    // The UI only needs to react to two things: the saving / failure /
    // success status (button label, disabled flag, error line) and the
    // `canSave` toggle (button enabled/disabled). `canSave` flips at
    // most twice per session — when front+back transition empty↔non-
    // empty — so most keystrokes don't trigger any rebuild at all.
    return BlocConsumer<FlashcardCubit, FlashcardState>(
      listener: (context, state) {
        if (state.status == FlashcardStatus.success) {
          Navigator.of(context).pop();
        }
      },
      buildWhen: (prev, curr) =>
          prev.status != curr.status || prev.canSave != curr.canSave,
      builder: (context, state) {
        final cubit = context.read<FlashcardCubit>();
        final isSaving = state.status == FlashcardStatus.saving;

        return ActionBottomSheetLayout(
          title: 'Create Flashcard',
          headerSpacing: AppSpacing.sm,
          bodyPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Selected text preview
              SelectionPreviewCard(text: selection.selectedText),
              const SizedBox(height: AppSpacing.md),
              // Front field
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Front',
                  hintText: 'Question or term',
                  isDense: true,
                ),
                maxLines: 2,
                enabled: !isSaving,
                onChanged: cubit.setFront,
              ),
              const SizedBox(height: AppSpacing.sm),
              // Back field
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Back',
                  hintText: 'Answer or definition',
                  isDense: true,
                ),
                maxLines: 2,
                enabled: !isSaving,
                onChanged: cubit.setBack,
              ),
              const SizedBox(height: AppSpacing.sm),
              // Hint field
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Hint (optional)',
                  isDense: true,
                ),
                enabled: !isSaving,
                onChanged: cubit.setHint,
              ),
              const SizedBox(height: AppSpacing.md),
              if (state.status == FlashcardStatus.failure)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    'Failed to save flashcard',
                    style: context.text.bodyMedium.copyWith(
                      color: context.colors.error,
                    ),
                  ),
                ),
              FilledButton(
                onPressed: isSaving || !state.canSave
                    ? null
                    : () => cubit.save(
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
