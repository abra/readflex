import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';

import 'reader_layout_presets.dart';

/// Three text lines whose gap previews a [ReaderLineSpacingPreset].
///
/// Inked with the ambient [IconTheme] color like an [Icon], so a segmented
/// choice tints it for its selected and disabled states.
class ReaderLineSpacingGlyph extends StatelessWidget {
  const ReaderLineSpacingGlyph(this.preset, {super.key});

  final ReaderLineSpacingPreset preset;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: AppIconSize.sm,
      child: CustomPaint(
        painter: _LineSpacingGlyphPainter(
          gap: switch (preset) {
            ReaderLineSpacingPreset.compact => 4,
            ReaderLineSpacingPreset.normal => 6,
            ReaderLineSpacingPreset.relaxed => 8,
          },
          color: IconTheme.of(context).color ?? context.colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Draws on the 24-unit icon grid with the icon set's 2-unit stroke.
class _LineSpacingGlyphPainter extends CustomPainter {
  const _LineSpacingGlyphPainter({required this.gap, required this.color});

  final double gap;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.scale(scale, scale);
    for (var line = -1; line <= 1; line++) {
      final y = 12 + line * gap;
      canvas.drawLine(Offset(4, y), Offset(20, y), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LineSpacingGlyphPainter oldDelegate) =>
      oldDelegate.gap != gap || oldDelegate.color != color;
}
