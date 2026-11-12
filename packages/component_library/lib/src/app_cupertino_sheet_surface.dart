import 'package:cupertino_ui/cupertino_ui.dart'
    show
        CupertinoDynamicColor,
        CupertinoPopupSurface,
        kCupertinoModalBarrierColor;
import 'package:flutter/widgets.dart';

import 'theme/extensions/build_context_ext.dart';

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
  Widget build(BuildContext context) => CupertinoPopupSurface(
    blurSigma: 0,
    isSurfacePainted: false,
    child: ColoredBox(color: context.appTheme.sheetColor, child: child),
  );
}
