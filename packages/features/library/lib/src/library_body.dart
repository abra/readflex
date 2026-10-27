import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'library_bloc.dart';
import 'library_collection_scope_icon.dart';
import 'library_empty_state.dart';
import 'library_content_scroll_view.dart';
import 'library_import_entry.dart';
import 'library_layout.dart';
import 'library_layout_cubit.dart';
import 'library_practice_row.dart';
import 'library_selection_cubit.dart';

/// Scrollable body of the library: [LibraryContentScrollView] in the layout
/// the user chose (list / grid), or one of two empty states if there's
/// nothing to show.
///
/// Distinguishes two empty states by design:
///   1. Library is genuinely empty — offer file and article import.
///   2. Library has items but the current filter/search hides them all —
///      tell the user to relax the filter.
///
/// In the default view (no search or collection) the Practice row, once
/// something is saved for review, and then the Continue reading card lead
/// the content in both layouts, the card in place of its source's row or
/// tile, also while selecting.
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
    this.onPracticePressed,
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

  /// Opens Practice from its row; `null` leaves the content without it.
  final VoidCallback? onPracticePressed;

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
              final practice = state.practice;
              final onPracticePressed = this.onPracticePressed;
              // Appears after the first save and then stays: a stable entry
              // up here besides the capsule, only in the default view like
              // the card.
              final leading =
                  state.isDefaultView &&
                      practice != null &&
                      !practice.isEmpty &&
                      onPracticePressed != null
                  ? LibraryPracticeRow(
                      practice: practice,
                      onPressed: onPracticePressed,
                    )
                  : null;
              return LibraryContentScrollView(
                layoutMode: layoutMode,
                sources: state.listedItems,
                leading: leading,
                continueReadingSource: continueReadingSource,
                selection: selection,
                scrollController: scrollController,
                onSourcePressed: onSourcePressed,
                onSourceLongPressed: onSourceLongPressed,
                onConfirmSwipeDelete: onConfirmSwipeDelete,
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
