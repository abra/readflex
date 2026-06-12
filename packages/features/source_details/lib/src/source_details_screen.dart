import 'dart:math' as math;

import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:highlight_repository/highlight_repository.dart';

import 'source_details_bloc.dart';

const _heroCoverMaxWidth = 112.0;
const _heroCoverMinWidth = 96.0;
const _heroCoverScreenWidthFactor = 0.28;
const _coverTextScale = 1.45;
const _articleCoverIconWidthFactor = 0.40;
const _heroTitleLineHeight = 1.20;
const _heroTitleMinFontSize = 12.0;
const _heroTitleFontStep = 0.5;
const _authorMaxLines = 2;
const _authorFontSize = 16.0;
const _authorLineHeight = 1.30;
const _statMaxLines = 1;
const _articleWordsPerMinute = 225;
const _articleCharactersPerMinute = 500;
const _characterBasedReadingLanguageCodes = <String>{
  'ja',
  'zh',
  'ko',
  'th',
  'lo',
  'km',
  'my',
};
const _characterPerWordFallbackRatio = 18;

class SourceDetailsScreen extends StatelessWidget {
  const SourceDetailsScreen({
    required this.sourceId,
    required this.bookRepository,
    required this.highlightRepository,
    required this.flashcardRepository,
    required this.dictionaryRepository,
    required this.onReadPressed,
    this.articleRepository,
    this.initialSource,
    this.onArticleTitlePressed,
    super.key,
  });

  final String sourceId;
  final BookRepository bookRepository;
  final ArticleRepository? articleRepository;
  final HighlightRepository highlightRepository;
  final FlashcardRepository flashcardRepository;
  final DictionaryRepository dictionaryRepository;
  final Future<void> Function(Book source, SourceType sourceType) onReadPressed;
  final LibrarySource? initialSource;
  final void Function(String url, String title)? onArticleTitlePressed;

  @override
  Widget build(BuildContext context) {
    debugLogScreenBuild('SourceDetailsScreen(sourceId: $sourceId)');

    return BlocProvider(
      create: (_) => SourceDetailsBloc(
        bookRepository: bookRepository,
        articleRepository: articleRepository,
        highlightRepository: highlightRepository,
        flashcardRepository: flashcardRepository,
        dictionaryRepository: dictionaryRepository,
        initialSource: initialSource,
      )..add(SourceDetailsLoadRequested(sourceId)),
      child: SourceDetailsView(
        sourceId: sourceId,
        onReadPressed: onReadPressed,
        onArticleTitlePressed: onArticleTitlePressed,
      ),
    );
  }
}

class SourceDetailsView extends StatelessWidget {
  const SourceDetailsView({
    required this.sourceId,
    required this.onReadPressed,
    this.onArticleTitlePressed,
    super.key,
  });

  final String sourceId;
  final Future<void> Function(Book source, SourceType sourceType) onReadPressed;
  final void Function(String url, String title)? onArticleTitlePressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<SourceDetailsBloc, SourceDetailsState>(
        buildWhen: (previous, current) =>
            previous.status != current.status ||
            previous.source != current.source ||
            previous.reviewSummary != current.reviewSummary,
        builder: (context, state) {
          return SafeArea(
            bottom: false,
            child: switch (state.status) {
              SourceDetailsStatus.initial || SourceDetailsStatus.loading =>
                const CenteredCircularProgressIndicator(),
              SourceDetailsStatus.notFound => ErrorState(
                message: 'Source not found',
                retryLabel: 'Back',
                onRetry: () => Navigator.of(context).maybePop(),
              ),
              SourceDetailsStatus.failure => ErrorState(
                message: 'Failed to load source details',
                retryLabel: 'Retry',
                onRetry: () => context.read<SourceDetailsBloc>().add(
                  SourceDetailsLoadRequested(sourceId),
                ),
              ),
              SourceDetailsStatus.success => _SourceDetailsContent(
                source: state.source!,
                showReviewSection: state.showReviewSection,
                reviewSummary: state.reviewSummary,
                onArticleTitlePressed: onArticleTitlePressed,
              ),
            },
          );
        },
      ),
      bottomNavigationBar: BlocBuilder<SourceDetailsBloc, SourceDetailsState>(
        buildWhen: (previous, current) =>
            previous.status != current.status ||
            previous.source != current.source ||
            previous.readerBook != current.readerBook,
        builder: (context, state) {
          if (state.status != SourceDetailsStatus.success) {
            return const SizedBox.shrink();
          }
          final readerBook = state.readerBook;
          if (readerBook == null) return const SizedBox.shrink();
          return _SourceDetailsBottomBar(
            source: state.source!,
            readerBook: readerBook,
            onReadPressed: onReadPressed,
          );
        },
      ),
    );
  }
}

