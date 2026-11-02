import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

/// Material's large badge is 16dp; the ring around it is the app surface's
/// colour, so the count stays legible where it crosses the glyph's strokes.
const double _badgeRing = 2;
const double _badgeHeight = 16 + _badgeRing * 2;
const double _practiceIconSize = 32;
const double _badgeOutset = (AppSizes.buttonHeight - _practiceIconSize) / 2;

/// Counts above this show as "99+" to stay inside the touch target.
const int _badgeMaxCount = 99;

/// A plain Practice icon above "+", outside the Library's bottom capsule:
/// Practice has one stable entry under the thumb
/// even before anything is saved, with the due count as a badge once cards
/// are waiting.
///
/// One semantics node: "Practice, 2 cards due today".
class LibraryPracticeButton extends StatelessWidget {
  const LibraryPracticeButton({
    required this.due,
    required this.onPressed,
    super.key,
  });

  /// Cards due now; zero hides the badge.
  final int due;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    return MergeSemantics(
      key: const ValueKey('libraryPracticeButton'),
      child: Semantics(
        value: due > 0 ? l10n.practiceDueToday(due) : null,
        child: AppPlainIconButton(
          tooltip: l10n.practiceTitle,
          color: colors.onSurface,
          iconSize: _practiceIconSize,
          onPressed: onPressed,
          iconWidget: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                AppIcons.practiceFloating,
                size: _practiceIconSize,
                shadows: [
                  for (final shadow in AppShadows.popover)
                    Shadow(
                      color: shadow.color,
                      offset: shadow.offset,
                      blurRadius: shadow.blurRadius,
                    ),
                ],
              ),
              if (due > 0)
                // Offset to the corner while staying inside the 48dp target.
                // A wider count grows inwards; semantics say the full count.
                PositionedDirectional(
                  top: -_badgeOutset,
                  end: -_badgeOutset,
                  child: ExcludeSemantics(child: _DueBadge(count: due)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The count in a primary stadium with a ring in the surface's colour.
class _DueBadge extends StatelessWidget {
  const _DueBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      key: const ValueKey('libraryPracticeBadge'),
      decoration: ShapeDecoration(
        color: colors.primary,
        shape: StadiumBorder(
          side: BorderSide(color: colors.surface, width: _badgeRing),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: _badgeHeight,
          minHeight: _badgeHeight,
          maxWidth: AppSizes.buttonHeight,
          maxHeight: AppSizes.buttonHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _badgeRing + AppSpacing.xs,
            vertical: _badgeRing,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              count > _badgeMaxCount ? '$_badgeMaxCount+' : '$count',
              maxLines: 1,
              softWrap: false,
              textDirection: TextDirection.ltr,
              style: context.text.labelSmall.copyWith(color: colors.onPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
