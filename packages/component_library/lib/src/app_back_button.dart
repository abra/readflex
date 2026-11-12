import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
import 'package:material_ui/material_ui.dart';

import 'app_icons.dart';
import 'app_plain_icon_button.dart';
import 'theme/tokens/app_icon_size.dart';
import 'theme/extensions/build_context_ext.dart';

/// Platform chevron and localized back action for navigation bars.
/// Pops the enclosing route unless [onPressed] is given.
class AppBackButton extends StatelessWidget {
  const AppBackButton({this.onPressed, this.color, super.key});

  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => AppPlainIconButton(
    icon: context.isCupertino ? cupertino.CupertinoIcons.back : AppIcons.back,
    iconSize: AppIconSize.lg,
    tooltip: context.isCupertino
        ? cupertino.CupertinoLocalizations.of(context).backButtonLabel
        : MaterialLocalizations.of(context).backButtonTooltip,
    color: color,
    onPressed: onPressed ?? () => Navigator.maybePop(context),
  );
}
