import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';

/// Apple-Books-style "plating" wrapper for a book cover.
///
/// Adds the directional drop shadow and the soft left-edge binding
/// shade that together give the cover its physical "real book" feel.
/// The cover itself is passed in as [cover] (typically a
/// [AppSourceCover]); call sites that need extra badges or selection
/// overlays on top of the cover stack them via [overlays].
///
/// Used by both the grid and the list tiles so the cover treatment
/// stays identical across layouts.
class BookCoverPlate extends StatelessWidget {
  const BookCoverPlate({
    required this.cover,
    this.overlays = const [],
    super.key,
  });

  final Widget cover;

  /// Extra widgets stacked on top of the cover and binding shade —
  /// e.g. a format badge, a finished badge, the selection tint and
  /// checkmark, or a progress overlay. Painted in order, so later
  /// items end up on top.
  final List<Widget> overlays;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        // Two-layer Apple-Books shadow: a tight contact layer (so the
        // bottom edge looks pressed onto the surface) plus a longer
        // directional layer that gives the lift. Conservative alphas
        // keep it grounded in both light and dark themes — softer than
        // a Material elevation shadow on purpose.
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 14,
            offset: Offset(2, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Stack(
          fit: StackFit.expand,
          children: [
            cover,
            const Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3,
              child: _BindingShade(),
            ),
            ...overlays,
          ],
        ),
      ),
    );
  }
}

/// 3dp gradient on the very left edge of the cover, fading from a
/// soft dark to transparent. Reads as the spine seen edge-on without
/// being a bezel or a separator line — Apple Books does the same.
///
/// Alpha kept low (≈15%) so it stays a subtle directional hint rather
/// than a hard dark stripe along the cover's left edge.
class _BindingShade extends StatelessWidget {
  const _BindingShade();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0x26000000),
            Color(0x00000000),
          ],
        ),
      ),
    );
  }
}
