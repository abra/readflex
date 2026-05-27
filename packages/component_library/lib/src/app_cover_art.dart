import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'source_cover_tokens.dart';
import 'theme/tokens/app_radius.dart';

/// Stylised cover placeholder used when a book has no real cover image of
/// its own.
///
/// Ported from `readwell_demo`'s `ReadwellCoverArt` — every clamp,
/// reserve, stripe, and font ratio is kept 1:1 so a library grid here
/// reads the same as the demo. The only semantic deviation is how the
/// gradient is picked: the demo stores a curated `(color1, color2)` pair
/// per item in its data layer, whereas we pick deterministically from a
/// shared palette keyed by [seed] (usually the book id).
///
/// The [isArticle] / [source] inputs render saved web articles with a
/// distinct newspaper-style treatment instead of making them look like
/// generated book covers.
///
/// Must be hosted inside a bounded box (grid cell, SizedBox, LayoutBuilder).
/// Caller passes the exact [height] / [width] — the widget does not
/// consult `LayoutBuilder` internally because several typography and
/// reserve decisions key off of `height` and need to be stable for a
/// given tile size.
class AppCoverArt extends StatelessWidget {
  const AppCoverArt({
    required this.title,
    required this.height,
    this.width,
    this.author,
    this.source,
    this.seed,
    this.isArticle = false,
    this.showAuthor = true,
    this.showTitle = true,
    this.centerText = false,
    this.topAlignText = false,
    this.topReserve = 0,
    this.bottomReserve = 0,
    this.progress,
    this.showMatte = true,
    this.articleBadgeAlignment = Alignment.topLeft,
    this.showArticleBadge = true,
    this.textDirection,
    this.textScale = 1,
    super.key,
  });

  final String title;

  /// Book author line, shown under the title when [showAuthor] is true
  /// and the cover is tall enough for extended meta (`height >= 110`).
  final String? author;

  /// Small uppercase label shown *above* the title — only for articles,
  /// and only at extended meta size. Used for site name / publication
  /// (e.g. "AP NEWS", "THE GUARDIAN").
  final String? source;

  /// Opaque seed used to pick a gradient deterministically. Defaults to
  /// [title] when null — callers that have a stable id should pass it so
  /// renaming a book doesn't shuffle its cover color.
  final String? seed;

  /// Render as article: adds a small newspaper icon in the top-left
  /// corner and surfaces the [source] label above the title.
  final bool isArticle;

  /// When false, suppresses the author line even if [author] is set.
  /// Used by the list view thumbnail where the full author text lives
  /// next to the thumbnail, not on top of it.
  final bool showAuthor;

  /// When false, suppresses the title, author, and source text on the
  /// cover entirely — only the gradient + stripe texture is drawn (plus
  /// the article icon / progress pill, if any). Used by the library
  /// list-mode thumbnail where all textual info lives in the right-hand
  /// column, not stamped on the cover. This deviates from readwell_demo
  /// (the demo keeps the title on the cover in list mode), and is an
  /// explicit user request for readflex.
  final bool showTitle;

  /// When true, the text column is bounded between the top area and
  /// [bottomReserve] instead of being bottom-aligned. Used in grid-mode
  /// article tiles where the bottom of the cover is reserved for the
  /// progress overlay.
  final bool centerText;

  /// Places fallback title/meta text near the top of the cover. Useful
  /// for generated book covers when an external progress overlay owns
  /// the bottom edge.
  final bool topAlignText;

  /// Pixel reserve at the top of the cover for an external overlay,
  /// such as the catalog grid format badge.
  final double topReserve;

  /// Pixel reserve at the bottom of the cover for an *external* overlay
  /// that the cover itself doesn't draw — typically the grid-shell's
  /// progress bar painted by the catalog grid tile on top of the cover. The
  /// title-line computation subtracts this so wrapped text never extends
  /// into the bar zone, and in [centerText] / [topAlignText] mode the text column is
  /// physically bounded above this inset so even ellipsis-edge cases
  /// don't bleed into the bar.
  final double bottomReserve;

  /// Reading progress in `[0, 1]`. When non-null, a rounded progress pill
  /// is rendered at the bottom of the cover. The caller decides whether
  /// to pass a value or `null` — the widget does not filter.
  final double? progress;

  /// Whether to draw the 2dp scaffold-colored matte border around the
  /// cover edges. Defaults to true (the demo's framed-card look). The
  /// library grid tile suppresses it so the Apple-Books-style spine
  /// strip can sit at the actual cover edge instead of being framed
  /// in by the matte.
  final bool showMatte;

  /// Corner for the article icon. Grid tiles can reserve the top-left
  /// corner for their external WEB badge and move this icon to the right.
  final Alignment articleBadgeAlignment;

  /// Whether to draw the built-in article corner icon.
  final bool showArticleBadge;

