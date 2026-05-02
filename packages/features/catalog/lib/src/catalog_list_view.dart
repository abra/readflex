import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

import 'catalog_list_tile.dart';
import 'catalog_selection_cubit.dart';

/// Vertically scrolling list of book rows.
///
/// Each row is one tile; per-row bottom hairlines are drawn by the tile
/// itself (see `showDivider`) so there's no trailing separator under the
/// last row. Rows are wrapped in [Dismissible] so a single right-to-left
/// swipe deletes one book — matched to the demo's iOS-mail style swipe.
/// Swipe is suppressed while a multi-select is active to avoid two
/// destructive paths competing for the same gesture.
///
/// [onConfirmSwipeDelete] is invoked from `Dismissible.confirmDismiss`:
/// the parent screen shows a confirmation bottom sheet, dispatches the
/// delete on confirm, and returns true to let the row finish dismissing
/// (or false to spring it back).
class CatalogListView extends StatelessWidget {
  const CatalogListView({
    required this.books,
    required this.selection,
    required this.onBookPressed,
    required this.onBookLongPressed,
    required this.onConfirmSwipeDelete,
    super.key,
  });

  final List<Book> books;
  final CatalogSelectionState selection;
  final void Function(Book book) onBookPressed;
  final void Function(Book book) onBookLongPressed;
  final Future<bool> Function(Book book) onConfirmSwipeDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
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
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        final showDivider = index < books.length - 1;
        final tile = BookLibraryListTile(
          book: book,
          isSelected: selection.contains(book.id),
          showDivider: showDivider,
          onTap: () => onBookPressed(book),
          onLongPress: () => onBookLongPressed(book),
        );

        if (selection.isActive) {
          return tile;
        }

        return Dismissible(
          key: ValueKey('catalog-row-${book.id}'),
          direction: DismissDirection.endToStart,
          background: const _SwipeDeleteBackground(),
          confirmDismiss: (_) => onConfirmSwipeDelete(book),
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
