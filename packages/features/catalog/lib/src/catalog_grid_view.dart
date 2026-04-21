import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

import 'catalog_item_widgets.dart';

class CatalogGridView extends StatelessWidget {
  const CatalogGridView({
    required this.items,
    required this.onBookPressed,
    required this.onArticlePressed,
    super.key,
  });

  final List<Object> items;
  final void Function(Book book) onBookPressed;
  final void Function(Article article) onArticlePressed;

  @override
  Widget build(BuildContext context) {
    // 3-column grid. Aspect ratio accommodates cover (2:3 proportion)
    // plus progress bar, 2-line title, and author/site below it.
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 0,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.48,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return switch (item) {
          Book book => BookLibraryGridTile(
            book: book,
            onTap: () => onBookPressed(book),
          ),
          Article article => ArticleLibraryGridTile(
            article: article,
            onTap: () => onArticlePressed(article),
          ),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}
