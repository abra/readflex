import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:toast_service/toast_service.dart';

import 'catalog_bloc.dart';
import 'catalog_body.dart';
import 'catalog_header.dart';
import 'catalog_layout_cubit.dart';
import 'catalog_selection_cubit.dart';
import 'confirm_book_deletion_sheet.dart';

/// Entry point for the Library tab.
///
/// Pure composition: creates [CatalogBloc] + [CatalogLayoutCubit] +
/// [CatalogSelectionCubit], kicks off the initial load, and hands the
/// widget tree down to [_CatalogView]. All external callbacks
/// (`onBookPressed`, `onAddPressed`) come from the composition root
/// (`routing.dart`) — the feature itself doesn't know about navigation.
class CatalogScreen extends StatelessWidget {
  const CatalogScreen({
    required this.bookRepository,
    required this.preferencesService,
    required this.onBookPressed,
    required this.onAddPressed,
    super.key,
  });

  final BookRepository bookRepository;
  final PreferencesService preferencesService;
  final Future<void> Function(Book book) onBookPressed;
  final AsyncCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    debugLogScreenBuild('CatalogScreen');

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              CatalogBloc(bookRepository: bookRepository)
                ..add(const CatalogLoadRequested()),
        ),
        BlocProvider(
          create: (_) => CatalogLayoutCubit(
            preferencesService: preferencesService,
          ),
        ),
        BlocProvider(create: (_) => CatalogSelectionCubit()),
      ],
      child: _CatalogView(
        onBookPressed: onBookPressed,
        onAddPressed: onAddPressed,
      ),
    );
  }
}

/// Stateful shell that owns the transient UI state of the catalog screen —
/// the search text controller and the in-flight guard for the FAB — and
/// assembles [CatalogHeader] + [CatalogBody] around them.
///
/// Keeping this state local (rather than in [CatalogBloc]) means it doesn't
/// survive navigation, which is what we want: re-entering the screen starts
/// fresh.
class _CatalogView extends StatefulWidget {
  const _CatalogView({
    required this.onBookPressed,
    required this.onAddPressed,
  });

  final Future<void> Function(Book book) onBookPressed;
  final AsyncCallback onAddPressed;

  @override
  State<_CatalogView> createState() => _CatalogViewState();
}

class _CatalogViewState extends State<_CatalogView> {
  /// Search field is a local controller + local state: the bloc only needs
  /// to know about query changes (not every keystroke triggers a new load),
  /// and owning a controller lets us clear the field from the clear button.
  final _searchController = TextEditingController();

  /// Guards the FAB against re-entry while an import sheet is being pushed.
  bool _addInFlight = false;

  /// FIFO queue of pending delete descriptors. One entry is pushed per
  /// dispatched [CatalogBookDeleted] / [CatalogBooksDeleted] event,
  /// and one is popped each time the bloc emits a state with a fresh
  /// `deletionVersion`. Sequential bloc transformer guarantees one
  /// terminal emit per dispatch, so push-order matches pop-order.
  ///
  /// Replaces the earlier single-field design (`_pendingDeleteCount`
  /// + `_pendingSingleTitle`) which silently overwrote itself when a
  /// second delete was dispatched while the first was still in
  /// flight, causing the success toast to describe the wrong batch.
  final List<_PendingDeletion> _pendingDeletions = [];

  /// Last `deletionVersion` we've already shown a toast for. Compared
  /// against the current state's value in [BlocListener.listenWhen]
  /// so the listener fires exactly once per dispatched delete.
  int _consumedDeletionVersion = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleAdd(BuildContext context) async {
    if (_addInFlight) return;
    _addInFlight = true;
    try {
      await widget.onAddPressed();
      if (!context.mounted) return;
      context.read<CatalogBloc>().add(const CatalogRefreshRequested());
    } finally {
      _addInFlight = false;
    }
  }

  Future<void> _handleBookTap(BuildContext context, Book book) async {
    final selection = context.read<CatalogSelectionCubit>();
    if (selection.state.isActive) {
      selection.toggle(book.id);
      return;
    }
    await widget.onBookPressed(book);
    if (!context.mounted) return;
    context.read<CatalogBloc>().add(const CatalogRefreshRequested());
  }

  void _handleBookLongPress(BuildContext context, Book book) {
    context.read<CatalogSelectionCubit>().toggle(book.id);
  }

  Future<void> _handleDeleteSelected(BuildContext context) async {
    final selection = context.read<CatalogSelectionCubit>();
    final ids = selection.state.selectedIds;
    if (ids.isEmpty) return;
    final scope = await showConfirmBookDeletionSheet(
      context,
      count: ids.length,
    );
    if (scope == null || !context.mounted) return;
    final bloc = context.read<CatalogBloc>();
    _pendingDeletions.add(
      _PendingDeletion(
        count: ids.length,
        singleTitle: ids.length == 1
            ? _titleOf(bloc.state.books, ids.first)
            : null,
      ),
    );
    bloc.add(CatalogBooksDeleted(ids, scope: scope));
    selection.clear();
  }

  /// Locates a book in [books] by id and returns its title, or null if
  /// the row is gone (race between dispatch and the bloc emitting an
  /// already-deleted state). Caller treats null as "fall back to the
  /// generic 'Book deleted' wording".
  static String? _titleOf(List<Book> books, String id) {
    for (final book in books) {
      if (book.id == id) return book.title;
    }
    return null;
  }

