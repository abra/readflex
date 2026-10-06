import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:flutter/widgets.dart';

/// Gap between the header's chip row and the first cover. The list's row
/// padding supplies it; the grid adds it as top padding so both layouts
/// start at the same offset.
const double kLibraryContentTopPadding = AppSpacing.md;

/// Bottom padding for Library grid/list content so the last row's progress
/// bar is never hidden under the import FAB.
///
/// The FAB (56dp) is lifted 8dp above the Scaffold's 16dp margin, which itself
/// sits on `max(16, bottom safe inset)`; a 16dp content gap follows. Only the
/// part of the inset beyond that margin pushes the button further up.
double libraryContentBottomPadding(BuildContext context) {
  final bottomInset = MediaQuery.paddingOf(context).bottom;
  return AppSizes.floatingActionButton +
      AppSpacing.sm +
      AppSpacing.lg +
      AppSpacing.lg +
      math.max(0, bottomInset - AppSpacing.lg);
}
