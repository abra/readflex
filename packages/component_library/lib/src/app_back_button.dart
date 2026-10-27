import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'app_plain_icon_button.dart';
import 'theme/tokens/app_icon_size.dart';

/// Back action for an [AppBar.leading] slot: the app's directional chevron
/// ([AppIcons.back], the reader's glyph) in place of Material's platform
/// arrow, named with Material's localized "Back". Pops the enclosing route
/// unless [onPressed] is given.
class AppBackButton extends StatelessWidget {
  const AppBackButton({this.onPressed, this.color, super.key});

  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => AppPlainIconButton(
    icon: AppIcons.back,
    iconSize: AppIconSize.lg,
    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    color: color,
    onPressed: onPressed ?? () => Navigator.maybePop(context),
  );
}
