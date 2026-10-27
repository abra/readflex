part of 'practice_screen.dart';

/// Start review as one filled stadium floating over the content, the
/// Library "+" circle stretched to carry a label: no capsule around it, so
/// nothing peeks out from under the button. When nothing is due it offers
/// Review ahead instead.
class PracticeStartButton extends StatelessWidget {
  const PracticeStartButton({
    required this.ahead,
    required this.onPressed,
    super.key,
  });

  /// Nothing is due: the button offers to review ahead instead.
  final bool ahead;
  final VoidCallback onPressed;

  static const double _maxTextScale = 1.5;
  static const double _iconTextScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = ahead ? l10n.practiceReviewAhead : l10n.practiceStartReview;
    final icon = Icon(ahead ? AppIcons.reviewAgain : AppIcons.practice);
    final style = FilledButton.styleFrom(
      shape: const StadiumBorder(),
      minimumSize: const Size(0, AppSizes.buttonHeight),
    );
    // The button keeps its height: the label scales up to 1.5× and drops
    // its icon past 1.3×, and the whole never exceeds the screen minus the
    // gutters, so the longest localized label still fits on one line.
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - AppSpacing.lg * 2,
      ),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: _maxTextScale,
        child: DecoratedBox(
          // The same soft shadow the Library capsule floats on.
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(
              Radius.circular(AppSizes.buttonHeight / 2),
            ),
            boxShadow: AppShadows.popover,
          ),
          child: scale > _iconTextScale
              ? FilledButton(
                  key: const ValueKey('practiceStartReview'),
                  style: style,
                  onPressed: onPressed,
                  child: AppButtonLabel(label, maxLines: 1),
                )
              : FilledButton.icon(
                  key: const ValueKey('practiceStartReview'),
                  style: style,
                  onPressed: onPressed,
                  icon: icon,
                  label: AppButtonLabel(label, maxLines: 1),
                ),
        ),
      ),
    );
  }
}

/// Today's numbers: the due count large, its split, then the streak and
/// totals in one muted line.
class PracticeTodayCard extends StatelessWidget {
  const PracticeTodayCard({
    required this.due,
    required this.dueWords,
    required this.dueHighlights,
    required this.newToday,
    required this.streakDays,
    required this.reviewedLast7Days,
    required this.total,
    super.key,
  });

  final int due;
  final int dueWords;
  final int dueHighlights;
  final int newToday;
  final int streakDays;
  final int reviewedLast7Days;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;
    final muted = text.bodySmall.copyWith(color: colors.onSurfaceVariant);
    // The outlined frame of the Library's Practice row: the two surfaces
    // say the same thing and look the same.
    return DecoratedBox(
      key: const ValueKey('practiceTodayCard'),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.practiceTodayTitle,
              style: text.labelMedium.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              due == 0 ? l10n.practiceCaughtUp : l10n.practiceDueCount(due),
              key: const ValueKey('practiceTodayDue'),
              style: AppTypography.sans(
                textStyle: text.headlineLarge,
                color: colors.onSurface,
              ),
            ),
            if (due > 0) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                [
                  l10n.practiceWordCount(dueWords),
                  l10n.practiceHighlightCount(dueHighlights),
                  l10n.practiceNewToday(newToday),
                ].join(' · '),
                style: muted,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              [
                if (streakDays > 0) l10n.practiceStreak(streakDays),
                l10n.practiceThisWeek(reviewedLast7Days),
                l10n.practiceTotalCards(total),
              ].join(' · '),
              key: const ValueKey('practiceTodayStats'),
              style: muted,
            ),
          ],
        ),
      ),
    );
  }
}

const double _sourceCoverWidth = 40;
const double _sourceCoverHeight = 60;

/// One source's share: its cover, title, counts and what is due. Tap starts
/// a review of that source.
class PracticeSourceRow extends StatelessWidget {
  const PracticeSourceRow({
    required this.summary,
    required this.onPressed,
    super.key,
  });

  final PracticeSourceSummary summary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;
    final counts = [
      l10n.practiceWordCount(summary.words),
      l10n.practiceHighlightCount(summary.highlights),
    ].join(' · ');
    return Semantics(
      button: true,
      label: summary.source.title,
      value: [counts, l10n.practiceDueCount(summary.due)].join(', '),
      onTapHint: l10n.practiceStartReview,
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              SizedBox(
                width: _sourceCoverWidth,
                height: _sourceCoverHeight,
                child: PracticeSourceCover(source: summary.source),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.source.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      // The Library list's title role: one row vocabulary.
                      style: text.sourceListTitle.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      counts,
                      style: text.bodySmall.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      summary.due == 0
                          ? l10n.practiceCaughtUpShort
                          : l10n.practiceDueCount(summary.due),
                      key: ValueKey('practiceSourceDue-${summary.source.id}'),
                      style: text.labelMedium.copyWith(
                        color: summary.due == 0
                            ? colors.onSurfaceVariant
                            : context.actionForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                AppIcons.chevronRight,
                size: AppIconSize.sm,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
