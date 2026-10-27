import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

import 'library_list_tile.dart';
import 'library_selection_cubit.dart';
import 'library_layout.dart';

/// The Library's source rows as a sliver of [LibraryContentScrollView].
///
/// Each row is one tile; per-row top hairlines are drawn by the tile
/// itself (see `showTopDivider`) so cover shadows cannot cover separators.
/// Rows are wrapped in [Dismissible] so a single right-to-left swipe deletes
/// one source — matched to the demo's iOS-mail style swipe.
/// Swipe is suppressed while a multi-select is active to avoid two
/// destructive paths competing for the same gesture.
///
/// [onConfirmSwipeDelete] is invoked from `Dismissible.confirmDismiss`:
/// the parent screen shows a confirmation bottom sheet, dispatches the
/// delete on confirm, and resolves true only once the write succeeded so
/// the row finishes dismissing (false on cancel or failure springs it back).
///
/// The first row's own top padding supplies [kLibraryContentTopPadding];
/// with [hasContentAbove] (the Practice row or the Continue reading card)
/// the sliver adds the rest of [kLibraryContinueReadingGap]. Rows carry
/// their own semantic index from [semanticIndexOffset], after the card.
///
/// A wide window ([AppWindowSize]) lays the rows out in two columns, read
/// across then down, so a tablet line neither stretches a row nor leaves it
/// mostly empty. Each line is as tall as its taller row; rows keep their own
/// height, and every line after the first starts with both hairlines. Screen
/// readers still count sources, not lines, as in the grid.
class LibraryListSliver extends StatelessWidget {
  const LibraryListSliver({
    required this.sources,
    required this.selection,
    required this.hasContentAbove,
    required this.semanticIndexOffset,
    required this.onSourcePressed,
    required this.onSourceLongPressed,
    required this.onConfirmSwipeDelete,
    super.key,
  });

  final List<LibrarySource> sources;
  final LibrarySelectionState selection;

  /// Something scrolls above the rows, so the gap below it is completed.
  final bool hasContentAbove;

  /// Semantic index of the first row: 1 after the Continue reading card.
  final int semanticIndexOffset;
  final void Function(LibrarySource source) onSourcePressed;
  final void Function(LibrarySource source) onSourceLongPressed;
  final Future<bool> Function(LibrarySource source) onConfirmSwipeDelete;

  @override
  Widget build(BuildContext context) {
    final cardCount = semanticIndexOffset;
    final columns = AppWindowSize.isWide(context) ? 2 : 1;
    final lineCount = (sources.length + columns - 1) ~/ columns;
    // Rows own the 16dp gutter so selection tints and the swipe background
    // run edge to edge.
    return SliverPadding(
      padding: EdgeInsets.only(
        // The first row's own top padding completes the gap below the card.
        top: hasContentAbove
            ? kLibraryContinueReadingGap - kLibraryContentTopPadding
            : 0,
        bottom: libraryContentBottomPadding(context),
      ),
      sliver: SliverList(
        // A line can hold two sources, so screen readers count the sources,
        // each carrying its own index instead of the line's.
        delegate: SliverChildBuilderDelegate(
          childCount: lineCount,
          addSemanticIndexes: false,
          (context, line) {
            if (columns == 1) {
              return _LibraryListRow(
                source: sources[line],
                semanticIndex: cardCount + line,
                selection: selection,
                showTopDivider: line > 0,
                onSourcePressed: onSourcePressed,
                onSourceLongPressed: onSourceLongPressed,
                onConfirmSwipeDelete: onConfirmSwipeDelete,
              );
            }
            final first = line * 2;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _LibraryListRow(
                    source: sources[first],
                    semanticIndex: cardCount + first,
                    selection: selection,
                    showTopDivider: line > 0,
                    gutters: _kStartColumnGutters,
                    onSourcePressed: onSourcePressed,
                    onSourceLongPressed: onSourceLongPressed,
                    onConfirmSwipeDelete: onConfirmSwipeDelete,
                  ),
                ),
                Expanded(
                  child: first + 1 < sources.length
                      ? _LibraryListRow(
                          source: sources[first + 1],
                          semanticIndex: cardCount + first + 1,
                          selection: selection,
                          showTopDivider: line > 0,
                          gutters: _kEndColumnGutters,
                          onSourcePressed: onSourcePressed,
                          onSourceLongPressed: onSourceLongPressed,
                          onConfirmSwipeDelete: onConfirmSwipeDelete,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// Two columns keep the screen gutters outside and the grid's 12dp gap
// between them.
const _kStartColumnGutters = EdgeInsetsDirectional.only(
  start: AppSpacing.lg,
  end: AppSpacing.md / 2,
);
const _kEndColumnGutters = EdgeInsetsDirectional.only(
  start: AppSpacing.md / 2,
  end: AppSpacing.lg,
);

/// One source row; swiping it deletes the source unless a selection is
/// active. [semanticIndex] is its place in the list for screen readers.
class _LibraryListRow extends StatelessWidget {
  const _LibraryListRow({
    required this.source,
    required this.semanticIndex,
    required this.selection,
    required this.showTopDivider,
    required this.onSourcePressed,
    required this.onSourceLongPressed,
    required this.onConfirmSwipeDelete,
    this.gutters = kLibraryListRowGutters,
  });

  final LibrarySource source;
  final int semanticIndex;
  final LibrarySelectionState selection;
  final bool showTopDivider;
  final EdgeInsetsDirectional gutters;
  final void Function(LibrarySource source) onSourcePressed;
  final void Function(LibrarySource source) onSourceLongPressed;
  final Future<bool> Function(LibrarySource source) onConfirmSwipeDelete;

  @override
  Widget build(BuildContext context) {
    final tile = BookLibraryListTile(
      source: source,
      isSelected: selection.contains(source.id),
      isSelectionMode: selection.isActive,
      showTopDivider: showTopDivider,
      gutters: gutters,
      onTap: () => onSourcePressed(source),
      onLongPress: () => onSourceLongPressed(source),
    );

    return IndexedSemantics(
      index: semanticIndex,
      child: selection.isActive
          ? tile
          : Dismissible(
              key: ValueKey('library-row-${source.id}'),
              direction: DismissDirection.endToStart,
              background: const _SwipeDeleteBackground(),
              confirmDismiss: (_) => onConfirmSwipeDelete(source),
              child: tile,
            ),
    );
  }
}

class _SwipeDeleteBackground extends StatelessWidget {
  const _SwipeDeleteBackground();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('librarySwipeDeleteBackground'),
      alignment: AlignmentDirectional.centerEnd,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.lg),
      color: colors.error,
      child: Icon(
        key: const ValueKey('librarySwipeDeleteIcon'),
        AppIcons.delete,
        color: colors.onError,
      ),
    );
  }
}
