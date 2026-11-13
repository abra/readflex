import 'package:flutter/widgets.dart';

import 'app_surface.dart';
import 'app_surface_appearance.dart';

/// Normal Cupertino fill opacity: content scrolled under the capsule stays
/// faintly visible while its labels keep their contrast.
const double kAppFloatingCapsuleOpacity =
    AppSurfaceAppearance.floatingToolbarOpacity;

/// Stadium that floats a screen's bottom controls over its content: the
/// reader chrome, and the Library's collection switcher with "+".
///
/// Cupertino clips backdrop blur to the stadium; Material paints its native
/// elevation. The caller owns placement, insets and interaction feedback.
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
    return AppSurface(
      role: AppSurfaceRole.floatingToolbar,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(height: height, child: child),
    );
  }
}
