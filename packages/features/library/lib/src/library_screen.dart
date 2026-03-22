import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';

import 'library_bloc.dart';

/// Library tab: shows all books and articles.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({
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
  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LibraryBloc(
        bookRepository: bookRepository,
        articleRepository: articleRepository,
      )..add(const LibraryLoadRequested()),
      child: LibraryView(
        onBookPressed: onBookPressed,
        onArticlePressed: onArticlePressed,
        onAddPressed: onAddPressed,
      ),
    );
  }
}

class LibraryView extends StatelessWidget {
  const LibraryView({
    required this.onBookPressed,
    required this.onArticlePressed,
    required this.onAddPressed,
    super.key,
  });

  final void Function(Book book) onBookPressed;
  final void Function(Article article) onArticlePressed;
  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      floatingActionButton: FloatingActionButton(
        onPressed: onAddPressed,
        child: const Icon(Icons.add),
      ),
      body: BlocBuilder<LibraryBloc, LibraryState>(
        builder: (context, state) {
          return switch (state.status) {
            LibraryStatus.initial ||
            LibraryStatus.loading => const CenteredCircularProgressIndicator(),
            LibraryStatus.failure => ErrorState(
              message: 'Failed to load library',
              retryLabel: 'Retry',
              onRetry: () => context.read<LibraryBloc>().add(
                const LibraryLoadRequested(),
              ),
            ),
            LibraryStatus.success =>
              state.isEmpty
                  ? const EmptyState(
                      message:
                          'Your library is empty.\nTap + to add a book or article.',
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        context.read<LibraryBloc>().add(
                          const LibraryRefreshRequested(),
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
                              onDelete: () => context.read<LibraryBloc>().add(
                                LibraryBookDeleted(book.id),
                              ),
                            ),
                            Article article => _ArticleTile(
                              article: article,
                              onTap: () => onArticlePressed(article),
                              onDelete: () => context.read<LibraryBloc>().add(
                                LibraryArticleDeleted(article.id),
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
