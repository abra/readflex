import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'catalog_bloc.dart';
import 'catalog_grid_view.dart';
import 'catalog_layout_cubit.dart';
import 'catalog_list_view.dart';

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
    required this.onBookPressed,
    required this.onRefresh,
    super.key,
  });

  final CatalogState state;
  final void Function(Book book) onBookPressed;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final visibleItems = state.visibleItems;

    if (visibleItems.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
              onBookPressed: onBookPressed,
            ),
            CatalogLayoutMode.grid => CatalogGridView(
              books: visibleItems,
              onBookPressed: onBookPressed,
            ),
          };
        },
      ),
    );
  }
}
