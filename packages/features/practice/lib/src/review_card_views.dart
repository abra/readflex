import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

import 'practice_bloc.dart';

/// Returns a contextual reveal button label for the given practice item type.
String revealLabel(PracticeItem? item) => switch (item) {
  FlashcardItem() => 'Show Answer',
  HighlightItem() => 'Recall?',
  DictionaryItem() => 'Show Translation',
  _ => 'Reveal',
};

/// Flashcard content: front text, divider, back text + optional hint.
class FlashcardCardContent extends StatelessWidget {
  const FlashcardCardContent({
    required this.card,
    required this.isRevealed,
    super.key,
  });

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
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Divider(),
          ),
          Text(
            card.back,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (card.hint != null) ...[
            const SizedBox(height: AppSpacing.sm),
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

/// Highlight content: quote icon, text, optional note on reveal.
class HighlightCardContent extends StatelessWidget {
  const HighlightCardContent({
    required this.highlight,
    required this.isRevealed,
    super.key,
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
        const SizedBox(height: AppSpacing.md),
        Text(
          highlight.text,
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        if (isRevealed && highlight.note != null) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
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

/// Dictionary entry content: translate icon, word, translation + context.
class DictionaryCardContent extends StatelessWidget {
  const DictionaryCardContent({
    required this.entry,
    required this.isRevealed,
    super.key,
  });

  final DictionaryEntry entry;
  final bool isRevealed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.translate, color: theme.colorScheme.primary),
        const SizedBox(height: AppSpacing.md),
        Text(
          entry.word,
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        if (isRevealed) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Divider(),
          ),
          Text(
            entry.translation,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (entry.context != null) ...[
            const SizedBox(height: AppSpacing.sm),
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

/// Four FSRS rating buttons (Again / Hard / Good / Easy).
class RatingButtons extends StatelessWidget {
  const RatingButtons({required this.onRate, super.key});

  final ValueChanged<Rating> onRate;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).ext;
    return Row(
      children: [
        _button(Rating.again, 'Again', ext.ratingAgain),
        const SizedBox(width: AppSpacing.sm),
        _button(Rating.hard, 'Hard', ext.ratingHard),
        const SizedBox(width: AppSpacing.sm),
        _button(Rating.good, 'Good', ext.ratingGood),
        const SizedBox(width: AppSpacing.sm),
        _button(Rating.easy, 'Easy', ext.ratingEasy),
      ],
    );
  }

  Widget _button(Rating rating, String label, Color color) {
    return Expanded(
      child: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: color),
        onPressed: () => onRate(rating),
        child: Text(label),
      ),
    );
  }
}
