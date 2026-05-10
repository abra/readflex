import 'dart:io';
import 'dart:math' as math;

import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'source_details_bloc.dart';

const _coverMaxWidth = 192.0;
const _coverMinWidth = 150.0;
const _coverScreenWidthFactor = 0.46;
const _titleMaxLines = 3;
const _authorMaxLines = 2;
const _statValueMaxLines = 1;
const _statSurfaceAlpha = 0.6;
const _coverShadow = [
  BoxShadow(
    color: Color(0x14000000),
    blurRadius: 2,
    offset: Offset(0, 1),
  ),
  BoxShadow(
    color: Color(0x1F000000),
    blurRadius: 18,
    offset: Offset(2, 6),
  ),
];

class SourceDetailsScreen extends StatelessWidget {
  const SourceDetailsScreen({
    required this.sourceId,
    required this.bookRepository,
    required this.onReadPressed,
    this.initialSource,
    super.key,
  });

  final String sourceId;
  final BookRepository bookRepository;
  final Future<void> Function(Book source) onReadPressed;
  final Book? initialSource;

  @override
  Widget build(BuildContext context) {
    debugLogScreenBuild('SourceDetailsScreen(sourceId: $sourceId)');

    return BlocProvider(
      create: (_) => SourceDetailsBloc(
        bookRepository: bookRepository,
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
  final Future<void> Function(Book source) onReadPressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<SourceDetailsBloc, SourceDetailsState>(
          builder: (context, state) {
            return switch (state.status) {
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
                fileSizeBytes: state.fileSizeBytes,
                onReadPressed: onReadPressed,
              ),
            };
          },
        ),
      ),
    );
  }
}

class _SourceDetailsContent extends StatelessWidget {
  const _SourceDetailsContent({
    required this.source,
    required this.fileSizeBytes,
    required this.onReadPressed,
  });

  final Book source;
  final int? fileSizeBytes;
  final Future<void> Function(Book source) onReadPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final coverWidth = math.min(
      _coverMaxWidth,
      math.max(_coverMinWidth, screenWidth * _coverScreenWidthFactor),
    );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xs,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _BackButton(colors: colors),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
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
                    _SourceStats(
                      source: source,
                      fileSizeBytes: fileSizeBytes,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton(
                      onPressed: () async {
                        await onReadPressed(source);
                        if (!context.mounted) return;
                        context.read<SourceDetailsBloc>().add(
                          SourceDetailsLoadRequested(source.id),
                        );
                      },
                      child: Text(_readButtonLabel(source)),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Review',
                      style: text.titleSmall.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const _ReviewActions(),
                    const SizedBox(height: AppSpacing.xxl),
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

class _BackButton extends StatelessWidget {
  const _BackButton({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      onPressed: () => Navigator.of(context).maybePop(),
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.onSurface,
      ),
      icon: Icon(AppIcons.back, size: AppIconSize.md, color: colors.onSurface),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.source,
    required this.coverWidth,
  });

  final Book source;
  final double coverWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: coverWidth,
          height: coverWidth * _SourceCover.aspectRatio,
          child: _SourceCover(
            source: source,
            width: coverWidth,
            height: coverWidth * _SourceCover.aspectRatio,
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
        if (source.author case final author? when author.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            author,
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
    required this.width,
    required this.height,
  });

  static const aspectRatio = 190.0 / 128.0;

  final Book source;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fallback = AppCoverArt(
      title: source.title,
      author: source.author,
      seed: source.id,
      progress: source.readingProgress > 0 ? source.readingProgress : null,
      showMatte: false,
      height: height,
      width: width,
    );

    final coverPath = source.coverImagePath;
    final cover = coverPath != null && coverPath.isNotEmpty
        ? Image.file(
            File(coverPath),
            fit: BoxFit.fill,
            errorBuilder: (_, _, _) => fallback,
          )
        : fallback;

    return DecoratedBox(
      decoration: const BoxDecoration(boxShadow: _coverShadow),
      child: Hero(
        tag: sourceCoverHeroTag(source.id),
        transitionOnUserGestures: true,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: cover,
        ),
      ),
    );
  }
}

class _SourceStats extends StatelessWidget {
  const _SourceStats({required this.source, required this.fileSizeBytes});

  final Book source;
  final int? fileSizeBytes;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SourceStat(
            icon: AppIcons.bookmark,
            value: 'Saved',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _SourceStat(
            icon: AppIcons.book,
            value: _formatLength(source),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _SourceStat(
            icon: AppIcons.article,
            value: _formatFileSize(fileSizeBytes),
          ),
        ),
      ],
    );
  }
}

class _SourceStat extends StatelessWidget {
  const _SourceStat({
    required this.icon,
    required this.value,
  });

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(
          alpha: _statSurfaceAlpha,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        child: Column(
          children: [
            Icon(icon, size: AppIconSize.sm, color: colors.primary),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              maxLines: _statValueMaxLines,
              overflow: TextOverflow.ellipsis,
              style: text.labelMedium.copyWith(color: colors.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewActions extends StatelessWidget {
  const _ReviewActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppActionTile(
            icon: AppIcons.highlight,
            title: 'Highlights',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: AppActionTile(
            icon: AppIcons.flashcard,
            title: 'Flashcards',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: AppActionTile(
            icon: AppIcons.dictionary,
            title: 'Dictionary',
          ),
        ),
      ],
    );
  }
}

String _formatLabel(BookFormat format) => switch (format) {
  BookFormat.epub => 'Book',
  BookFormat.cbz => 'Comic',
  BookFormat.pdf => 'PDF',
  BookFormat.fb2 => 'FB2',
  BookFormat.mobi => 'MOBI',
  BookFormat.azw3 => 'AZW3',
};

String _readButtonLabel(Book source) =>
    source.readingProgress > 0 || source.lastOpenedAt != null
    ? 'Continue reading'
    : 'Start reading';

String _formatLength(Book source) {
  if (source.totalLocations > 0) return '${source.totalLocations} locs';
  return _formatLabel(source.format);
}

String _formatFileSize(int? bytes) {
  if (bytes == null || bytes <= 0) return 'Unknown';
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final precision = value >= 10 || unit == 0 ? 0 : 1;
  return '${value.toStringAsFixed(precision)} ${units[unit]}';
}