class _SourceDetailsBottomBar extends StatelessWidget {
  const _SourceDetailsBottomBar({
    required this.source,
    required this.readerBook,
    required this.onReadPressed,
  });

  final LibrarySource source;
  final Book readerBook;
  final Future<void> Function(Book source, SourceType sourceType) onReadPressed;

  @override
  Widget build(BuildContext context) {
    final style = _plainIconButtonStyle(context);

    return AppBottomActionBar(
      children: [
        SizedBox.square(
          dimension: AppSizes.buttonHeight,
          child: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: style,
            icon: const Icon(AppIcons.back, size: AppIconSize.lg),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: AppSizes.buttonHeight,
            child: FilledButton.icon(
              onPressed: () async {
                await onReadPressed(readerBook, source.sourceType);
                if (!context.mounted) return;
                context.read<SourceDetailsBloc>().add(
                  SourceDetailsLoadRequested(source.id),
                );
              },
              icon: Icon(_readButtonIcon(source), size: AppIconSize.sm),
              label: Text(_readButtonLabel(source)),
            ),
          ),
        ),
      ],
    );
  }
}

class _SourceDetailsContent extends StatelessWidget {
  const _SourceDetailsContent({
    required this.source,
    required this.showReviewSection,
    required this.reviewSummary,
    this.onArticleTitlePressed,
  });

