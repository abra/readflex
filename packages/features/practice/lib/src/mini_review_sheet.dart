import 'package:component_library/component_library.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:highlight_repository/highlight_repository.dart';

import 'mini_review_cubit.dart';
import 'practice_item.dart';
import 'review_card_views.dart';

/// Opens the in-reader mini review bottom sheet scoped to [sourceId].
///
/// Used by the reader's inline review reminder — the user taps "Review"
/// on the reminder banner and this sheet surfaces only items due for the
/// book currently being read.
void showMiniReviewSheet(
  BuildContext context, {
  required String sourceId,
  required FsrsRepository fsrsRepository,
  required FlashcardRepository flashcardRepository,
  required HighlightRepository highlightRepository,
  required DictionaryRepository dictionaryRepository,
}) {
  showAppBottomSheet<void>(
    context,
    builder: (_) => _MiniReviewSheet(
      sourceId: sourceId,
      fsrsRepository: fsrsRepository,
      flashcardRepository: flashcardRepository,
      highlightRepository: highlightRepository,
      dictionaryRepository: dictionaryRepository,
    ),
  );
}

class _MiniReviewSheet extends StatelessWidget {
  const _MiniReviewSheet({
    required this.sourceId,
    required this.fsrsRepository,
    required this.flashcardRepository,
    required this.highlightRepository,
    required this.dictionaryRepository,
  });

  final String sourceId;
  final FsrsRepository fsrsRepository;
  final FlashcardRepository flashcardRepository;
  final HighlightRepository highlightRepository;
  final DictionaryRepository dictionaryRepository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MiniReviewCubit(
        fsrsRepository: fsrsRepository,
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
          headerSpacing: AppSpacing.sm,
          bodyPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, MiniReviewState state) {
    return switch (state.status) {
      MiniReviewStatus.loading => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: CenteredCircularProgressIndicator(),
      ),
      MiniReviewStatus.empty => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: EmptyState(message: 'No items due for review.'),
      ),
      MiniReviewStatus.failure => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Something went wrong',
              style: context.text.bodyMedium.copyWith(
                color: context.colors.error,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
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
    final cubit = context.read<MiniReviewCubit>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Text(
            '${state.reviewed}/${state.items.length}',
            style: context.text.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
        Card(
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
        const SizedBox(height: AppSpacing.md),
        if (!state.isRevealed)
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: cubit.reveal,
              child: Text(revealLabel(state.currentItem)),
            ),
          )
        else
          RatingButtons(
            onRate: cubit.rate,
          ),
      ],
    );
  }
}
