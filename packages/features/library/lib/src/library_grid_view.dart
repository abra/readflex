import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

import 'library_grid_tile.dart';
import 'library_selection_cubit.dart';

/// Lazy grid with up to three columns, leaving room for scaled cover text.
class LibraryGridView extends StatelessWidget {
  const LibraryGridView({
    required this.sources,
    required this.selection,
    required this.scrollController,
    required this.onSourcePressed,
    required this.onSourceLongPressed,
    super.key,
  });

  final List<LibrarySource> sources;
  final LibrarySelectionState selection;
  final ScrollController scrollController;
  final void Function(LibrarySource source) onSourcePressed;
  final void Function(LibrarySource source) onSourceLongPressed;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Keep three columns at 320dp with normal text; enlarged text gets two.
        final minTileWidth = 88 * textScale.clamp(1.0, 1.5);
        final columns =
            ((constraints.maxWidth - AppSpacing.lg * 2 + AppSpacing.md) /
                    (minTileWidth + AppSpacing.md))
                .floor()
                .clamp(1, 3);
        return GridView.builder(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 2 / 3,
          ),
          itemCount: sources.length,
          itemBuilder: (context, index) {
            final source = sources[index];
            return BookLibraryGridTile(
              key: ValueKey('library-grid-${source.id}'),
              source: source,
              isSelected: selection.contains(source.id),
              isSelectionMode: selection.isActive,
              onTap: () => onSourcePressed(source),
              onLongPress: () => onSourceLongPressed(source),
            );
          },
        );
      },
    );
  }
}
