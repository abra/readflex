import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:collection_repository/collection_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:toast_service/toast_service.dart';

import 'add_to_collection_cubit.dart';
import 'add_to_collection_sheet.dart';
import 'library_bloc.dart';
import 'library_body.dart';
import 'library_header.dart';
import 'library_layout_cubit.dart';
import 'manage_collection_cubit.dart';
import 'manage_collection_sheet.dart';
import 'library_selection_cubit.dart';
import 'select_collection_scope_sheet.dart';
import 'confirm_book_deletion_sheet.dart';

const _sourceRouteReturnRefreshDelay = Duration(milliseconds: 320);

/// Entry point for the Library tab.
///
/// Pure composition: creates [LibraryBloc] + [LibraryLayoutCubit] +
/// [LibrarySelectionCubit], kicks off the initial load, and hands the
/// widget tree down to [_LibraryView]. All external callbacks
/// (`onSourcePressed`, `onAddPressed`) come from the composition root
/// (`routing.dart`) — the feature itself doesn't know about navigation.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({
    required this.bookRepository,
    required this.collectionRepository,
    required this.preferencesService,
    required this.onSourcePressed,
    required this.onAddPressed,
    this.articleRepository,
    super.key,
  });

  final BookRepository bookRepository;
  final ArticleRepository? articleRepository;
  final CollectionRepository collectionRepository;
  final PreferencesService preferencesService;
  final Future<void> Function(
    LibrarySource source, {
    VoidCallback? onSourceOpened,
  })
  onSourcePressed;
  final AsyncCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    debugLogScreenBuild('LibraryScreen');

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => LibraryBloc(
            bookRepository: bookRepository,
            articleRepository: articleRepository,
            collectionRepository: collectionRepository,
          )..add(const LibraryLoadRequested()),
        ),
        BlocProvider(
          create: (_) => LibraryLayoutCubit(
            preferencesService: preferencesService,
          ),
        ),
        BlocProvider(create: (_) => LibrarySelectionCubit()),
        BlocProvider(
          create: (_) => AddToCollectionCubit(
            collectionRepository: collectionRepository,
          ),
        ),
        BlocProvider(
          create: (_) => ManageCollectionCubit(
            collectionRepository: collectionRepository,
          ),
        ),
      ],
      child: _LibraryView(
        onSourcePressed: onSourcePressed,
        onAddPressed: onAddPressed,
      ),
    );
  }
}

/// Stateful shell that owns the transient UI state of the library screen —
/// the search text controller and the in-flight guard for the FAB — and
/// assembles [LibraryHeader] + [LibraryBody] around them.
///
/// Keeping this state local (rather than in [LibraryBloc]) means it doesn't
/// survive navigation, which is what we want: re-entering the screen starts
/// fresh.
class _LibraryView extends StatefulWidget {
  const _LibraryView({
    required this.onSourcePressed,
    required this.onAddPressed,
  });

  final Future<void> Function(
    LibrarySource source, {
    VoidCallback? onSourceOpened,
  })
  onSourcePressed;
  final AsyncCallback onAddPressed;

