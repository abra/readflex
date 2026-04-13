import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:highlight_repository/highlight_repository.dart';

import 'home_bloc.dart';

/// Home tab: dashboard with stats and recent items.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.bookRepository,
    required this.articleRepository,
    required this.highlightRepository,
    required this.fsrsRepository,
    required this.onBookPressed,
    required this.onArticlePressed,
    required this.onPracticePressed,
    super.key,
  });

  final BookRepository bookRepository;
  final ArticleRepository articleRepository;
  final HighlightRepository highlightRepository;
  final FsrsRepository fsrsRepository;
  final void Function(Book book) onBookPressed;
  final void Function(Article article) onArticlePressed;
  final VoidCallback onPracticePressed;

  @override
  Widget build(BuildContext context) {
    debugLogScreenBuild('HomeScreen');

    return BlocProvider(
      create: (_) => HomeBloc(
        bookRepository: bookRepository,
        articleRepository: articleRepository,
        highlightRepository: highlightRepository,
        fsrsRepository: fsrsRepository,
      )..add(const HomeLoadRequested()),
      child: HomeView(
        onBookPressed: onBookPressed,
        onArticlePressed: onArticlePressed,
        onPracticePressed: onPracticePressed,
      ),
    );
  }
}

class HomeView extends StatelessWidget {
  const HomeView({
    required this.onBookPressed,
    required this.onArticlePressed,
    required this.onPracticePressed,
    super.key,
  });

  final void Function(Book book) onBookPressed;
  final void Function(Article article) onArticlePressed;
  final VoidCallback onPracticePressed;

  @override
  Widget build(BuildContext context) {
    // TODO: implement home dashboard UI.
    return Placeholder();
    // return Scaffold(
    //   appBar: AppBar(title: const Text('Readflex')),
    //   body: BlocBuilder<HomeBloc, HomeState>(
    //     builder: (context, state) {
    //       final bloc = context.read<HomeBloc>();
    //
    //       return switch (state.status) {
    //         HomeStatus.initial ||
    //         HomeStatus.loading => const CenteredCircularProgressIndicator(),
    //         HomeStatus.failure => ErrorState(
    //           message: 'Failed to load dashboard',
    //           retryLabel: 'Retry',
    //           onRetry: () => bloc.add(const HomeLoadRequested()),
    //         ),
    //         HomeStatus.success => ListView(
    //           padding: const EdgeInsets.all(AppSpacing.lg),
    //           children: [
    //             _StatsRow(state: state, onPracticePressed: onPracticePressed),
    //             const SizedBox(height: AppSpacing.xl),
    //             if (state.recentItems.isNotEmpty) ...[
    //               Text(
    //                 'Continue Reading',
    //                 style: context.text.titleMedium,
    //               ),
    //               const SizedBox(height: AppSpacing.sm),
    //               ...state.recentItems.map(
    //                 (item) => switch (item) {
    //                   Book book => ListTile(
    //                     leading: const Icon(Icons.book),
    //                     title: Text(
    //                       book.title,
    //                       maxLines: 1,
    //                       overflow: TextOverflow.ellipsis,
    //                     ),
    //                     subtitle: Text(
    //                       '${(book.readingProgress * 100).round()}%',
    //                     ),
    //                     onTap: () => onBookPressed(book),
    //                   ),
    //                   Article article => ListTile(
    //                     leading: const Icon(Icons.article),
    //                     title: Text(
    //                       article.title,
    //                       maxLines: 1,
    //                       overflow: TextOverflow.ellipsis,
    //                     ),
    //                     subtitle: Text(article.siteName ?? ''),
    //                     onTap: () => onArticlePressed(article),
    //                   ),
    //                   _ => const SizedBox.shrink(),
    //                 },
    //               ),
    //             ] else
    //               const EmptyState(
    //                 message:
    //                     'No items yet.\nAdd books or articles from the Library tab.',
    //               ),
    //           ],
    //         ),
    //       };
    //     },
    //   ),
    // );
  }
}

// ignore: unused_element
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.state, required this.onPracticePressed});

  final HomeState state;
  final VoidCallback onPracticePressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colors;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: AppIcons.library,
            label: 'Sources',
            value: '${state.totalSources}',
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            icon: AppIcons.highlight,
            label: 'Highlights',
            value: '${state.totalHighlights}',
            color: colorScheme.secondary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            icon: AppIcons.practice,
            label: 'Due',
            value: '${state.dueFlashcards}',
            color: state.dueFlashcards > 0
                ? colorScheme.error
                : colorScheme.outline,
            onTap: state.dueFlashcards > 0 ? onPracticePressed : null,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.sm,
          ),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: AppSpacing.xs),
              Text(
                value,
                style: context.text.headlineSmall.copyWith(color: color),
              ),
              Text(
                label,
                style: context.text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
