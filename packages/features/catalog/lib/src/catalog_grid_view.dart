import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

import 'catalog_grid_tile.dart';

/// Scrollable 3-column grid of book tiles.
class CatalogGridView extends StatelessWidget {
  const CatalogGridView({
    required this.books,
    required this.onBookPressed,
    super.key,
  });

  final List<Book> books;
  final void Function(Book book) onBookPressed;

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
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return BookLibraryGridTile(
          book: book,
          onTap: () => onBookPressed(book),
        );
      },
    );
  }
}
