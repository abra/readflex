import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

class BookLibraryGridTile extends StatelessWidget {
  const BookLibraryGridTile({
    required this.book,
    required this.onTap,
    required this.onDelete,
    super.key,
  });

  final Book book;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final progress = (book.readingProgress * 100).round();

    return MediaCollectionCard(
      onTap: onTap,
      media: _BookMedia(book: book),
      title: book.title,
      subtitle: book.author ?? book.format.name.toUpperCase(),
      meta: book.isFinished
          ? 'Finished'
          : progress > 0
          ? '$progress% read'
          : 'New book',
      topRight: _DeleteMenuButton(onDelete: onDelete),
    );
  }
}

class ArticleLibraryGridTile extends StatelessWidget {
  const ArticleLibraryGridTile({
    required this.article,
    required this.onTap,
    required this.onDelete,
    super.key,
  });

  final Article article;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return MediaCollectionCard(
      onTap: onTap,
      media: _ArticleMedia(article: article),
      title: article.title,
      subtitle: article.siteName ?? domainOf(article.url),
      meta: article.isFinished
          ? 'Finished'
          : article.estimatedWordCount > 0
          ? '${article.estimatedWordCount} words'
          : 'Article',
      topRight: _DeleteMenuButton(onDelete: onDelete),
    );
  }
}

class BookLibraryListTile extends StatelessWidget {
  const BookLibraryListTile({
    required this.book,
    required this.onTap,
    required this.onDelete,
    super.key,
  });

  final Book book;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final progress = (book.readingProgress * 100).round();

    return ListTile(
      leading: _CompactMediaThumb(
        child: _BookMedia(book: book),
      ),
      title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (book.author != null) book.author!,
          if (book.isFinished)
            'Finished'
          else if (progress > 0)
            '$progress% read'
          else
            'New book',
        ].join(' · '),
      ),
      trailing: _DeleteMenuButton(onDelete: onDelete),
      onTap: onTap,
    );
  }
}

class ArticleLibraryListTile extends StatelessWidget {
  const ArticleLibraryListTile({
    required this.article,
    required this.onTap,
    required this.onDelete,
    super.key,
  });

  final Article article;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _CompactMediaThumb(
        child: _ArticleMedia(article: article),
      ),
      title: Text(article.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          article.siteName ?? domainOf(article.url),
          if (article.isFinished)
            'Finished'
          else if (article.estimatedWordCount > 0)
            '${article.estimatedWordCount} words',
        ].join(' · '),
      ),
      trailing: _DeleteMenuButton(onDelete: onDelete),
      onTap: onTap,
    );
  }
}

class _CompactMediaThumb extends StatelessWidget {
  const _CompactMediaThumb({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 56,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.small),
        child: child,
      ),
    );
  }
}

class _BookMedia extends StatelessWidget {
  const _BookMedia({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    if (book.coverImagePath case final path? when path.isNotEmpty) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _FallbackBookCover(book: book),
      );
    }

    return _FallbackBookCover(book: book);
  }
}

class _FallbackBookCover extends StatelessWidget {
  const _FallbackBookCover({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surfaceContainerHighest,
            theme.colorScheme.surfaceContainer,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.mediumLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.small,
                  vertical: 6,
                ),
                child: Text(
                  book.format.name.toUpperCase(),
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ),
            const Spacer(),
            Text(
              initials(book.title),
              style: theme.textTheme.displaySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Spacing.small),
            Text(
              book.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticleMedia extends StatelessWidget {
  const _ArticleMedia({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    if (article.coverImageUrl case final url? when url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _ArticlePlaceholder(article: article),
      );
    }

    return _ArticlePlaceholder(article: article);
  }
}

class _ArticlePlaceholder extends StatelessWidget {
  const _ArticlePlaceholder({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final domain = domainOf(article.url);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.mediumLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WWW',
              style: theme.textTheme.displaySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              domain,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: Spacing.small),
            Text(
              'ARTICLE',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteMenuButton extends StatelessWidget {
  const _DeleteMenuButton({required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_LibraryMenuAction>(
      tooltip: 'Actions',
      onSelected: (action) {
        if (action == _LibraryMenuAction.delete) {
          onDelete();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _LibraryMenuAction.delete,
          child: Text('Delete'),
        ),
      ],
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        child: const Padding(
          padding: EdgeInsets.all(Spacing.xSmall),
          child: Icon(Icons.more_horiz, size: 18),
        ),
      ),
    );
  }
}

enum _LibraryMenuAction { delete }

String initials(String title) {
  final parts = title
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .toList();

  if (parts.isEmpty) {
    return 'BK';
  }

  return parts.map((part) => part.substring(0, 1).toUpperCase()).join();
}

String domainOf(String url) {
  final host = Uri.tryParse(url)?.host;
  if (host == null || host.isEmpty) {
    return 'web';
  }

  return host.replaceFirst(RegExp(r'^www\.'), '');
}
