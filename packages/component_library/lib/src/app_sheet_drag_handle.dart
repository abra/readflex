import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoColors, CupertinoDynamicColor;
import 'package:flutter/widgets.dart';

import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_radius.dart';
import 'theme/tokens/app_spacing.dart';

/// Height of [AppSheetDragHandle] including its gaps: a guarded sheet keeps
/// this much space so its title does not move.
const double kAppSheetDragHandleExtent = AppSpacing.sm * 2 + 4;

/// Platform drag affordance in a stable 20dp slot. Decorative: the sheet's
/// explicit Close and scrim carry the semantics.
class AppSheetDragHandle extends StatelessWidget {
  const AppSheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final cupertino = context.isCupertino;
    return Padding(
      padding: cupertino
          ? const EdgeInsets.only(top: 5, bottom: 10)
          : const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Center(
        child: Container(
          width: cupertino ? 36 : 32,
          height: cupertino ? 5 : 4,
          decoration: BoxDecoration(
            color: cupertino
                ? CupertinoDynamicColor.resolve(
                    CupertinoColors.tertiaryLabel,
                    context,
                  )
                : context.colors.onSurfaceVariant.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        ),
      ),
    );
  }
}
