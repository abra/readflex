import 'package:flutter/material.dart';

import 'theme/tokens/app_icon_size.dart';
import 'theme/tokens/app_sizes.dart';

/// Unfilled utility action with circular press feedback and a full-size target.
///
/// Pass [icon] for a standard glyph, or [iconWidget] for a custom-painted one
/// (the reader's bookmark glyph, a busy indicator). Exactly one is required.
/// Disabled state dims [color] to Material's 38% rather than swapping to the
/// theme's `onSurface`, so toolbars drawn over reader surfaces keep their tone.
class AppPlainIconButton extends StatelessWidget {
  const AppPlainIconButton({
    required this.tooltip,
    required this.onPressed,
    this.icon,
    this.iconWidget,
    this.color,
    this.iconSize = AppIconSize.sm,
    super.key,
  }) : assert(
         (icon == null) != (iconWidget == null),
         'Provide exactly one of icon or iconWidget.',
       );

  final IconData? icon;
  final Widget? iconWidget;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final double iconSize;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      foregroundColor: color,
      disabledForegroundColor: color?.withValues(alpha: 0.38),
      backgroundColor: Colors.transparent,
      minimumSize: const Size.square(AppSizes.buttonHeight),
      shape: const CircleBorder(),
      visualDensity: VisualDensity.standard,
    ),
    icon: iconWidget ?? Icon(icon, size: iconSize),
  );
}
