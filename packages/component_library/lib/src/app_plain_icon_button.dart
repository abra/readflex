import 'package:flutter/widgets.dart';

import 'app_icon_button.dart';
import 'app_window_size.dart';
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
    this.iconSize,
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

  /// Defaults to 20dp in narrow windows and 24dp in medium windows.
  final double? iconSize;

  /// Default glyph size for utility actions in the current window.
  static double defaultIconSizeOf(BuildContext context) =>
      AppWindowSize.isMedium(context) ? AppIconSize.md : AppIconSize.sm;

  /// Part of the 48dp target beyond its default glyph, used at content gutters.
  static double defaultIconOutsetOf(BuildContext context) =>
      (AppSizes.buttonHeight - defaultIconSizeOf(context)) / 2;

  @override
  Widget build(BuildContext context) {
    final size = iconSize ?? defaultIconSizeOf(context);
    return AppIconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      foregroundColor: color,
      disabledForegroundColor: color?.withValues(alpha: 0.38),
      backgroundColor: const Color(0x00000000),
      minimumSize: const Size.square(AppSizes.buttonHeight),
      shape: const CircleBorder(),
      icon: iconWidget ?? Icon(icon, size: size),
    );
  }
}
