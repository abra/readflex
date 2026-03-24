import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

import 'content_library_item_widgets.dart';

class ContentLibraryListView extends StatelessWidget {
  const ContentLibraryListView({
    required this.items,
    required this.onBookPressed,
    required this.onArticlePressed,
    required this.onBookDeleted,
    required this.onArticleDeleted,
    super.key,
  });

  final List<Object> items;
  final void Function(Book book) onBookPressed;
  final void Function(Article article) onArticlePressed;
  final void Function(Book book) onBookDeleted;
  final void Function(Article article) onArticleDeleted;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        Spacing.large,
        Spacing.small,
        Spacing.large,
        Spacing.xxxLarge,
      ),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: Spacing.small),
      itemBuilder: (context, index) {
        final item = items[index];
        return switch (item) {
          Book book => BookLibraryListTile(
            book: book,
            onTap: () => onBookPressed(book),
            onDelete: () => onBookDeleted(book),
          ),
          Article article => ArticleLibraryListTile(
            article: article,
            onTap: () => onArticlePressed(article),
            onDelete: () => onArticleDeleted(article),
          ),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}
