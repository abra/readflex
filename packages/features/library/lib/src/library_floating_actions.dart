import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';

import 'library_add_button.dart';
import 'library_bloc.dart';
import 'library_collections_button.dart';
import 'library_layout.dart';
import 'library_practice_button.dart';

/// Inset of the 48dp controls inside the 56dp capsule, also the gap between
/// them.
const double _controlInset =
    (kLibraryFloatingActionsHeight - AppSizes.buttonHeight) / 2;

/// The collection switcher and "+" share a bottom capsule. Practice is a
/// separate plain icon above "+", aligned with it in both LTR and RTL.
///
/// Mounted in the Scaffold's floating action slot. That slot strips the safe
/// insets, so the width bound uses the 16dp gutters only; side insets exist
/// in landscape, where [kLibraryFloatingActionsMaxWidth] binds first.
class LibraryFloatingActions extends StatelessWidget {
  const LibraryFloatingActions({
    required this.scope,
    required this.onCollectionsPressed,
    required this.onAddPressed,
    this.practiceDue = 0,
    this.onPracticePressed,
    super.key,
  });

  /// The shown collection; `null` for the whole Library.
  final LibraryCollectionScope? scope;
  final VoidCallback onCollectionsPressed;

  /// `null` while an import flow is already open.
  final VoidCallback? onAddPressed;

  /// Cards due in Practice, shown as a badge.
  final int practiceDue;

  /// Opens Practice; `null` omits the separate icon.
  final VoidCallback? onPracticePressed;

  @override
  Widget build(BuildContext context) {
    final onPracticePressed = this.onPracticePressed;
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: LibraryCollectionsButton(
            scope: scope,
            onPressed: onCollectionsPressed,
          ),
        ),
        const SizedBox(width: _controlInset),
        LibraryAddButton(onPressed: onAddPressed),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = math.max(
          0.0,
          math.min(
            kLibraryFloatingActionsMaxWidth,
            constraints.maxWidth - AppSpacing.lg * 2,
          ),
        );
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: kLibraryFloatingActionsMaxTextScale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (onPracticePressed != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: _controlInset,
                      bottom: kLibraryPracticeActionGap,
                    ),
                    child: LibraryPracticeButton(
                      due: practiceDue,
                      onPressed: onPracticePressed,
                    ),
                  ),
                AppFloatingCapsule(
                  key: const ValueKey('libraryFloatingActions'),
                  height: kLibraryFloatingActionsHeight,
                  child: Padding(
                    padding: const EdgeInsets.all(_controlInset),
                    // A new collection name resizes the capsule smoothly, "+"
                    // anchored at the outer end. Reduced motion skips the
                    // widget: a zero-duration AnimatedSize re-dirties itself
                    // during its own layout.
                    child: context.reduceMotion
                        ? controls
                        : AnimatedSize(
                            duration: AppMotion.short,
                            curve: Curves.easeOutCubic,
                            alignment: AlignmentDirectional.centerEnd,
                            child: controls,
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
