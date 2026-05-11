import 'dart:io';
import 'dart:math' as math;

import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'source_details_bloc.dart';

const _coverMaxWidth = 220.0;
const _coverMinWidth = 168.0;
const _coverScreenWidthFactor = 0.54;
const _coverAspectRatio = 2 / 3;
const _titleMaxLines = 3;
const _authorMaxLines = 2;

class SourceDetailsScreen extends StatelessWidget {
  const SourceDetailsScreen({
    required this.sourceId,
    required this.bookRepository,
    required this.onReadPressed,
    this.initialSource,
    this.onBookmarkPressed,
    this.onMorePressed,
    super.key,
  });

  final String sourceId;
  final BookRepository bookRepository;
  final Future<void> Function(Book source) onReadPressed;
  final Book? initialSource;
  final VoidCallback? onBookmarkPressed;
  final VoidCallback? onMorePressed;

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
        onBookmarkPressed: onBookmarkPressed,
        onMorePressed: onMorePressed,
      ),
    );
  }
}

class SourceDetailsView extends StatelessWidget {
  const SourceDetailsView({
    required this.sourceId,
    required this.onReadPressed,
    this.onBookmarkPressed,
    this.onMorePressed,
    super.key,
  });

  final String sourceId;
  final Future<void> Function(Book source) onReadPressed;
  final VoidCallback? onBookmarkPressed;
  final VoidCallback? onMorePressed;

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
                onReadPressed: onReadPressed,
              ),
            },
          );
        },
      ),
      bottomNavigationBar: BlocBuilder<SourceDetailsBloc, SourceDetailsState>(
        buildWhen: (previous, current) => previous.status != current.status,
        builder: (context, state) {
          if (state.status != SourceDetailsStatus.success) {
            return const SizedBox.shrink();
          }
          return _SourceDetailsBottomBar(
            onBookmarkPressed: onBookmarkPressed,
            onMorePressed: onMorePressed,
          );
        },
      ),
    );
  }
}

class _SourceDetailsBottomBar extends StatelessWidget {
  const _SourceDetailsBottomBar({
    this.onBookmarkPressed,
    this.onMorePressed,
  });

  final VoidCallback? onBookmarkPressed;
  final VoidCallback? onMorePressed;

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
            icon: const Icon(AppIcons.back, size: AppIconSize.md),
          ),
        ),
        const Spacer(),
        SizedBox.square(
          dimension: AppSizes.buttonHeight,
          child: IconButton(
            tooltip: 'Bookmark',
            onPressed: onBookmarkPressed,
            style: style,
            icon: const Icon(AppIcons.bookmark, size: AppIconSize.sm),
          ),
        ),
        SizedBox.square(
          dimension: AppSizes.buttonHeight,
          child: IconButton(
            tooltip: 'More',
            onPressed: onMorePressed,
            style: style,
            icon: const Icon(AppIcons.moreHorizontal, size: AppIconSize.sm),
          ),
        ),
      ],
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
    final text = context.text;
    final screenSize = MediaQuery.sizeOf(context);
    final coverWidth = math.min(
      _coverMaxWidth,
      math.max(_coverMinWidth, screenSize.width * _coverScreenWidthFactor),
    );
    final topSpacer = math.max(AppSpacing.xxl, screenSize.height * 0.12);

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
                  AppSpacing.xl,
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
                    Text(
                      'Review',
                      style: text.titleSmall.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const _ReviewActions(),
                    const SizedBox(height: AppSpacing.lg),
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

  final Book source;
  final double coverWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final coverImage = _coverImageFor(source);

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
    required this.coverImage,
  });

  final Book source;
  final ImageProvider? coverImage;

  @override
  Widget build(BuildContext context) {
    return AppSourceCoverFrame(
      cover: AppSourceCover(
        title: source.title,
        author: source.author,
        seed: source.id,
        coverImage: coverImage,
        progress: source.readingProgress > 0 ? source.readingProgress : null,
        showMatte: false,
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

String _readButtonLabel(Book source) =>
    source.readingProgress > 0 || source.lastOpenedAt != null
    ? 'Continue reading'
    : 'Start reading';

ImageProvider? _coverImageFor(Book source) {
  return switch (source.coverImagePath) {
    final path? when path.isNotEmpty => FileImage(File(path)),
    _ => null,
  };
}
