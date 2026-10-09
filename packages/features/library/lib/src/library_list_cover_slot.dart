import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';

import 'library_layout.dart';
import 'library_selection_tint.dart';

const double _selectionCheckInset = AppSpacing.xs;

/// The list row's fixed 60×90 cover slot (2:3 book aspect) with its selected
/// state: a 2dp outline, the shared cover wash and a check in the top-end
/// corner. The Continue reading card uses the same slot, so its cover sits
/// on the rows' lines and selects like a row.
class LibraryListCoverSlot extends StatelessWidget {
  const LibraryListCoverSlot({
    required this.cover,
    required this.isSelected,
    super.key,
  });

  final Widget cover;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final selectionColor = context.colors.selectionMarkerBackground;

    // AppCoverArt clips its own corners (Container.clipBehavior), so no
    // outer ClipRRect is needed.
    return SizedBox(
      width: kLibraryListCoverWidth,
      height: kLibraryListCoverHeight,
      child: Stack(
        children: [
          Positioned.fill(child: cover),
          if (isSelected) ...[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  border: Border.all(color: selectionColor, width: 2),
                  color: selectionColor.withValues(
                    alpha: kLibraryCoverSelectionTintAlpha,
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              top: _selectionCheckInset,
              end: _selectionCheckInset,
              child: _SelectionCheck(color: selectionColor),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectionCheck extends StatelessWidget {
  const _SelectionCheck({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('libraryListSelectionCheck'),
      width: 18,
      height: 18,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(
        AppIcons.check,
        size: 10,
        color: context.colors.selectionMarkerForeground,
      ),
    );
  }
}
