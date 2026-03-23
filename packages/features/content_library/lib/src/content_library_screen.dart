import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';

import 'content_library_bloc.dart';

/// Content library tab: shows all books and articles.
class ContentLibraryScreen extends StatelessWidget {
  const ContentLibraryScreen({
    required this.bookRepository,
    required this.articleRepository,
    required this.onBookPressed,
    required this.onArticlePressed,
    required this.onAddPressed,
    super.key,
  });

  final BookRepository bookRepository;
  final ArticleRepository articleRepository;
  final void Function(Book book) onBookPressed;
  final void Function(Article article) onArticlePressed;
  final AsyncCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ContentLibraryBloc(
        bookRepository: bookRepository,
        articleRepository: articleRepository,
      )..add(const ContentLibraryLoadRequested()),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await onAddPressed();
          if (!context.mounted) return;
          context.read<ContentLibraryBloc>().add(
            const ContentLibraryRefreshRequested(),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: BlocBuilder<ContentLibraryBloc, ContentLibraryState>(
        builder: (context, state) {
          return switch (state.status) {
            ContentLibraryStatus.initial || ContentLibraryStatus.loading =>
              const CenteredCircularProgressIndicator(),
            ContentLibraryStatus.failure => ErrorState(
              message: 'Failed to load library',
              retryLabel: 'Retry',
              onRetry: () => context.read<ContentLibraryBloc>().add(
                const ContentLibraryLoadRequested(),
              ),
            ),
            ContentLibraryStatus.success =>
              state.isEmpty
                  ? const EmptyState(
                      message:
                          'Your library is empty.\nTap + to add a book or article.',
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        context.read<ContentLibraryBloc>().add(
                          const ContentLibraryRefreshRequested(),
                        );
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.only(
                          bottom: Spacing.xxxLarge,
                        ),
                        itemCount: state.items.length,
                        itemBuilder: (context, index) {
                          final item = state.items[index];
                          return switch (item) {
                            Book book => _BookTile(
                              book: book,
                              onTap: () => onBookPressed(book),
                              onDelete: () =>
                                  context.read<ContentLibraryBloc>().add(
                                    ContentLibraryBookDeleted(book.id),
                                  ),
                            ),
                            Article article => _ArticleTile(
                              article: article,
                              onTap: () => onArticlePressed(article),
                              onDelete: () =>
                                  context.read<ContentLibraryBloc>().add(
                                    ContentLibraryArticleDeleted(article.id),
                                  ),
                            ),
                            _ => const SizedBox.shrink(),
                          };
                        },
                      ),
                    ),
          };
        },
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({
    required this.book,
    required this.onTap,
    required this.onDelete,
  });

  final Book book;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final progress = (book.readingProgress * 100).round();

    return Dismissible(
      key: ValueKey('book-${book.id}'),
      direction: DismissDirection.endToStart,
      background: _DismissBackground(),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        leading: const Icon(Icons.book),
        title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            if (book.author != null) book.author!,
            if (progress > 0) '$progress%',
          ].join(' · '),
        ),
        trailing: book.isFinished
            ? const Icon(Icons.check_circle, color: Colors.green)
            : null,
        onTap: onTap,
      ),
    );
  }
}

class _ArticleTile extends StatelessWidget {
  const _ArticleTile({
    required this.article,
    required this.onTap,
    required this.onDelete,
  });

  final Article article;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('article-${article.id}'),
      direction: DismissDirection.endToStart,
      background: _DismissBackground(),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        leading: const Icon(Icons.article),
        title: Text(
          article.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(article.siteName ?? article.url),
        trailing: article.isFinished
            ? const Icon(Icons.check_circle, color: Colors.green)
            : null,
        onTap: onTap,
      ),
    );
  }
}

class _DismissBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.error,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: Spacing.large),
      child: Icon(
        Icons.delete,
        color: Theme.of(context).colorScheme.onError,
      ),
    );
  }
}
