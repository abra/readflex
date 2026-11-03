import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'theme/tokens/app_shadows.dart';
import 'theme/tokens/app_spacing.dart';

/// The floating review deck: opaque cards with no surrounding button surface.
class AppFloatingPracticeIcon extends StatelessWidget {
  const AppFloatingPracticeIcon({this.showAura = false, super.key});

  /// Static emphasis for a due reminder; does not schedule animation frames.
  final bool showAura;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (showAura)
          Positioned.fill(
            top: -AppSpacing.md,
            bottom: -AppSpacing.md,
            left: -AppSpacing.md,
            right: -AppSpacing.md,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    colors.primary.withValues(alpha: .32),
                    colors.primary.withValues(alpha: .16),
                    colors.primary.withValues(alpha: 0),
                  ],
                  stops: const [0, .5, 1],
                ),
              ),
            ),
          ),
        DecoratedBox(
          decoration: ShapeDecoration(
            color: colors.surface,
            shape: const _PracticeCardsShape(),
            shadows: AppShadows.popover,
          ),
          child: const Icon(AppIcons.practiceFloating, size: 32),
        ),
      ],
    );
  }
}

/// Closed silhouettes beneath Lucide's open playing-cards-fan strokes.
class _PracticeCardsShape extends ShapeBorder {
  const _PracticeCardsShape();

  // The glyph uses a 24×24 view box. Cache the union so the overlapping
  // cards cast one shadow and only the bounds transform during painting.
  static final Path _silhouette = Path.combine(
    PathOperation.union,
    Path.combine(
      PathOperation.union,
      Path()
        ..moveTo(8, 4.389)
        ..lineTo(3.636, 5.198)
        ..arcToPoint(
          const Offset(2.034, 7.528),
          radius: const Radius.circular(2),
          clockwise: false,
        )
        ..lineTo(3.856, 17.361)
        ..arcToPoint(
          const Offset(6.187, 18.963),
          radius: const Radius.circular(2),
          clockwise: false,
        )
        ..lineTo(8.729, 18.493)
        ..close(),
      Path()..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(8, 2, 10, 14),
          const Radius.circular(2),
        ),
      ),
    ),
    Path()
      ..moveTo(12.65, 7.65)
      ..arcToPoint(
        const Offset(15.279, 6.604),
        radius: const Radius.circular(2),
      )
      ..lineTo(20.789, 8.978)
      ..arcToPoint(
        const Offset(21.835, 11.606),
        radius: const Radius.circular(2),
      )
      ..lineTo(17.878, 20.79)
      ..arcToPoint(
        const Offset(15.25, 21.836),
        radius: const Radius.circular(2),
      )
      ..lineTo(9.74, 19.462)
      ..arcToPoint(
        const Offset(8.694, 16.834),
        radius: const Radius.circular(2),
      )
      ..close(),
  );

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return _silhouette
        .transform(
          Matrix4.diagonal3Values(rect.width / 24, rect.height / 24, 1).storage,
        )
        .shift(rect.topLeft);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  // ShapeDecoration paints the fill and shadow; Icon owns the strokes.
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}
