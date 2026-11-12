import 'package:flutter/widgets.dart';
import 'package:native_text_selection/native_text_selection.dart';

import 'theme/extensions/build_context_ext.dart';

/// Shared platform selection boundary for read-only Flutter text controls.
class AppTextSelectionHost extends StatelessWidget {
  const AppTextSelectionHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => NativeEditableSelectionHost(
    handleColor: context.theme.textSelectionTheme.selectionHandleColor,
    child: child,
  );
}
