import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

import 'library_continue_reading_card.dart';
import 'library_list_tile.dart';
import 'library_selection_cubit.dart';
import 'library_layout.dart';

/// Vertically scrolling list of library source rows.
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
/// A non-null [continueReadingSource] puts its full-width card first,
/// scrolling with the rows; [sources] leave it out.
class LibraryListView extends StatelessWidget {
  const LibraryListView({
    required this.sources,
    required this.selection,
    required this.scrollController,
    required this.onSourcePressed,
    required this.onSourceLongPressed,
    required this.onConfirmSwipeDelete,
    this.continueReadingSource,
    super.key,
  });

  final List<LibrarySource> sources;
  final LibrarySource? continueReadingSource;
  final LibrarySelectionState selection;
  final ScrollController scrollController;
  final void Function(LibrarySource source) onSourcePressed;
  final void Function(LibrarySource source) onSourceLongPressed;
  final Future<bool> Function(LibrarySource source) onConfirmSwipeDelete;

  @override
  Widget build(BuildContext context) {
    final continueReadingSource = this.continueReadingSource;
    final leadingCount = continueReadingSource == null ? 0 : 1;
    // Rows own the 16dp gutter so selection tints and the swipe background
    // run edge to edge.
    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.only(bottom: libraryContentBottomPadding(context)),
      // Bouncing parent guarantees the elastic snap-back even on
      // short lists where ClampingScrollPhysics (the Android default)
      // would silently absorb the drag without returning.
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      itemCount: sources.length + leadingCount,
      itemBuilder: (context, itemIndex) {
        if (continueReadingSource != null && itemIndex == 0) {
          // The first row's own top padding completes the gap below.
          return Padding(
            padding: const EdgeInsets.only(
              top: kLibraryContentTopPadding,
              bottom: kLibraryContinueReadingGap - kLibraryContentTopPadding,
            ),
            child: LibraryContinueReadingCard(
              source: continueReadingSource,
              isSelectionMode: selection.isActive,
              isSelected: selection.contains(continueReadingSource.id),
              onPressed: () => onSourcePressed(continueReadingSource),
              onLongPressed: () => onSourceLongPressed(continueReadingSource),
            ),
          );
        }
        final index = itemIndex - leadingCount;
        final source = sources[index];
        final tile = BookLibraryListTile(
          source: source,
          isSelected: selection.contains(source.id),
          isSelectionMode: selection.isActive,
          showTopDivider: index > 0,
          onTap: () => onSourcePressed(source),
          onLongPress: () => onSourceLongPressed(source),
        );

        if (selection.isActive) {
          return tile;
        }

        return Dismissible(
          key: ValueKey('library-row-${source.id}'),
          direction: DismissDirection.endToStart,
          background: const _SwipeDeleteBackground(),
          confirmDismiss: (_) => onConfirmSwipeDelete(source),
          child: tile,
        );
      },
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
