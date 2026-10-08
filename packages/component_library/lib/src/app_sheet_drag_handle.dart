import 'package:flutter/widgets.dart';

import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_radius.dart';
import 'theme/tokens/app_spacing.dart';

/// Height of [AppSheetDragHandle] including its gaps: a guarded sheet keeps
/// this much space so its title does not move.
const double kAppSheetDragHandleExtent = AppSpacing.sm * 2 + 4;

/// 32×4 grab pill at the top of a draggable sheet, with an 8dp gap above and
/// below. Decorative: the sheet's own Close and scrim carry the semantics.
class AppSheetDragHandle extends StatelessWidget {
  const AppSheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Center(
        child: Container(
          width: 32,
          height: 4,
          decoration: BoxDecoration(
            color: context.colors.onSurfaceVariant.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        ),
      ),
    );
  }
}
