import 'package:flutter/material.dart';

/// [FloatingActionButtonLocation.endFloat] whose bottom safe inset holds
/// while the keyboard moves.
///
/// While the keyboard reports any inset, [Scaffold] passes a zero bottom
/// `minViewPadding`, so `endFloat` rides a closing keyboard down into the
/// home indicator area and jumps back above it on the frame the inset
/// reaches zero (and the reverse when it opens). With the view's own bottom
/// padding the button stays `max(keyboard, safe inset) + 16dp` above the
/// screen edge on every frame; everything else is `endFloat`'s layout.
class LibraryFloatingActionsLocation extends StandardFabLocation
    with FabEndOffsetX, FabFloatOffsetY {
  const LibraryFloatingActionsLocation({required this.bottomViewPadding});

  /// `MediaQuery.viewPaddingOf(context).bottom` above the Scaffold. The
  /// keyboard does not change it.
  final double bottomViewPadding;

  @override
  double getOffsetY(
    ScaffoldPrelayoutGeometry scaffoldGeometry,
    double adjustment,
  ) => super.getOffsetY(
    ScaffoldPrelayoutGeometry(
      bottomSheetSize: scaffoldGeometry.bottomSheetSize,
      contentBottom: scaffoldGeometry.contentBottom,
      contentTop: scaffoldGeometry.contentTop,
      floatingActionButtonSize: scaffoldGeometry.floatingActionButtonSize,
      minInsets: scaffoldGeometry.minInsets,
      minViewPadding: scaffoldGeometry.minViewPadding.copyWith(
        bottom: bottomViewPadding,
      ),
      scaffoldSize: scaffoldGeometry.scaffoldSize,
      snackBarSize: scaffoldGeometry.snackBarSize,
      materialBannerSize: scaffoldGeometry.materialBannerSize,
      textDirection: scaffoldGeometry.textDirection,
    ),
    adjustment,
  );

  // The Scaffold animates the button to every new location, so rebuilds
  // with the same inset must compare equal.
  @override
  bool operator ==(Object other) =>
      other is LibraryFloatingActionsLocation &&
      other.bottomViewPadding == bottomViewPadding;

  @override
  int get hashCode => bottomViewPadding.hashCode;

  @override
  String toString() =>
      'LibraryFloatingActionsLocation(bottomViewPadding: $bottomViewPadding)';
}
