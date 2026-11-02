import 'package:flutter/cupertino.dart' show CupertinoTheme;
import 'package:flutter/material.dart';

/// Matches the live fill to Flutter's adaptive Cupertino/Material handles.
class ReaderTextSelectionStyle extends StatelessWidget {
  const ReaderTextSelectionStyle({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cupertino =
        theme.platform == TargetPlatform.iOS ||
        theme.platform == TargetPlatform.macOS;
    final accent = cupertino
        ? CupertinoTheme.of(context).selectionHandleColor
        : TextSelectionTheme.of(context).selectionHandleColor ??
              theme.colorScheme.primary;
    final inherited = DefaultSelectionStyle.of(context);
    return DefaultSelectionStyle(
      selectionColor: accent.withValues(alpha: cupertino ? 0.20 : 0.40),
      cursorColor: inherited.cursorColor,
      mouseCursor: inherited.mouseCursor,
      child: child,
    );
  }
}
