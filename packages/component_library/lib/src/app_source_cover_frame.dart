import 'package:flutter/material.dart';

import 'theme/tokens/app_radius.dart';

/// Shared physical frame for source covers.
///
/// Keeps the cover treatment identical across Library and SourceDetails, which
/// is important for stable Hero flights: the same clipped frame, binding shade,
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
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
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
