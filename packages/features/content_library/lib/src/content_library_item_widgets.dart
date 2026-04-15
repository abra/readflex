import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

/// Grid-style tile for a [Book].
///
/// Layout: cover (expanded) → progress bar → title (2 lines) → author.
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
      cover: _BookMedia(book: book, showTitle: false, showAuthor: false),
      isFinished: book.isFinished,
      progress: book.readingProgress,
      title: book.title,
      subtitle: book.author,
      formatLabel: book.format.name.toUpperCase(),
      onTap: onTap,
    );
  }
}

/// Grid-style tile for an [Article].
///
/// Layout: cover (expanded) → progress bar → title (2 lines) → site name.
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
      cover: _ArticleMedia(article: article, showProgress: false),
      isFinished: article.isFinished,
      progress: article.currentScrollOffset,
      title: article.title,
      subtitle: article.siteName ?? domainOf(article.url),
      onTap: onTap,
    );
  }
}

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
    final mutedColor = colors.onSurface.withValues(alpha: 0.55);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover — fixed aspect ratio so all tiles align.
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
          // Progress bar.
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
          // Text area — takes remaining space, top-aligned.
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
        color: Colors.black.withValues(alpha: 0.55),
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
      child: const Icon(
        AppIcons.check,
        size: 11,
        color: Colors.white,
      ),
    );
  }
}

class BookLibraryListTile extends StatelessWidget {
  const BookLibraryListTile({
    required this.book,
    required this.showDivider,
    required this.onTap,
    super.key,
  });

  final Book book;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = (book.readingProgress * 100).round();

    return _ListRowShell(
      cover: _BookMedia(
        book: book,
        showAuthor: false,
        showTitle: false,
        showProgress: false,
      ),
      title: book.title,
      subtitle: book.author,
      showDivider: showDivider,
      onTap: onTap,
      metaBuilder: (context, mutedColor) => [
        // Material analogue for demo's LucideIcons.bookOpen. No sub-sm
        // icon size token exists, so we bypass AppIconSize and use the
        // exact demo-tuned literal (10).
        Icon(AppIcons.book, size: 10, color: mutedColor),
        const SizedBox(width: AppSpacing.xs),
        Text('Book', style: _metaStyle(mutedColor)),
        _MetaDot(mutedColor: mutedColor),
        Text(book.format.name.toUpperCase(), style: _metaStyle(mutedColor)),
        _MetaDot(mutedColor: mutedColor),
        if (book.isFinished)
          ..._doneBadge(context)
        else if (progress > 0)
          Text(
            '$progress%',
            style: _metaStyle(
              context.colors.onSurface,
            ).copyWith(fontWeight: FontWeight.w500),
          )
        else
          Text('New', style: _metaStyle(mutedColor)),
      ],
    );
  }
}

class ArticleLibraryListTile extends StatelessWidget {
  const ArticleLibraryListTile({
    required this.article,
    required this.showDivider,
    required this.onTap,
    super.key,
  });

  final Article article;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final readMinutes = article.estimatedWordCount > 0
        ? (article.estimatedWordCount / 200).ceil()
        : 0;

    return _ListRowShell(
      cover: Stack(
        alignment: Alignment.center,
        children: [
          _ArticleMedia(
            article: article,
            showTitle: false,
            showProgress: false,
          ),
          Icon(
            AppIcons.language,
            size: 20,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ],
      ),
      title: article.title,
      subtitle: article.siteName ?? domainOf(article.url),
      showDivider: showDivider,
      onTap: onTap,
      metaBuilder: (context, mutedColor) => [
        Icon(AppIcons.article, size: 10, color: mutedColor),
        const SizedBox(width: AppSpacing.xs),
        Text('Article', style: _metaStyle(mutedColor)),
        if (readMinutes > 0) ...[
          _MetaDot(mutedColor: mutedColor),
          Icon(AppIcons.clock, size: 10, color: mutedColor),
          const SizedBox(width: AppSpacing.xs),
          Text('$readMinutes min', style: _metaStyle(mutedColor)),
        ],
        if (article.isFinished) ...[
          _MetaDot(mutedColor: mutedColor),
          ..._doneBadge(context),
        ],
      ],
    );
  }
}

/// Shared row layout for list-mode book and article tiles. Matches
/// readwell_demo's `_ListView` row geometry: 44x60 clean cover on the
/// left, 14dp gap, right column with title / subtitle / meta row, and
/// a bottom divider except on the last row. Tap target spans the whole
/// row via `GestureDetector`.
class _ListRowShell extends StatelessWidget {
  const _ListRowShell({
    required this.cover,
    required this.title,
    required this.subtitle,
    required this.metaBuilder,
    required this.showDivider,
    required this.onTap,
  });

