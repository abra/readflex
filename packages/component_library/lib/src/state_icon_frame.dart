import 'package:flutter/material.dart';

import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_icon_size.dart';
import 'theme/tokens/app_sizes.dart';

/// Tinted circle behind the icon of an empty or error state.
class StateIconFrame extends StatelessWidget {
  const StateIconFrame({required this.icon, required this.color, super.key});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: AppSizes.stateIconFrame,
    height: AppSizes.stateIconFrame,
    decoration: BoxDecoration(
      color: context.colors.surfaceContainerHighest,
      shape: BoxShape.circle,
    ),
    child: Icon(icon, size: AppIconSize.md, color: color),
  );
}
