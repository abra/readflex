import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:shared/shared.dart';

import 'highlight_cubit.dart';

/// Opens the [HighlightSheet] as a modal bottom sheet. Called by
/// [HighlightAction] from the reader's text-selection context panel.
Future<void> showHighlightSheet(
  BuildContext context, {
  required HighlightRepository highlightRepository,
  required FsrsRepository fsrsRepository,
  required TextSelectionContext selection,
}) {
  return showAppBottomSheet<void>(
    context,
    builder: (_) => HighlightSheet(
      highlightRepository: highlightRepository,
      fsrsRepository: fsrsRepository,
      selection: selection,
    ),
  );
}

/// Bottom sheet for creating a new highlight from selected reader text.
///
/// Shows the selected passage, a color picker, and an optional note field.
/// Provides its own [HighlightCubit]; closes itself on successful save.
/// Usually launched via [showHighlightSheet], not constructed directly.
class HighlightSheet extends StatelessWidget {
  const HighlightSheet({
    required this.highlightRepository,
    required this.fsrsRepository,
    required this.selection,
    super.key,
  });

  final HighlightRepository highlightRepository;
  final FsrsRepository fsrsRepository;
  final TextSelectionContext selection;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HighlightCubit(
        highlightRepository: highlightRepository,
        fsrsRepository: fsrsRepository,
      ),
      child: _HighlightSheetView(selection: selection),
    );
  }
}

class _HighlightSheetView extends StatelessWidget {
  const _HighlightSheetView({required this.selection});

  final TextSelectionContext selection;

  @override
  Widget build(BuildContext context) {
    // The note `TextField` pushes every keystroke to `setNote`, which
    // emits a new state. Without `buildWhen` the entire sheet rebuilds
    // on each character — re-mounting the color picker, the
    // `SelectionPreviewCard`, and the failure message — and the IME /
    // cursor jitters. Note text isn't reactively shown anywhere, so we
    // only need to rebuild when something the UI actually displays
    // changes: the saving / failure / success status, or the picked
    // colour (which tints both the preview card and the picker).
    return BlocConsumer<HighlightCubit, HighlightSheetState>(
      listener: (context, state) {
        if (state.status == HighlightSheetStatus.success) {
          Navigator.of(context).pop();
        }
      },
      buildWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.selectedColor != curr.selectedColor,
      builder: (context, state) {
        final isSaving = state.status == HighlightSheetStatus.saving;

        return ActionBottomSheetLayout(
          title: 'Highlight',
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
              SelectionPreviewCard(
                text: selection.selectedText,
                backgroundColor: _colorForHighlight(
                  context,
                  state.selectedColor,
                ).withValues(alpha: 0.3),
              ),
              const SizedBox(height: AppSpacing.md),
              // Color picker
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: HighlightColor.values.map((color) {
                  final isSelected = state.selectedColor == color;
                  return GestureDetector(
                    onTap: () => context.read<HighlightCubit>().setColor(color),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _colorForHighlight(context, color),
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(width: 3) : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),
              // Note field
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Add a note (optional)',
                  isDense: true,
                ),
                maxLines: 2,
                enabled: !isSaving,
                onChanged: (v) => context.read<HighlightCubit>().setNote(v),
              ),
              const SizedBox(height: AppSpacing.md),
              if (state.status == HighlightSheetStatus.failure)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    'Failed to save highlight',
                    style: TextStyle(
                      color: context.colors.error,
                    ),
                  ),
                ),
              FilledButton(
                onPressed: isSaving
                    ? null
                    : () => context.read<HighlightCubit>().save(
                        text: selection.selectedText,
                        sourceId: selection.sourceId,
                        sourceType: selection.sourceType,
                        cfiRange: selection.cfiRange,
                        pageNumber: selection.pageNumber,
                        scrollOffset: selection.scrollOffset,
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

  Color _colorForHighlight(BuildContext context, HighlightColor color) {
    final ext = context.appColors;
    return switch (color) {
      HighlightColor.yellow => ext.highlightYellow,
      HighlightColor.green => ext.highlightGreen,
      HighlightColor.blue => ext.highlightBlue,
      HighlightColor.pink => ext.highlightPink,
      HighlightColor.purple => ext.highlightPurple,
    };
  }
}
