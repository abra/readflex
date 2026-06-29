import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

import 'library_grid_tile.dart';
import 'library_selection_cubit.dart';

/// Scrollable 3-column grid of book tiles.
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
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
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
          onTap: () => onSourcePressed(source),
          onLongPress: () => onSourceLongPressed(source),
        );
      },
    );
  }
}