  /// Direction used for fallback cover title/meta text.
  final TextDirection? textDirection;

  /// Multiplier for fallback cover typography. Keep at `1` for dense
  /// library tiles; larger standalone covers can opt into more legible text.
  final double textScale;

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    // Numbers come straight from readwell_demo's ReadwellCoverArt — do
    // not "clean up" these magic values; they were tuned together and
    // the visual falls apart quickly if you round them.
    final contentPadding = (height * 0.075).clamp(6.0, 12.0).toDouble();
    final effectiveTextDirection =
        textDirection ?? Directionality.maybeOf(context) ?? TextDirection.ltr;
    final effectiveTextScale = textScale.clamp(0.75, 1.6).toDouble();
    final titleFontSize =
        (height * 0.06875).clamp(6.0, 11.0).toDouble() * effectiveTextScale;
    final authorFontSize =
        (height * 0.06).clamp(7.0, 9.0).toDouble() * effectiveTextScale;
    final sourceFontSize =
        (height * 0.05).clamp(7.0, 8.0).toDouble() * effectiveTextScale;
    final articleIconSize = (height * 0.075).clamp(10.0, 12.0).toDouble();
    final showExtendedMeta = height >= 110;
    final effectiveShowAuthor = showAuthor && !isArticle;

    final clampedProgress = progress?.clamp(0.0, 1.0);
    final showProgress = clampedProgress != null;
    final progressBarHeight = (height * 0.022).clamp(3.0, 4.0).toDouble();
    final progressBottomInset = (contentPadding * 0.7).clamp(4.0, 8.0);
    final progressReservedSpace = showProgress
        ? progressBarHeight + progressBottomInset + 4
        : 0.0;
    final externalReservedSpace = math.max(0.0, bottomReserve).toDouble();
    final textReservedSpace = math
        .max(
          progressReservedSpace,
          externalReservedSpace,
        )
        .toDouble();
    final externalTopReservedSpace = math.max(0.0, topReserve).toDouble();

    final useTopAlignedText = centerText || topAlignText;
    final topInset = math
        .max(
          (useTopAlignedText && isArticle && showExtendedMeta)
              ? 8 + articleIconSize + 4
              : contentPadding,
          externalTopReservedSpace,
        )
        .toDouble();
    final effectiveBottomReserve = useTopAlignedText
        ? (externalReservedSpace > 0 ? externalReservedSpace : contentPadding)
        : contentPadding + textReservedSpace;

    final titleMaxLines = _computeTitleMaxLines(
      titleFontSize: titleFontSize,
      authorFontSize: authorFontSize,
      sourceFontSize: sourceFontSize,
      topInset: topInset,
      bottomReserve: effectiveBottomReserve,
      showAuthor: effectiveShowAuthor,
      showExtendedMeta: showExtendedMeta,
    );

