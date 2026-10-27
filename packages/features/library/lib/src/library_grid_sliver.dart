import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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

/// The Library's covers as a sliver of [LibraryContentScrollView]: a lazy
/// grid with up to three columns on phones, leaving room for scaled cover
/// text; wider windows add columns (see [libraryGridColumnCount]). The
/// columns follow the width in layout, so a height change, such as the
/// keyboard resizing the body, rebuilds no tiles.
///
/// The grid starts [kLibraryContentTopPadding] under the header, or
/// [kLibraryContinueReadingGap] under the content above it
/// ([hasContentAbove]). Tiles carry their semantic index from
/// [semanticIndexOffset], after the Continue reading card.
class LibraryGridSliver extends StatelessWidget {
  const LibraryGridSliver({
    required this.sources,
    required this.selection,
    required this.hasContentAbove,
    required this.semanticIndexOffset,
    required this.onSourcePressed,
    required this.onSourceLongPressed,
    super.key,
  });

  final List<LibrarySource> sources;
  final LibrarySelectionState selection;

  /// Something scrolls above the covers, so the gap below it applies.
  final bool hasContentAbove;

  /// Semantic index of the first tile: 1 after the Continue reading card.
  final int semanticIndexOffset;
  final void Function(LibrarySource source) onSourcePressed;
  final void Function(LibrarySource source) onSourceLongPressed;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        hasContentAbove
            ? kLibraryContinueReadingGap
            : kLibraryContentTopPadding,
        AppSpacing.lg,
        libraryContentBottomPadding(context),
      ),
      sliver: SliverGrid(
        gridDelegate: _LibraryGridDelegate(textScale: textScale),
        delegate: SliverChildBuilderDelegate(
          childCount: sources.length,
          semanticIndexOffset: semanticIndexOffset,
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
    );
  }
}
