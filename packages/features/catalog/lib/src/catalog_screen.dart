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

  /// Number of books we expect the next [CatalogBloc] emission to confirm
  /// (or fail) the deletion of. Set right before dispatching a delete
  /// event; consumed in the [BlocListener] to choose between a
  /// success/failure toast and reset.
  int? _pendingDeleteCount;

  /// Title captured at delete-dispatch time for the singular case
  /// (`_pendingDeleteCount == 1`) so the success toast can name the
  /// book — e.g. "Madame Bovary deleted" — instead of generic
  /// "Book deleted". Null for bulk deletes (≥2) where the toast just
  /// reports the count.
  String? _pendingSingleTitle;

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
    _pendingDeleteCount = ids.length;
    _pendingSingleTitle = ids.length == 1
        ? _titleOf(bloc.state.books, ids.first)
        : null;
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
    _pendingDeleteCount = 1;
    _pendingSingleTitle = book.title;
    context.read<CatalogBloc>().add(
      CatalogBookDeleted(book.id, scope: scope),
    );
    return true;
  }

  void _onCatalogStateForToast(BuildContext context, CatalogState state) {
    final pending = _pendingDeleteCount;
    if (pending == null) return;
    final title = _pendingSingleTitle;
    if (state.status == CatalogStatus.success) {
      _pendingDeleteCount = null;
      _pendingSingleTitle = null;
      if (pending == 1 && title != null) {
        showToast(
          context,
          type: NotificationType.success,
          // Title may be very long. Pinning " deleted" as a suffix keeps
          // the verb visible regardless of available width.
          message: '"$title"',
          messageSuffix: ' deleted',
        );
      } else {
        showToast(
          context,
          type: NotificationType.success,
          message: pending == 1 ? 'Book deleted' : '$pending books deleted',
        );
      }
    } else if (state.status == CatalogStatus.failure) {
      _pendingDeleteCount = null;
      _pendingSingleTitle = null;
      showToast(
        context,
        type: NotificationType.error,
        message: pending == 1
            ? 'Failed to delete the book'
            : 'Failed to delete the books',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CatalogBloc, CatalogState>(
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
