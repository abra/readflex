import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_floating_actions_location.dart';

void main() {
  const scaffold = Size(390, 844);
  const fab = Size(220, 64);
  const safeInset = 34.0;

  // What the Scaffold passes: `minInsets.bottom` is the keyboard, and
  // `minViewPadding.bottom` is zeroed while any keyboard inset is reported.
  ScaffoldPrelayoutGeometry geometry({
    double keyboard = 0,
    double viewPadding = safeInset,
    Size snackBar = Size.zero,
    Size bottomSheet = Size.zero,
    TextDirection textDirection = TextDirection.ltr,
  }) => ScaffoldPrelayoutGeometry(
    bottomSheetSize: bottomSheet,
    contentBottom: scaffold.height - keyboard,
    contentTop: 0,
    floatingActionButtonSize: fab,
    minInsets: EdgeInsets.only(bottom: keyboard),
    minViewPadding: EdgeInsets.only(bottom: keyboard == 0 ? viewPadding : 0),
    scaffoldSize: scaffold,
    snackBarSize: snackBar,
    materialBannerSize: Size.zero,
    textDirection: textDirection,
  );

  const location = LibraryFloatingActionsLocation(
    bottomViewPadding: safeInset,
  );
  double gapFor(ScaffoldPrelayoutGeometry geometry) =>
      scaffold.height - (location.getOffset(geometry).dy + fab.height);

  test('matches endFloat without a keyboard', () {
    for (final textDirection in TextDirection.values) {
      final rest = geometry(textDirection: textDirection);
      expect(
        location.getOffset(rest),
        FloatingActionButtonLocation.endFloat.getOffset(rest),
      );
    }
  });

  test('stays on the safe inset or the keyboard, whichever is higher', () {
    for (final keyboard in [320.0, 60.0, safeInset, 20.0, 1.0, 0.0]) {
      expect(
        gapFor(geometry(keyboard: keyboard)),
        closeTo(
          (keyboard > safeInset ? keyboard : safeInset) +
              kFloatingActionButtonMargin,
          .01,
        ),
        reason: 'keyboard $keyboard',
      );
    }
    // endFloat drops into the inset under a nearly closed keyboard.
    expect(
      scaffold.height -
          (FloatingActionButtonLocation.endFloat
                  .getOffset(geometry(keyboard: 1))
                  .dy +
              fab.height),
      1 + kFloatingActionButtonMargin,
    );
  });

  test('keeps endFloat clear of snack bars and bottom sheets', () {
    for (final keyboard in [0.0, 20.0]) {
      final withSnackBar = geometry(
        keyboard: keyboard,
        snackBar: const Size(390, 120),
      );
      final withSheet = geometry(
        keyboard: keyboard,
        bottomSheet: const Size(390, 300),
      );
      expect(
        location.getOffset(withSnackBar).dy,
        lessThanOrEqualTo(
          withSnackBar.contentBottom -
              120 -
              fab.height -
              kFloatingActionButtonMargin,
        ),
      );
      expect(
        location.getOffset(withSheet).dy,
        withSheet.contentBottom - 300 - fab.height / 2,
      );
    }
  });

  test('a view without a safe inset keeps the 16dp margin', () {
    const flat = LibraryFloatingActionsLocation(bottomViewPadding: 0);
    for (final keyboard in [0.0, 20.0]) {
      final g = geometry(keyboard: keyboard, viewPadding: 0);
      expect(
        scaffold.height - (flat.getOffset(g).dy + fab.height),
        keyboard + kFloatingActionButtonMargin,
      );
    }
  });

  test('equal insets compare equal, so rebuilds do not move the button', () {
    expect(
      location,
      const LibraryFloatingActionsLocation(bottomViewPadding: safeInset),
    );
    expect(
      location.hashCode,
      const LibraryFloatingActionsLocation(
        bottomViewPadding: safeInset,
      ).hashCode,
    );
    expect(
      location,
      isNot(const LibraryFloatingActionsLocation(bottomViewPadding: 21)),
    );
  });
}
