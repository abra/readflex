import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

import 'content_library_item_widgets.dart';

class ContentLibraryGridView extends StatelessWidget {
  const ContentLibraryGridView({
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
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 64),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.58,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return switch (item) {
          Book book => BookLibraryGridTile(
            book: book,
            onTap: () => onBookPressed(book),
            onDelete: () => onBookDeleted(book),
          ),
          Article article => ArticleLibraryGridTile(
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
