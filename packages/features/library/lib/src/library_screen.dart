import 'dart:async';

import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:collection_repository/collection_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:toast_service/toast_service.dart';

import 'add_to_collection_cubit.dart';
import 'add_to_collection_sheet.dart';
import 'library_bloc.dart';
import 'library_body.dart';
import 'library_header.dart';
import 'library_layout_cubit.dart';
import 'library_locale_cubit.dart';
import 'library_theme_cubit.dart';
import 'manage_collection_cubit.dart';
import 'manage_collection_sheet.dart';
import 'library_selection_cubit.dart';
import 'library_selection_bar.dart';
import 'select_collection_scope_sheet.dart';
import 'confirm_book_deletion_sheet.dart';

const _sourceRouteReturnRefreshDelay = Duration(milliseconds: 320);
const _libraryFabBottomLift = AppSpacing.sm;

/// Completes when the import UI closes. [onImported] fires only after storage
/// commits, including when the user dismissed the sheet during an import.
typedef LibraryImportLauncher =
    Future<void> Function({required VoidCallback onImported});

/// Entry point for the Library screen.
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
    this.isOffline = false,
    super.key,
  });

  final BookRepository bookRepository;
  final ArticleRepository? articleRepository;
  final CollectionRepository collectionRepository;
  final PreferencesService preferencesService;
  final bool isOffline;
  final Future<void> Function(
    LibrarySource source, {
    VoidCallback? onSourceOpened,
  })
  onSourcePressed;
  final LibraryImportLauncher onAddPressed;

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
        BlocProvider(
          create: (_) => LibraryThemeCubit(
            preferencesService: preferencesService,
          ),
        ),
        BlocProvider(
          create: (_) => LibraryLocaleCubit(
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
        isOffline: isOffline,
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
    required this.isOffline,
    required this.onSourcePressed,
    required this.onAddPressed,
  });

  final bool isOffline;
  final Future<void> Function(
    LibrarySource source, {
    VoidCallback? onSourceOpened,
  })
  onSourcePressed;
  final LibraryImportLauncher onAddPressed;

  @override
  State<_LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<_LibraryView> {
  /// Search field is a local controller + local state: the bloc only needs
  /// to know about query changes (not every keystroke triggers a new load),
  /// and owning a controller lets us clear the field from the clear button.
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode(debugLabel: 'Library search');

  /// Prevents duplicate import sheets and disables the FAB while the current
  /// import flow is open.
  bool _addInFlight = false;
  final _scrollController = ScrollController();

  /// Swipe deletes awaiting their write, keyed by source id. Each completer
  /// is resolved by the matching [LibraryDeletionEffect] so `Dismissible`
  /// only finishes the row once storage has confirmed the delete.
  final _pendingSwipeDeletions = <String, Completer<bool>>{};

  @override
  void dispose() {
    for (final pending in _pendingSwipeDeletions.values) {
      if (!pending.isCompleted) pending.complete(false);
    }
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleAdd(BuildContext context) async {
    if (_addInFlight) return;
    setState(() => _addInFlight = true);
    try {
      final bloc = context.read<LibraryBloc>();
      await widget.onAddPressed(
        onImported: () {
          if (mounted && !bloc.isClosed) {
            bloc.add(const LibraryRefreshRequested());
          }
        },
      );
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
    _suspendSearchFocus();

    var sourceOpened = false;
    void handleSourceOpened() {
      if (!mounted || sourceOpened) return;
      sourceOpened = true;
      context.read<LibraryBloc>().add(const LibraryRefreshRequested());
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }

    try {
      await widget.onSourcePressed(source, onSourceOpened: handleSourceOpened);
    } finally {
      if (mounted) {
        _dismissCurrentFocus();
        _restoreSearchFocusAfterRouteFrame();
      }
    }
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

  void _suspendSearchFocus() {
    _searchFocusNode.canRequestFocus = false;
    _dismissCurrentFocus();
  }

  void _restoreSearchFocusAfterRouteFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocusNode.canRequestFocus = true;
      _dismissCurrentFocus();
    });
  }

  void _dismissCurrentFocus() {
    FocusManager.instance.primaryFocus?.unfocus(
      disposition: UnfocusDisposition.scope,
    );
    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus(disposition: UnfocusDisposition.scope);
    }
  }

  void _handleSourceLongPress(BuildContext context, LibrarySource source) {
    _dismissCurrentFocus();
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
          ? context.l10n.libraryAddedToCollection
          : context.l10n.libraryItemsAddedToCollection(ids.length),
    );
  }

  Future<void> _handleCollectionScopePressed(
    BuildContext context,
    LibraryState state,
  ) async {
    final result = await showLibraryCollectionScopeSheet(
      context: context,
      state: state,
      states: context.read<LibraryBloc>().stream,
      onRetry: () =>
          context.read<LibraryBloc>().add(const LibraryRefreshRequested()),
      manageBuilder: (sheetContext, scope, onBack, onClose) {
        final sourceIds = scope.sourceIds.toSet();
        return BlocProvider.value(
          value: context.read<ManageCollectionCubit>(),
          child: ManageCollectionSheet(
            scope: scope,
            sources: context
                .read<LibraryBloc>()
                .state
                .sources
                .where((source) => sourceIds.contains(source.id))
                .toList(growable: false),
            onCollectionChanged: () => context.read<LibraryBloc>().add(
              const LibraryRefreshRequested(),
            ),
            onCloseFlow: onClose,
            onFinished: (result) {
              onBack();
              if (result == ManageCollectionSheetResult.deleted) {
                showToast(
                  context,
                  type: NotificationType.success,
                  message: context.l10n.libraryCollectionDeleted,
                );
              }
            },
          ),
        );
      },
    );
    if (result == null || !context.mounted) return;

    if (result case LibraryCollectionScopeSelected(:final scope)) {
      context.read<LibraryBloc>().add(LibraryCollectionScopeChanged(scope));
    }
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

  /// Confirms the swipe-to-delete via the same bottom sheet, then waits for
  /// the write. Resolves `true` once storage confirms the delete so
  /// `Dismissible` finishes the row, `false` (cancel or failure) to spring
  /// it back. The delete event is dispatched here so we know the chosen
  /// scope at dispatch time.
  Future<bool> _confirmAndDispatchSwipe(
    BuildContext context,
    LibrarySource source,
  ) async {
    final scope = await showConfirmBookDeletionSheet(context, count: 1);
    if (scope == null || !context.mounted) return false;
    final completer = Completer<bool>();
    _pendingSwipeDeletions[source.id] = completer;
    context.read<LibraryBloc>().add(
      LibrarySourceDeleted(source.id, scope: scope),
    );
    return completer.future;
  }

  void _onDeletionEffect(BuildContext context, LibraryState state) {
    final effect = state.deletionEffect;
    if (effect == null) return;
    for (final id in effect.sourceIds) {
      final pending = _pendingSwipeDeletions.remove(id);
      if (pending != null && !pending.isCompleted) {
        pending.complete(effect.success);
      }
    }
    if (effect.success) {
      if (effect.count == 1 && effect.singleTitle != null) {
        showToast(
          context,
          type: NotificationType.success,
          // Title may be very long. Pinning " deleted" as a suffix keeps
          // the verb visible regardless of available width.
          message: '"${effect.singleTitle}"',
          messageSuffix: context.l10n.libraryDeletedSuffix,
        );
      } else {
        showToast(
          context,
          type: NotificationType.success,
          message: context.l10n.libraryItemsDeleted(effect.count),
        );
      }
    } else {
      showToast(
        context,
        type: NotificationType.error,
        message: context.l10n.libraryDeleteFailed(effect.count),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LibraryBloc, LibraryState>(
      listenWhen: (prev, curr) =>
          prev.deletionEffect != curr.deletionEffect &&
          curr.deletionEffect != null,
      listener: _onDeletionEffect,
      child: _LibrarySelectionPopScope(
        onCancelSelection: () => context.read<LibrarySelectionCubit>().clear(),
        child: Scaffold(
          bottomNavigationBar: LibrarySelectionBar(
            onAddToCollection: () => _handleAddSelectedToCollection(context),
            onDelete: () => _handleDeleteSelected(context),
          ),
          floatingActionButton: Padding(
            padding: const EdgeInsetsDirectional.only(
              bottom: _libraryFabBottomLift,
            ),
            child: _LibraryFabDriver(
              addInFlight: _addInFlight,
              onAddPressed: () => _handleAdd(context),
            ),
          ),
          body: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: BlocBuilder<LibraryBloc, LibraryState>(
                  buildWhen: (prev, curr) =>
                      prev.status != curr.status ||
                      prev.sources != curr.sources ||
                      prev.filter != curr.filter ||
                      prev.collectionScopes != curr.collectionScopes ||
                      prev.collectionsLoadFailed !=
                          curr.collectionsLoadFailed ||
                      prev.selectedCollectionScope !=
                          curr.selectedCollectionScope ||
                      prev.searchQuery != curr.searchQuery,
                  builder: (context, state) {
                    final bloc = context.read<LibraryBloc>();

                    return switch (state.status) {
                      LibraryStatus.initial || LibraryStatus.loading =>
                        const CenteredCircularProgressIndicator(),
                      LibraryStatus.failure => ErrorState(
                        message: context.l10n.libraryFailedToLoad,
                        retryLabel: context.l10n.commonRetry,
                        onRetry: () => bloc.add(const LibraryLoadRequested()),
                      ),
                      LibraryStatus.success => Column(
                        children: [
                          LibraryHeader(
                            state: state,
                            isOffline: widget.isOffline,
                            searchController: _searchController,
                            searchFocusNode: _searchFocusNode,
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
                                onRefresh: () {
                                  // Keep the indicator until the reload ends.
                                  final done = Completer<void>();
                                  bloc.add(
                                    LibraryRefreshRequested(completer: done),
                                  );
                                  return done.future;
                                },
                                onResetFilters: () {
                                  _searchController.clear();
                                  _searchFocusNode.unfocus();
                                  bloc.add(const LibraryFiltersReset());
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

/// Hide import while the contextual selection bar is active.
class _LibraryFabDriver extends StatelessWidget {
  const _LibraryFabDriver({
    required this.addInFlight,
    required this.onAddPressed,
  });

  final bool addInFlight;
  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<LibrarySelectionCubit, LibrarySelectionState, bool>(
      selector: (state) => state.isActive,
      builder: (context, selectionActive) {
        if (selectionActive) {
          return const SizedBox.shrink();
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

class _LibraryFab extends StatelessWidget {
  const _LibraryFab({required this.onAddPressed});

  /// Nullable so the parent can render the FAB as disabled while an
  /// import is in-flight. `FloatingActionButton` greys itself out when
  /// `onPressed` is null.
  final VoidCallback? onAddPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return FloatingActionButton(
      onPressed: onAddPressed,
      tooltip: context.l10n.importAddToLibraryTitle,
      backgroundColor: colors.primary,
      foregroundColor: colors.onPrimary,
      shape: const CircleBorder(),
      elevation: AppElevation.level2,
      // Keep the FAB out of Hero transitions; this screen can be opened
      // beside other FAB-based surfaces when frozen tabs are re-enabled.
      heroTag: null,
      child: const Icon(AppIcons.add, size: AppIconSize.md),
    );
  }
}
