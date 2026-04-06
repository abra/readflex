import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:shared/shared.dart';

import 'highlight_cubit.dart';

void showHighlightSheet(
  BuildContext context, {
  required HighlightRepository highlightRepository,
  required TextSelectionContext selection,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => HighlightSheet(
      highlightRepository: highlightRepository,
      selection: selection,
    ),
  );
}

class HighlightSheet extends StatelessWidget {
  const HighlightSheet({
    required this.highlightRepository,
    required this.selection,
    super.key,
  });

  final HighlightRepository highlightRepository;
  final TextSelectionContext selection;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HighlightCubit(highlightRepository: highlightRepository),
      child: _HighlightSheetView(selection: selection),
    );
  }
}

class _HighlightSheetView extends StatelessWidget {
  const _HighlightSheetView({required this.selection});

  final TextSelectionContext selection;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HighlightCubit, HighlightSheetState>(
      listener: (context, state) {
        if (state.status == HighlightSheetStatus.success) {
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        final isSaving = state.status == HighlightSheetStatus.saving;

        return ActionBottomSheetLayout(
          title: 'Highlight',
          onClose: () => Navigator.of(context).pop(),
          headerSpacing: AppSpacing.sm,
          bodyPadding: const EdgeInsets.all(AppSpacing.xl),
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
                      color: Theme.of(context).colorScheme.error,
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
    final ext = Theme.of(context).ext;
    return switch (color) {
      HighlightColor.yellow => ext.highlightYellow,
      HighlightColor.green => ext.highlightGreen,
      HighlightColor.blue => ext.highlightBlue,
      HighlightColor.pink => ext.highlightPink,
      HighlightColor.purple => ext.highlightPurple,
    };
  }
}
