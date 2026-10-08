import 'package:flutter/material.dart';

import 'theme/tokens/app_shadows.dart';

/// Fill opacity of [AppFloatingCapsule]: content scrolled under it stays
/// faintly visible while its labels keep their contrast.
const double kAppFloatingCapsuleOpacity = 0.92;

/// Stadium that floats a screen's bottom controls over its content: the
/// reader chrome, and the Library's collection switcher with "+".
///
/// A dumb container: the `surface` at [kAppFloatingCapsuleOpacity], a
/// hairline `outlineVariant` border and [AppShadows.popover], with the radius
/// following [height]. The caller owns the controls, their insets and
/// placement; controls paint their own ink.
class AppFloatingCapsule extends StatelessWidget {
  const AppFloatingCapsule({
    required this.height,
    required this.child,
    super.key,
  });

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: kAppFloatingCapsuleOpacity),
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(
          color: colors.outlineVariant,
          width: 1 / MediaQuery.devicePixelRatioOf(context),
        ),
        boxShadow: AppShadows.popover,
      ),
      child: SizedBox(height: height, child: child),
    );
  }
}
