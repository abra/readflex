import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'library_bloc.dart';

const double _glyphFrameSize = 32;
const double _glyphFrameAlpha = 0.12;

/// The Library's way into Practice, leading the content under the search
/// field: an outlined row that counts what is due today, or says everything
/// is reviewed and how much is saved. It scrolls with the rows, so a short
/// window at large text keeps its list; the caller shows it only in the
/// default view and only once something is saved, so a reader who never
/// saves sees no Practice chrome in the Library.
///
/// The glyph takes the accent tint while cards are due and goes muted once
/// they are done, so the row reads at a glance. One semantics node:
/// "2 cards due today, 1 word · 1 highlight".
class LibraryPracticeRow extends StatelessWidget {
  const LibraryPracticeRow({
    required this.practice,
    required this.onPressed,
    super.key,
  });

  final LibraryPracticeSummary practice;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final due = practice.due > 0;
    final glyphColor = due ? context.actionForeground : colors.onSurfaceVariant;
    return Material(
      key: const ValueKey('libraryPracticeRow'),
      type: MaterialType.transparency,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: AppDrillInRow(
        title: due
            ? l10n.practiceDueToday(practice.due)
            : l10n.practiceCaughtUp,
        subtitle: [
          l10n.practiceWordCount(practice.words),
          l10n.practiceHighlightCount(practice.highlights),
        ].join(' · '),
        leading: DecoratedBox(
          decoration: BoxDecoration(
            color: due
                ? glyphColor.withValues(alpha: _glyphFrameAlpha)
                : colors.surfaceContainerHigh,
            shape: BoxShape.circle,
          ),
          child: SizedBox.square(
            dimension: _glyphFrameSize,
            child: Icon(
              AppIcons.practice,
              size: AppIconSize.xs,
              color: glyphColor,
            ),
          ),
        ),
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.md + AppSpacing.xxs,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
        ),
        onTap: onPressed,
      ),
    );
  }
}
