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

const _coverMaxWidth = 184.0;
const _coverMinWidth = 140.0;
const _coverScreenWidthFactor = 0.45;
const _coverAspectRatio = 2 / 3;
const _coverTextScale = 1.3;
const _titleMaxLines = 3;
const _authorMaxLines = 2;
const _metadataMaxLines = 1;

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
      ),
    );
  }
}

class SourceDetailsView extends StatelessWidget {
  const SourceDetailsView({
    required this.sourceId,
    required this.onReadPressed,
    super.key,
  });

  final String sourceId;
  final Future<void> Function(Book source, SourceType sourceType) onReadPressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<SourceDetailsBloc, SourceDetailsState>(
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
            tooltip: 'Back',
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
              icon: const Icon(AppIcons.book, size: AppIconSize.sm),
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
  });

  final LibrarySource source;
  final bool showReviewSection;
  final SourceReviewSummary reviewSummary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final screenSize = MediaQuery.sizeOf(context);
    final coverWidth = math.min(
      _coverMaxWidth,
      math.max(_coverMinWidth, screenSize.width * _coverScreenWidthFactor),
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
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeroSection(
                      source: source,
                      coverWidth: coverWidth,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _SourceMetadata(source: source),
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

class _SourceMetadata extends StatelessWidget {
  const _SourceMetadata({required this.source});

  final LibrarySource source;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final items = [
      source.typeLabel,
      _progressLabel(source),
    ];

    return Text(
      items.join('  •  '),
      textAlign: TextAlign.center,
      maxLines: _metadataMaxLines,
      overflow: TextOverflow.ellipsis,
      style: text.labelMedium.copyWith(
        color: colors.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

ButtonStyle _plainIconButtonStyle(BuildContext context) {
  final colors = context.colors;

  return ButtonStyle(
    backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
    foregroundColor: WidgetStatePropertyAll(colors.onSurface),
    overlayColor: WidgetStatePropertyAll(
      colors.onSurface.withValues(alpha: 0.08),
    ),
    minimumSize: const WidgetStatePropertyAll(
      Size.square(AppSizes.iconButtonSize),
    ),
    padding: const WidgetStatePropertyAll(EdgeInsets.all(AppSpacing.sm)),
  );
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.source,
    required this.coverWidth,
  });

  final LibrarySource source;
  final double coverWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final coverImage = _coverImageFor(source);
    final subtitle = _subtitleFor(source);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: coverWidth,
          height: coverWidth / _coverAspectRatio,
          child: Hero(
            tag: sourceCoverHeroTag(source.id),
            transitionOnUserGestures: true,
            child: _SourceCover(
              source: source,
              coverImage: coverImage,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          source.title,
          textAlign: TextAlign.center,
          maxLines: _titleMaxLines,
          overflow: TextOverflow.ellipsis,
          style: text.titleMedium.copyWith(color: colors.onSurface),
        ),
        if (subtitle case final value? when value.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: _authorMaxLines,
            overflow: TextOverflow.ellipsis,
            style: text.bodyMedium.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _SourceCover extends StatelessWidget {
  const _SourceCover({
    required this.source,
    required this.coverImage,
  });

  final LibrarySource source;
  final ImageProvider? coverImage;

  @override
  Widget build(BuildContext context) {
    final isArticle = source.sourceType == SourceType.article;

    return AppSourceCoverFrame(
      cover: isArticle
          ? AppSourceCover(
              title: source.title,
              author: source.author,
              source: source.sourceName,
              seed: source.id,
              isArticle: true,
              coverImage: coverImage,
              showTitle: true,
              showProgress: false,
              showMatte: false,
              showArticleBadge: false,
              centerText: true,
              textScale: _coverTextScale,
            )
          : AppSourceCover(
              title: source.title,
              author: source.author,
              source: source.sourceName,
              seed: source.id,
              coverImage: coverImage,
              showProgress: false,
              showMatte: false,
              textScale: _coverTextScale,
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

String _readButtonLabel(LibrarySource source) =>
    source.readingProgress > 0 || source.lastOpenedAt != null
    ? 'Continue reading'
    : 'Start reading';

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
  return progress > 0 ? '$progress% read' : 'New';
}

String? _subtitleFor(LibrarySource source) {
  if (source.sourceType == SourceType.article) {
    final sourceName = source.sourceName?.trim();
    if (sourceName != null && sourceName.isNotEmpty) return sourceName;
    return null;
  }
  final author = source.author?.trim();
  if (author != null && author.isNotEmpty) return author;
  return null;
}

ImageProvider? _coverImageFor(LibrarySource source) {
  return appSourceCoverImageFromPath(source.coverImagePath);
}