    final gradient = isArticle
        ? _articleGradient(seed ?? title)
        : _bookGradient(seed ?? title);
    final textColor = Colors.white;
    final metaColor = Colors.white.withValues(alpha: 0.5);
    final sourceColor = Colors.white.withValues(alpha: 0.7);
    final articleIconColor = Colors.white.withValues(alpha: 0.7);

    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(appSourceCoverRadius),
        gradient: gradient,
      ),
      foregroundDecoration: showMatte
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(appSourceCoverRadius),
              border: Border.all(
                color: Theme.of(context).scaffoldBackgroundColor,
                width: 2,
              ),
            )
          : null,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const _StripeTexture(),
          if (showTitle)
            _CoverTextColumn(
              title: title,
              author: author,
              source: source,
              showAuthor: effectiveShowAuthor,
              isArticle: isArticle,
              topAlignText: useTopAlignedText,
              contentPadding: contentPadding,
              progressReservedSpace: textReservedSpace,
              topInset: topInset,
              bottomReserve: effectiveBottomReserve,
              titleFontSize: titleFontSize,
              titleMaxLines: titleMaxLines,
              authorFontSize: authorFontSize,
              sourceFontSize: sourceFontSize,
              textColor: textColor,
              metaColor: metaColor,
              sourceColor: sourceColor,
              textDirection: effectiveTextDirection,
              showExtendedMeta: showExtendedMeta,
            ),
          if (isArticle && showArticleBadge && showExtendedMeta)
            _ArticleBadge(
              iconSize: articleIconSize,
              color: articleIconColor,
              alignment: articleBadgeAlignment,
            ),
          if (showProgress)
            _ProgressPill(
              contentPadding: contentPadding,
              progressBarHeight: progressBarHeight,
              progressBottomInset: progressBottomInset,
              clampedProgress: clampedProgress,
            ),
        ],
      ),
    );
  }

  int _computeTitleMaxLines({
    required double titleFontSize,
    required double authorFontSize,
    required double sourceFontSize,
    required double topInset,
    required double bottomReserve,
    required bool showAuthor,
    required bool showExtendedMeta,
  }) {
    // Dynamic title line count: grow the title to fill whatever vertical
    // space is left after the top inset, bottom reserve, and any kicker
    // meta lines. Ellipsis only triggers when the text physically doesn't
    // fit — fixed `maxLines` (demo's 2/3) leaves big gaps on tall article
    // tiles, which the user explicitly rejected.
    //
    // Source is reserved for up to 2 lines (its actual `maxLines` cap),
    // so a long publication name can wrap without bleeding into the
    // progress bar zone — the title just gets one fewer line of capacity
    // in that worst case.
    const titleLineHeight = 1.2;
    final authorReserve =
        showTitle && showAuthor && author != null && showExtendedMeta
        ? authorFontSize * 1.2 + 4
        : 0.0;
    final sourceReserve =
        showTitle && isArticle && source != null && showExtendedMeta
        ? sourceFontSize * 1.2 * 2 + 4
        : 0.0;
    final availableTitleHeight =
        height - topInset - bottomReserve - authorReserve - sourceReserve;
    final fittingLines =
        (availableTitleHeight / (titleFontSize * titleLineHeight)).floor();
    return fittingLines.clamp(1, isArticle ? 10 : 5).toInt();
  }

  // Palette seeded from readwell_demo/demo_data.dart — the demo hand-picks
  // a pair per `BookItem`; we don't have per-item colors in our domain, so
  // we hash the seed into this list. Stable across runs, so a given book /
  // article always draws the same gradient.
  //
  // Deviation from the demo: three of the demo's pairs (crimson, orange,
  // green) have ~equal lightness between the two stops, which produces an
  // almost-flat tile next to the other 9 pairs that all go from a dark
  // topLeft to a light bottomRight. Those three are replaced here with
  // honest dark→light pairs in the same hue family, so every cover shows
  // a consistent diagonal fall-off.
  static LinearGradient _bookGradient(String seed) {
    final colors = _coverGradientColors(seed);

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [colors.$1, colors.$2],
    );
  }

  static LinearGradient _articleGradient(String seed) {
    final colors = _coverGradientColors(seed);

    return LinearGradient(
      begin: const Alignment(-0.25, 1),
      end: const Alignment(0.25, -1),
      colors: [colors.$1, colors.$2],
    );
  }

  static (Color, Color) _coverGradientColors(String seed) {
    const palettes = <(Color, Color)>[
      (Color(0xFF8B4513), Color(0xFFD2691E)), // saddle brown
      (Color(0xFF1a1a2e), Color(0xFFe2c044)), // near black → mustard
      (Color(0xFF2c3e50), Color(0xFFe74c3c)), // navy → red
      (Color(0xFF0d1b2a), Color(0xFF1b4965)), // deep navy
      (Color(0xFF2d3436), Color(0xFF636e72)), // charcoal
      (Color(0xFF6b2fa0), Color(0xFFc471ed)), // purple
      (Color(0xFF1e3a2b), Color(0xFF4a7c59)), // forest
      (Color(0xFF7f1d1d), Color(0xFFf87171)), // crimson (readflex: dark→light)
      (Color(0xFF7c2d12), Color(0xFFfb923c)), // orange (readflex: dark→light)
      (Color(0xFF14532d), Color(0xFF4ade80)), // green (readflex: dark→light)
      (Color(0xFF34495e), Color(0xFF7f8c8d)), // slate
      (Color(0xFF2c3e50), Color(0xFF3498db)), // navy → blue
    ];

    // hashCode is fine here — we only need stable bucketing, not crypto.
    // abs() guards against the min-int edge case that would make % return
    // a negative index.
    final index = seed.hashCode.abs() % palettes.length;
    return palettes[index];
  }
}

/// Paints 45° stripes across the canvas, matched to `readwell_demo`:
/// stroke width 2, spacing 4 px along the top edge, color white @ 5%
/// (effective alpha ≈ 0.005 once the wrapping `Opacity(0.1)` applies).
class _DiagonalStripesPainter extends CustomPainter {
  const _DiagonalStripesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 2;

    for (double i = -size.height; i < size.width + size.height; i += 4) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Diagonal-stripe texture layer for [AppCoverArt]. `Opacity(0.1)` on
/// top of a stroke painted at alpha 0.05 gives an effective alpha
/// ≈ 0.005 — "texture, not decoration".
class _StripeTexture extends StatelessWidget {
  const _StripeTexture();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: Opacity(
        opacity: 0.1,
        child: CustomPaint(painter: _DiagonalStripesPainter()),
      ),
    );
  }
}

