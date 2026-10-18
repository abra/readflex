import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'library_continue_reading_card.dart';
import 'library_grid_tile.dart';
import 'library_selection_cubit.dart';
import 'library_layout.dart';

part 'library_grid_delegate.dart';

// A tile keeps room for its cover text at normal size: three columns at
// 320dp. Text scales both limits up to 150%.
const double _kGridMinTileWidth = 88;
// Wider windows add columns rather than grow covers past this.
const double _kGridMaxTileWidth = 160;
// The most columns that fit phone-sized covers.
const int _kGridFittingMaxColumns = 6;
const double _kGridMaxTextScale = 1.5;

/// Columns of the Library grid in [width] logical pixels.
///
/// Phones fit as many tiles as their text allows, up to six. A wider window
/// adds a column whenever covers would pass the largest tile, so a tablet
/// shows more covers instead of bigger ones; phone results stay the same.
@visibleForTesting
int libraryGridColumnCount(double width, {required double textScale}) {
  final scale = textScale.clamp(1.0, _kGridMaxTextScale);
  // Tiles plus one gap each fill the width inside the gutters plus one gap.
  final space = width - AppSpacing.lg * 2 + AppSpacing.md;
  final fitting = (space / (_kGridMinTileWidth * scale + AppSpacing.md))
      .floor()
      .clamp(1, _kGridFittingMaxColumns);
  final bounded = (space / (_kGridMaxTileWidth * scale + AppSpacing.md)).ceil();
  return math.max(fitting, bounded);
}

/// Lazy grid with up to three columns on phones, leaving room for scaled
/// cover text; wider windows add columns (see [libraryGridColumnCount]).
/// The columns follow the width in layout, so a height change, such as the
/// keyboard resizing the body, rebuilds no tiles.
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
                onLongPressed: () => onSourceLongPressed(continueReadingSource),
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
            gridDelegate: _LibraryGridDelegate(textScale: textScale),
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
  }
}
