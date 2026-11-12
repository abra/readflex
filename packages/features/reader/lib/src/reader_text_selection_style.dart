import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoTheme;
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show TextSelectionTheme;

/// Shared selection colours for Flutter text and fixed-layout text overlays.
({Color fill, Color handle}) readerTextSelectionColorsOf(BuildContext context) {
  final cupertino = context.isCupertino;
  final accent = cupertino
      ? CupertinoTheme.of(context).selectionHandleColor
      : TextSelectionTheme.of(context).selectionHandleColor ??
            context.colors.primary;
  return (
    fill: accent.withValues(alpha: cupertino ? 0.20 : 0.40),
    handle: accent,
  );
}

/// Matches the live fill to Flutter's adaptive Cupertino/Material handles.
class ReaderTextSelectionStyle extends StatelessWidget {
  const ReaderTextSelectionStyle({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = readerTextSelectionColorsOf(context);
    final inherited = DefaultSelectionStyle.of(context);
    return DefaultSelectionStyle(
      selectionColor: colors.fill,
      cursorColor: inherited.cursorColor,
      mouseCursor: inherited.mouseCursor,
      child: child,
    );
  }
}
