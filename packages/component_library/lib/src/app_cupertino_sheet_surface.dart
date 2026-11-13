import 'package:cupertino_ui/cupertino_ui.dart'
    show
        CupertinoDynamicColor,
        CupertinoPopupSurface,
        kCupertinoModalBarrierColor;
import 'package:flutter/widgets.dart';

import 'app_surface_appearance.dart';

/// Internal Cupertino card shared by routed and retained bottom sheets.
/// The presenter owns positioning, safe areas and dismissal behavior.
class AppCupertinoSheetSurface extends StatelessWidget {
  const AppCupertinoSheetSurface({required this.child, super.key});

  static const double maxWidth = 540;
  static const double minimumGap = 8;

  static Color barrierColorOf(BuildContext context) => Color(
    CupertinoDynamicColor.resolve(
      kCupertinoModalBarrierColor,
      context,
    ).toARGB32(),
  );

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final appearance = AppSurfaceAppearance.resolve(
      context,
      AppSurfaceRole.modal,
    );
    return ClipPath(
      clipper: ShapeBorderClipper(shape: appearance.shape),
      child: CupertinoPopupSurface(
        blurSigma: 0,
        isSurfacePainted: false,
        child: ColoredBox(color: appearance.color, child: child),
      ),
    );
  }
}
