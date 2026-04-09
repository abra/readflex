import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';

import 'content_library_bloc.dart';
import 'content_library_layout_cubit.dart';

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
  final void Function(Book book) onBookPressed;
  final void Function(Article article) onArticlePressed;
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

class ContentLibraryView extends StatelessWidget {
  const ContentLibraryView({
    required this.onBookPressed,
    required this.onArticlePressed,
    required this.onAddPressed,
    super.key,
  });

  final void Function(Book book) onBookPressed;
  final void Function(Article article) onArticlePressed;
  final AsyncCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    // TODO: implement library grid/list view.
    return Placeholder();
    // return Scaffold(
    //   appBar: AppBar(
    //     title: const Text('Library'),
    //     actions: [
    //       Padding(
    //         padding: const EdgeInsets.only(right: AppSpacing.md),
    //         child:
    //             BlocBuilder<
    //               ContentLibraryLayoutCubit,
    //               ContentLibraryLayoutMode
    //             >(
    //               builder: (context, layoutMode) {
    //                 final cubit = context.read<ContentLibraryLayoutCubit>();
    //                 return SegmentedButton<ContentLibraryLayoutMode>(
    //                   showSelectedIcon: false,
    //                   segments: const [
    //                     ButtonSegment(
    //                       value: ContentLibraryLayoutMode.list,
    //                       icon: Icon(Icons.view_list_outlined),
    //                       label: Text('List'),
    //                     ),
    //                     ButtonSegment(
    //                       value: ContentLibraryLayoutMode.grid,
    //                       icon: Icon(Icons.grid_view_outlined),
    //                       label: Text('Grid'),
    //                     ),
    //                   ],
    //                   selected: {layoutMode},
    //                   onSelectionChanged: (value) {
    //                     cubit.setLayoutMode(
    //                       value.first,
    //                     );
    //                   },
    //                 );
    //               },
    //             ),
    //       ),
    //     ],
    //   ),
    //   floatingActionButton: FloatingActionButton(
    //     onPressed: () async {
    //       await onAddPressed();
    //       if (!context.mounted) return;
    //       context.read<ContentLibraryBloc>().add(
    //         const ContentLibraryRefreshRequested(),
    //       );
    //     },
    //     child: const Icon(Icons.add),
    //   ),
    //   body: BlocBuilder<ContentLibraryBloc, ContentLibraryState>(
    //     builder: (context, state) {
    //       final bloc = context.read<ContentLibraryBloc>();
    //
    //       return switch (state.status) {
    //         ContentLibraryStatus.initial || ContentLibraryStatus.loading =>
    //           const CenteredCircularProgressIndicator(),
    //         ContentLibraryStatus.failure => ErrorState(
    //           message: 'Failed to load library',
    //           retryLabel: 'Retry',
    //           onRetry: () => bloc.add(const ContentLibraryLoadRequested()),
    //         ),
    //         ContentLibraryStatus.success =>
    //           state.isEmpty
    //               ? const EmptyState(
    //                   message:
    //                       'Your library is empty.\nTap + to add a book or article.',
    //                 )
    //               : RefreshIndicator(
    //                   onRefresh: () async {
    //                     bloc.add(const ContentLibraryRefreshRequested());
    //                   },
    //                   child:
    //                       BlocBuilder<
    //                         ContentLibraryLayoutCubit,
    //                         ContentLibraryLayoutMode
    //                       >(
    //                         builder: (context, layoutMode) {
    //                           return switch (layoutMode) {
    //                             ContentLibraryLayoutMode.list =>
    //                               ContentLibraryListView(
    //                                 items: state.items,
    //                                 onBookPressed: onBookPressed,
    //                                 onArticlePressed: onArticlePressed,
    //                                 onBookDeleted: (book) =>
    //                                     _deleteBook(context, book),
    //                                 onArticleDeleted: (article) =>
    //                                     _deleteArticle(context, article),
    //                               ),
    //                             ContentLibraryLayoutMode.grid =>
    //                               ContentLibraryGridView(
    //                                 items: state.items,
    //                                 onBookPressed: onBookPressed,
    //                                 onArticlePressed: onArticlePressed,
    //                                 onBookDeleted: (book) =>
    //                                     _deleteBook(context, book),
    //                                 onArticleDeleted: (article) =>
    //                                     _deleteArticle(context, article),
    //                               ),
    //                           };
    //                         },
    //                       ),
    //                 ),
    //       };
    //     },
    //   ),
    // );
  }

  // ignore: unused_element
  void _deleteBook(BuildContext context, Book book) {
    final bloc = context.read<ContentLibraryBloc>();
    bloc.add(ContentLibraryBookDeleted(book.id));
  }

  // ignore: unused_element
  void _deleteArticle(BuildContext context, Article article) {
    final bloc = context.read<ContentLibraryBloc>();
    bloc.add(ContentLibraryArticleDeleted(article.id));
  }
}
