import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:shared/shared.dart';

import 'home_bloc.dart';

/// Home tab: dashboard with stats and recent items.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.bookRepository,
    required this.highlightRepository,
    required this.flashcardRepository,
    required this.onBookPressed,
    required this.onArticlePressed,
    required this.onPracticePressed,
    super.key,
  });

  final BookRepository bookRepository;
  final HighlightRepository highlightRepository;
  final FlashcardRepository flashcardRepository;
  final void Function(Book book) onBookPressed;
  final void Function(Article article) onArticlePressed;
  final VoidCallback onPracticePressed;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeBloc(
        bookRepository: bookRepository,
        highlightRepository: highlightRepository,
        flashcardRepository: flashcardRepository,
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
    return Scaffold(
      appBar: AppBar(title: const Text('Readflex')),
      body: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          return switch (state.status) {
            HomeStatus.initial ||
            HomeStatus.loading => const CenteredCircularProgressIndicator(),
            HomeStatus.failure => ErrorState(
              message: 'Failed to load dashboard',
              retryLabel: 'Retry',
              onRetry: () => context.read<HomeBloc>().add(
                const HomeLoadRequested(),
              ),
            ),
            HomeStatus.success => ListView(
              padding: const EdgeInsets.all(Spacing.large),
              children: [
                _StatsRow(state: state, onPracticePressed: onPracticePressed),
                const SizedBox(height: Spacing.xLarge),
                if (state.recentItems.isNotEmpty) ...[
                  Text(
                    'Continue Reading',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: Spacing.small),
                  ...state.recentItems.map(
                    (item) => switch (item) {
                      Book book => ListTile(
                        leading: const Icon(Icons.book),
                        title: Text(
                          book.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${(book.readingProgress * 100).round()}%',
                        ),
                        onTap: () => onBookPressed(book),
                      ),
                      Article article => ListTile(
                        leading: const Icon(Icons.article),
                        title: Text(
                          article.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(article.siteName ?? ''),
                        onTap: () => onArticlePressed(article),
                      ),
                      _ => const SizedBox.shrink(),
                    },
                  ),
                ] else
                  const EmptyState(
                    message:
                        'No items yet.\nAdd books or articles from the Library tab.',
                  ),
              ],
            ),
          };
        },
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.state, required this.onPracticePressed});

  final HomeState state;
  final VoidCallback onPracticePressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        _StatCard(
          icon: Icons.library_books,
          label: 'Sources',
          value: '${state.totalSources}',
          color: colorScheme.primary,
        ),
        const SizedBox(width: Spacing.small),
        _StatCard(
          icon: Icons.highlight,
          label: 'Highlights',
          value: '${state.totalHighlights}',
          color: colorScheme.secondary,
        ),
        const SizedBox(width: Spacing.small),
        GestureDetector(
          onTap: state.dueFlashcards > 0 ? onPracticePressed : null,
          child: _StatCard(
            icon: Icons.school,
            label: 'Due',
            value: '${state.dueFlashcards}',
            color: state.dueFlashcards > 0
                ? colorScheme.error
                : colorScheme.outline,
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
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: Spacing.medium,
            horizontal: Spacing.small,
          ),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: Spacing.xSmall),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
