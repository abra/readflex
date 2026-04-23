import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

import 'catalog_tile_cover.dart';

/// Fraction used to desaturate muted text / secondary colors on catalog
/// tiles. Kept as a file-local constant so the same visual weight travels
/// together across grid and list tiles.
const double _kMutedAlpha = 0.55;

/// Alpha for the format badge background (dark overlay on cover art).
const double _kBadgeBackgroundAlpha = 0.55;

/// Grid-mode tile for a [Book].
///
/// Layout, top to bottom: cover (2:3 aspect) with optional format/finished
/// badges → slim progress bar → two-line title → author. Tap target spans
/// the whole column. Width is decided by the enclosing grid delegate.
class BookLibraryGridTile extends StatelessWidget {
  const BookLibraryGridTile({
    required this.book,
    required this.onTap,
    super.key,
  });

  final Book book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _GridTileShell(
      cover: BookTileCover(book: book, showTitle: false, showAuthor: false),
      isFinished: book.isFinished,
      progress: book.readingProgress,
      title: book.title,
      subtitle: book.author,
      formatLabel: book.format.name.toUpperCase(),
      onTap: onTap,
    );
  }
}

/// Grid-mode tile for an [Article].
///
/// Same shape as [BookLibraryGridTile] but uses the article's site name as
/// the subtitle and has no format badge. Reading progress is sourced from
/// [Article.currentScrollOffset].
class ArticleLibraryGridTile extends StatelessWidget {
  const ArticleLibraryGridTile({
    required this.article,
    required this.onTap,
    super.key,
  });

  final Article article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _GridTileShell(
      cover: ArticleTileCover(article: article, showProgress: false),
      isFinished: article.isFinished,
      progress: article.currentScrollOffset,
      title: article.title,
      subtitle: article.siteName ?? domainOf(article.url),
      onTap: onTap,
    );
  }
}

/// Layout scaffold shared by both grid-mode tiles. Owns the geometry —
/// cover aspect ratio, badge placement, progress bar size, text spacing —
/// so book- and article-specific tiles stay small and data-focused.
class _GridTileShell extends StatelessWidget {
  const _GridTileShell({
    required this.cover,
    required this.isFinished,
    required this.progress,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.formatLabel,
  });

  final Widget cover;
  final bool isFinished;
  final double progress;
  final String title;
  final String? subtitle;
  final String? formatLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final mutedColor = colors.onSurface.withValues(alpha: _kMutedAlpha);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                cover,
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
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(1),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 2,
              backgroundColor: colors.surfaceContainerHighest,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: mutedColor),
                ),
              ],
            ),
          ),
        ],
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
