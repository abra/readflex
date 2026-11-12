import 'package:component_library/component_library.dart';
import 'package:flutter/widgets.dart';

/// [AppFloatingActionButtonLocation.endFloat] whose bottom safe inset holds
/// while the keyboard moves.
///
/// While the keyboard reports any inset, a scaffold may pass a zero bottom
/// view padding, so `endFloat` rides a closing keyboard down into the
/// home indicator area and jumps back above it on the frame the inset
/// reaches zero (and the reverse when it opens). With the view's own bottom
/// padding the button stays `max(keyboard, safe inset) + 16dp` above the
/// screen edge on every frame; everything else is `endFloat`'s layout.
class LibraryFloatingActionsLocation extends AppFloatingActionButtonLocation {
  const LibraryFloatingActionsLocation({required this.bottomViewPadding});

  /// `MediaQuery.viewPaddingOf(context).bottom` above the scaffold. The
  /// keyboard does not change it.
  final double bottomViewPadding;

  @override
  Offset getOffset(AppScaffoldGeometry geometry) =>
      AppFloatingActionButtonLocation.endFloat.getOffset(
        geometry.copyWith(
          viewPadding: geometry.viewPadding.copyWith(bottom: bottomViewPadding),
        ),
      );

  // Equal insets avoid restarting Scaffold's location controller on rebuilds.
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