  @override
  State<_LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<_LibraryView> {
  /// Search field is a local controller + local state: the bloc only needs
  /// to know about query changes (not every keystroke triggers a new load),
  /// and owning a controller lets us clear the field from the clear button.
  final _searchController = TextEditingController();

  /// Guards the FAB against re-entry while an import sheet is being
  /// pushed. Mutated through `setState` so the FAB also visually
  /// disables for the duration of the call — that's both correct UX
  /// (one tap = one sheet, the user shouldn't be able to queue
  /// another) and removes the silent-flag fragility flagged in audit:
  /// any future build-time read of this field will now see fresh
  /// values via the rebuild cycle.
  bool _addInFlight = false;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleAdd(BuildContext context) async {
    if (_addInFlight) return;
    setState(() => _addInFlight = true);
    try {
      await widget.onAddPressed();
      if (!context.mounted) return;
      context.read<LibraryBloc>().add(const LibraryRefreshRequested());
    } finally {
      // mounted check: the screen may have been popped while
      // onAddPressed awaited. setState on an unmounted State throws.
      if (mounted) setState(() => _addInFlight = false);
    }
  }

  Future<void> _handleSourceTap(
    BuildContext context,
    LibrarySource source,
  ) async {
    final selection = context.read<LibrarySelectionCubit>();
    if (selection.state.isActive) {
      selection.toggle(source.id);
      return;
    }

    var sourceOpened = false;
    void handleSourceOpened() {
      if (!mounted || sourceOpened) return;
      sourceOpened = true;
      context.read<LibraryBloc>().add(const LibraryRefreshRequested());
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }

    await widget.onSourcePressed(source, onSourceOpened: handleSourceOpened);
    // `Navigator.push` completes as soon as the details route starts popping,
    // before the reverse Hero flight finishes. Refreshing immediately can move
    // the opened item to the top and destroy the Hero endpoint mid-flight.
    // If the reader was opened, we still need this second delayed refresh:
    // the early refresh only updates recency, while reading progress is written
    // later by ReaderBloc.
    await Future<void>.delayed(_sourceRouteReturnRefreshDelay);
    if (!context.mounted) return;
    context.read<LibraryBloc>().add(const LibraryRefreshRequested());
  }

  void _handleSourceLongPress(BuildContext context, LibrarySource source) {
    context.read<LibrarySelectionCubit>().toggle(source.id);
  }

  Future<void> _handleAddSelectedToCollection(BuildContext context) async {
    final selection = context.read<LibrarySelectionCubit>();
    final ids = selection.state.selectedIds;
    if (ids.isEmpty) return;

    final added = await showAddToCollectionSheet(
      context: context,
      cubit: context.read<AddToCollectionCubit>(),
      sourceIds: ids,
    );
    if (added != true || !context.mounted) return;
    selection.clear();
    context.read<LibraryBloc>().add(const LibraryRefreshRequested());
    showToast(
      context,
      type: NotificationType.success,
      message: ids.length == 1
          ? 'Added to collection'
          : '${ids.length} items added to collection',
    );
  }

  Future<void> _handleCollectionScopePressed(
    BuildContext context,
    LibraryState state,
  ) async {
    final result = await showLibraryCollectionScopeSheet(
      context: context,
      state: state,
    );
    if (result == null || !context.mounted) return;

    switch (result) {
      case LibraryCollectionScopeSelected(:final scope):
        context.read<LibraryBloc>().add(LibraryCollectionScopeChanged(scope));
      case LibraryCollectionScopeManageRequested(:final scope):
        await _handleManageCollection(context, state, scope);
    }
  }

  Future<void> _handleManageCollection(
    BuildContext context,
    LibraryState state,
    LibraryCollectionScope scope,
  ) async {
    if (!scope.canManage) return;
    final sourceIds = scope.sourceIds.toSet();
    final sources = state.sources
        .where((source) => sourceIds.contains(source.id))
        .toList(growable: false);

    final result = await showManageCollectionSheet(
      context: context,
      cubit: context.read<ManageCollectionCubit>(),
      scope: scope,
      sources: sources,
      onCollectionChanged: () {
        if (!context.mounted) return;
        context.read<LibraryBloc>().add(const LibraryRefreshRequested());
      },
    );
    if (!context.mounted || result != ManageCollectionSheetResult.deleted) {
      return;
    }
    showToast(
      context,
      type: NotificationType.success,
      message: 'Collection deleted',
    );
  }

  void _handleCollectionScopeCleared(BuildContext context) {
    context.read<LibraryBloc>().add(
      const LibraryCollectionScopeChanged(null),
    );
  }

  Future<void> _handleDeleteSelected(BuildContext context) async {
    final selection = context.read<LibrarySelectionCubit>();
    final ids = selection.state.selectedIds;
    if (ids.isEmpty) return;
    final scope = await showConfirmBookDeletionSheet(
      context,
      count: ids.length,
    );
    if (scope == null || !context.mounted) return;
    context.read<LibraryBloc>().add(LibrarySourcesDeleted(ids, scope: scope));
    selection.clear();
  }

  /// Confirms the swipe-to-delete via the same bottom sheet. Returns
  /// `true` to let `Dismissible` finish the row dismissal, `false` to
  /// spring it back. The actual delete event is dispatched here so we
  /// know the chosen scope at dispatch time.
  Future<bool> _confirmAndDispatchSwipe(
    BuildContext context,
    LibrarySource source,
  ) async {
    final scope = await showConfirmBookDeletionSheet(context, count: 1);
    if (scope == null || !context.mounted) return false;
    context.read<LibraryBloc>().add(
      LibrarySourceDeleted(source.id, scope: scope),
    );
    return true;
  }

  void _onLibraryStateForToast(BuildContext context, LibraryState state) {
    final effect = state.deletionEffect;
    if (effect == null) return;
    if (effect.success) {
      if (effect.count == 1 && effect.singleTitle != null) {
        showToast(
          context,
          type: NotificationType.success,
          // Title may be very long. Pinning " deleted" as a suffix keeps
          // the verb visible regardless of available width.
          message: '"${effect.singleTitle}"',
          messageSuffix: ' deleted',
        );
      } else {
        showToast(
          context,
          type: NotificationType.success,
          message: effect.count == 1
              ? 'Item deleted'
              : '${effect.count} items deleted',
        );
      }
    } else {
      showToast(
        context,
        type: NotificationType.error,
        message: effect.count == 1
            ? 'Failed to delete the item'
            : 'Failed to delete the items',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LibraryBloc, LibraryState>(
      listenWhen: (prev, curr) =>
          prev.deletionEffect != curr.deletionEffect &&
          curr.deletionEffect != null,
      listener: _onLibraryStateForToast,
      child: _LibrarySelectionPopScope(
        onCancelSelection: () => context.read<LibrarySelectionCubit>().clear(),
        child: Scaffold(
          floatingActionButton: _LibraryFabDriver(
            addInFlight: _addInFlight,
            onAddPressed: () => _handleAdd(context),
            onDeletePressed: () => _handleDeleteSelected(context),
          ),
          body: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: BlocBuilder<LibraryBloc, LibraryState>(
                  buildWhen: (prev, curr) =>
                      prev.status != curr.status ||
                      prev.books != curr.books ||
                      prev.articles != curr.articles ||
                      prev.filter != curr.filter ||
                      prev.collectionScopes != curr.collectionScopes ||
                      prev.selectedCollectionScope !=
                          curr.selectedCollectionScope ||
                      prev.searchQuery != curr.searchQuery,
                  builder: (context, state) {
                    final bloc = context.read<LibraryBloc>();

                    return switch (state.status) {
                      LibraryStatus.initial || LibraryStatus.loading =>
                        const CenteredCircularProgressIndicator(),
                      LibraryStatus.failure => ErrorState(
                        message: 'Failed to load library',
                        retryLabel: 'Retry',
                        onRetry: () => bloc.add(const LibraryLoadRequested()),
                      ),
                      LibraryStatus.success => Column(
                        children: [
                          LibraryHeader(
                            state: state,
                            searchController: _searchController,
                            onSearchChanged: (query) =>
                                bloc.add(LibrarySearchQueryChanged(query)),
                            onFilterChanged: (filter) =>
                                bloc.add(LibraryFilterChanged(filter)),
                            onCollectionScopePressed: () =>
                                _handleCollectionScopePressed(
                                  context,
                                  state,
                                ),
                            onCollectionScopeCleared: () =>
                                _handleCollectionScopeCleared(context),
                          ),
                          Expanded(
                            child: ScrollEdgeFadeStack(
                              child: LibraryBody(
                                state: state,
                                scrollController: _scrollController,
                                onSourcePressed: (source) =>
                                    _handleSourceTap(context, source),
                                onSourceLongPressed: (source) =>
                                    _handleSourceLongPress(context, source),
                                onConfirmSwipeDelete: (source) =>
                                    _confirmAndDispatchSwipe(
                                      context,
                                      source,
                                    ),
                                onRefresh: () async {
                                  bloc.add(
                                    const LibraryRefreshRequested(),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    };
                  },
                ),
              ),
              _LibraryAddCollectionFabDriver(
                onAddToCollectionPressed: () =>
                    _handleAddSelectedToCollection(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Converts system back into "cancel selection" while multi-select is active.
class _LibrarySelectionPopScope extends StatelessWidget {
  const _LibrarySelectionPopScope({
    required this.onCancelSelection,
    required this.child,
  });

  final VoidCallback onCancelSelection;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<LibrarySelectionCubit, LibrarySelectionState, bool>(
      selector: (state) => state.isActive,
      builder: (context, selectionActive) {
        return PopScope(
          // Intercept the system back gesture only while a selection is
          // active so the user can cancel multi-select without leaving
          // the tab.
          canPop: !selectionActive,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            onCancelSelection();
          },
          child: child,
        );
      },
    );
  }
}

/// Selects the Library FAB mode from selection state: add when idle, delete
/// when multi-select is active.
class _LibraryFabDriver extends StatelessWidget {
  const _LibraryFabDriver({
    required this.addInFlight,
    required this.onAddPressed,
    required this.onDeletePressed,
  });

  final bool addInFlight;
  final VoidCallback onAddPressed;
  final VoidCallback onDeletePressed;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<LibrarySelectionCubit, LibrarySelectionState, bool>(
      selector: (state) => state.isActive,
      builder: (context, selectionActive) {
        if (selectionActive) {
          return _LibraryDeleteFab(onDeletePressed: onDeletePressed);
        }

        return _LibraryFab(
          // null while an import sheet is in-flight — Flutter's FAB renders
          // disabled (greyed) when onPressed is null, matching the actual
          // re-entry guard.
          onAddPressed: addInFlight ? null : onAddPressed,
        );
      },
    );
  }
}

/// Shows the secondary "add to collection" FAB only during multi-select.
class _LibraryAddCollectionFabDriver extends StatelessWidget {
  const _LibraryAddCollectionFabDriver({
    required this.onAddToCollectionPressed,
  });

  final VoidCallback onAddToCollectionPressed;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<LibrarySelectionCubit, LibrarySelectionState, bool>(
      selector: (state) => state.isActive,
      builder: (context, selectionActive) {
        if (!selectionActive) return const SizedBox.shrink();

        return PositionedDirectional(
          start: AppSpacing.lg,
          bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
          child: _LibraryAddCollectionFab(
            onAddToCollectionPressed: onAddToCollectionPressed,
          ),
        );
      },
    );
  }
}

/// Left-side selection action. The delete action intentionally remains the
/// Scaffold FAB so the normal add FAB swaps in-place instead of moving.
class _LibraryAddCollectionFab extends StatelessWidget {
  const _LibraryAddCollectionFab({required this.onAddToCollectionPressed});

  final VoidCallback onAddToCollectionPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return FloatingActionButton.extended(
      onPressed: onAddToCollectionPressed,
      backgroundColor: colors.primary.withValues(alpha: 0.9),
      foregroundColor: colors.onPrimary,
      elevation: 3,
      heroTag: null,
      icon: const Icon(AppIcons.collectionAdd, size: 20),
      label: const Text('Add collection'),
    );
  }
}

class _LibraryDeleteFab extends StatelessWidget {
  const _LibraryDeleteFab({required this.onDeletePressed});

  final VoidCallback onDeletePressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return FloatingActionButton(
      onPressed: onDeletePressed,
      backgroundColor: colors.error,
      foregroundColor: colors.onError,
      shape: const CircleBorder(),
      elevation: 3,
      heroTag: null,
      child: const Icon(AppIcons.delete, size: 24),
    );
  }
}

class _LibraryFab extends StatelessWidget {
  const _LibraryFab({required this.onAddPressed});

  /// Nullable so the parent can render the FAB as disabled while an
  /// import is in-flight. `FloatingActionButton` greys itself out when
  /// `onPressed` is null.
  final VoidCallback? onAddPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return FloatingActionButton(
      onPressed: onAddPressed,
      backgroundColor: colors.primary.withValues(alpha: 0.9),
      foregroundColor: colors.onPrimary,
      shape: const CircleBorder(),
      elevation: 3,
      // Keep the FAB out of Hero transitions; this screen can be opened
      // beside other FAB-based surfaces when frozen tabs are re-enabled.
      heroTag: null,
      child: const Icon(AppIcons.add, size: 24),
    );
  }
}
