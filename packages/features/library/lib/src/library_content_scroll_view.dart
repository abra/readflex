import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoSliverRefreshControl;
import 'package:domain_models/domain_models.dart';
import 'package:material_ui/material_ui.dart';

import 'library_continue_reading_card.dart';
import 'library_grid_sliver.dart';
import 'library_layout.dart';
import 'library_layout_cubit.dart';
import 'library_list_sliver.dart';
import 'library_selection_cubit.dart';

/// The Library's one scroll view: a non-null [continueReadingSource] as its
/// inset reading panel, then a non-null [leading] (the Practice row) inside
/// the gutters, then [sources] in [layoutMode], a [LibraryListSliver] or
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
    this.hasPracticeAction = false,
    this.leading,
    this.continueReadingSource,
    this.selectionActionsHeight,
    this.onRefresh,
    super.key,
  });

  final LibraryLayoutMode layoutMode;
  final List<LibrarySource> sources;

  /// Secondary content inside the gutters, such as the Practice row.
  final Widget? leading;
  final LibrarySource? continueReadingSource;

  /// Reserves space for the upper floating action, including during selection.
  final bool hasPracticeAction;
  final LibrarySelectionState selection;
  final double? selectionActionsHeight;
  final ScrollController scrollController;
  final Future<void> Function()? onRefresh;
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
      physics: AlwaysScrollableScrollPhysics(
        parent: context.isCupertino
            ? const BouncingScrollPhysics()
            : const ClampingScrollPhysics(),
      ),
      semanticChildCount: sources.length + cardCount,
      slivers: [
        if (context.isCupertino && onRefresh != null)
          CupertinoSliverRefreshControl(onRefresh: onRefresh),
        if (continueReadingSource != null || leading != null)
          SliverPadding(
            padding: const EdgeInsets.only(
              top: kLibraryContentTopPadding,
            ),
            sliver: SliverToBoxAdapter(
              child: _LibraryLeadingContent(
                leading: leading,
                source: continueReadingSource,
                selection: selection,
                onSourcePressed: onSourcePressed,
                onSourceLongPressed: onSourceLongPressed,
              ),
            ),
          ),
        _LibrarySourcesTransition(
          layoutMode: layoutMode,
          sliver: switch (layoutMode) {
            LibraryLayoutMode.list => LibraryListSliver(
              sources: sources,
              hasPracticeAction: hasPracticeAction,
              selection: selection,
              selectionActionsHeight: selectionActionsHeight,
              hasContentAbove: leading != null || hasCard,
              semanticIndexOffset: cardCount,
              onSourcePressed: onSourcePressed,
              onSourceLongPressed: onSourceLongPressed,
              onConfirmSwipeDelete: onConfirmSwipeDelete,
            ),
            LibraryLayoutMode.grid => LibraryGridSliver(
              sources: sources,
              hasPracticeAction: hasPracticeAction,
              selection: selection,
              selectionActionsHeight: selectionActionsHeight,
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

/// Wide windows give reading and review their own columns; the shelf below
/// continues to use all the available width.
class _LibraryLeadingContent extends StatelessWidget {
  const _LibraryLeadingContent({
    required this.leading,
    required this.source,
    required this.selection,
    required this.onSourcePressed,
    required this.onSourceLongPressed,
  });

  final Widget? leading;
  final LibrarySource? source;
  final LibrarySelectionState selection;
  final ValueChanged<LibrarySource> onSourcePressed;
  final ValueChanged<LibrarySource> onSourceLongPressed;

  @override
  Widget build(BuildContext context) {
    final source = this.source;
    final leading = this.leading;
    final card = source == null
        ? null
        : IndexedSemantics(
            index: 0,
            child: LibraryContinueReadingCard(
              source: source,
              isSelectionMode: selection.isActive,
              isSelected: selection.contains(source.id),
              onPressed: () => onSourcePressed(source),
              onLongPressed: () => onSourceLongPressed(source),
            ),
          );
    if (AppWindowSize.isWide(context)) {
      if (card != null && leading != null) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: card),
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpacing.lg),
                child: leading,
              ),
            ),
          ],
        );
      }
      return Align(
        alignment: AlignmentDirectional.topStart,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSizes.pageContentMaxWidth * 2 / 3,
          ),
          child:
              card ??
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: leading,
              ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?card,
        if (leading != null)
          Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: card == null ? 0 : kLibraryContinueReadingGap,
            ),
            child: leading,
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
