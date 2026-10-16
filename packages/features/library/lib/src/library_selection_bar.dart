import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'library_selection_cubit.dart';

const _actionInset = AppSpacing.lg - AppSizes.iconActionOutset;

/// Scaffold reserves this bar's height so bulk actions never cover sources.
///
/// A phone stacks the count above a command across the screen; a wide window
/// ([AppWindowSize]) keeps everything in one toolbar row with the command at
/// its own width.
class LibrarySelectionBar extends StatelessWidget {
  const LibrarySelectionBar({
    required this.onAddToCollection,
    required this.onDelete,
    super.key,
  });

  final VoidCallback onAddToCollection;
  final VoidCallback onDelete;

  @override
  Widget build(
    BuildContext context,
  ) => BlocSelector<LibrarySelectionCubit, LibrarySelectionState, int>(
    selector: (state) => state.selectedIds.length,
    builder: (context, count) {
      if (count == 0) return const SizedBox.shrink();
      return Material(
        color: context.colors.surface,
        child: AppBottomSafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(height: 1),
              if (AppWindowSize.isWide(context))
                _SelectionToolbarRow(
                  count: count,
                  onAddToCollection: onAddToCollection,
                  onDelete: onDelete,
                )
              else
                _SelectionToolbarRows(
                  count: count,
                  onAddToCollection: onAddToCollection,
                  onDelete: onDelete,
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _SelectionToolbarRows extends StatelessWidget {
  const _SelectionToolbarRows({
    required this.count,
    required this.onAddToCollection,
    required this.onDelete,
  });

  final int count;
  final VoidCallback onAddToCollection;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: const EdgeInsetsDirectional.only(
          start: _actionInset,
          end: AppSpacing.lg,
        ),
        child: Row(
          children: [
            const _CancelSelectionButton(),
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: _SelectedCount(count: count)),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          0,
          _actionInset,
          AppSpacing.lg,
        ),
        child: Row(
          children: [
            Expanded(
              child: _AddToCollectionButton(onPressed: onAddToCollection),
            ),
            const SizedBox(width: AppSpacing.md),
            _DeleteSelectedButton(onPressed: onDelete),
          ],
        ),
      ),
    ],
  );
}

class _SelectionToolbarRow extends StatelessWidget {
  const _SelectionToolbarRow({
    required this.count,
    required this.onAddToCollection,
    required this.onDelete,
  });

  final int count;
  final VoidCallback onAddToCollection;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: _actionInset,
      vertical: AppSpacing.sm,
    ),
    child: LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          const _CancelSelectionButton(),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: _SelectedCount(count: count)),
          const SizedBox(width: AppSpacing.md),
          // At most half the row: large text wraps the label instead of
          // squeezing the count.
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth / 2),
            child: _AddToCollectionButton(onPressed: onAddToCollection),
          ),
          const SizedBox(width: AppSpacing.md),
          _DeleteSelectedButton(onPressed: onDelete),
        ],
      ),
    ),
  );
}

class _CancelSelectionButton extends StatelessWidget {
  const _CancelSelectionButton();

  @override
  Widget build(BuildContext context) => AppPlainIconButton(
    icon: AppIcons.close,
    tooltip: context.l10n.libraryCancelSelection,
    onPressed: context.read<LibrarySelectionCubit>().clear,
  );
}

class _SelectedCount extends StatelessWidget {
  const _SelectedCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(
      context.l10n.librarySelectedCount(count),
      style: context.text.titleMedium,
    ),
  );
}

class _AddToCollectionButton extends StatelessWidget {
  const _AddToCollectionButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: const Icon(AppIcons.collectionAdd, size: AppIconSize.sm),
    label: AppButtonLabel(context.l10n.libraryAddToCollection),
  );
}

class _DeleteSelectedButton extends StatelessWidget {
  const _DeleteSelectedButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => AppPlainIconButton(
    icon: AppIcons.delete,
    tooltip: context.l10n.commonDelete,
    color: context.colors.error,
    onPressed: onPressed,
  );
}