  final Widget cover;
  final String title;
  final String? subtitle;
  final List<Widget> Function(BuildContext context, Color mutedColor)
  metaBuilder;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final mutedColor = colors.onSurface.withValues(alpha: 0.55);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          border: showDivider
              // Project exposes a semantic divider hairline via
              // AppColorsExt (gray250 light / darkGray700 dark) —
              // that's the direct analogue of demo's `ext.divider`.
              // `ColorScheme.outlineVariant` is NOT the same role
              // here and falls back to a near-black default.
              ? Border(
                  bottom: BorderSide(color: context.appColors.divider),
                )
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Fixed 44x60 cover slot. AppCoverArt clips its own corners
            // (Container.clipBehavior), so no outer ClipRRect needed.
            SizedBox(
              width: 44,
              height: 60,
              child: cover,
            ),
            // Demo uses 14dp cover-to-text gap — sits between our
            // md(12) and lg(16) tokens. `md + xxs` = 14 exactly and
            // composes from real tokens, so we don't add a new one.
            const SizedBox(width: AppSpacing.md + AppSpacing.xxs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurface,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: mutedColor,
                      ),
                    ),
                  ],
                  // Demo uses 6dp author-to-meta gap (between xs=4 and
                  // sm=8). Composed from xs + xxs to stay token-based.
                  const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: metaBuilder(context, mutedColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dot separator ` · ` used between meta row segments. Extracted so
/// individual call sites don't repeat the fontSize/color wiring.
class _MetaDot extends StatelessWidget {
  const _MetaDot({required this.mutedColor});

  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return Text(' · ', style: _metaStyle(mutedColor));
  }
}

TextStyle _metaStyle(Color color) => TextStyle(fontSize: 11, color: color);

/// Green ` · Done` kicker shown when an item is finished. Uses the
/// semantic `successForeground` token from `AppColorsExt` — the direct
/// analogue of demo's `ext.successForeground`.
List<Widget> _doneBadge(BuildContext context) {
  final success = context.appColors.successForeground;
  return [
    Icon(AppIcons.check, size: 10, color: success),
    const SizedBox(width: 2),
    Text(
      'Done',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: success,
      ),
    ),
  ];
}

class _BookMedia extends StatelessWidget {
  const _BookMedia({
    required this.book,
    this.showAuthor = true,
    this.showTitle = true,
    this.showProgress = true,
  });

  final Book book;
  final bool showAuthor;
  final bool showTitle;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fallback = AppCoverArt(
          title: book.title,
          author: book.author,
          seed: book.id,
          progress: showProgress && book.readingProgress > 0
              ? book.readingProgress
              : null,
          showAuthor: showAuthor,
          showTitle: showTitle,
          height: constraints.maxHeight,
          width: constraints.maxWidth,
        );

        if (book.coverImagePath case final path? when path.isNotEmpty) {
          return DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: Theme.of(context).scaffoldBackgroundColor,
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Image.file(
                File(path),
                fit: BoxFit.fill,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                errorBuilder: (_, _, _) => fallback,
              ),
            ),
          );
        }

        return fallback;
      },
    );
  }
}

class _ArticleMedia extends StatelessWidget {
  const _ArticleMedia({
    required this.article,
    this.showTitle = true,
    this.showProgress = true,
  });

  final Article article;
  final bool showTitle;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    // Articles always render as a stylized cover — we deliberately do NOT
    // show the remote/cached origin image here. The demo's library shows
    // the title stamped directly on the gradient, and mixing in raw cover
    // photos would put the title awkwardly below a photo instead.
    //
    // Progress source: `currentScrollOffset` stores a normalized [0, 1]
    // fraction for articles (despite the name), already computed and
    // debounced by the reader. See the doc on `Article.currentScrollOffset`
    // for the history of the naming.
    return LayoutBuilder(
      builder: (context, constraints) => AppCoverArt(
        title: article.title,
        source: article.siteName ?? domainOf(article.url),
        seed: article.id,
        isArticle: true,
        progress: showProgress && article.currentScrollOffset > 0
            ? article.currentScrollOffset
            : null,
        showTitle: showTitle,
        height: constraints.maxHeight,
        width: constraints.maxWidth,
      ),
    );
  }
}

String domainOf(String url) {
  final host = Uri.tryParse(url)?.host;
  if (host == null || host.isEmpty) {
    return 'web';
  }

  return host.replaceFirst(RegExp(r'^www\.'), '');
}
