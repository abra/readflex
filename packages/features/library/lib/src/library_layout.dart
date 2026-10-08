import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:flutter/widgets.dart';

/// Gap between the header's search field and the first cover (or the
/// Continue reading card). The list's row padding supplies it for rows; the grid and
/// the card add it as top padding so both layouts start at the same offset.
const double kLibraryContentTopPadding = AppSpacing.md;

/// Gap between the Continue reading card and the first cover in both layouts.
const double kLibraryContinueReadingGap = AppSpacing.lg;

/// Height of the bottom capsule (collection switcher and "+"): Material's
/// regular floating action height, holding 48dp controls 4dp from its edge.
const double kLibraryFloatingActionsHeight = AppSizes.floatingActionButton;

/// Lift of the bottom capsule above the Scaffold's own 16dp margin.
const double kLibraryFloatingActionsLift = AppSpacing.sm;

/// The bottom capsule's widest extent, so a long collection name truncates
/// instead of turning the capsule into a bar over the covers. On narrow
/// screens it also stops 16dp short of the start edge.
const double kLibraryFloatingActionsMaxWidth = 320;

/// The capsule's height is fixed (content clears it by
/// [libraryContentBottomPadding]); text grows up to 200%, which still fits
/// its 48dp controls on one line.
const double kLibraryFloatingActionsMaxTextScale = 2;

/// Bottom padding for Library grid/list content, so the last row's progress
/// bar is never hidden under the bottom capsule.
///
/// The capsule (56dp) is lifted 8dp above the Scaffold's 16dp margin, which
/// itself sits on `max(16, bottom safe inset)`; a 16dp content gap follows.
/// Only the part of the inset beyond that margin pushes the capsule further
/// up. The space stays reserved while selecting, when the selection bar
/// replaces the capsule, so entering selection never reflows the end of the
/// list.
double libraryContentBottomPadding(BuildContext context) {
  final bottomInset = MediaQuery.paddingOf(context).bottom;
  return kLibraryFloatingActionsHeight +
      kLibraryFloatingActionsLift +
      AppSpacing.lg +
      AppSpacing.lg +
      math.max(0, bottomInset - AppSpacing.lg);
}
