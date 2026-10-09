import 'package:component_library/component_library.dart';
import 'package:flutter/widgets.dart';

/// Background band under the header's search field. Scrolled content
/// clips at its lower edge, where the top scroll fade starts, so covers
/// never run flush against the field.
const double kLibraryHeaderBottomPadding = AppSpacing.md;

/// Gap between the header (its [kLibraryHeaderBottomPadding] band) and the
/// first cover or the Continue reading card. The list's row padding supplies
/// it for rows; the grid and the card add it as top padding so both layouts
/// start at the same offset.
const double kLibraryContentTopPadding = AppSpacing.md;

/// Gap between the Continue reading card and the first cover in both layouts.
const double kLibraryContinueReadingGap = AppSpacing.lg;

/// The list row's cover (2:3) and its gap to the text, between the md and lg
/// tokens. The Continue reading card uses the same, so its cover and text
/// start on the rows' lines.
const double kLibraryListCoverWidth = 60;
const double kLibraryListCoverHeight = 90;
const double kLibraryListCoverToTextGap = AppSpacing.md + AppSpacing.xxs;

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

/// Bottom padding for Library grid/list content: the last row ends a 16dp
/// gap above the bottom capsule.
///
/// The capsule (56dp) is lifted 8dp above the Scaffold's 16dp margin, which
/// sits on the bottom safe inset or the keyboard, whichever is higher
/// (`LibraryFloatingActionsLocation`). [context] is inside the Scaffold body,
/// which already ends at the keyboard and whose bottom padding is the part
/// of the safe inset the keyboard leaves uncovered, so the gap holds on every
/// keyboard frame. The space stays reserved while selecting, when the
/// selection bar replaces the capsule, so entering selection never reflows
/// the end of the list.
double libraryContentBottomPadding(BuildContext context) =>
    kLibraryFloatingActionsHeight +
    kLibraryFloatingActionsLift +
    AppSpacing.lg +
    AppSpacing.lg +
    MediaQuery.paddingOf(context).bottom;
