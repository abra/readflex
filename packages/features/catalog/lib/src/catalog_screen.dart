import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';

import 'catalog_bloc.dart';
import 'catalog_body.dart';
import 'catalog_header.dart';
import 'catalog_layout_cubit.dart';

/// Entry point for the Library tab.
///
/// Pure composition: creates [CatalogBloc] + [CatalogLayoutCubit], kicks
/// off the initial load, and hands the widget tree down to [_CatalogView].
/// All external callbacks (`onBookPressed`, `onArticlePressed`,
/// `onAddPressed`) come from the composition root (`routing.dart`) — the
/// feature itself doesn't know about navigation.
class CatalogScreen extends StatelessWidget {
  const CatalogScreen({
    required this.bookRepository,
    required this.articleRepository,
    required this.preferencesService,
    required this.onBookPressed,
    required this.onArticlePressed,
    required this.onAddPressed,
    super.key,
  });

  final BookRepository bookRepository;
  final ArticleRepository articleRepository;
  final PreferencesService preferencesService;
  final Future<void> Function(Book book) onBookPressed;
  final Future<void> Function(Article article) onArticlePressed;
  final AsyncCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    debugLogScreenBuild('CatalogScreen');

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => CatalogBloc(
            bookRepository: bookRepository,
            articleRepository: articleRepository,
          )..add(const CatalogLoadRequested()),
        ),
        BlocProvider(
          create: (_) => CatalogLayoutCubit(
            preferencesService: preferencesService,
          ),
        ),
      ],
      child: _CatalogView(
        onBookPressed: onBookPressed,
        onArticlePressed: onArticlePressed,
        onAddPressed: onAddPressed,
      ),
    );
  }
}

/// Stateful shell that owns the transient UI state of the catalog screen —
/// the search text controller, the scroll-under scrim flag, and the
/// in-flight guard for the FAB — and assembles [CatalogHeader] + [CatalogBody]
/// around them.
///
/// Keeping this state local (rather than in [CatalogBloc]) means it doesn't
/// survive navigation, which is what we want: re-entering the screen starts
/// fresh.
class _CatalogView extends StatefulWidget {
  const _CatalogView({
    required this.onBookPressed,
    required this.onArticlePressed,
    required this.onAddPressed,
  });

  final Future<void> Function(Book book) onBookPressed;
  final Future<void> Function(Article article) onArticlePressed;
  final AsyncCallback onAddPressed;

  @override
  State<_CatalogView> createState() => _CatalogViewState();
}

class _CatalogViewState extends State<_CatalogView> {
  /// Search field is a local controller + local state: the bloc only needs
  /// to know about query changes (not every keystroke triggers a new load),
  /// and owning a controller lets us clear the field from the clear button.
  final _searchController = TextEditingController();

  /// Scroll-under scrim visibility. The demo toggles the shadow on the
  /// first vertical scroll, so we track `extentBefore > 0`.
  bool _showHeaderShadow = false;

  /// Guards the FAB against re-entry while an import sheet is being pushed.
  bool _addInFlight = false;

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
    await widget.onBookPressed(book);
    if (!context.mounted) return;
    context.read<CatalogBloc>().add(const CatalogRefreshRequested());
  }

  Future<void> _handleArticleTap(
    BuildContext context,
    Article article,
  ) async {
    await widget.onArticlePressed(article);
    if (!context.mounted) return;
    context.read<CatalogBloc>().add(const CatalogRefreshRequested());
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _handleAdd(context),
        backgroundColor: colors.primary.withValues(alpha: 0.9),
        foregroundColor: colors.onPrimary,
        shape: const CircleBorder(),
        elevation: 3,
        child: const Icon(AppIcons.add, size: 24),
      ),
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<CatalogBloc, CatalogState>(
          buildWhen: (prev, curr) =>
              prev.status != curr.status ||
              prev.items != curr.items ||
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
                    child: Stack(
                      children: [
                        NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification.metrics.axis != Axis.vertical) {
                              return false;
                            }
                            final shouldShow =
                                notification.metrics.extentBefore > 0;
                            if (shouldShow != _showHeaderShadow && mounted) {
                              setState(
                                () => _showHeaderShadow = shouldShow,
                              );
                            }
                            return false;
                          },
                          child: CatalogBody(
                            state: state,
                            onBookPressed: (book) =>
                                _handleBookTap(context, book),
                            onArticlePressed: (article) =>
                                _handleArticleTap(context, article),
                            onRefresh: () async {
                              bloc.add(const CatalogRefreshRequested());
                            },
                          ),
                        ),
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: ScrollEdgeFade(visible: _showHeaderShadow),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            };
          },
        ),
      ),
    );
  }
}
