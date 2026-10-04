import 'package:flutter/material.dart';

import 'theme/tokens/app_icon_size.dart';
import 'theme/tokens/app_sizes.dart';

/// Unfilled utility action with circular press feedback and a full-size target.
class AppPlainIconButton extends StatelessWidget {
  const AppPlainIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.iconSize = AppIconSize.sm,
    super.key,
  });

  final IconData icon;
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
      backgroundColor: Colors.transparent,
      minimumSize: const Size.square(AppSizes.buttonHeight),
      shape: const CircleBorder(),
      visualDensity: VisualDensity.standard,
    ),
    icon: Icon(icon, size: iconSize),
  );
}
