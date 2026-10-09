import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

import 'library_continue_reading_card.dart';
import 'library_grid_tile.dart';
import 'library_selection_cubit.dart';
import 'library_layout.dart';

/// Lazy grid with up to three columns, leaving room for scaled cover text.
///
/// A non-null [continueReadingSource] puts its full-width card above the
/// grid, scrolling with it; [sources] leave it out.
class LibraryGridView extends StatelessWidget {
  const LibraryGridView({
    required this.sources,
    required this.selection,
    required this.scrollController,
    required this.onSourcePressed,
    required this.onSourceLongPressed,
    this.continueReadingSource,
    super.key,
  });

  final List<LibrarySource> sources;
  final LibrarySource? continueReadingSource;
  final LibrarySelectionState selection;
  final ScrollController scrollController;
  final void Function(LibrarySource source) onSourcePressed;
  final void Function(LibrarySource source) onSourceLongPressed;

  @override
  Widget build(BuildContext context) {
    final continueReadingSource = this.continueReadingSource;
    final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Keep three columns at 320dp with normal text; enlarged text gets two.
        final minTileWidth = 88 * textScale.clamp(1.0, 1.5);
        final columns =
            ((constraints.maxWidth - AppSpacing.lg * 2 + AppSpacing.md) /
                    (minTileWidth + AppSpacing.md))
                .floor()
                // Phones stay at three columns; tablets get more instead of
                // oversized covers.
                .clamp(1, 6);
        return CustomScrollView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          semanticChildCount:
              sources.length + (continueReadingSource == null ? 0 : 1),
          slivers: [
            if (continueReadingSource != null)
              SliverPadding(
                padding: const EdgeInsets.only(top: kLibraryContentTopPadding),
                sliver: SliverToBoxAdapter(
                  child: LibraryContinueReadingCard(
                    source: continueReadingSource,
                    isSelectionMode: selection.isActive,
                    isSelected: selection.contains(continueReadingSource.id),
                    onPressed: () => onSourcePressed(continueReadingSource),
                    onLongPressed: () =>
                        onSourceLongPressed(continueReadingSource),
                  ),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                continueReadingSource == null
                    ? kLibraryContentTopPadding
                    : kLibraryContinueReadingGap,
                AppSpacing.lg,
                libraryContentBottomPadding(context),
              ),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  childAspectRatio: 2 / 3,
                ),
                delegate: SliverChildBuilderDelegate(
                  childCount: sources.length,
                  (context, index) {
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
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
