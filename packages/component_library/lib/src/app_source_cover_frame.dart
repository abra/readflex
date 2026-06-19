import 'package:flutter/material.dart';

import 'source_cover_tokens.dart';

/// Shared physical frame for source covers.
///
/// Keeps the cover treatment identical across Library surfaces, which is
/// important for stable Hero flights: the same clipped frame, binding shade,
/// and cover shadow should participate on both route endpoints.
class AppSourceCoverFrame extends StatelessWidget {
  const AppSourceCoverFrame({
    required this.cover,
    this.overlays = const [],
    super.key,
  });

  final Widget cover;

  /// Extra widgets stacked above the cover and binding shade, such as format
  /// badges, finished badges, selection tint, or progress overlays.
  final List<Widget> overlays;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(appSourceCoverRadius);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x30000000),
            blurRadius: 6,
            spreadRadius: -1,
            offset: Offset(-2, 3),
          ),
          BoxShadow(
            color: Color(0x2A000000),
            blurRadius: 14,
            spreadRadius: -3,
            offset: Offset(-4, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
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

/// Narrow left-edge shadow that gives generated covers a physical book spine.
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
