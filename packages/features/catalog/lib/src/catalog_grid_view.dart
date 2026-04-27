import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

import 'catalog_grid_tile.dart';

/// Scrollable 3-column grid of mixed book/article tiles.
///
/// Knows only about the layout (spacing, aspect ratio) and dispatches to the
/// right tile widget for each item type. Item types beyond book/article are
/// silently rendered as empty space — keeps the switch total without forcing
/// every caller to filter first.
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
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 2 / 3,
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
