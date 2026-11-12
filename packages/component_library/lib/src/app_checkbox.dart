import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' as material;

import 'theme/extensions/build_context_ext.dart';

class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    required this.value,
    required this.onChanged,
    this.tristate = false,
    this.activeColor,
    this.side,
    this.shape,
    super.key,
  });

  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final bool tristate;
  final Color? activeColor;
  final BorderSide? side;
  final OutlinedBorder? shape;

  @override
  Widget build(BuildContext context) {
    if (!context.isCupertino) {
      return material.Checkbox(
        value: value,
        onChanged: onChanged,
        tristate: tristate,
        activeColor: activeColor,
        side: side,
        shape: shape,
      );
    }
    final enabled = onChanged != null;
    final selected = value != false;
    final accent =
        activeColor ?? cupertino.CupertinoTheme.of(context).primaryColor;
    void activate() => onChanged?.call(switch (value) {
      false => true,
      true => tristate ? null : false,
      null => false,
    });
    return Semantics(
      checked: value == true,
      mixed: value == null,
      enabled: enabled,
      excludeSemantics: true,
      onTap: enabled ? activate : null,
      child: cupertino.CupertinoButton(
        onPressed: enabled ? activate : null,
        padding: EdgeInsets.zero,
        minimumSize: const Size.square(48),
        child: Opacity(
          opacity: enabled ? 1 : .38,
          child: Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? accent : const Color(0x00000000),
              shape: BoxShape.circle,
              border: selected
                  ? null
                  : Border.all(
                      color: cupertino.CupertinoColors.tertiaryLabel
                          .resolveFrom(context),
                      width: 1.5,
                    ),
            ),
            child: selected
                ? Icon(
                    value == null
                        ? cupertino.CupertinoIcons.minus
                        : cupertino.CupertinoIcons.check_mark,
                    size: 16,
                    color: cupertino.CupertinoTheme.of(context)
                        .primaryContrastingColor,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
