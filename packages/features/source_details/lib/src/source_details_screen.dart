import 'dart:io';

import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'source_details_bloc.dart';

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
    required this.onReadPressed,
  });

  final Book source;
  final Future<void> Function(Book source) onReadPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final progressPercent = (source.readingProgress * 100)
        .clamp(0, 100)
        .round();

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
                      progressPercent: progressPercent,
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
                    _ProgressCard(
                      progress: source.readingProgress,
                      progressPercent: progressPercent,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _MetadataGrid(source: source),
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
  const _HeroSection({required this.source, required this.progressPercent});

  final Book source;
  final int progressPercent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 128,
          height: 190,
          child: _SourceCover(source: source),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                source.title,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium.copyWith(color: colors.onSurface),
              ),
              if (source.author case final author? when author.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  author,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text(
                progressPercent > 0 ? '$progressPercent% read' : 'Not started',
                style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SourceCover extends StatelessWidget {
  const _SourceCover({required this.source});

  static const _width = 128.0;
  static const _height = 190.0;

  final Book source;

  @override
  Widget build(BuildContext context) {
    final fallback = AppCoverArt(
      title: source.title,
      author: source.author,
      seed: source.id,
      progress: source.readingProgress > 0 ? source.readingProgress : null,
      showMatte: false,
      height: _height,
      width: _width,
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
      decoration: const BoxDecoration(
        boxShadow: [
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
        ],
      ),
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

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.progress,
    required this.progressPercent,
  });

  final double progress;
  final int progressPercent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reading progress',
              style: context.text.titleMedium.copyWith(color: colors.onSurface),
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: progress.clamp(0, 1),
                minHeight: 8,
                backgroundColor: colors.surface,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              progressPercent > 0
                  ? '$progressPercent% complete'
                  : 'Ready to start',
              style: context.text.bodySmall.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetadataGrid extends StatelessWidget {
  const _MetadataGrid({required this.source});

  final Book source;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        _MetadataTile(label: 'Format', value: _formatLabel(source.format)),
        _MetadataTile(label: 'Added', value: _formatDate(source.addedAt)),
        _MetadataTile(
          label: 'Last opened',
          value: source.lastOpenedAt != null
              ? _formatDate(source.lastOpenedAt!)
              : 'Never',
        ),
        _MetadataTile(
          label: 'Status',
          value: source.isFinished ? 'Finished' : 'In progress',
        ),
      ],
    );
  }
}

class _MetadataTile extends StatelessWidget {
  const _MetadataTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox(
      width: 150,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: context.text.labelSmall.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium.copyWith(
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
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

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}.$month.$day';
}
