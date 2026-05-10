import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

import 'book_cover_plate.dart';

/// Alpha for the format badge background (dark overlay on cover art).
const double _kBadgeBackgroundAlpha = 0.55;

/// Grid-mode tile for a [Book].
///
/// Cover-only: 2:3 aspect ratio with optional format/finished badges and a
/// slim progress bar overlay. Tap target spans the whole cover. Width is
/// decided by the enclosing grid delegate.
class BookLibraryGridTile extends StatelessWidget {
  const BookLibraryGridTile({
    required this.book,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    super.key,
  });

  final Book book;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return _GridTileShell(
      cover: Hero(
        tag: sourceCoverHeroTag(book.id),
        transitionOnUserGestures: true,
        child: AppSourceCover(
          title: book.title,
          author: book.author,
          seed: book.id,
          coverImagePath: book.coverImagePath,
          progress: book.readingProgress > 0 ? book.readingProgress : null,
          // Show the title on the fallback cover art so any format
          // that doesn't ship an embedded cover (a CBZ without a
          // cover image, an EPUB stripped to text-only, etc.) stays
          // identifiable by name. AppSourceCover only honours this on
          // the fallback path — when a real cover image is present,
          // the image takes over and the title stays off.
          showTitle: true,
          showAuthor: false,
          showProgress: false,
          // Apple Books covers run edge-to-edge — no white matte frame
          // around them. The matte fights with the binding strip the
          // shell paints over the left edge, so we suppress it here.
          showMatte: false,
        ),
      ),
      isFinished: book.isFinished,
      progress: book.readingProgress,
      formatLabel: book.format.name.toUpperCase(),
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
    required this.cover,
    required this.isFinished,
    required this.progress,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
    this.formatLabel,
  });

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

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        // Subtle press-in cue when selected — same idea as iOS Photos
        // multi-select: tile shrinks slightly so the unselected siblings
        // visually "stay in place" when a checkmark appears.
        scale: isSelected ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: BookCoverPlate(
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
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: colors.primary, width: 3),
                    color: colors.primary.withValues(alpha: 0.15),
                  ),
                ),
              ),
            if (isSelected)
              Positioned(
                top: AppSpacing.xs,
                right: AppSpacing.xs,
                child: _SelectionCheck(color: colors.primary),
              ),
            if (progress > 0 && !isFinished) ...[
              // Edge-to-edge gradient: the BookCoverPlate's ClipRRect
              // already trims the bottom corners to AppRadius.sm, so
              // we don't need an inset here. (We did when the cover
              // was framed by AppCoverArt's 2dp matte, but the grid
              // tile suppresses the matte for the Apple-Books look —
              // a stale 2dp inset would otherwise paint a white kerf
              // around light covers.)
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      stops: [0.0, 0.15],
                      colors: [Color(0x4D1B1F30), Color(0x001B1F30)],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 6,
                right: 6,
                bottom: 4,
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
                                constraints.maxWidth * progress.clamp(0.0, 1.0),
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
        style: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.5,
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
