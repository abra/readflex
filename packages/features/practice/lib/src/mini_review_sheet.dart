import 'package:component_library/component_library.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:highlight_repository/highlight_repository.dart';

import 'mini_review_cubit.dart';
import 'practice_bloc.dart';

void showMiniReviewSheet(
  BuildContext context, {
  required String sourceId,
  required FlashcardRepository flashcardRepository,
  required HighlightRepository highlightRepository,
  required DictionaryRepository dictionaryRepository,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _MiniReviewSheet(
      sourceId: sourceId,
      flashcardRepository: flashcardRepository,
      highlightRepository: highlightRepository,
      dictionaryRepository: dictionaryRepository,
    ),
  );
}

class _MiniReviewSheet extends StatelessWidget {
  const _MiniReviewSheet({
    required this.sourceId,
    required this.flashcardRepository,
    required this.highlightRepository,
    required this.dictionaryRepository,
  });

  final String sourceId;
  final FlashcardRepository flashcardRepository;
  final HighlightRepository highlightRepository;
  final DictionaryRepository dictionaryRepository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MiniReviewCubit(
        flashcardRepository: flashcardRepository,
        highlightRepository: highlightRepository,
        dictionaryRepository: dictionaryRepository,
      )..load(sourceId),
      child: const _MiniReviewSheetView(),
    );
  }
}

class _MiniReviewSheetView extends StatelessWidget {
  const _MiniReviewSheetView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MiniReviewCubit, MiniReviewState>(
      listener: (context, state) {
        if (state.status == MiniReviewStatus.completed) {
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        return ActionBottomSheetLayout(
          title: 'Mini Review',
          onClose: () => Navigator.of(context).pop(),
          headerSpacing: Spacing.small,
          bodyPadding: const EdgeInsets.all(Spacing.large),
          child: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, MiniReviewState state) {
    return switch (state.status) {
      MiniReviewStatus.loading => const Padding(
        padding: EdgeInsets.symmetric(vertical: Spacing.xxLarge),
        child: CenteredCircularProgressIndicator(),
      ),
      MiniReviewStatus.empty => const Padding(
        padding: EdgeInsets.symmetric(vertical: Spacing.xxLarge),
        child: EmptyState(message: 'No items due for review.'),
      ),
      MiniReviewStatus.failure => Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.xxLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Something went wrong',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: Spacing.medium),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
      MiniReviewStatus.reviewing => _ReviewContent(state: state),
      MiniReviewStatus.completed => const SizedBox.shrink(),
    };
  }
}

class _ReviewContent extends StatelessWidget {
  const _ReviewContent({required this.state});

  final MiniReviewState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Progress indicator
        Padding(
          padding: const EdgeInsets.only(bottom: Spacing.medium),
          child: Text(
            '${state.reviewed}/${state.items.length}',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
        // Card content
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.xLarge),
            child: switch (state.currentItem) {
              FlashcardItem(:final flashcard) => _MiniFlashcardView(
                card: flashcard,
                isRevealed: state.isRevealed,
              ),
              HighlightItem(:final highlight) => _MiniHighlightView(
                highlight: highlight,
                isRevealed: state.isRevealed,
              ),
              DictionaryItem(:final entry) => _MiniDictionaryView(
                entry: entry,
                isRevealed: state.isRevealed,
              ),
              _ => const SizedBox.shrink(),
            },
          ),
        ),
        const SizedBox(height: Spacing.medium),
        // Action buttons
        if (!state.isRevealed)
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.read<MiniReviewCubit>().reveal(),
              child: Text(_revealLabel(state.currentItem)),
            ),
          )
        else
          _MiniRatingButtons(),
      ],
    );
  }

  String _revealLabel(PracticeItem? item) => switch (item) {
    FlashcardItem() => 'Show Answer',
    HighlightItem() => 'Recall?',
    DictionaryItem() => 'Show Translation',
    _ => 'Reveal',
  };
}

class _MiniFlashcardView extends StatelessWidget {
  const _MiniFlashcardView({required this.card, required this.isRevealed});

  final Flashcard card;
  final bool isRevealed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          card.front,
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        if (isRevealed) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: Spacing.medium),
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
    );
  }
}

class _MiniHighlightView extends StatelessWidget {
  const _MiniHighlightView({
    required this.highlight,
    required this.isRevealed,
  });

  final Highlight highlight;
  final bool isRevealed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.format_quote, color: theme.colorScheme.primary),
        const SizedBox(height: Spacing.medium),
        Text(
          highlight.text,
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        if (isRevealed && highlight.note != null) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: Spacing.medium),
            child: Divider(),
          ),
          Text(
            highlight.note!,
            style: theme.textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _MiniDictionaryView extends StatelessWidget {
  const _MiniDictionaryView({required this.entry, required this.isRevealed});

  final DictionaryEntry entry;
  final bool isRevealed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.translate, color: theme.colorScheme.primary),
        const SizedBox(height: Spacing.medium),
        Text(
          entry.word,
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        if (isRevealed) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: Spacing.medium),
            child: Divider(),
          ),
          Text(
            entry.translation,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (entry.context != null) ...[
            const SizedBox(height: Spacing.small),
            Text(
              entry.context!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ],
    );
  }
}

class _MiniRatingButtons extends StatelessWidget {
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
        onPressed: () => context.read<MiniReviewCubit>().rate(rating),
        child: Text(label),
      ),
    );
  }
}
