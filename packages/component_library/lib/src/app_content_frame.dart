import 'package:flutter/widgets.dart';

import 'theme/tokens/app_sizes.dart';

/// Centers a screen's content without stretching it across a wide window.
/// The child retains the height constraints of its parent, including Expanded
/// scroll views; this frame never measures intrinsic content.
class AppContentFrame extends StatelessWidget {
  const AppContentFrame({
    required this.child,
    this.maxWidth = AppSizes.pageContentMaxWidth,
    this.padding = EdgeInsets.zero,
    super.key,
  }) : assert(maxWidth > 0);

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    );
  }
}
