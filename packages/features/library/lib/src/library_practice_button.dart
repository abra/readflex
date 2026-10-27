import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

/// Material's large badge is 16dp; the ring around it is the capsule's own
/// colour, so the count stays legible where it crosses the glyph's strokes.
const double _badgeRing = 2;
const double _badgeHeight = 16 + _badgeRing * 2;

/// Counts above this show as "99+": the capsule has no room for more digits.
const int _badgeMaxCount = 99;

/// Practice in the Library's bottom capsule, between the collection switcher
/// and "+": always there, so Practice has one stable entry under the thumb
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
          onPressed: onPressed,
          iconWidget: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(AppIcons.practice, size: AppIconSize.sm),
              if (due > 0)
                // Centred on the glyph's top-end corner, as Material places
                // a badge on a 24dp icon; Flutter's defaults would cover a
                // third of this 20dp glyph. A wider count grows inwards, so
                // it stays within the 48dp target. The value already says
                // the number in words.
                PositionedDirectional(
                  top: -_badgeHeight / 2,
                  end: -_badgeHeight / 2,
                  child: ExcludeSemantics(child: _DueBadge(count: due)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The count in a primary stadium with a ring in the capsule's colour.
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
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _badgeRing + AppSpacing.xs,
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              count > _badgeMaxCount ? '$_badgeMaxCount+' : '$count',
              style: context.text.labelSmall.copyWith(color: colors.onPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
