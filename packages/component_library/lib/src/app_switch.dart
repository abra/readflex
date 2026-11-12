import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' as material;

import 'theme/extensions/build_context_ext.dart';

class AppSwitch extends StatelessWidget {
  const AppSwitch({
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.autofocus = false,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    child: context.isCupertino
        ? cupertino.CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: activeColor,
            autofocus: autofocus,
          )
        : material.Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: activeColor,
            autofocus: autofocus,
          ),
  );
}
