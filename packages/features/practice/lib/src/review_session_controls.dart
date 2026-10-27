part of 'review_session_screen.dart';

/// Close, the card's position and the overflow menu on one row, with the
/// session's progress as a thin line under it.
class ReviewSessionTopBar extends StatelessWidget {
  const ReviewSessionTopBar({
    required this.position,
    required this.total,
    required this.canOpenInSource,
    required this.onClose,
    required this.onOpenInSource,
    required this.onRemove,
    super.key,
  });

  final int position;
  final int total;
  final bool canOpenInSource;
  final VoidCallback onClose;
  final VoidCallback onOpenInSource;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg - AppSizes.iconActionOutset,
          ),
          child: Row(
            children: [
              AppPlainIconButton(
                key: const ValueKey('reviewClose'),
                tooltip: l10n.commonClose,
                icon: AppIcons.close,
                color: colors.onSurfaceVariant,
                onPressed: onClose,
              ),
              Expanded(
                child: Text(
                  l10n.practiceCardPosition(position, total),
                  key: const ValueKey('reviewPosition'),
                  textAlign: TextAlign.center,
                  style: context.text.screenCounter,
                ),
              ),
              MenuAnchor(
                menuChildren: [
                  MenuItemButton(
                    key: const ValueKey('reviewMenuOpen'),
                    onPressed: canOpenInSource ? onOpenInSource : null,
                    leadingIcon: const Icon(AppIcons.book),
                    child: Text(l10n.practiceOpenInBook),
                  ),
                  MenuItemButton(
                    key: const ValueKey('reviewMenuRemove'),
                    onPressed: onRemove,
                    leadingIcon: const Icon(AppIcons.delete),
                    child: Text(l10n.practiceRemoveFromReview),
                  ),
                ],
                builder: (context, controller, _) => AppPlainIconButton(
                  key: const ValueKey('reviewMenu'),
                  tooltip: l10n.practiceMoreActions,
                  icon: AppIcons.moreVertical,
                  color: colors.onSurfaceVariant,
                  onPressed: () => controller.isOpen
                      ? controller.close()
                      : controller.open(),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              key: const ValueKey('reviewProgress'),
              value: total == 0 ? 0 : (position - 1) / total,
              minHeight: 3,
              backgroundColor: colors.surfaceContainerHighest,
              color: context.actionForeground,
            ),
          ),
        ),
      ],
    );
  }
}

/// Show answer before the reveal; after it the ratings: Again / Hard / Good
/// with their intervals for a word, Keep / Show less for a highlight.
class ReviewSessionControls extends StatelessWidget {
  const ReviewSessionControls({
    required this.item,
    required this.revealed,
    required this.intervals,
    required this.onReveal,
    required this.onRated,
    required this.onOpenInSource,
    super.key,
  });

  final PracticeItem item;
  final bool revealed;
  final Map<Rating, Duration> intervals;
  final VoidCallback onReveal;
  final ValueChanged<Rating> onRated;
  final VoidCallback? onOpenInSource;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: context.colors.surface,
      child: AppBottomSafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            0,
          ),
          child: !revealed
              ? FilledButton(
                  key: const ValueKey('reviewShowAnswer'),
                  onPressed: onReveal,
                  child: AppButtonLabel(l10n.practiceShowAnswer),
                )
              : switch (item) {
                  PracticeWordItem() => Row(
                    spacing: AppSpacing.sm,
                    children: [
                      for (final rating in const [
                        Rating.again,
                        Rating.hard,
                        Rating.good,
                      ])
                        Expanded(
                          child: ReviewRatingButton(
                            key: ValueKey('reviewRate-${rating.name}'),
                            label: switch (rating) {
                              Rating.again => l10n.practiceRateAgain,
                              Rating.hard => l10n.practiceRateHard,
                              _ => l10n.practiceRateGood,
                            },
                            interval: intervals[rating],
                            color: switch (rating) {
                              Rating.again => context.appColors.ratingAgain,
                              Rating.hard => context.appColors.ratingHard,
                              _ => context.appColors.ratingGood,
                            },
                            onPressed: () => onRated(rating),
                          ),
                        ),
                    ],
                  ),
                  PracticeHighlightItem() => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        spacing: AppSpacing.sm,
                        children: [
                          Expanded(
                            child: ReviewRatingButton(
                              key: const ValueKey('reviewRate-keep'),
                              label: l10n.practiceKeep,
                              interval: intervals[Rating.good],
                              color: context.appColors.ratingGood,
                              onPressed: () => onRated(Rating.good),
                            ),
                          ),
                          Expanded(
                            child: ReviewRatingButton(
                              key: const ValueKey('reviewRate-showLess'),
                              label: l10n.practiceShowLess,
                              interval: intervals[Rating.easy],
                              color: context.appColors.ratingEasy,
                              onPressed: () => onRated(Rating.easy),
                            ),
                          ),
                        ],
                      ),
                      if (onOpenInSource != null)
                        TextButton(
                          key: const ValueKey('reviewOpenInBook'),
                          onPressed: onOpenInSource,
                          child: AppButtonLabel(l10n.practiceOpenInBook),
                        ),
                    ],
                  ),
                },
        ),
      ),
    );
  }
}

/// A rating with its interval under the label, tinted by the rating's colour.
class ReviewRatingButton extends StatelessWidget {
  const ReviewRatingButton({
    required this.label,
    required this.interval,
    required this.color,
    required this.onPressed,
    super.key,
  });

  final String label;
  final Duration? interval;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final interval = this.interval;
    final l10n = context.l10n;
    return Semantics(
      button: true,
      label: label,
      value: interval == null ? null : reviewIntervalLabel(l10n, interval),
      excludeSemantics: true,
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.16),
          foregroundColor: context.colors.onSurface,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          minimumSize: const Size(0, AppSizes.buttonHeight),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelLarge,
            ),
            if (interval != null)
              Text(
                reviewIntervalLabel(l10n, interval),
                maxLines: 1,
                style: context.text.labelSmall.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The session's numbers once every card is rated, with Done and a second
/// pass over the cards rated Again.
class ReviewSessionSummary extends StatelessWidget {
  const ReviewSessionSummary({
    required this.reviewed,
    required this.known,
    required this.again,
    required this.onDone,
    required this.onReviewAgain,
    super.key,
  });

  final int reviewed;
  final int known;
  final int again;
  final VoidCallback onDone;
  final VoidCallback onReviewAgain;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            AppIcons.checkCircle,
            size: AppIconSize.lg,
            color: context.actionForeground,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.practiceSessionDone,
            key: const ValueKey('reviewSummaryTitle'),
            textAlign: TextAlign.center,
            style: text.headlineMedium.copyWith(color: colors.onSurface),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.practiceSessionSummary(reviewed, known, again),
            key: const ValueKey('reviewSummaryCounts'),
            textAlign: TextAlign.center,
            style: text.bodyMedium.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            key: const ValueKey('reviewDone'),
            onPressed: onDone,
            child: AppButtonLabel(l10n.commonDone),
          ),
          if (again > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              key: const ValueKey('reviewAgain'),
              onPressed: onReviewAgain,
              child: AppButtonLabel(l10n.practiceReviewAgainCount(again)),
            ),
          ],
        ],
      ),
    );
  }
}
