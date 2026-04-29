import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

import 'catalog_list_tile.dart';

/// Vertically scrolling list of book rows.
///
/// Each row is one tile; per-row bottom hairlines are drawn by the tile
/// itself (see `showDivider`) so there's no trailing separator under the
/// last row.
class CatalogListView extends StatelessWidget {
  const CatalogListView({
    required this.books,
    required this.onBookPressed,
    super.key,
  });

  final List<Book> books;
  final void Function(Book book) onBookPressed;

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
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        final showDivider = index < books.length - 1;
        return BookLibraryListTile(
          book: book,
          showDivider: showDivider,
          onTap: () => onBookPressed(book),
        );
      },
    );
  }
}
