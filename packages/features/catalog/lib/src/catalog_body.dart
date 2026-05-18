import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'catalog_bloc.dart';
import 'catalog_grid_view.dart';
import 'catalog_layout_cubit.dart';
import 'catalog_list_view.dart';
import 'catalog_selection_cubit.dart';

/// Scrollable body of the catalog: renders the right layout (list / grid)
/// for the current user preference, or one of two empty states if there's
/// nothing to show.
///
/// Distinguishes two empty states by design:
///   1. Library is genuinely empty — prompt the user to import.
///   2. Library has items but the current filter/search hides them all —
///      tell the user to relax the filter.
///
/// Wrapping [RefreshIndicator] is always present (even for the empty
/// states) so pull-to-refresh stays available.
class CatalogBody extends StatelessWidget {
  const CatalogBody({
    required this.state,
    required this.selection,
    required this.scrollController,
    required this.onBookPressed,
    required this.onBookLongPressed,
    required this.onConfirmSwipeDelete,
    required this.onRefresh,
    super.key,
  });

  final CatalogState state;
  final CatalogSelectionState selection;
  final ScrollController scrollController;
  final void Function(Book book) onBookPressed;
  final void Function(Book book) onBookLongPressed;
  final Future<bool> Function(Book book) onConfirmSwipeDelete;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final visibleItems = state.visibleItems;

    if (visibleItems.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: state.isEmpty
                ? const EmptyState(
                    icon: AppIcons.book,
                    message: 'Your library is empty',
                    subtitle: 'Import your first book to get started',
                  )
                : const EmptyState(
                    icon: AppIcons.searchOff,
                    message: 'No results found',
                    subtitle: 'Try a different search or filter',
                  ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: BlocBuilder<CatalogLayoutCubit, CatalogLayoutMode>(
        builder: (context, layoutMode) {
          return switch (layoutMode) {
            CatalogLayoutMode.list => CatalogListView(
              books: visibleItems,
              selection: selection,
              scrollController: scrollController,
              onBookPressed: onBookPressed,
              onBookLongPressed: onBookLongPressed,
              onConfirmSwipeDelete: onConfirmSwipeDelete,
            ),
            CatalogLayoutMode.grid => CatalogGridView(
              books: visibleItems,
              selection: selection,
              scrollController: scrollController,
              onBookPressed: onBookPressed,
              onBookLongPressed: onBookLongPressed,
            ),
          };
        },
      ),
    );
  }
}
