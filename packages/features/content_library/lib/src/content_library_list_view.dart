import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

import 'content_library_item_widgets.dart';

class ContentLibraryListView extends StatelessWidget {
  const ContentLibraryListView({
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
    // Demo uses ListView.builder with per-row bottom borders (no
    // Divider/SizedBox separators) so the last row draws no extra line
    // under it. We replicate that by passing `showDivider` to each tile.
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
