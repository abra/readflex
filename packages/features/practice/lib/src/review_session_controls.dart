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
    this.isSaving = false,
    super.key,
  });

  final int position;
  final int total;
  final bool canOpenInSource;
  final VoidCallback onClose;
  final VoidCallback onOpenInSource;
  final VoidCallback onRemove;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal:
                AppSpacing.lg - AppPlainIconButton.defaultIconOutsetOf(context),
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
                  style: AppWindowSize.isMedium(context)
                      ? context.text.screenCounter.copyWith(
                          fontSize: context.text.labelLarge.fontSize,
                        )
                      : context.text.screenCounter,
                ),
              ),
              MenuAnchor(
                menuChildren: [
                  MenuItemButton(
                    key: const ValueKey('reviewMenuOpen'),
                    onPressed: canOpenInSource && !isSaving
                        ? onOpenInSource
                        : null,
                    leadingIcon: const Icon(AppIcons.book),
                    child: Text(l10n.practiceOpenInBook),
                  ),
                  MenuItemButton(
                    key: const ValueKey('reviewMenuRemove'),
                    onPressed: isSaving ? null : onRemove,
                    leadingIcon: const Icon(AppIcons.delete),
                    child: Text(l10n.practiceRemoveFromReview),
                  ),
                ],
                builder: (context, controller, _) => AppPlainIconButton(
                  key: const ValueKey('reviewMenu'),
                  tooltip: l10n.practiceMoreActions,
                  icon: AppIcons.moreVertical,
                  color: colors.onSurfaceVariant,
                  onPressed: isSaving
                      ? null
                      : () => controller.isOpen
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
            child: TickerMode(
              enabled: !context.reduceMotion,
              child: LinearProgressIndicator(
                key: const ValueKey('reviewProgress'),
                value: isSaving
                    ? null
                    : total == 0
                    ? 0
                    : (position - 1) / total,
                minHeight: 3,
                backgroundColor: colors.surfaceContainerHighest,
                color: context.actionForeground,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Words reveal their answer before rating. Highlights offer Keep / Show less
/// immediately, with the next review interval under each action.
class ReviewSessionControls extends StatelessWidget {
  const ReviewSessionControls({
    required this.item,
    required this.revealed,
    required this.intervals,
    required this.onReveal,
    required this.onRated,
    this.isSaving = false,
    super.key,
  });

  final PracticeItem item;
  final bool revealed;
  final Map<Rating, Duration> intervals;
  final VoidCallback onReveal;
  final ValueChanged<Rating> onRated;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _ReviewControlsSurface(
      child: AppContentFrame(
        maxWidth: _reviewCardMaxWidth + AppSpacing.lg * 2,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
          child: item is PracticeWordItem && !revealed
              ? FilledButton(
                  key: const ValueKey('reviewShowAnswer'),
                  onPressed: isSaving ? null : onReveal,
                  child: AppButtonLabel(l10n.practiceShowAnswer),
                )
              : switch (item) {
                  PracticeWordItem() => _WordRatingControls(
                    intervals: intervals,
                    onRated: isSaving ? null : onRated,
                  ),
                  PracticeHighlightItem() => _HighlightRatingControls(
                    intervals: intervals,
                    onRated: isSaving ? null : onRated,
                  ),
                },
        ),
      ),
    );
  }
}

/// An opaque dock, separated from the clipped reading area above it.
class _ReviewControlsSurface extends StatelessWidget {
  const _ReviewControlsSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(
    key: const ValueKey('reviewControlsShadowClip'),
    clipper: const _ReviewControlsShadowClipper(),
    child: Material(
      key: const ValueKey('reviewControlsPanel'),
      color: context.colors.surface,
      elevation: AppElevation.level1,
      surfaceTintColor: Colors.transparent,
      child: AppBottomSafeArea(child: child),
    ),
  );
}

/// The dock casts a shadow only toward the reading area above it.
class _ReviewControlsShadowClipper extends CustomClipper<Rect> {
  const _ReviewControlsShadowClipper();

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, -AppSpacing.xl, size.width, size.height);

  @override
  bool shouldReclip(_ReviewControlsShadowClipper oldClipper) => false;
}

class _HighlightRatingControls extends StatelessWidget {
  const _HighlightRatingControls({
    required this.intervals,
    required this.onRated,
  });

  final Map<Rating, Duration> intervals;
  final ValueChanged<Rating>? onRated;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final l10n = context.l10n;
      final goodInterval = intervals[Rating.good];
      final easyInterval = intervals[Rating.easy];
      final goodCaption = goodInterval == null
          ? null
          : reviewIntervalLabel(l10n, goodInterval);
      final easyCaption = easyInterval == null
          ? null
          : reviewIntervalLabel(l10n, easyInterval);
      final stacked =
          AppSheetActions.stacks(
            context,
            maxWidth: constraints.maxWidth,
            primaryLabel: l10n.practiceKeep,
            secondaryLabel: l10n.practiceShowLess,
          ) ||
          AppSheetActions.stacks(
            context,
            maxWidth: constraints.maxWidth,
            primaryLabel: goodCaption ?? '',
            secondaryLabel: easyCaption ?? '',
          );
      final minimumHeight = stacked
          ? AppSizes.buttonHeight
          : _highlightRatingRowHeight(
              context,
              maxWidth: constraints.maxWidth,
              labels: [
                (l10n.practiceKeep, goodCaption),
                (l10n.practiceShowLess, easyCaption),
              ],
            );
      final keep = ReviewRatingButton(
        key: const ValueKey('reviewRate-keep'),
        label: l10n.practiceKeep,
        interval: intervals[Rating.good],
        color: context.appColors.ratingGood,
        emphasis: ReviewRatingEmphasis.primary,
        horizontal: stacked,
        minimumHeight: minimumHeight,
        onPressed: onRated == null ? null : () => onRated!(Rating.good),
      );
      final showLess = ReviewRatingButton(
        key: const ValueKey('reviewRate-showLess'),
        label: l10n.practiceShowLess,
        interval: intervals[Rating.easy],
        color: context.appColors.ratingEasy,
        emphasis: ReviewRatingEmphasis.secondary,
        horizontal: stacked,
        minimumHeight: minimumHeight,
        onPressed: onRated == null ? null : () => onRated!(Rating.easy),
      );
      return stacked
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.sm,
              children: [keep, showLess],
            )
          : Row(
              spacing: AppSpacing.md,
              children: [
                Expanded(child: showLess),
                Expanded(child: keep),
              ],
            );
    },
  );
}

