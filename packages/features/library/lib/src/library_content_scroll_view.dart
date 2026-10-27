import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

import 'library_continue_reading_card.dart';
import 'library_grid_sliver.dart';
import 'library_layout.dart';
import 'library_layout_cubit.dart';
import 'library_list_sliver.dart';
import 'library_selection_cubit.dart';

/// The Library's one scroll view: a non-null [leading] (the Practice row)
/// inside the gutters, then a non-null [continueReadingSource] as its
/// full-width card, then [sources] in [layoutMode], a [LibraryListSliver] or
/// a [LibraryGridSliver]. [sources] leave the card's source out.
///
/// A layout change swaps only the sources sliver, which fades in over
/// [AppMotion.short]: the row and the card keep their elements and their
/// place, and the scroll position survives, so switching between List and
/// Grid changes the covers and nothing else on the screen.
///
/// [leading] is not a source: screen readers count the card and the
/// sources, each carrying its own index.
class LibraryContentScrollView extends StatelessWidget {
  const LibraryContentScrollView({
    required this.layoutMode,
    required this.sources,
    required this.selection,
    required this.scrollController,
    required this.onSourcePressed,
    required this.onSourceLongPressed,
    required this.onConfirmSwipeDelete,
    this.leading,
    this.continueReadingSource,
    super.key,
  });

  final LibraryLayoutMode layoutMode;
  final List<LibrarySource> sources;

  /// Leads the content inside the gutters, such as the Practice row.
  final Widget? leading;
  final LibrarySource? continueReadingSource;
  final LibrarySelectionState selection;
  final ScrollController scrollController;
  final void Function(LibrarySource source) onSourcePressed;
  final void Function(LibrarySource source) onSourceLongPressed;

  /// Confirms a row's swipe to delete; the grid has no swipe.
  final Future<bool> Function(LibrarySource source) onConfirmSwipeDelete;

  @override
  Widget build(BuildContext context) {
    final leading = this.leading;
    final continueReadingSource = this.continueReadingSource;
    final hasCard = continueReadingSource != null;
    final cardCount = hasCard ? 1 : 0;
    return CustomScrollView(
      controller: scrollController,
      // Bouncing parent guarantees the elastic snap-back even on short
      // content where ClampingScrollPhysics (the Android default) would
      // silently absorb the drag without returning.
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      semanticChildCount: sources.length + cardCount,
      slivers: [
        if (leading != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              kLibraryContentTopPadding,
              AppSpacing.lg,
              0,
            ),
            sliver: SliverToBoxAdapter(child: leading),
          ),
        if (continueReadingSource != null)
          SliverPadding(
            padding: EdgeInsets.only(
              top: leading == null
                  ? kLibraryContentTopPadding
                  : kLibraryContinueReadingGap,
            ),
            sliver: SliverToBoxAdapter(
              child: IndexedSemantics(
                index: 0,
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
          ),
        _LibrarySourcesTransition(
          layoutMode: layoutMode,
          sliver: switch (layoutMode) {
            LibraryLayoutMode.list => LibraryListSliver(
              sources: sources,
              selection: selection,
              hasContentAbove: leading != null || hasCard,
              semanticIndexOffset: cardCount,
              onSourcePressed: onSourcePressed,
              onSourceLongPressed: onSourceLongPressed,
              onConfirmSwipeDelete: onConfirmSwipeDelete,
            ),
            LibraryLayoutMode.grid => LibraryGridSliver(
              sources: sources,
              selection: selection,
              hasContentAbove: leading != null || hasCard,
              semanticIndexOffset: cardCount,
              onSourcePressed: onSourcePressed,
              onSourceLongPressed: onSourceLongPressed,
            ),
          },
        ),
      ],
    );
  }
}

/// Fades the sources sliver in when the layout changes. Nothing moves: a
/// slide would shift the covers under the still row and card above them.
/// Under reduced motion the new layout is simply there.
class _LibrarySourcesTransition extends StatefulWidget {
  const _LibrarySourcesTransition({
    required this.layoutMode,
    required this.sliver,
  });

  final LibraryLayoutMode layoutMode;
  final Widget sliver;

  @override
  State<_LibrarySourcesTransition> createState() =>
      _LibrarySourcesTransitionState();
}

class _LibrarySourcesTransitionState extends State<_LibrarySourcesTransition>
    with SingleTickerProviderStateMixin {
  // Settled at first: the opening layout does not fade in.
  late final _controller = AnimationController(vsync: this, value: 1);
  late final _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void didUpdateWidget(_LibrarySourcesTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layoutMode == widget.layoutMode) return;
    final duration = context.motion(AppMotion.short);
    if (duration == Duration.zero) {
      _controller.value = 1;
      return;
    }
    _controller
      ..duration = duration
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _opacity.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SliverFadeTransition(
    opacity: _opacity,
    sliver: KeyedSubtree(
      key: ValueKey(widget.layoutMode),
      child: widget.sliver,
    ),
  );
}
