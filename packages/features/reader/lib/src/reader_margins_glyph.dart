import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';

import 'reader_layout_presets.dart';

/// A page outline whose centered text lines preview a [ReaderMarginPreset]:
/// narrow margins leave long lines, wide margins short ones.
///
/// Inked with the ambient [IconTheme] color like an [Icon], so a segmented
/// choice tints it for its selected and disabled states.
class ReaderMarginsGlyph extends StatelessWidget {
  const ReaderMarginsGlyph(this.preset, {super.key});

  final ReaderMarginPreset preset;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: AppIconSize.sm,
      child: CustomPaint(
        painter: _MarginsGlyphPainter(
          halfLineLength: switch (preset) {
            ReaderMarginPreset.narrow => 4.5,
            ReaderMarginPreset.medium => 3,
            ReaderMarginPreset.wide => 1.5,
          },
          color: IconTheme.of(context).color ?? context.colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Draws on the 24-unit icon grid with the icon set's 2-unit stroke.
class _MarginsGlyphPainter extends CustomPainter {
  const _MarginsGlyphPainter({
    required this.halfLineLength,
    required this.color,
  });

  static final RRect _page = RRect.fromLTRBR(4, 2, 20, 22, Radius.circular(2));

  final double halfLineLength;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.scale(scale, scale);
    canvas.drawRRect(_page, paint);
    for (final y in const [8.0, 12.0, 16.0]) {
      canvas.drawLine(
        Offset(12 - halfLineLength, y),
        Offset(12 + halfLineLength, y),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MarginsGlyphPainter oldDelegate) =>
      oldDelegate.halfLineLength != halfLineLength ||
      oldDelegate.color != color;
}
