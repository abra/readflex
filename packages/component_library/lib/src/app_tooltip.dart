import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' as material;

import 'theme/extensions/build_context_ext.dart';

/// A discoverable label without a Material long-press bubble on iOS.
class AppTooltip extends StatelessWidget {
  const AppTooltip({
    required this.message,
    required this.child,
    this.excludeFromSemantics = false,
    super.key,
  });

  final String message;
  final Widget child;
  final bool excludeFromSemantics;

  @override
  Widget build(BuildContext context) => material.Tooltip(
    message: message,
    excludeFromSemantics: excludeFromSemantics,
    triggerMode: context.isCupertino
        ? material.TooltipTriggerMode.manual
        : null,
    child: child,
  );
}
