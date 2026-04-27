import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'theme/tokens/app_radius.dart';

/// Stylised cover placeholder used when a book or article has no real
/// cover image of its own.
///
/// Ported from `readwell_demo`'s `ReadwellCoverArt` — every clamp,
/// reserve, stripe, and font ratio is kept 1:1 so a library grid here
/// reads the same as the demo. The only semantic deviation is how the
/// gradient is picked: the demo stores a curated `(color1, color2)` pair
/// per item in its data layer, whereas we pick deterministically from a
/// shared palette keyed by [seed] (usually the book / article id).
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
    this.progress,
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

  /// When true, the text column is vertically centered instead of
  /// bottom-aligned. Used in grid-mode article tiles where the bottom
  /// of the cover is reserved for the progress overlay.
  final bool centerText;

  /// Reading progress in `[0, 1]`. When non-null, a rounded progress pill
  /// is rendered at the bottom of the cover. The caller decides whether
  /// to pass a value or `null` — the widget does not filter.
  final double? progress;

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    // Numbers come straight from readwell_demo's ReadwellCoverArt — do
    // not "clean up" these magic values; they were tuned together and
    // the visual falls apart quickly if you round them.
    final contentPadding = (height * 0.075).clamp(6.0, 12.0).toDouble();
    final titleFontSize = (height * 0.06875).clamp(6.0, 11.0).toDouble();
    final authorFontSize = (height * 0.06).clamp(7.0, 9.0).toDouble();
    final sourceFontSize = (height * 0.05).clamp(7.0, 8.0).toDouble();
    final articleIconSize = (height * 0.075).clamp(10.0, 12.0).toDouble();
    final showExtendedMeta = height >= 110;

    final clampedProgress = progress?.clamp(0.0, 1.0);
    final showProgress = clampedProgress != null;
    final progressBarHeight = (height * 0.022).clamp(3.0, 4.0).toDouble();
    final progressBottomInset = (contentPadding * 0.7).clamp(4.0, 8.0);
    final progressReservedSpace = showProgress
        ? progressBarHeight + progressBottomInset + 4
        : 0.0;

    final titleMaxLines = _computeTitleMaxLines(
      titleFontSize: titleFontSize,
      authorFontSize: authorFontSize,
      sourceFontSize: sourceFontSize,
      contentPadding: contentPadding,
      progressReservedSpace: progressReservedSpace,
      showExtendedMeta: showExtendedMeta,
    );

    final gradient = _pickGradient(seed ?? title);

    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        gradient: LinearGradient(
          begin: isArticle ? Alignment.bottomCenter : Alignment.topLeft,
          end: isArticle ? Alignment.topCenter : Alignment.bottomRight,
          colors: [gradient.$1, gradient.$2],
        ),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          _buildStripeTexture(),
          if (showTitle)
            _buildTextColumn(
              contentPadding: contentPadding,
              progressReservedSpace: progressReservedSpace,
              titleFontSize: titleFontSize,
              titleMaxLines: titleMaxLines,
              authorFontSize: authorFontSize,
              sourceFontSize: sourceFontSize,
              showExtendedMeta: showExtendedMeta,
              articleIconSize: articleIconSize,
            ),
          if (isArticle && showExtendedMeta)
            _buildArticleBadge(articleIconSize),
          if (showProgress)
            _buildProgressPill(
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
    required double contentPadding,
    required double progressReservedSpace,
    required bool showExtendedMeta,
  }) {
    // Dynamic title line count: grow the title to fill whatever vertical
    // space is left after padding, progress pill, and any kicker meta
    // lines. Ellipsis only triggers when the text physically doesn't fit
    // — fixed `maxLines` (demo's 2/3) leaves big gaps on tall article
    // tiles, which the user explicitly rejected.
    const titleLineHeight = 1.2;
    final authorReserve =
        showTitle && showAuthor && author != null && showExtendedMeta
        ? authorFontSize * 1.2 + 4
        : 0.0;
    final sourceReserve =
        showTitle && isArticle && source != null && showExtendedMeta
        ? sourceFontSize * 1.2 + 4
        : 0.0;
    final availableTitleHeight =
        height -
        contentPadding * 2 -
        progressReservedSpace -
        authorReserve -
        sourceReserve;
    final fittingLines =
        (availableTitleHeight / (titleFontSize * titleLineHeight)).floor();
    return fittingLines.clamp(1, isArticle ? 10 : 5).toInt();
  }

  Widget _buildStripeTexture() {
    // Opacity(0.1) on top of a stroke painted at alpha 0.05 gives an
    // effective alpha ≈ 0.005 — "texture, not decoration".
    return const Positioned.fill(
      child: Opacity(
        opacity: 0.1,
        child: CustomPaint(painter: _DiagonalStripesPainter()),
      ),
    );
  }

  Widget _buildTextColumn({
    required double contentPadding,
    required double progressReservedSpace,
    required double titleFontSize,
    required int titleMaxLines,
    required double authorFontSize,
    required double sourceFontSize,
    required bool showExtendedMeta,
    double articleIconSize = 0,
  }) {
    final textColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: titleMaxLines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: titleFontSize,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            height: 1.2,
          ),
        ),
        if (showAuthor && author != null && showExtendedMeta) ...[
          const SizedBox(height: 4),
          Text(
            author!.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: authorFontSize,
              color: Colors.white.withValues(alpha: 0.5),
              letterSpacing: 1,
            ),
          ),
        ],
        if (isArticle && source != null && showExtendedMeta) ...[
          const SizedBox(height: 4),
          Text(
            source!.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: sourceFontSize,
              color: Colors.white.withValues(alpha: 0.7),
              letterSpacing: 1,
            ),
          ),
        ],
      ],
    );

    if (centerText) {
      final topInset = isArticle ? 8 + articleIconSize + 4 : contentPadding;
      return Positioned(
        left: contentPadding,
        right: contentPadding,
        top: topInset,
        child: textColumn,
      );
    }

    return Positioned(
      left: contentPadding,
      right: contentPadding,
      bottom: contentPadding + progressReservedSpace,
      child: textColumn,
    );
  }

  Widget _buildArticleBadge(double iconSize) {
    return Positioned(
      top: 8,
      left: 8,
      child: Icon(
        AppIcons.language,
        size: iconSize,
        color: Colors.white.withValues(alpha: 0.7),
      ),
    );
  }

  Widget _buildProgressPill({
    required double contentPadding,
    required double progressBarHeight,
    required double progressBottomInset,
    required double clampedProgress,
  }) {
    return Positioned(
      left: contentPadding,
      right: contentPadding,
      bottom: progressBottomInset,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
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
  static (Color, Color) _pickGradient(String seed) {
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
