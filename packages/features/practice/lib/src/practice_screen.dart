import 'package:component_library/component_library.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:highlight_repository/highlight_repository.dart';

import 'practice_bloc.dart';
import 'review_card_views.dart';

/// Practice tab: review due flashcards, highlights, and dictionary entries.
class PracticeScreen extends StatelessWidget {
  const PracticeScreen({
    required this.fsrsRepository,
    required this.flashcardRepository,
    required this.highlightRepository,
    required this.dictionaryRepository,
    super.key,
  });

  final FsrsRepository fsrsRepository;
  final FlashcardRepository flashcardRepository;
  final HighlightRepository highlightRepository;
  final DictionaryRepository dictionaryRepository;

  @override
  Widget build(BuildContext context) {
    debugLogScreenBuild('PracticeScreen');

    return BlocProvider(
      create: (_) => PracticeBloc(
        fsrsRepository: fsrsRepository,
        flashcardRepository: flashcardRepository,
        highlightRepository: highlightRepository,
        dictionaryRepository: dictionaryRepository,
      )..add(const PracticeLoadRequested()),
      child: const PracticeView(),
    );
  }
}

class PracticeView extends StatelessWidget {
  const PracticeView({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: implement practice/review UI.
    return Placeholder();
    // return Scaffold(
    //   appBar: AppBar(
    //     title: const Text('Practice'),
    //     actions: [
    //       BlocBuilder<PracticeBloc, PracticeState>(
    //         buildWhen: (prev, curr) =>
    //             prev.reviewed != curr.reviewed ||
    //             prev.items.length != curr.items.length,
    //         builder: (context, state) {
    //           if (state.status != PracticeStatus.reviewing) {
    //             return const SizedBox.shrink();
    //           }
    //           return Padding(
    //             padding: const EdgeInsets.only(right: AppSpacing.md),
    //             child: Center(
    //               child: Text(
    //                 '${state.reviewed}/${state.items.length}',
    //                 style: Theme.of(context).textTheme.bodyMedium,
    //               ),
    //             ),
    //           );
    //         },
    //       ),
    //     ],
    //   ),
    //   body: BlocBuilder<PracticeBloc, PracticeState>(
    //     builder: (context, state) {
    //       final bloc = context.read<PracticeBloc>();
    //
    //       return switch (state.status) {
    //         PracticeStatus.initial ||
    //         PracticeStatus.loading => const CenteredCircularProgressIndicator(),
    //         PracticeStatus.failure => ErrorState(
    //           message: 'Something went wrong',
    //           retryLabel: 'Retry',
    //           onRetry: () => bloc.add(const PracticeLoadRequested()),
    //         ),
    //         PracticeStatus.empty => const EmptyState(
    //           message: 'No items due for review.\nGreat job!',
    //         ),
    //         PracticeStatus.completed => _CompletedView(
    //           reviewed: state.items.length,
    //           onRestart: () => bloc.add(const PracticeLoadRequested()),
    //         ),
    //         PracticeStatus.reviewing => _ReviewingView(state: state),
    //       };
    //     },
    //   ),
    // );
  }
}

// ignore: unused_element
class _ReviewingView extends StatelessWidget {
  const _ReviewingView({required this.state});

  final PracticeState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<PracticeBloc>();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Card(
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: switch (state.currentItem) {
                      FlashcardItem(:final flashcard) => FlashcardCardContent(
                        card: flashcard,
                        isRevealed: state.isRevealed,
                      ),
                      HighlightItem(:final highlight) => HighlightCardContent(
                        highlight: highlight,
                        isRevealed: state.isRevealed,
                      ),
                      DictionaryItem(:final entry) => DictionaryCardContent(
                        entry: entry,
                        isRevealed: state.isRevealed,
                      ),
                      _ => const SizedBox.shrink(),
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (!state.isRevealed)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => bloc.add(const PracticeCardRevealed()),
                child: Text(revealLabel(state.currentItem)),
              ),
            )
          else
            RatingButtons(
              onRate: (rating) => bloc.add(PracticeCardRated(rating)),
            ),
        ],
      ),
    );
  }
}

// ignore: unused_element
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
          const Icon(AppIcons.celebration, size: 64),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Session complete!',
            style: context.text.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('$reviewed items reviewed'),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: onRestart,
            child: const Text('Review again'),
          ),
        ],
      ),
    );
  }
}
