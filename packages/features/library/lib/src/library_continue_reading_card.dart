import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'library_continue_reading_title_layout.dart';
import 'library_layout.dart';
import 'library_list_cover_slot.dart';
import 'library_progress_fill.dart';
import 'library_source_semantics.dart';
import 'library_title_layout.dart';

const double _progressBarHeight = 4;
const double _articleIconAlpha = 0.4;
const double _selectedTrackAlpha = 0.24;

/// Shortcut to the most recently read source, leading the Library content in
/// the default view. It is that source's place there: the list and grid
/// below leave it out.
///
/// An inset reading panel with the row's compact cover and full title.
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
    final wide = AppWindowSize.isWide(context);
    const coverWidth = kLibraryListCoverWidth;
    const coverHeight = kLibraryListCoverHeight;
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
    final medium = AppWindowSize.isMedium(context);
    final mutedStyle = (medium ? text.bodyMedium : text.bodySmall).copyWith(
      color: mutedColor,
    );
    final overlineStyle = (medium ? text.labelLarge : text.labelSmall).copyWith(
      color: mutedColor,
    );
    final titleStyle = AppTypography.serif(
      textStyle: wide ? text.titleLarge : text.titleMedium,
      color: emphasisColor,
    );
    final expanded =
        MediaQuery.textScalerOf(context).scale(titleStyle.fontSize!) >
        titleStyle.fontSize! * 1.3;
    final metadataHeight = _lineHeight(context, mutedStyle);
    final headerHeight = math.max(
      metadataHeight,
      _lineHeight(context, overlineStyle),
    );
    final preferredTitleHeight = _lineHeight(context, titleStyle);
    final showHeader =
        headerHeight +
            AppSpacing.xxs +
            preferredTitleHeight +
            _progressBarHeight <=
        coverHeight;
    final separateAuthor =
        showHeader &&
        headerHeight +
                AppSpacing.xxs * 2 +
                preferredTitleHeight +
                metadataHeight +
                _progressBarHeight <=
            coverHeight;
    final appearance = AppSurfaceAppearance.resolve(
      context,
      AppSurfaceRole.contentCard,
    );
    final shape = isSelected
        ? appearance.shape.copyWith(
            side: BorderSide(color: colors.selectedControlForeground),
          )
        : appearance.shape;

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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: AppSurface(
          key: const ValueKey('libraryContinueReadingCard'),
          role: AppSurfaceRole.contentCard,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          color: isSelected ? colors.selectedControlBackground : null,
          child: AppTappable(
            customBorder: shape,
            onTap: onPressed,
            onLongPress: onLongPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.lg,
              ),
              child: expanded
                  ? _ContinueReadingExpandedContent(
                      source: source,
                      caption: caption,
                      progress: progress,
                      isSelected: isSelected,
                      coverWidth: coverWidth,
                      coverHeight: coverHeight,
                      titleStyle: titleStyle,
                      mutedStyle: mutedStyle,
                      overlineStyle: overlineStyle,
                    )
                  : SizedBox(
                      height: coverHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LibraryListCoverSlot(
                            key: const ValueKey('libraryContinueReadingCover'),
                            cover: _ContinueReadingCover(source: source),
                            isSelected: isSelected,
                            width: coverWidth,
                            height: coverHeight,
                          ),
                          const SizedBox(width: kLibraryListCoverToTextGap),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (showHeader) ...[
                                  SizedBox(
                                    height: headerHeight,
                                    child: _ContinueReadingHeader(
                                      label: !separateAuthor && hasAuthor
                                          ? author
                                          : l10n.libraryContinueReading,
                                      labelStyle: !separateAuthor && hasAuthor
                                          ? mutedStyle
                                          : overlineStyle,
                                      caption: caption,
                                      captionStyle: mutedStyle,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xxs),
                                ],
                                Expanded(
                                  child: _ContinueReadingDetails(
                                    title: source.title,
                                    style: titleStyle,
                                    author: separateAuthor && hasAuthor
                                        ? author
                                        : null,
                                    authorStyle: mutedStyle,
                                    authorHeight: separateAuthor
                                        ? metadataHeight + AppSpacing.xxs
                                        : 0,
                                  ),
                                ),
                                _ContinueReadingProgressBar(
                                  sourceId: source.id,
                                  progress: progress,
                                  isSelected: isSelected,
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
      ),
    );
  }
}