double _highlightRatingRowHeight(
  BuildContext context, {
  required double maxWidth,
  required List<(String, String?)> labels,
}) {
  final textWidth = ((maxWidth - AppSpacing.md) / 2 - AppSpacing.lg * 2)
      .clamp(0.0, double.infinity)
      .toDouble();
  final labelStyle = context.text.labelLarge;
  final intervalStyle = AppWindowSize.isMedium(context)
      ? context.text.labelLarge
      : context.text.labelSmall;
  final direction = Directionality.of(context);
  final scaler = MediaQuery.textScalerOf(context);
  final locale = Localizations.maybeLocaleOf(context);
  double textHeight(String value, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: direction,
      textScaler: scaler,
      locale: locale,
    )..layout(maxWidth: textWidth);
    final height = painter.height;
    painter.dispose();
    return height;
  }

  // Fallback fonts can give equally short captions different natural heights.
  var height = AppSizes.buttonHeight;
  for (final (label, interval) in labels) {
    final contentHeight =
        textHeight(label, labelStyle) +
        (interval == null ? 0 : textHeight(interval, intervalStyle));
    final buttonHeight = contentHeight + AppSpacing.md * 2;
    if (buttonHeight > height) {
      height = buttonHeight;
    }
  }
  return height;
}

class _WordRatingControls extends StatelessWidget {
  const _WordRatingControls({required this.intervals, required this.onRated});

  final Map<Rating, Duration> intervals;
  final ValueChanged<Rating>? onRated;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final stacked = constraints.maxWidth < 3 * 88 * scale;
        final buttons = [
          for (final rating in const [Rating.again, Rating.hard, Rating.good])
            ReviewRatingButton(
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
              horizontal: stacked,
              onPressed: onRated == null ? null : () => onRated!(rating),
            ),
        ];
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.sm,
            children: buttons,
          );
        }
        return Row(
          spacing: AppSpacing.sm,
          children: [for (final button in buttons) Expanded(child: button)],
        );
      },
    );
  }
}

enum ReviewRatingEmphasis { tonal, primary, secondary }

/// A rating with its interval and the action hierarchy of its review surface.
class ReviewRatingButton extends StatelessWidget {
  const ReviewRatingButton({
    required this.label,
    required this.interval,
    required this.color,
    required this.onPressed,
    this.emphasis = ReviewRatingEmphasis.tonal,
    this.horizontal = false,
    this.minimumHeight = AppSizes.buttonHeight,
    super.key,
  }) : assert(minimumHeight >= AppSizes.buttonHeight);

  final String label;
  final Duration? interval;
  final Color color;
  final VoidCallback? onPressed;
  final ReviewRatingEmphasis emphasis;
  final bool horizontal;
  final double minimumHeight;

