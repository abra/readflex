import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

/// Alpha for the format badge background (dark overlay on cover art).
const double _kBadgeBackgroundAlpha = 0.55;
const double _kGridCoverInset = AppSpacing.xxs;
const double _kFormatBadgeTextReserve = 24.0;
const double _kProgressOverlayReserve = 16.0;

/// Grid-mode tile for a library source.
///
/// Cover-only: 2:3 aspect ratio with optional format/finished badges and a
/// slim progress bar overlay. Tap target spans the whole cover. Width is
/// decided by the enclosing grid delegate.
class BookLibraryGridTile extends StatelessWidget {
  const BookLibraryGridTile({
    required this.source,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    super.key,
  });

  final LibrarySource source;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final coverImage = appSourceCoverImageFromPath(source.coverImagePath);
    final isArticle = source.sourceType == SourceType.article;
    final showsProgressOverlay =
        source.readingProgress > 0 && !source.isFinished;

    return _GridTileShell(
      sourceId: source.id,
      cover: AppSourceCover(
        title: source.title,
        author: source.author,
        source: source.sourceName,
        seed: source.id,
        isArticle: isArticle,
        coverImage: coverImage,
        progress: source.readingProgress > 0 ? source.readingProgress : null,
        // Show the title on the fallback cover art so any format
        // that doesn't ship an embedded cover (a CBZ without a
        // cover image, an EPUB stripped to text-only, etc.) stays
        // identifiable by name. AppSourceCover only honours this on
        // the fallback path — when a real cover image is present,
        // the image takes over and the title stays off.
        showTitle: true,
        showAuthor: !isArticle,
        showProgress: false,
        // The shared frame owns cover edges; AppCoverArt's matte would add
        // a white inner border around generated article covers.
        showMatte: false,
        centerText: isArticle,
        topAlignText: !isArticle && showsProgressOverlay,
        topReserve: !isArticle && showsProgressOverlay
            ? _kFormatBadgeTextReserve
            : 0,
        bottomReserve: showsProgressOverlay ? _kProgressOverlayReserve : 0,
        articleBadgeAlignment: isArticle
            ? Alignment.topRight
            : Alignment.topLeft,
      ),
      isFinished: source.isFinished,
      progress: source.readingProgress,
      formatLabel: isArticle ? 'WEB' : source.typeLabel,
      isSelected: isSelected,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

/// Layout scaffold for the grid-mode tile. Owns the geometry —
/// cover aspect ratio, badge placement, progress overlay.
class _GridTileShell extends StatelessWidget {
  const _GridTileShell({
    required this.sourceId,
    required this.cover,
    required this.isFinished,
    required this.progress,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
    this.formatLabel,
  });

  final String sourceId;
  final Widget cover;
  final bool isFinished;
  final double progress;
  final bool isSelected;
  final String? formatLabel;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selectionColor = colors.error;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(_kGridCoverInset),
        child: AnimatedScale(
          // Subtle press-in cue when selected — same idea as iOS Photos
          // multi-select: tile shrinks slightly so the unselected siblings
          // visually "stay in place" when a checkmark appears.
          scale: isSelected ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: Hero(
            tag: sourceCoverHeroTag(sourceId),
            transitionOnUserGestures: true,
            child: AppSourceCoverFrame(
              cover: cover,
              overlays: [
                if (formatLabel != null)
                  Positioned(
                    top: AppSpacing.xs,
                    left: AppSpacing.xs,
                    child: _FormatBadge(label: formatLabel!),
                  ),
                if (isFinished)
                  const Positioned(
                    top: AppSpacing.xs,
                    right: AppSpacing.xs,
                    child: _FinishedBadge(),
                  ),
                if (isSelected)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          appSourceCoverRadius,
                        ),
                        border: Border.all(color: selectionColor, width: 3),
                        color: selectionColor.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                if (isSelected)
                  Positioned(
                    top: AppSpacing.xs,
                    right: AppSpacing.xs,
                    child: _SelectionCheck(color: selectionColor),
                  ),
                if (progress > 0 && !isFinished) ...[
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(appSourceCoverRadius - 2),
                          bottomRight: Radius.circular(
                            appSourceCoverRadius - 2,
                          ),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          stops: [0.0, 0.20],
                          colors: [Color(0x4D1B1F30), Color(0x001B1F30)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: LayoutBuilder(
                      builder: (_, constraints) => ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        child: SizedBox(
                          height: 3,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ColoredBox(
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                              ),
                              Container(
                                width:
                                    constraints.maxWidth *
                                    progress.clamp(0.0, 1.0),
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small dark pill in the cover corner that shows the book file format
/// (EPUB, PDF, FB2, …). Only present on book tiles.
class _FormatBadge extends StatelessWidget {
  const _FormatBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: _kBadgeBackgroundAlpha),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        label,
        style: context.text.sourceCoverBadge.copyWith(
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Filled circle with a checkmark, sitting in the top-right corner of a
/// selected grid tile. Same 20×20 footprint as [_FinishedBadge] so a
/// selection state replaces the finished badge in the same slot.
class _SelectionCheck extends StatelessWidget {
  const _SelectionCheck({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: const Icon(AppIcons.check, size: 11, color: Colors.white),
    );
  }
}

/// Small green check badge in the cover corner indicating the item has
/// been read through to the end.
class _FinishedBadge extends StatelessWidget {
  const _FinishedBadge();

  @override
  Widget build(BuildContext context) {
    // Size, icon size and palette role copied from readwell_demo's grid
    // tile: 20x20 success-colored circle with a white check icon of
    // 11px. Uses `appColors.successForeground` (same role as demo's
    // `ext.successForeground`).
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: context.appColors.successForeground,
        shape: BoxShape.circle,
      ),
      child: const Icon(AppIcons.check, size: 11, color: Colors.white),
    );
  }
}
