import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';

import 'content_library_bloc.dart';
import 'content_library_grid_view.dart';
import 'content_library_layout_cubit.dart';
import 'content_library_list_view.dart';

/// Content library tab: shows all books and articles.
class ContentLibraryScreen extends StatelessWidget {
  const ContentLibraryScreen({
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
    debugLogScreenBuild('ContentLibraryScreen');

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => ContentLibraryBloc(
            bookRepository: bookRepository,
            articleRepository: articleRepository,
          )..add(const ContentLibraryLoadRequested()),
        ),
        BlocProvider(
          create: (_) => ContentLibraryLayoutCubit(
            preferencesService: preferencesService,
          ),
        ),
      ],
      child: ContentLibraryView(
        onBookPressed: onBookPressed,
        onArticlePressed: onArticlePressed,
        onAddPressed: onAddPressed,
      ),
    );
  }
}

class ContentLibraryView extends StatefulWidget {
  const ContentLibraryView({
    required this.onBookPressed,
    required this.onArticlePressed,
    required this.onAddPressed,
    super.key,
  });

  final Future<void> Function(Book book) onBookPressed;
  final Future<void> Function(Article article) onArticlePressed;
  final AsyncCallback onAddPressed;

  @override
  State<ContentLibraryView> createState() => _ContentLibraryViewState();
}

class _ContentLibraryViewState extends State<ContentLibraryView> {
  // Search field is a local controller + local state: the bloc only
  // needs to know about query changes (not every keystroke triggers a
  // new load), so we debounce by just emitting into the bloc on change.
  // Using a controller rather than a pure `onChanged` lets us clear the
  // field when the user taps the clear button.
  final _searchController = TextEditingController();

  // Scroll-under scrim visibility. The demo toggles the shadow on the
  // first vertical scroll, so we track `extentBefore > 0`.
  bool _showHeaderShadow = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleAdd(BuildContext context) async {
    await widget.onAddPressed();
    if (!context.mounted) return;
    context.read<ContentLibraryBloc>().add(
      const ContentLibraryRefreshRequested(),
    );
  }

  Future<void> _handleBookTap(BuildContext context, Book book) async {
    await widget.onBookPressed(book);
    if (!context.mounted) return;
    context.read<ContentLibraryBloc>().add(
      const ContentLibraryRefreshRequested(),
    );
  }