  final LibrarySource source;
  final bool showReviewSection;
  final SourceReviewSummary reviewSummary;
  final void Function(String url, String title)? onArticleTitlePressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final screenSize = MediaQuery.sizeOf(context);
    final coverWidth = math.min(
      _heroCoverMaxWidth,
      math.max(
        _heroCoverMinWidth,
        screenSize.width * _heroCoverScreenWidthFactor,
      ),
    );
    final topSpacer = math.max(AppSpacing.sm, screenSize.height * 0.02);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: topSpacer),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeroSection(
                      source: source,
                      coverWidth: coverWidth,
                      onArticleTitlePressed: onArticleTitlePressed,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _SourceStats(source: source),
                    const SizedBox(height: AppSpacing.md),
                    _SourceProgressLine(progress: source.readingProgress),
                    if (showReviewSection) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Review',
                        style: text.titleSmall.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _ReviewActions(summary: reviewSummary),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SourceKindLabel extends StatelessWidget {
  const _SourceKindLabel({
    required this.source,
    required this.textDirection,
  });

  final LibrarySource source;
  final TextDirection textDirection;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final isArticle = source.sourceType == SourceType.article;
    final sourceName = isArticle ? source.sourceName?.trim() : null;

    return Row(
      textDirection: textDirection,
      children: [
        Icon(
          isArticle ? AppIcons.article : AppIcons.book,
          size: AppIconSize.xs,
          color: colors.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          isArticle ? 'Article' : 'Book',
          textAlign: TextAlign.start,
          textDirection: textDirection,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.labelSmall.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (sourceName != null && sourceName.isNotEmpty) ...[
          const SizedBox(width: AppSpacing.xs),
          Text(
            '·',
            textDirection: textDirection,
            style: text.labelSmall.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              sourceName,
              textAlign: TextAlign.start,
              textDirection: textDirection,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

TextDirection _sourceTextDirection(LibrarySource source) {
  return switch (source.inferredTextDirection) {
    ArticleTextDirection.rtl => TextDirection.rtl,
    ArticleTextDirection.ltr || null => TextDirection.ltr,
  };
}

CrossAxisAlignment _crossAxisAlignmentFor(TextDirection textDirection) {
  return textDirection == TextDirection.rtl
      ? CrossAxisAlignment.end
      : CrossAxisAlignment.start;
}

Alignment _bottomAlignmentFor(TextDirection textDirection) {
  return textDirection == TextDirection.rtl
      ? Alignment.bottomRight
      : Alignment.bottomLeft;
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.source,
    required this.coverWidth,
    this.onArticleTitlePressed,
  });

  final LibrarySource source;
  final double coverWidth;
  final void Function(String url, String title)? onArticleTitlePressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final coverImage = _coverImageFor(source);
    final subtitle = _subtitleFor(source);
    final coverHeight = coverWidth / appSourceCoverAspectRatio;
    final heroTextDirection = _sourceTextDirection(source);
    final articleUrl = source.sourceType == SourceType.article
        ? source.originalUrl?.trim()
        : null;
    final onTitlePressed =
        articleUrl != null &&
            articleUrl.isNotEmpty &&
            onArticleTitlePressed != null
        ? () => onArticleTitlePressed!(articleUrl, source.title)
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: SizedBox(
            height: coverHeight,
            child: Column(
              crossAxisAlignment: _crossAxisAlignmentFor(heroTextDirection),
              children: [
                _SourceKindLabel(
                  source: source,
                  textDirection: heroTextDirection,
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: _AutoSizedHeroTitle(
                    title: source.title,
                    textDirection: heroTextDirection,
                    onTap: onTitlePressed,
                  ),
                ),
                if (subtitle case final value? when value.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    value,
                    textAlign: TextAlign.start,
                    textDirection: heroTextDirection,
                    maxLines: _authorMaxLines,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.serif(
                      textStyle: text.bodyMedium,
                      color: colors.onSurfaceVariant,
                      fontSize: _authorFontSize,
                      fontStyle: FontStyle.italic,
                      height: _authorLineHeight,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        SizedBox(
          width: coverWidth,
          height: coverHeight,
          child: AppSourceCoverFrame(
            cover: _SourceCover(
              source: source,
              coverImage: coverImage,
              textDirection: heroTextDirection,
            ),
          ),
        ),
      ],
    );
  }
}

class _AutoSizedHeroTitle extends StatelessWidget {
  const _AutoSizedHeroTitle({
    required this.title,
    required this.textDirection,
    this.onTap,
  });

  final String title;
  final TextDirection textDirection;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final baseStyle = context.text.headlineMedium.copyWith(
      color: colors.onSurface,
      height: _heroTitleLineHeight,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth ||
            !constraints.hasBoundedHeight ||
            constraints.maxWidth <= 0 ||
            constraints.maxHeight <= 0) {
          return const SizedBox.shrink();
        }

        final fit = _fitHeroTitleLayout(
          title: title,
          baseStyle: baseStyle,
          maxWidth: constraints.maxWidth,
          maxHeight: constraints.maxHeight,
          textDirection: textDirection,
          textScaler: MediaQuery.textScalerOf(context),
        );

        Widget titleText = Text(
          title,
          key: const ValueKey('source-details-title'),
          textAlign: TextAlign.start,
          textDirection: textDirection,
          softWrap: true,
          maxLines: fit.maxLines,
          overflow: fit.maxLines == null
              ? TextOverflow.visible
              : TextOverflow.ellipsis,
          style: fit.style,
        );
        if (onTap != null) {
          titleText = Semantics(
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: titleText,
            ),
          );
        }

        return SizedBox.expand(
          key: const ValueKey('source-details-title-cell'),
          child: Align(
            alignment: _bottomAlignmentFor(textDirection),
            child: SizedBox(
              width: constraints.maxWidth,
              child: titleText,
            ),
          ),
        );
      },
    );
  }
}

_HeroTitleFit _fitHeroTitleLayout({
  required String title,
  required TextStyle baseStyle,
  required double maxWidth,
  required double maxHeight,
  required TextDirection textDirection,
  required TextScaler textScaler,
}) {
  final baseFontSize = baseStyle.fontSize ?? _heroTitleMinFontSize;
  var fontSize = baseFontSize;

  while (fontSize > _heroTitleMinFontSize) {
    final style = baseStyle.copyWith(fontSize: fontSize);
    final painter = _layoutHeroTitle(
      title: title,
      style: style,
      maxWidth: maxWidth,
      textDirection: textDirection,
      textScaler: textScaler,
    );
    if (painter.height <= maxHeight) {
      return _HeroTitleFit(style: style);
    }
    fontSize -= _heroTitleFontStep;
  }

  final minStyle = baseStyle.copyWith(fontSize: _heroTitleMinFontSize);
  final lineHeight = _heroTitleLineHeightFor(
    style: minStyle,
    textDirection: textDirection,
    textScaler: textScaler,
  );
  final maxLines = math.max(1, (maxHeight / lineHeight).floor());
  return _HeroTitleFit(style: minStyle, maxLines: maxLines);
}

TextPainter _layoutHeroTitle({
  required String title,
  required TextStyle style,
  required double maxWidth,
  required TextDirection textDirection,
  required TextScaler textScaler,
}) {
  return TextPainter(
    text: TextSpan(text: title, style: style),
    textDirection: textDirection,
    textScaler: textScaler,
  )..layout(maxWidth: maxWidth);
}

double _heroTitleLineHeightFor({
  required TextStyle style,
  required TextDirection textDirection,
  required TextScaler textScaler,
}) {
  final painter = TextPainter(
    text: TextSpan(text: 'Hg', style: style),
    textDirection: textDirection,
    textScaler: textScaler,
  )..layout();
  return painter.preferredLineHeight;
}

class _HeroTitleFit {
  const _HeroTitleFit({required this.style, this.maxLines});

  final TextStyle style;
  final int? maxLines;
}

class _SourceCover extends StatelessWidget {
  const _SourceCover({
    required this.source,
    required this.coverImage,
    required this.textDirection,
  });

  final LibrarySource source;
  final ImageProvider? coverImage;
  final TextDirection textDirection;

  @override
  Widget build(BuildContext context) {
    final isArticle = source.sourceType == SourceType.article;

    if (isArticle) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final iconSize = constraints.maxWidth * _articleCoverIconWidthFactor;

          return Stack(
            alignment: Alignment.center,
            children: [
              AppSourceCover(
                title: source.title,
                seed: source.id,
                isArticle: true,
                coverImage: coverImage,
                textDirection: textDirection,
                showAuthor: false,
                showTitle: false,
                showProgress: false,
                showMatte: false,
                showArticleBadge: false,
              ),
              Icon(
                AppIcons.language,
                size: iconSize,
                color: Colors.white.withValues(alpha: 0.40),
              ),
            ],
          );
        },
      );
    }

    return AppSourceCover(
      title: source.title,
      author: source.author,
      source: source.sourceName,
      seed: source.id,
      coverImage: coverImage,
      textDirection: textDirection,
      showProgress: false,
      showMatte: false,
      topAlignText: true,
      textScale: _coverTextScale,
    );
  }
}

