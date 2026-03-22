import 'package:component_library/component_library.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';

import 'practice_bloc.dart';

/// Practice tab: review due flashcards.
class PracticeScreen extends StatelessWidget {
  const PracticeScreen({
    required this.flashcardRepository,
    super.key,
  });

  final FlashcardRepository flashcardRepository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          PracticeBloc(flashcardRepository: flashcardRepository)
            ..add(const PracticeLoadRequested()),
      child: const PracticeView(),
    );
  }
}

class PracticeView extends StatelessWidget {
  const PracticeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice'),
        actions: [
          BlocBuilder<PracticeBloc, PracticeState>(
            buildWhen: (prev, curr) =>
                prev.reviewed != curr.reviewed ||
                prev.dueCards.length != curr.dueCards.length,
            builder: (context, state) {
              if (state.status != PracticeStatus.reviewing) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(right: Spacing.medium),
                child: Center(
                  child: Text(
                    '${state.reviewed}/${state.dueCards.length}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<PracticeBloc, PracticeState>(
        builder: (context, state) {
          return switch (state.status) {
            PracticeStatus.initial ||
            PracticeStatus.loading => const CenteredCircularProgressIndicator(),
            PracticeStatus.failure => ErrorState(
              message: 'Something went wrong',
              retryLabel: 'Retry',
              onRetry: () => context.read<PracticeBloc>().add(
                const PracticeLoadRequested(),
              ),
            ),
            PracticeStatus.empty => const EmptyState(
              message: 'No cards due for review.\nGreat job!',
            ),
            PracticeStatus.completed => _CompletedView(
              reviewed: state.dueCards.length,
              onRestart: () => context.read<PracticeBloc>().add(
                const PracticeLoadRequested(),
              ),
            ),
            PracticeStatus.reviewing => _CardView(
              card: state.currentCard!,
              isRevealed: state.isRevealed,
            ),
          };
        },
      ),
    );
  }
}

class _CardView extends StatelessWidget {
  const _CardView({required this.card, required this.isRevealed});

  final Flashcard card;
  final bool isRevealed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(Spacing.xLarge),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Card(
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.xLarge),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          card.front,
                          style: theme.textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        if (isRevealed) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: Spacing.medium,
                            ),
                            child: Divider(),
                          ),
                          Text(
                            card.back,
                            style: theme.textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          if (card.hint != null) ...[
                            const SizedBox(height: Spacing.small),
                            Text(
                              card.hint!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: Spacing.medium),
          if (!isRevealed)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.read<PracticeBloc>().add(
                  const PracticeCardRevealed(),
                ),
                child: const Text('Show Answer'),
              ),
            )
          else
            _RatingButtons(),
        ],
      ),
    );
  }
}

class _RatingButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ratingButton(context, Rating.again, 'Again', Colors.red),
        const SizedBox(width: Spacing.small),
        _ratingButton(context, Rating.hard, 'Hard', Colors.orange),
        const SizedBox(width: Spacing.small),
        _ratingButton(context, Rating.good, 'Good', Colors.green),
        const SizedBox(width: Spacing.small),
        _ratingButton(context, Rating.easy, 'Easy', Colors.blue),
      ],
    );
  }

  Widget _ratingButton(
    BuildContext context,
    Rating rating,
    String label,
    Color color,
  ) {
    return Expanded(
      child: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: color),
        onPressed: () => context.read<PracticeBloc>().add(
          PracticeCardRated(rating),
        ),
        child: Text(label),
      ),
    );
  }
}

class _CompletedView extends StatelessWidget {
  const _CompletedView({required this.reviewed, required this.onRestart});

  final int reviewed;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.celebration, size: 64),
          const SizedBox(height: Spacing.medium),
          Text(
            'Session complete!',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: Spacing.small),
          Text('$reviewed cards reviewed'),
          const SizedBox(height: Spacing.large),
          FilledButton(
            onPressed: onRestart,
            child: const Text('Review again'),
          ),
        ],
      ),
    );
  }
}