  Future<void> _handleArticleTap(
    BuildContext context,
    Article article,
  ) async {
    await widget.onArticlePressed(article);
    if (!context.mounted) return;
    context.read<ContentLibraryBloc>().add(
      const ContentLibraryRefreshRequested(),
    );
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
        child: BlocBuilder<ContentLibraryBloc, ContentLibraryState>(
          buildWhen: (prev, curr) =>
              prev.status != curr.status ||
              prev.items != curr.items ||
              prev.filter != curr.filter ||
              prev.searchQuery != curr.searchQuery,
          builder: (context, state) {
            final bloc = context.read<ContentLibraryBloc>();

            return switch (state.status) {
              ContentLibraryStatus.initial || ContentLibraryStatus.loading =>
                const CenteredCircularProgressIndicator(),
              ContentLibraryStatus.failure => ErrorState(
                message: 'Failed to load library',
                retryLabel: 'Retry',
                onRetry: () => bloc.add(const ContentLibraryLoadRequested()),
              ),
              ContentLibraryStatus.success => Column(
                children: [
                  _LibraryHeader(
                    state: state,
                    searchController: _searchController,
                    onSearchChanged: (query) => bloc.add(
                      ContentLibrarySearchQueryChanged(query),
                    ),
                    onFilterChanged: (filter) => bloc.add(
                      ContentLibraryFilterChanged(filter),
                    ),
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
                          child: _LibraryBody(
                            state: state,
                            onBookPressed: (book) =>
                                _handleBookTap(context, book),
                            onArticlePressed: (article) =>
                                _handleArticleTap(context, article),
                            onRefresh: () async {
                              bloc.add(
                                const ContentLibraryRefreshRequested(),
                              );
                            },
                            onAddPressed: () => _handleAdd(context),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: ScrollEdgeFade(
                            visible: _showHeaderShadow,
                          ),
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

/// Full sticky header: serif title + item counter, search field, filter
/// segment pills, and results-count + view toggle row. The "+" affordance
/// lives as a Scaffold FAB, not in the header (see `readwell_demo`).
class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({
    required this.state,
    required this.searchController,
    required this.onSearchChanged,
    required this.onFilterChanged,
  });

  final ContentLibraryState state;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ContentLibraryFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final visibleCount = state.visibleItems.length;

    // Demo uses literals 20/16/12/4/…; project convention is to stick to
    // AppSpacing tokens, so we take the nearest token in each slot.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Library',
                style: context.text.headlineMedium.copyWith(
                  color: colors.onSurface,
                ),
              ),
              Text(
                '${state.totalCount} items',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SearchField(
            hintText: 'Search books & articles...',
            controller: searchController,
            onChanged: onSearchChanged,
          ),
          const SizedBox(height: AppSpacing.lg),
          _FilterSegments(
            active: state.filter,
            onChanged: onFilterChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$visibleCount results',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const _LayoutToggle(),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _FilterSegments extends StatelessWidget {
  const _FilterSegments({
    required this.active,
    required this.onChanged,
  });

  final ContentLibraryFilter active;
  final ValueChanged<ContentLibraryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Demo: 40px pill height (matches AppSizes.iconButtonSize), separator
    // 6 (→ xs=4), padding H14 (→ md=12), radius 16 (→ AppRadius.lg).
    // Active pill uses onSurface/surface, inactive uses secondary/onSecondary.
    return SizedBox(
      height: AppSizes.iconButtonSize,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ContentLibraryFilter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (_, i) {
          final filter = ContentLibraryFilter.values[i];
          final selected = filter == active;

          return Material(
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                color: selected ? colors.onSurface : colors.secondary,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                onTap: () => onChanged(filter),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppSizes.iconButtonSize,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Center(
                      child: Text(
                        _labelFor(filter),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: selected ? colors.surface : colors.onSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static String _labelFor(ContentLibraryFilter filter) => switch (filter) {
    ContentLibraryFilter.all => 'All',
    ContentLibraryFilter.books => 'Books',
    ContentLibraryFilter.articles => 'Articles',
    ContentLibraryFilter.saved => 'Saved',
    ContentLibraryFilter.finished => 'Finished',
  };
}

class _LayoutToggle extends StatelessWidget {
  const _LayoutToggle();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ContentLibraryLayoutCubit, ContentLibraryLayoutMode>(
      builder: (context, mode) {
        final cubit = context.read<ContentLibraryLayoutCubit>();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LayoutToggleButton(
              icon: AppIcons.viewList,
              active: mode == ContentLibraryLayoutMode.list,
              onTap: () => cubit.setLayoutMode(ContentLibraryLayoutMode.list),
            ),
            const SizedBox(width: AppSpacing.xs),
            _LayoutToggleButton(
              icon: AppIcons.viewGrid,
              active: mode == ContentLibraryLayoutMode.grid,
              onTap: () => cubit.setLayoutMode(ContentLibraryLayoutMode.grid),
            ),
          ],
        );
      },
    );
  }
}

class _LayoutToggleButton extends StatelessWidget {
  const _LayoutToggleButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Demo button: 40x40 (→ AppSizes.iconButtonSize), radius 10 (→ sm=8,
    // −2), icon 16 (→ AppIconSize.xs). Active surface is `cs.secondary`,
    // active icon uses full onSurface, inactive uses onSurface @ 55%.
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: active ? colors.secondary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: SizedBox(
            width: AppSizes.iconButtonSize,
            height: AppSizes.iconButtonSize,
            child: Center(
              child: Icon(
                icon,
                size: AppIconSize.xs,
                color: active
                    ? colors.onSurface
                    : colors.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryBody extends StatelessWidget {
  const _LibraryBody({
    required this.state,
    required this.onBookPressed,
    required this.onArticlePressed,
    required this.onRefresh,
    required this.onAddPressed,
  });

  final ContentLibraryState state;
  final void Function(Book book) onBookPressed;
  final void Function(Article article) onArticlePressed;
  final Future<void> Function() onRefresh;
  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    final visibleItems = state.visibleItems;

    // Two distinct empty states:
    //   1. Library genuinely has nothing — call the user to import.
    //   2. Library has items but the current filter/search filters
    //      them all out — call them to relax the filter.
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
                    subtitle:
                        'Import your first book or article to get started',
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
      child: BlocBuilder<ContentLibraryLayoutCubit, ContentLibraryLayoutMode>(
        builder: (context, layoutMode) {
          return switch (layoutMode) {
            ContentLibraryLayoutMode.list => ContentLibraryListView(
              items: visibleItems,
              onBookPressed: onBookPressed,
              onArticlePressed: onArticlePressed,
            ),
            ContentLibraryLayoutMode.grid => ContentLibraryGridView(
              items: visibleItems,
              onBookPressed: onBookPressed,
              onArticlePressed: onArticlePressed,
            ),
          };
        },
      ),
    );
  }
}