  /// Confirms the swipe-to-delete via the same bottom sheet. Returns
  /// `true` to let `Dismissible` finish the row dismissal, `false` to
  /// spring it back. The actual delete event is dispatched here so we
  /// know the chosen scope at dispatch time.
  Future<bool> _confirmAndDispatchSwipe(
    BuildContext context,
    Book book,
  ) async {
    final scope = await showConfirmBookDeletionSheet(context, count: 1);
    if (scope == null || !context.mounted) return false;
    _pendingDeletions.add(_PendingDeletion(count: 1, singleTitle: book.title));
    context.read<CatalogBloc>().add(
      CatalogBookDeleted(book.id, scope: scope),
    );
    return true;
  }

  void _onCatalogStateForToast(BuildContext context, CatalogState state) {
    if (_pendingDeletions.isEmpty) return;
    _consumedDeletionVersion = state.deletionVersion;
    final pending = _pendingDeletions.removeAt(0);
    if (state.status == CatalogStatus.success) {
      if (pending.count == 1 && pending.singleTitle != null) {
        showToast(
          context,
          type: NotificationType.success,
          // Title may be very long. Pinning " deleted" as a suffix keeps
          // the verb visible regardless of available width.
          message: '"${pending.singleTitle}"',
          messageSuffix: ' deleted',
        );
      } else {
        showToast(
          context,
          type: NotificationType.success,
          message: pending.count == 1
              ? 'Book deleted'
              : '${pending.count} books deleted',
        );
      }
    } else if (state.status == CatalogStatus.failure) {
      showToast(
        context,
        type: NotificationType.error,
        message: pending.count == 1
            ? 'Failed to delete the book'
            : 'Failed to delete the books',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CatalogBloc, CatalogState>(
      // Fires once per dispatched delete (success OR failure). The
      // `deletionVersion` discriminator is the only thing that can
      // distinguish a post-delete success from any other success
      // emit (CatalogLoadRequested, CatalogRefreshRequested) that
      // happens while a delete is in flight.
      listenWhen: (prev, curr) =>
          curr.deletionVersion != _consumedDeletionVersion,
      listener: _onCatalogStateForToast,
      child: BlocBuilder<CatalogSelectionCubit, CatalogSelectionState>(
        builder: (context, selection) {
          return PopScope(
            // Intercept the system back gesture only while a selection is
            // active so the user can cancel multi-select without leaving
            // the tab.
            canPop: !selection.isActive,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              context.read<CatalogSelectionCubit>().clear();
            },
            child: Scaffold(
              floatingActionButton: _CatalogFab(
                selectionActive: selection.isActive,
                onAddPressed: () => _handleAdd(context),
                onDeletePressed: () => _handleDeleteSelected(context),
              ),
              body: SafeArea(
                bottom: false,
                child: BlocBuilder<CatalogBloc, CatalogState>(
                  buildWhen: (prev, curr) =>
                      prev.status != curr.status ||
                      prev.books != curr.books ||
                      prev.filter != curr.filter ||
                      prev.searchQuery != curr.searchQuery,
                  builder: (context, state) {
                    final bloc = context.read<CatalogBloc>();

                    return switch (state.status) {
                      CatalogStatus.initial || CatalogStatus.loading =>
                        const CenteredCircularProgressIndicator(),
                      CatalogStatus.failure => ErrorState(
                        message: 'Failed to load library',
                        retryLabel: 'Retry',
                        onRetry: () => bloc.add(const CatalogLoadRequested()),
                      ),
                      CatalogStatus.success => Column(
                        children: [
                          CatalogHeader(
                            state: state,
                            searchController: _searchController,
                            onSearchChanged: (query) =>
                                bloc.add(CatalogSearchQueryChanged(query)),
                            onFilterChanged: (filter) =>
                                bloc.add(CatalogFilterChanged(filter)),
                          ),
                          Expanded(
                            child: ScrollEdgeFadeStack(
                              child: CatalogBody(
                                state: state,
                                selection: selection,
                                onBookPressed: (book) =>
                                    _handleBookTap(context, book),
                                onBookLongPressed: (book) =>
                                    _handleBookLongPress(context, book),
                                onConfirmSwipeDelete: (book) =>
                                    _confirmAndDispatchSwipe(context, book),
                                onRefresh: () async {
                                  bloc.add(const CatalogRefreshRequested());
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
            ),
          );
        },
      ),
    );
  }
}

/// Swaps the FAB icon based on whether a multi-select is active.
///
/// Add (`+`) when idle, trash when ≥1 book is selected. Both share the
/// same shape / color so the swap reads as an icon change rather than a
/// new control appearing.
class _CatalogFab extends StatelessWidget {
  const _CatalogFab({
    required this.selectionActive,
    required this.onAddPressed,
    required this.onDeletePressed,
  });

  final bool selectionActive;
  final VoidCallback onAddPressed;
  final VoidCallback onDeletePressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return FloatingActionButton(
      onPressed: selectionActive ? onDeletePressed : onAddPressed,
      backgroundColor: selectionActive
          ? colors.error
          : colors.primary.withValues(alpha: 0.9),
      foregroundColor: selectionActive ? colors.onError : colors.onPrimary,
      shape: const CircleBorder(),
      elevation: 3,
      // Tab branches stay alive in StatefulShellRoute, so the Catalog
      // and Dictionary FABs would otherwise share the default Hero tag
      // during route transitions and trigger a duplicate-hero assertion.
      heroTag: null,
      child: Icon(
        selectionActive ? AppIcons.delete : AppIcons.add,
        size: 24,
      ),
    );
  }
}

/// Display-side metadata captured at delete-dispatch time so the
/// post-delete toast can reference the correct title / count even if
/// other deletes overlap or land first.
class _PendingDeletion {
  const _PendingDeletion({required this.count, this.singleTitle});

  final int count;
  final String? singleTitle;
}
