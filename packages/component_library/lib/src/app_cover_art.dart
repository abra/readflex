import 'package:flutter/material.dart';

import 'theme/tokens/app_radius.dart';

/// Stylised cover placeholder used when a book or article has no real
/// cover image of its own.
///
/// Intended as a fallback inside list/grid tiles — orchestration of the
/// "try real cover, then fall back to this" strategy happens at the call
/// site (see `_BookMedia` / `_ArticleMedia` in content_library). This
/// widget itself never fetches images; it only paints the decorative
/// gradient + diagonal pattern + title/subtitle/progress overlays.
///
/// Colors are deterministic for a given [seed] (usually the book/article
/// id, or the title when no id is available), so the same item always
/// draws the same gradient across sessions. When [seed] is omitted, the
/// title's hashCode is used.
///
/// Must be hosted inside a bounded box (grid cell, SizedBox, Expanded).
/// The widget fills the available space and scales its typography and
/// padding to the rendered height so the same component works equally
/// well at 40x56 (list thumbnail) and 220x380 (grid tile).
class AppCoverArt extends StatelessWidget {
  const AppCoverArt({
    required this.title,
    this.subtitle,
    this.seed,
    this.progress,
    this.isArticle = false,
    super.key,
  });

  final String title;

  /// Secondary line under the title. Typically the book author or the
  /// article's site name.
  final String? subtitle;

  /// Opaque seed used to pick a gradient deterministically. Defaults to
  /// [title] when null — callers that have a stable id should pass it so
  /// renaming a book doesn't shuffle its cover color.
  final String? seed;

  /// Reading progress in `[0, 1]`. A progress bar overlay renders only
  /// when this is strictly between 0 and 1 (so "not started" and
  /// "finished" items stay clean).
  final double? progress;

  /// When true, a small `article` icon is drawn in the top-right corner
  /// so articles are visually distinguishable from books at a glance.
  final bool isArticle;

  @override
  Widget build(BuildContext context) {
    final gradient = _pickGradient(seed ?? title);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : 160.0;
          // Typography and padding scale linearly with the rendered height
          // so the same widget reads well at thumb size (40x56) and full
          // grid-tile size (~200x340). Clamps keep text from disappearing
          // on tiny previews or blowing up on hero covers.
          final contentPadding = (height * 0.075).clamp(6.0, 14.0);
          final titleFontSize = (height * 0.065).clamp(11.0, 20.0);
          final subtitleFontSize = (height * 0.05).clamp(9.0, 13.0);
          final showSubtitle = subtitle != null && height >= 90;
          final showProgressBar =
              progress != null && progress! > 0 && progress! < 1;

          return Stack(
            fit: StackFit.expand,
            children: [
              // Gradient base.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [gradient.$1, gradient.$2],
                  ),
                ),
              ),

              // Diagonal stripe pattern overlay — kept faint so it reads as
              // texture, not decoration competing with the text.
              Positioned.fill(
                child: CustomPaint(
                  painter: const _DiagonalStripesPainter(
                    color: Color(0x0DFFFFFF), // white @ 5%
                    spacing: 8,
                    strokeWidth: 1.5,
                  ),
                ),
              ),

              // Title / subtitle anchored to the bottom. Padding has to
              // account for the progress bar's 4px reservation so text
              // doesn't collide with the bar even when progress is 0/1.
              Positioned(
                left: contentPadding,
                right: contentPadding,
                bottom: contentPadding + (showProgressBar ? 8 : 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: height < 120 ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    if (showSubtitle) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: subtitleFontSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Progress bar pinned to the very bottom.
              if (showProgressBar)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 3,
                    color: Colors.white.withValues(alpha: 0.18),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress!.clamp(0.0, 1.0),
                        child: Container(
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ),
                  ),
                ),

              // Article badge in the top-right, hidden on thumbnails where
              // it'd just be visual noise.
              if (isArticle && height >= 110)
                Positioned(
                  top: contentPadding,
                  right: contentPadding,
                  child: Icon(
                    Icons.article_outlined,
                    size: (height * 0.1).clamp(14.0, 20.0),
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // Fixed palette of 8 curated gradient pairs. A larger palette would give
  // more variation but risks visual incoherence; 8 is enough that a page
  // full of cards doesn't look repetitive without feeling random.
  static (Color, Color) _pickGradient(String seed) {
    const palettes = <(Color, Color)>[
      (Color(0xFF4C5578), Color(0xFF2B3147)), // dusty indigo
      (Color(0xFF7A6B52), Color(0xFF3F372A)), // warm brown
      (Color(0xFF4F6F6B), Color(0xFF263C3A)), // muted teal
      (Color(0xFF8A5B6C), Color(0xFF3E2A33)), // dusty rose
      (Color(0xFF5A7A8C), Color(0xFF2C3E4A)), // overcast blue
      (Color(0xFF7C6A8A), Color(0xFF3A3145)), // twilight violet
      (Color(0xFF6F7A4A), Color(0xFF363C22)), // olive
      (Color(0xFF8A6F4A), Color(0xFF4A3820)), // tobacco
    ];

    // hashCode is fine here — we only need stable bucketing, not crypto.
    // abs() guards against the min-int edge case that would make % return
    // a negative index.
    final index = seed.hashCode.abs() % palettes.length;
    return palettes[index];
  }
}

/// Paints a pattern of parallel 45° stripes across the entire canvas.
///
/// Lines are spaced [spacing] pixels apart along the top edge and drawn
/// down-and-right, so the pattern tiles seamlessly regardless of the
/// parent's aspect ratio.
class _DiagonalStripesPainter extends CustomPainter {
  const _DiagonalStripesPainter({
    required this.color,
    required this.spacing,
    required this.strokeWidth,
  });

  final Color color;
  final double spacing;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    // Start well to the left so the first stripe covers the top-left
    // corner; end past the right edge by size.height so the last stripe
    // covers the bottom-right.
    for (var x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DiagonalStripesPainter old) =>
      old.color != color ||
      old.spacing != spacing ||
      old.strokeWidth != strokeWidth;
}
