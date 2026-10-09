import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'library_bloc.dart';
import 'library_collection_scope_icon.dart';
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
    required this.onClearSearch,
    required this.onShowWholeLibrary,
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

  /// Clears a search without matches.
  final VoidCallback onClearSearch;

  /// Leaves an empty collection for the whole Library.
  final VoidCallback onShowWholeLibrary;

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
          // "No results" keeps the "+" button: its command must scroll clear
          // of it, like the last row of a list. An empty library has no
          // button.
          padding: state.isEmpty
              ? null
              : EdgeInsets.only(bottom: libraryContentBottomPadding(context)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.sizeOf(context).height * 0.6,
            ),
            child: state.isEmpty
                ? LibraryEmptyState(onImportPressed: onImportPressed)
                : _LibraryNoMatches(
                    searching: state.searchQuery.trim().isNotEmpty,
                    scope: state.selectedCollectionScope,
                    onClearSearch: onClearSearch,
                    onShowWholeLibrary: onShowWholeLibrary,
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

/// Why a non-empty library lists nothing, with the one way out: a search
/// without matches is cleared; an empty collection gives way to the whole
/// Library. Without a search a collection is the only thing that can hide
/// every source.
class _LibraryNoMatches extends StatelessWidget {
  const _LibraryNoMatches({
    required this.searching,
    required this.scope,
    required this.onClearSearch,
    required this.onShowWholeLibrary,
  });

  final bool searching;
  final LibraryCollectionScope? scope;
  final VoidCallback onClearSearch;
  final VoidCallback onShowWholeLibrary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scope = this.scope;
    if (searching || scope == null) {
      return EmptyState(
        icon: AppIcons.searchOff,
        message: l10n.libraryNoResultsTitle,
        subtitle: l10n.libraryNoResultsSubtitle,
        action: TextButton(
          key: const ValueKey('libraryClearSearchButton'),
          onPressed: onClearSearch,
          child: AppButtonLabel(l10n.commonClearSearch),
        ),
      );
    }
    return EmptyState(
      icon: libraryCollectionScopeIcon(scope.type),
      message: l10n.libraryEmptyCollectionTitle,
      action: TextButton(
        key: const ValueKey('libraryShowWholeLibraryButton'),
        onPressed: onShowWholeLibrary,
        child: AppButtonLabel(l10n.libraryShowWholeLibrary),
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