/// Large text keeps its requested size and gives the full title its own space.
class _ContinueReadingExpandedContent extends StatelessWidget {
  const _ContinueReadingExpandedContent({
    required this.source,
    required this.caption,
    required this.progress,
    required this.isSelected,
    required this.coverWidth,
    required this.coverHeight,
    required this.titleStyle,
    required this.mutedStyle,
    required this.overlineStyle,
  });

  final LibrarySource source;
  final String caption;
  final double progress;
  final bool isSelected;
  final double coverWidth;
  final double coverHeight;
  final TextStyle titleStyle;
  final TextStyle mutedStyle;
  final TextStyle overlineStyle;

  @override
  Widget build(BuildContext context) {
    final author = source.author?.trim();
    final direction = switch (source.inferredTextDirection) {
      ArticleTextDirection.rtl => TextDirection.rtl,
      ArticleTextDirection.ltr || null => TextDirection.ltr,
    };
    return Column(
      key: const ValueKey('libraryContinueReadingExpandedContent'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LibraryListCoverSlot(
              key: const ValueKey('libraryContinueReadingCover'),
              cover: _ContinueReadingCover(source: source),
              isSelected: isSelected,
              width: coverWidth,
              height: coverHeight,
            ),
            const SizedBox(width: kLibraryListCoverToTextGap),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.libraryContinueReading,
                    key: const ValueKey('libraryContinueReadingContext'),
                    style: overlineStyle,
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
        const SizedBox(height: AppSpacing.lg),
        Text(
          source.title,
          key: const ValueKey('libraryContinueReadingTitle'),
          textDirection: direction,
          style: titleStyle,
        ),
        if (author != null && author.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(author, textDirection: direction, style: mutedStyle),
        ],
        const SizedBox(height: AppSpacing.lg),
        _ContinueReadingProgressBar(
          sourceId: source.id,
          progress: progress,
          isSelected: isSelected,
        ),
      ],
    );
  }
}

/// Keeps title and author together within a content-independent height.
class _ContinueReadingDetails extends StatelessWidget {
  const _ContinueReadingDetails({
    required this.title,
    required this.style,
    required this.author,
    required this.authorStyle,
    required this.authorHeight,
  });

  final String title;
  final TextStyle style;
  final String? author;
  final TextStyle authorStyle;
  final double authorHeight;

  @override
  Widget build(BuildContext context) {
    final resolved = DefaultTextStyle.of(context).style.merge(style);
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = resolveContinueReadingTitleLayout(
          title: title,
          style: resolved,
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: Directionality.of(context),
          locale: Localizations.maybeLocaleOf(context),
          maxWidth: constraints.maxWidth,
          maxHeight: math.max(0, constraints.maxHeight - authorHeight),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              key: const ValueKey('libraryContinueReadingTitle'),
              maxLines: layout.maxLines,
              style: libraryTitleStyle(resolved, layout.fontScale),
            ),
            if (author case final author?) ...[
              const SizedBox(height: AppSpacing.xxs),
              SizedBox(
                height: authorHeight - AppSpacing.xxs,
                child: Text(
                  author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: authorStyle,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Metadata shares a line so the title fits beside the 60×90 cover.
class _ContinueReadingHeader extends StatelessWidget {
  const _ContinueReadingHeader({
    required this.label,
    required this.labelStyle,
    required this.caption,
    required this.captionStyle,
  });

  final String label;
  final TextStyle labelStyle;
  final String caption;
  final TextStyle captionStyle;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          key: const ValueKey('libraryContinueReadingContext'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: labelStyle,
        ),
      ),
      const SizedBox(width: AppSpacing.xs),
      Expanded(
        child: Text(
          caption,
          key: const ValueKey('libraryContinueReadingCaption'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
          style: captionStyle,
        ),
      ),
    ],
  );
}

double _lineHeight(BuildContext context, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(
      text: ' ',
      style: DefaultTextStyle.of(context).style.merge(style),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    locale: Localizations.maybeLocaleOf(context),
  );
  try {
    return painter.preferredLineHeight.ceilToDouble();
  } finally {
    painter.dispose();
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
    required this.sourceId,
    required this.progress,
    required this.isSelected,
  });

  final String sourceId;
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
          // Keyed by source: another book taking the card does not animate
          // from the previous book's progress.
          child: LibraryProgressFill(
            key: ValueKey(sourceId),
            progress: progress,
            color: fill,
            fillKey: const ValueKey('libraryContinueReadingProgressFill'),
          ),
        ),
      ),
    );
  }
}
