part of 'practice_screen.dart';

/// Review command, floating on phones and embedded in the tablet overview.
/// When nothing is due it offers Review ahead instead.
class PracticeStartButton extends StatelessWidget {
  const PracticeStartButton({
    required this.ahead,
    required this.onPressed,
    this.floating = true,
    super.key,
  });

  /// Nothing is due: the button offers to review ahead instead.
  final bool ahead;
  final VoidCallback onPressed;
  final bool floating;

  static const double _maxTextScale = 1.5;
  static const double _iconTextScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = ahead ? l10n.practiceReviewAhead : l10n.practiceStartReview;
    final icon = Icon(ahead ? AppIcons.reviewAgain : AppIcons.practice);
    final shape = floating
        ? const StadiumBorder()
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
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
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(
              Radius.circular(AppSizes.buttonHeight / 2),
            ),
            boxShadow: floating ? AppShadows.popover : const [],
          ),
          child: scale > _iconTextScale
              ? AppButton(
                  key: const ValueKey('practiceStartReview'),
                  shape: shape,
                  minimumSize: const Size(0, AppSizes.buttonHeight),
                  onPressed: onPressed,
                  child: AppButtonLabel(label, maxLines: 1),
                )
              : AppButton.icon(
                  key: const ValueKey('practiceStartReview'),
                  shape: shape,
                  minimumSize: const Size(0, AppSizes.buttonHeight),
                  onPressed: onPressed,
                  icon: icon,
                  label: AppButtonLabel(label, maxLines: 1),
                ),
        ),
      ),
    );
  }
}

/// Today's due count, its split and wrapping review statistics.
class PracticeTodayCard extends StatelessWidget {
  const PracticeTodayCard({
    required this.due,
    required this.dueWords,
    required this.dueHighlights,
    required this.newToday,
    required this.streakDays,
    required this.reviewedLast7Days,
    required this.total,
    this.action,
    super.key,
  });

  final int due;
  final int dueWords;
  final int dueHighlights;
  final int newToday;
  final int streakDays;
  final int reviewedLast7Days;
  final int total;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;
    final muted = text.bodySmall.copyWith(color: colors.onSurfaceVariant);
    final medium = AppWindowSize.isMedium(context);
    final dueDetails = (medium ? text.bodyMedium : text.bodySmall).copyWith(
      color: colors.onSurfaceVariant,
    );
    return DecoratedBox(
      key: const ValueKey('practiceTodayCard'),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.practiceTodayTitle,
                style: (medium ? text.labelLarge : text.labelMedium).copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              due == 0 ? l10n.practiceCaughtUp : l10n.practiceDueCount(due),
              key: const ValueKey('practiceTodayDue'),
              style: AppTypography.sans(
                textStyle: text.displaySmall,
                color: colors.onSurface,
              ),
            ),
            if (due > 0) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                children: [
                  Text(l10n.practiceWordCount(dueWords), style: dueDetails),
                  Text(
                    l10n.practiceHighlightCount(dueHighlights),
                    style: dueDetails,
                  ),
                  Text(l10n.practiceNewToday(newToday), style: dueDetails),
                ],
              ),
            ],
            if (action case final child?) ...[
              const SizedBox(height: AppSpacing.xl),
              Align(alignment: AlignmentDirectional.centerStart, child: child),
            ],
            const SizedBox(height: AppSpacing.lg),
            const AppDivider(height: 1),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              key: const ValueKey('practiceTodayStats'),
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                if (streakDays > 0)
                  Text(l10n.practiceStreak(streakDays), style: muted),
                Text(l10n.practiceThisWeek(reviewedLast7Days), style: muted),
                Text(l10n.practiceTotalCards(total), style: muted),
              ],
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
      enabled: true,
      label: summary.source.title,
      value: [counts, l10n.practiceDueCount(summary.due)].join(', '),
      onTapHint: l10n.practiceStartReview,
      onTap: onPressed,
      excludeSemantics: true,
      child: AppTappable(
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
                      style:
                          (AppWindowSize.isMedium(context)
                                  ? text.labelLarge
                                  : text.labelMedium)
                              .copyWith(
                                color: summary.due == 0
                                    ? colors.onSurfaceVariant
                                    : context.actionForeground,
                              ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpacing.md),
                child: Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? AppIcons.chevronLeft
                      : AppIcons.chevronRight,
                  size: AppIconSize.sm,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