class _SourceStats extends StatelessWidget {
  const _SourceStats({required this.source});

  final LibrarySource source;

  @override
  Widget build(BuildContext context) {
    final stats = _statsFor(source);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < stats.length; index++) ...[
          if (index > 0) const SizedBox(width: AppSpacing.md),
          Expanded(child: _SourceStat(data: stats[index])),
        ],
      ],
    );
  }
}

class _SourceStat extends StatelessWidget {
  const _SourceStat({required this.data});

  final _SourceStatData data;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          data.label,
          maxLines: _statMaxLines,
          overflow: TextOverflow.ellipsis,
          style: text.labelSmall.copyWith(
            color: colors.onSurfaceVariant.withValues(alpha: 0.68),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          data.value,
          maxLines: _statMaxLines,
          overflow: TextOverflow.ellipsis,
          style: text.labelMedium.copyWith(
            color: data.isPrimary ? colors.primary : colors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SourceProgressLine extends StatelessWidget {
  const _SourceProgressLine({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final clampedProgress = progress.clamp(0.0, 1.0).toDouble();

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: ColoredBox(
        color: colors.surfaceContainerHighest,
        child: SizedBox(
          key: const ValueKey('source-details-progress-line'),
          height: 3,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Align(
                alignment: Alignment.centerLeft,
                child: ColoredBox(
                  color: colors.primary,
                  child: SizedBox(
                    width: constraints.maxWidth * clampedProgress,
                    height: 3,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ReviewActions extends StatelessWidget {
  const _ReviewActions({required this.summary});

  final SourceReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ReviewActionRow(
          icon: AppIcons.highlight,
          title: 'Highlights',
          subtitle: _reviewSummaryLabel(
            summary.highlightCount,
            empty: 'No saved passages yet',
            singular: '1 saved passage',
            plural: 'saved passages',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _ReviewActionRow(
          icon: AppIcons.flashcard,
          title: 'Flashcards',
          subtitle: _reviewSummaryLabel(
            summary.flashcardCount,
            empty: 'No cards created yet',
            singular: '1 card created',
            plural: 'cards created',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _ReviewActionRow(
          icon: AppIcons.dictionary,
          title: 'Dictionary',
          subtitle: _reviewSummaryLabel(
            summary.dictionaryEntryCount,
            empty: 'No words collected yet',
            singular: '1 word collected',
            plural: 'words collected',
          ),
        ),
      ],
    );
  }
}

class _ReviewActionRow extends StatelessWidget {
  const _ReviewActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.30),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: SizedBox.square(
                dimension: AppSizes.iconButtonSize,
                child: Icon(
                  icon,
                  size: AppIconSize.sm,
                  color: colors.primary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              AppIcons.chevronRight,
              size: AppIconSize.sm,
              color: colors.onSurfaceVariant.withValues(alpha: 0.60),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceStatData {
  const _SourceStatData({
    required this.label,
    required this.value,
    this.isPrimary = false,
  });

  final String label;
  final String value;
  final bool isPrimary;
}

List<_SourceStatData> _statsFor(LibrarySource source) {
  if (source.sourceType == SourceType.article) {
    return _articleStatsFor(source);
  }

  return <_SourceStatData>[
    _SourceStatData(
      label: 'Format',
      value: source.typeLabel,
    ),
    _SourceStatData(
      label: 'Status',
      value: _progressLabel(source),
      isPrimary: source.readingProgress > 0 || source.isFinished,
    ),
    _SourceStatData(
      label: 'Added',
      value: _shortDate(source.addedAt),
    ),
  ];
}

List<_SourceStatData> _articleStatsFor(LibrarySource source) {
  return <_SourceStatData>[
    _articleReadingTimeStat(source),
    _SourceStatData(
      label: 'Status',
      value: _progressLabel(source),
      isPrimary: source.readingProgress > 0 || source.isFinished,
    ),
    _SourceStatData(
      label: 'Saved',
      value: _shortDate(source.addedAt),
    ),
  ];
}

_SourceStatData _articleReadingTimeStat(LibrarySource source) {
  final totalMinutes = _estimatedArticleReadingMinutes(source);
  if (totalMinutes == null) {
    return const _SourceStatData(label: 'Time', value: '—');
  }

  return _SourceStatData(label: 'Time', value: '$totalMinutes min');
}

int? _estimatedArticleReadingMinutes(LibrarySource source) {
  if (_usesCharacterBasedReadingTime(source)) {
    final characterCount = source.estimatedCharacterCount;
    if (characterCount <= 0) return null;
    return math.max(1, (characterCount / _articleCharactersPerMinute).ceil());
  }

  final wordCount = source.estimatedWordCount;
  if (wordCount > 0) {
    return math.max(1, (wordCount / _articleWordsPerMinute).ceil());
  }

  final characterCount = source.estimatedCharacterCount;
  if (characterCount <= 0) return null;
  return math.max(1, (characterCount / _articleCharactersPerMinute).ceil());
}

bool _usesCharacterBasedReadingTime(LibrarySource source) {
  final languageCode = normalizeArticleLanguage(
    source.language,
  )?.split('-').first;
  if (languageCode != null &&
      _characterBasedReadingLanguageCodes.contains(languageCode)) {
    return true;
  }

  final wordCount = source.estimatedWordCount;
  final characterCount = source.estimatedCharacterCount;
  if (wordCount <= 0 || characterCount <= 0) return false;
  return characterCount / wordCount >= _characterPerWordFallbackRatio;
}

String _readButtonLabel(LibrarySource source) {
  final hasProgress = source.readingProgress > 0 || source.lastOpenedAt != null;
  if (source.sourceType == SourceType.article) {
    return hasProgress ? 'Continue article' : 'Read article';
  }
  return hasProgress ? 'Continue reading' : 'Start reading';
}

IconData _readButtonIcon(LibrarySource source) => AppIcons.play;

String _reviewSummaryLabel(
  int count, {
  required String empty,
  required String singular,
  required String plural,
}) {
  if (count == 0) return empty;
  if (count == 1) return singular;
  final value = count > 999 ? '999+' : '$count';
  return '$value $plural';
}

String _progressLabel(LibrarySource source) {
  if (source.isFinished) return 'Finished';
  final progress = (source.readingProgress * 100).round();
  return progress > 0 ? '$progress%' : 'New';
}

String? _subtitleFor(LibrarySource source) {
  final author = source.author?.trim();
  if (author != null && author.isNotEmpty) return author;
  if (source.sourceType == SourceType.article) return null;
  return null;
}

String _shortDate(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[value.month - 1]} ${value.day}';
}

ImageProvider? _coverImageFor(LibrarySource source) {
  return appSourceCoverImageFromPath(source.coverImagePath);
}

ButtonStyle _plainIconButtonStyle(BuildContext context) {
  final colors = context.colors;

  return ButtonStyle(
    backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
    foregroundColor: WidgetStatePropertyAll(colors.onSurface),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    minimumSize: const WidgetStatePropertyAll(
      Size.square(AppSizes.iconButtonSize),
    ),
    padding: const WidgetStatePropertyAll(EdgeInsets.all(AppSpacing.sm)),
  );
}
