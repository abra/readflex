import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'library_source_semantics.dart';

const double _coverWidth = 64;
const double _coverHeight = 96;
const double _progressBarHeight = 4;
const double _articleIconAlpha = 0.4;

/// Shortcut to the most recently read source, shown above the Library
/// content in the default view. The whole card is one button; long-press
/// does nothing: it neither enters selection mode nor opens on release.
class LibraryContinueReadingCard extends StatelessWidget {
  const LibraryContinueReadingCard({
    required this.source,
    required this.onPressed,
    super.key,
  });

  final LibrarySource source;
  final VoidCallback onPressed;

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
    final mutedStyle = text.bodySmall.copyWith(color: colors.onSurfaceVariant);
    final radius = BorderRadius.circular(AppRadius.lg);

    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: librarySourceSemanticsLabel(source, l10n),
      value: [l10n.librarySourcePercentRead(percent), ?timeLeft].join(', '),
      onTap: onPressed,
      child: Material(
        key: const ValueKey('libraryContinueReadingCard'),
        color: colors.surfaceContainerLow,
        borderRadius: radius,
        // Wins the arena over the InkWell's tap once a press is held.
        child: GestureDetector(
          onLongPress: () {},
          child: InkWell(
            onTap: onPressed,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  SizedBox(
                    key: const ValueKey('libraryContinueReadingCover'),
                    width: _coverWidth,
                    height: _coverHeight,
                    child: _ContinueReadingCover(source: source),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.libraryContinueReading,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelSmall.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          source.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.serif(
                            textStyle: text.titleMedium,
                            color: colors.onSurface,
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
                        _ContinueReadingProgressBar(progress: progress),
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
  const _ContinueReadingProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: SizedBox(
        key: const ValueKey('libraryContinueReadingProgress'),
        width: double.infinity,
        height: _progressBarHeight,
        child: ColoredBox(
          color: context.colors.surfaceContainerHighest,
          child: FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: progress,
            child: ColoredBox(
              key: const ValueKey('libraryContinueReadingProgressFill'),
              color: context.actionForeground,
            ),
          ),
        ),
      ),
    );
  }
}
