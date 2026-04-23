import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

import 'catalog_list_tile.dart';

/// Vertically scrolling list of mixed book/article rows.
///
/// Each row is one tile; per-row bottom hairlines are drawn by the tile
/// itself (see `showDivider`) so there's no trailing separator under the
/// last row. Unknown item types render as empty space.
class CatalogListView extends StatelessWidget {
  const CatalogListView({
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
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final showDivider = index < items.length - 1;
        return switch (item) {
          Book book => BookLibraryListTile(
            book: book,
            showDivider: showDivider,
            onTap: () => onBookPressed(book),
          ),
          Article article => ArticleLibraryListTile(
            article: article,
            showDivider: showDivider,
            onTap: () => onArticlePressed(article),
          ),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}
