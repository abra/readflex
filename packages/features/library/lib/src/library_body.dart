import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'library_bloc.dart';
import 'library_grid_view.dart';
import 'library_layout_cubit.dart';
import 'library_list_view.dart';
import 'library_selection_cubit.dart';

/// Scrollable body of the library: renders the right layout (list / grid)
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
class LibraryBody extends StatelessWidget {
  const LibraryBody({
    required this.state,
    required this.scrollController,
    required this.onSourcePressed,
    required this.onSourceLongPressed,
    required this.onConfirmSwipeDelete,
    required this.onRefresh,
    super.key,
  });

  final LibraryState state;
  final ScrollController scrollController;
  final void Function(LibrarySource source) onSourcePressed;
  final void Function(LibrarySource source) onSourceLongPressed;
  final Future<bool> Function(LibrarySource source) onConfirmSwipeDelete;
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
                    subtitle: 'Add your first book or article to get started',
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
      child: BlocBuilder<LibraryLayoutCubit, LibraryLayoutMode>(
        builder: (context, layoutMode) {
          return BlocSelector<
            LibrarySelectionCubit,
            LibrarySelectionState,
            LibrarySelectionState
          >(
            selector: (state) => state,
            builder: (context, selection) {
              return switch (layoutMode) {
                LibraryLayoutMode.list => LibraryListView(
                  sources: visibleItems,
                  selection: selection,
                  scrollController: scrollController,
                  onSourcePressed: onSourcePressed,
                  onSourceLongPressed: onSourceLongPressed,
                  onConfirmSwipeDelete: onConfirmSwipeDelete,
                ),
                LibraryLayoutMode.grid => LibraryGridView(
                  sources: visibleItems,
                  selection: selection,
                  scrollController: scrollController,
                  onSourcePressed: onSourcePressed,
                  onSourceLongPressed: onSourceLongPressed,
                ),
              };
            },
          );
        },
      ),
    );
  }
}
