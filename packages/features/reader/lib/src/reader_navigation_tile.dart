import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoListTile;
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show ListTile;

/// Reader navigation rows share their content and adapt press behavior.
class ReaderNavigationTile extends StatelessWidget {
  const ReaderNavigationTile({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.selectedTileColor,
    this.shape = const RoundedRectangleBorder(),
    this.contentPadding,
    this.minVerticalPadding,
    super.key,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final Color? selectedTileColor;
  final ShapeBorder shape;
  final EdgeInsetsGeometry? contentPadding;
  final double? minVerticalPadding;

  @override
  Widget build(BuildContext context) {
    if (!context.isCupertino) {
      return ListTile(
        title: title,
        subtitle: subtitle,
        leading: leading,
        trailing: trailing,
        onTap: onTap,
        selected: selected,
        selectedTileColor: selectedTileColor,
        shape: shape,
        contentPadding: contentPadding,
        minVerticalPadding: minVerticalPadding,
      );
    }
    return Semantics(
      selected: selected ? true : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.buttonHeight),
        child: ClipPath(
          clipper: ShapeBorderClipper(shape: shape),
          child: CupertinoListTile(
            title: title,
            subtitle: subtitle,
            leading: leading,
            trailing: trailing,
            onTap: onTap,
            padding: contentPadding,
            backgroundColor: selected
                ? selectedTileColor ?? context.colors.selectedControlBackground
                : const Color(0x00000000),
            backgroundColorActivated: context.colors.selectedControlBackground,
          ),
        ),
      ),
    );
  }
}