  @override
  Widget build(BuildContext context) {
    final interval = this.interval;
    final l10n = context.l10n;
    final enabled = onPressed != null;
    final foreground = !enabled
        ? Theme.of(context).disabledColor
        : emphasis == ReviewRatingEmphasis.primary
        ? context.colors.onPrimary
        : context.colors.onSurface;
    final content = _ReviewRatingButtonLabel(
      label: label,
      interval: interval == null ? null : reviewIntervalLabel(l10n, interval),
      foreground: foreground,
      intervalColor: enabled && emphasis == ReviewRatingEmphasis.tonal
          ? context.colors.onSurfaceVariant
          : foreground,
      horizontal: horizontal,
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      value: interval == null ? null : reviewIntervalLabel(l10n, interval),
      onTap: onPressed,
      excludeSemantics: true,
      child: switch (emphasis) {
        ReviewRatingEmphasis.primary => FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(minimumSize: Size(0, minimumHeight)),
          child: content,
        ),
        ReviewRatingEmphasis.secondary => OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(minimumSize: Size(0, minimumHeight)),
          child: content,
        ),
        ReviewRatingEmphasis.tonal => FilledButton.tonal(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: color.withValues(alpha: 0.16),
            foregroundColor: foreground,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            minimumSize: Size(0, minimumHeight),
          ),
          child: content,
        ),
      },
    );
  }
}

class _ReviewRatingButtonLabel extends StatelessWidget {
  const _ReviewRatingButtonLabel({
    required this.label,
    required this.interval,
    required this.foreground,
    required this.intervalColor,
    required this.horizontal,
  });

  final String label;
  final String? interval;
  final Color foreground;
  final Color intervalColor;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final labelStyle = context.text.labelLarge.copyWith(color: foreground);
    final intervalStyle =
        (AppWindowSize.isMedium(context)
                ? context.text.labelLarge
                : context.text.labelSmall)
            .copyWith(color: intervalColor);
    return horizontal
        ? Row(
            children: [
              Expanded(child: Text(label, style: labelStyle)),
              if (interval case final value?) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(value, style: intervalStyle),
              ],
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, textAlign: TextAlign.center, style: labelStyle),
              if (interval case final value?)
                Text(value, textAlign: TextAlign.center, style: intervalStyle),
            ],
          );
  }
}

/// Scrollable session totals above thumb-reachable, pinned completion actions.
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            key: const ValueKey('reviewSummaryViewport'),
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - AppSpacing.xl * 2)
                    .clamp(0.0, double.infinity)
                    .toDouble(),
              ),
              child: Center(
                child: AppContentFrame(
                  maxWidth: AppSizes.centeredColumnMaxWidth,
                  child: _ReviewSummaryCard(
                    reviewed: reviewed,
                    known: known,
                    again: again,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      _ReviewSummaryActions(
        again: again,
        onDone: onDone,
        onReviewAgain: onReviewAgain,
      ),
    ],
  );
}

class _ReviewSummaryCard extends StatelessWidget {
  const _ReviewSummaryCard({
    required this.reviewed,
    required this.known,
    required this.again,
  });

  final int reviewed;
  final int known;
  final int again;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;
    return DecoratedBox(
      key: const ValueKey('reviewSummaryCard'),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Icon(
                    AppIcons.checkCircle,
                    size: AppIconSize.lg,
                    color: context.actionForeground,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              header: true,
              child: Text(
                l10n.practiceSessionDone,
                key: const ValueKey('reviewSummaryTitle'),
                textAlign: TextAlign.center,
                style: text.headlineMedium.copyWith(color: colors.onSurface),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.practiceSessionSummary(reviewed, known, again),
              key: const ValueKey('reviewSummaryCounts'),
              textAlign: TextAlign.center,
              style: text.bodyMedium.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewSummaryActions extends StatelessWidget {
  const _ReviewSummaryActions({
    required this.again,
    required this.onDone,
    required this.onReviewAgain,
  });

  final int again;
  final VoidCallback onDone;
  final VoidCallback onReviewAgain;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final primary = FilledButton(
      key: const ValueKey('reviewDone'),
      onPressed: onDone,
      child: AppButtonLabel(l10n.commonDone),
    );
    return _ReviewControlsSurface(
      child: AppContentFrame(
        maxWidth: _reviewCardMaxWidth + AppSpacing.lg * 2,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
          child: again == 0
              ? primary
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final secondaryLabel = l10n.practiceReviewAgainCount(again);
                    final secondary = OutlinedButton(
                      key: const ValueKey('reviewAgain'),
                      onPressed: onReviewAgain,
                      child: AppButtonLabel(secondaryLabel),
                    );
                    return AppSheetActions.stacks(
                          context,
                          maxWidth: constraints.maxWidth,
                          primaryLabel: l10n.commonDone,
                          secondaryLabel: secondaryLabel,
                        )
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              primary,
                              const SizedBox(height: AppSpacing.sm),
                              secondary,
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: secondary),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(child: primary),
                            ],
                          );
                  },
                ),
        ),
      ),
    );
  }
}
