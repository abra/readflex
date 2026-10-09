import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'library_layout.dart';
import 'library_list_cover_slot.dart';
import 'library_source_semantics.dart';

const double _progressBarHeight = 4;
const double _articleIconAlpha = 0.4;
const double _selectedTrackAlpha = 0.24;

/// Shortcut to the most recently read source, leading the Library content in
/// the default view. It is that source's place there: the list and grid
/// below leave it out.
///
/// A full-width band, like a row's selection fill, whose cover and text sit
/// on the list rows' lines (16dp gutter, [LibraryListCoverSlot], 14dp gap).
/// It behaves like a row: tap opens (or toggles while selecting), long-press
/// starts selection, and a selected card takes the row's selected colours.
class LibraryContinueReadingCard extends StatelessWidget {
  const LibraryContinueReadingCard({
    required this.source,
    required this.onPressed,
    required this.onLongPressed,
    this.isSelectionMode = false,
    this.isSelected = false,
    super.key,
  });

  final LibrarySource source;
  final VoidCallback onPressed;
  final VoidCallback onLongPressed;
  final bool isSelectionMode;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final l10n = context.l10n;
    final progress = source.readingProgress.clamp(0.0, 1.0).toDouble();
    final percent = (progress * 100).round();
    final timeLeft = l10n.readingTimeLeft(source.estimatedMinutesLeft);
    final caption = timeLeft == null ? '$percent%' : '$percent% · $timeLeft';
    final author = source.author?.trim();
    final hasAuthor = author != null && author.isNotEmpty;
    // A selected card is a selected control, like a selected row.
    final emphasisColor = isSelected
        ? colors.selectedControlForeground
        : colors.onSurface;
    final mutedColor = isSelected
        ? colors.selectedControlForeground
        : colors.onSurfaceVariant;
    final mutedStyle = text.bodySmall.copyWith(color: mutedColor);

    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      selected: isSelectionMode ? isSelected : null,
      label: librarySourceSemanticsLabel(source, l10n),
      value: [l10n.librarySourcePercentRead(percent), ?timeLeft].join(', '),
      onTapHint: librarySourceTapHint(
        isSelectionMode: isSelectionMode,
        isSelected: isSelected,
        l10n: l10n,
      ),
      onLongPressHint: librarySourceLongPressHint(
        isSelectionMode: isSelectionMode,
        l10n: l10n,
      ),
      onTap: onPressed,
      onLongPress: onLongPressed,
      child: Material(
        key: const ValueKey('libraryContinueReadingCard'),
        color: isSelected
            ? colors.selectedControlBackground
            : colors.surfaceContainerLow,
        child: InkWell(
          onTap: onPressed,
          onLongPress: onLongPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                LibraryListCoverSlot(
                  key: const ValueKey('libraryContinueReadingCover'),
                  cover: _ContinueReadingCover(source: source),
                  isSelected: isSelected,
                ),
                const SizedBox(width: kLibraryListCoverToTextGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.libraryContinueReading,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelSmall.copyWith(color: mutedColor),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        source.title,
                        key: const ValueKey('libraryContinueReadingTitle'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.serif(
                          textStyle: text.titleMedium,
                          color: emphasisColor,
                        ),
                      ),
                      if (hasAuthor) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: mutedStyle,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      _ContinueReadingProgressBar(
                        progress: progress,
                        isSelected: isSelected,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        caption,
                        key: const ValueKey('libraryContinueReadingCaption'),
                        style: mutedStyle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Same generated cover as list rows: artwork only, with the article globe.
class _ContinueReadingCover extends StatelessWidget {
  const _ContinueReadingCover({required this.source});

  final LibrarySource source;

  @override
  Widget build(BuildContext context) {
    final isArticle = source.sourceType == SourceType.article;
    final cover = AppSourceCover(
      title: source.title,
      author: source.author,
      source: source.sourceName,
      seed: source.id,
      isArticle: isArticle,
      coverImage: appSourceCoverImageFromPath(source.coverImagePath),
      textDirection: switch (source.inferredTextDirection) {
        ArticleTextDirection.rtl => TextDirection.rtl,
        ArticleTextDirection.ltr || null => TextDirection.ltr,
      },
      showAuthor: false,
      showTitle: false,
      showProgress: false,
      showMatte: false,
    );

    return AppSourceCoverFrame(
      cover: isArticle
          ? Stack(
              alignment: Alignment.center,
              children: [
                cover,
                Icon(
                  AppIcons.language,
                  size: AppIconSize.md,
                  color: Colors.white.withValues(alpha: _articleIconAlpha),
                ),
              ],
            )
          : cover,
    );
  }
}

class _ContinueReadingProgressBar extends StatelessWidget {
  const _ContinueReadingProgressBar({
    required this.progress,
    required this.isSelected,
  });

  final double progress;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // On the selected fill the accent fill would vanish (dark mode's fill is
    // the accent itself), so the bar takes the selected foreground.
    final fill = isSelected
        ? colors.selectedControlForeground
        : context.actionForeground;
    final track = isSelected
        ? colors.selectedControlForeground.withValues(
            alpha: _selectedTrackAlpha,
          )
        : colors.surfaceContainerHighest;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: SizedBox(
        key: const ValueKey('libraryContinueReadingProgress'),
        width: double.infinity,
        height: _progressBarHeight,
        child: ColoredBox(
          color: track,
          child: FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: progress,
            child: ColoredBox(
              key: const ValueKey('libraryContinueReadingProgressFill'),
              color: fill,
            ),
          ),
        ),
      ),
    );
  }
}