/// Title (+ optional author / source) text column for [AppCoverArt].
/// Layout switches between bottom-anchored (default) and bounded
/// `Align(topLeft)` (article tiles where a progress bar is overlaid
/// outside the cover).
class _CoverTextColumn extends StatelessWidget {
  const _CoverTextColumn({
    required this.title,
    required this.author,
    required this.source,
    required this.showAuthor,
    required this.isArticle,
    required this.topAlignText,
    required this.contentPadding,
    required this.progressReservedSpace,
    required this.topInset,
    required this.bottomReserve,
    required this.titleFontSize,
    required this.titleMaxLines,
    required this.authorFontSize,
    required this.sourceFontSize,
    required this.textColor,
    required this.metaColor,
    required this.sourceColor,
    required this.textDirection,
    required this.showExtendedMeta,
  });

  final String title;
  final String? author;
  final String? source;
  final bool showAuthor;
  final bool isArticle;
  final bool topAlignText;
  final double contentPadding;
  final double progressReservedSpace;
  final double topInset;
  final double bottomReserve;
  final double titleFontSize;
  final int titleMaxLines;
  final double authorFontSize;
  final double sourceFontSize;
  final Color textColor;
  final Color metaColor;
  final Color sourceColor;
  final TextDirection textDirection;
  final bool showExtendedMeta;

  @override
  Widget build(BuildContext context) {
    final isRtl = textDirection == TextDirection.rtl;
    final textColumn = Directionality(
      textDirection: textDirection,
      child: Column(
        crossAxisAlignment: isRtl
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.start,
            textDirection: textDirection,
            maxLines: titleMaxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              inherit: false,
              fontSize: titleFontSize,
              fontWeight: FontWeight.w600,
              color: textColor,
              height: 1.2,
              decoration: TextDecoration.none,
            ),
          ),
          if (showAuthor && author != null && showExtendedMeta) ...[
            const SizedBox(height: 4),
            Text(
              author!.toUpperCase(),
              textAlign: TextAlign.start,
              textDirection: textDirection,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                inherit: false,
                fontSize: authorFontSize,
                color: metaColor,
                letterSpacing: 1,
                decoration: TextDecoration.none,
              ),
            ),
          ],
          if (isArticle && source != null && showExtendedMeta) ...[
            const SizedBox(height: 8),
            Text(
              source!.toUpperCase(),
              textAlign: TextAlign.start,
              textDirection: textDirection,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                inherit: false,
                fontSize: sourceFontSize,
                color: sourceColor,
                letterSpacing: 1,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ],
      ),
    );

    if (topAlignText) {
      // Bound the column between the icon (top) and the bar reserve
      // (bottom) so a worst-case wrapped source plus a long
      // ellipsised title can never paint into the external
      // progress-bar zone. `Align(topLeft)` keeps the column anchored
      // at the icon edge when its intrinsic height is shorter than
      // the bounded box.
      return Positioned(
        left: contentPadding,
        right: contentPadding,
        top: topInset,
        bottom: bottomReserve,
        child: Align(
          alignment: isRtl ? Alignment.topRight : Alignment.topLeft,
          child: textColumn,
        ),
      );
    }

    return Positioned(
      left: contentPadding,
      right: contentPadding,
      bottom: contentPadding + progressReservedSpace,
      child: textColumn,
    );
  }
}

/// Small newspaper-style icon shown in the top-left corner of an
/// article-flavoured cover.
class _ArticleBadge extends StatelessWidget {
  const _ArticleBadge({
    required this.iconSize,
    required this.color,
    required this.alignment,
  });

  final double iconSize;
  final Color color;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final horizontalPosition = alignment.x > 0
        ? const _BadgeHorizontalPosition.right(8)
        : const _BadgeHorizontalPosition.left(8);
    return PositionedDirectional(
      top: 8,
      start: horizontalPosition.start,
      end: horizontalPosition.end,
      child: Icon(AppIcons.language, size: iconSize, color: color),
    );
  }
}

class _BadgeHorizontalPosition {
  const _BadgeHorizontalPosition.left(double value) : start = value, end = null;

  const _BadgeHorizontalPosition.right(double value)
    : start = null,
      end = value;

  final double? start;
  final double? end;
}

/// Bottom-anchored progress pill rendered when [AppCoverArt.progress]
/// is non-null. Translucent track + nearly-opaque fill so it reads on
/// top of any gradient.
class _ProgressPill extends StatelessWidget {
  const _ProgressPill({
    required this.contentPadding,
    required this.progressBarHeight,
    required this.progressBottomInset,
    required this.clampedProgress,
  });

  final double contentPadding;
  final double progressBarHeight;
  final double progressBottomInset;
  final double clampedProgress;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: contentPadding,
      right: contentPadding,
      bottom: progressBottomInset,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            height: progressBarHeight,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                Container(
                  width: constraints.maxWidth * clampedProgress,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
