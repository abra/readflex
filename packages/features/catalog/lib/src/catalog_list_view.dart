import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

import 'catalog_list_tile.dart';
import 'catalog_selection_cubit.dart';

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
/// delete on confirm, and returns true to let the row finish dismissing
/// (or false to spring it back).
class CatalogListView extends StatelessWidget {
  const CatalogListView({
    required this.sources,
    required this.selection,
    required this.scrollController,
    required this.onSourcePressed,
    required this.onSourceLongPressed,
    required this.onConfirmSwipeDelete,
    super.key,
  });

  final List<LibrarySource> sources;
  final CatalogSelectionState selection;
  final ScrollController scrollController;
  final void Function(LibrarySource source) onSourcePressed;
  final void Function(LibrarySource source) onSourceLongPressed;
  final Future<bool> Function(LibrarySource source) onConfirmSwipeDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      // Bouncing parent guarantees the elastic snap-back even on
      // short lists where ClampingScrollPhysics (the Android default)
      // would silently absorb the drag without returning.
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      itemCount: sources.length,
      itemBuilder: (context, index) {
        final source = sources[index];
        final tile = BookLibraryListTile(
          source: source,
          isSelected: selection.contains(source.id),
          showTopDivider: index > 0,
          onTap: () => onSourcePressed(source),
          onLongPress: () => onSourceLongPressed(source),
        );

        if (selection.isActive) {
          return tile;
        }

        return Dismissible(
          key: ValueKey('catalog-row-${source.id}'),
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
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      color: colors.error,
      child: Icon(AppIcons.delete, color: colors.onError),
    );
  }
}
