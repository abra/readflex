import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'library_bloc.dart';
import 'library_empty_state.dart';
import 'library_grid_view.dart';
import 'library_import_entry.dart';
import 'library_layout.dart';
import 'library_layout_cubit.dart';
import 'library_list_view.dart';
import 'library_selection_cubit.dart';

const _layoutTransitionOffset = 8.0;

/// Scrollable body of the library: renders the right layout (list / grid)
/// for the current user preference, or one of two empty states if there's
/// nothing to show.
///
/// Distinguishes two empty states by design:
///   1. Library is genuinely empty — offer file and article import.
///   2. Library has items but the current filter/search hides them all —
///      tell the user to relax the filter.
///
/// In the default view (no search or collection) the Continue reading card
/// leads the content in both layouts, in place of its source's row or tile,
/// also while selecting.
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
    required this.onImportPressed,
    required this.onRefresh,
    required this.onResetFilters,
    super.key,
  });

  final LibraryState state;
  final ScrollController scrollController;
  final void Function(LibrarySource source) onSourcePressed;
  final void Function(LibrarySource source) onSourceLongPressed;
  final Future<bool> Function(LibrarySource source) onConfirmSwipeDelete;

  /// Empty-library import commands; `null` while an import flow is open.
  final ValueChanged<LibraryImportEntry>? onImportPressed;
  final Future<void> Function() onRefresh;
  final VoidCallback onResetFilters;

  @override
  Widget build(BuildContext context) {
    final visibleItems = state.visibleItems;
    final l10n = context.l10n;

    if (visibleItems.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          // "No results" keeps the "+" button: Reset filters must scroll
          // clear of it, like the last row of a list. An empty library has
          // no button.
          padding: state.isEmpty
              ? null
              : EdgeInsets.only(bottom: libraryContentBottomPadding(context)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.sizeOf(context).height * 0.6,
            ),
            child: state.isEmpty
                ? LibraryEmptyState(onImportPressed: onImportPressed)
                : EmptyState(
                    icon: AppIcons.searchOff,
                    message: l10n.libraryNoResultsTitle,
                    subtitle: l10n.libraryNoResultsSubtitle,
                    action: TextButton(
                      onPressed: onResetFilters,
                      child: AppButtonLabel(l10n.libraryResetFilters),
                    ),
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
              // The card stays while selecting, so entering selection never
              // moves the covers under it.
              final continueReadingSource = state.continueReadingCardSource;
              final child = switch (layoutMode) {
                LibraryLayoutMode.list => LibraryListView(
                  sources: state.listedItems,
                  continueReadingSource: continueReadingSource,
                  selection: selection,
                  scrollController: scrollController,
                  onSourcePressed: onSourcePressed,
                  onSourceLongPressed: onSourceLongPressed,
                  onConfirmSwipeDelete: onConfirmSwipeDelete,
                ),
                LibraryLayoutMode.grid => LibraryGridView(
                  sources: state.listedItems,
                  continueReadingSource: continueReadingSource,
                  selection: selection,
                  scrollController: scrollController,
                  onSourcePressed: onSourcePressed,
                  onSourceLongPressed: onSourceLongPressed,
                ),
              };

              return _LibraryLayoutTransition(
                layoutMode: layoutMode,
                child: child,
              );
            },
          );
        },
      ),
    );
  }
}

class _LibraryLayoutTransition extends StatelessWidget {
  const _LibraryLayoutTransition({
    required this.layoutMode,
    required this.child,
  });

  final LibraryLayoutMode layoutMode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) {
      return KeyedSubtree(
        key: ValueKey(layoutMode),
        child: child,
      );
    }

    return TweenAnimationBuilder<double>(
      key: ValueKey(layoutMode),
      tween: Tween(begin: 0, end: 1),
      duration: context.motion(AppMotion.short),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * _layoutTransitionOffset),
            child: child,
          ),
        );
      },
    );
  }
}
