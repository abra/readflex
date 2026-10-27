import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:intl/intl.dart' show Bidi;
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'practice_highlight_tint.dart';
import 'practice_item.dart';
import 'review_interval_label.dart';
import 'review_session_bloc.dart';

part 'review_session_cards.dart';
part 'review_session_controls.dart';

/// A full-screen review session over the tabs: one card at a time, Show
/// answer, then a rating. Words are rated Again / Hard / Good; highlights
/// are kept or shown less. Ends with the session's numbers.
class ReviewSessionScreen extends StatelessWidget {
  const ReviewSessionScreen({
    required this.fsrsRepository,
    required this.dictionaryRepository,
    required this.highlightRepository,
    required this.bookRepository,
    required this.preferencesService,
    required this.onOpenInSource,
    this.articleRepository,
    this.sourceId,
    this.ahead = false,
    super.key,
  });

  final FsrsRepository fsrsRepository;
  final DictionaryRepository dictionaryRepository;
  final HighlightRepository highlightRepository;
  final BookRepository bookRepository;
  final ArticleRepository? articleRepository;
  final PreferencesService preferencesService;

  /// Opens the card's source at its passage.
  final Future<void> Function(String sourceId, String? cfiRange) onOpenInSource;
  final String? sourceId;
  final bool ahead;

  @override
  Widget build(BuildContext context) {
    debugLogScreenBuild('ReviewSessionScreen');
    return BlocProvider(
      create: (_) => ReviewSessionBloc(
        fsrsRepository: fsrsRepository,
        dictionaryRepository: dictionaryRepository,
        highlightRepository: highlightRepository,
        bookRepository: bookRepository,
        articleRepository: articleRepository,
        preferencesService: preferencesService,
        sourceId: sourceId,
        ahead: ahead,
      )..add(const ReviewSessionStarted()),
      child: _ReviewSessionView(onOpenInSource: onOpenInSource),
    );
  }
}

class _ReviewSessionView extends StatelessWidget {
  const _ReviewSessionView({required this.onOpenInSource});

  final Future<void> Function(String sourceId, String? cfiRange) onOpenInSource;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<ReviewSessionBloc, ReviewSessionState>(
      builder: (context, state) {
        final bloc = context.read<ReviewSessionBloc>();
        final current = state.current;
        return Scaffold(
          body: SafeArea(
            child: switch (state.status) {
              ReviewSessionStatus.loading =>
                const CenteredCircularProgressIndicator(),
              ReviewSessionStatus.failure => ErrorState(
                message: l10n.practiceLoadFailed,
                retryLabel: l10n.commonRetry,
                onRetry: () => bloc.add(const ReviewSessionStarted()),
                secondaryLabel: l10n.commonClose,
                onSecondary: () => Navigator.of(context).pop(),
              ),
              ReviewSessionStatus.empty => EmptyState(
                icon: AppIcons.practice,
                message: l10n.practiceCaughtUp,
                subtitle: l10n.practiceCaughtUpBody,
                action: FilledButton.tonal(
                  onPressed: () => Navigator.of(context).pop(),
                  child: AppButtonLabel(l10n.commonDone),
                ),
              ),
              ReviewSessionStatus.completed => ReviewSessionSummary(
                reviewed: state.reviewed,
                known: state.known,
                again: state.again.length,
                onDone: () => Navigator.of(context).pop(),
                onReviewAgain: () =>
                    bloc.add(const ReviewSessionAgainRequested()),
              ),
              ReviewSessionStatus.reviewing when current != null => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ReviewSessionTopBar(
                    position: state.index + 1,
                    total: state.items.length,
                    canOpenInSource: current.sourceId != null,
                    onClose: () => Navigator.of(context).pop(),
                    onOpenInSource: () =>
                        onOpenInSource(current.sourceId!, current.cfiRange),
                    onRemove: () => bloc.add(const ReviewSessionCardRemoved()),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.xl,
                      ),
                      child: switch (current) {
                        PracticeWordItem() => ReviewWordCard(
                          key: ValueKey('reviewCard-${current.itemId}'),
                          item: current,
                          revealed: state.revealed,
                        ),
                        PracticeHighlightItem() => ReviewHighlightCard(
                          key: ValueKey('reviewCard-${current.itemId}'),
                          item: current,
                          revealed: state.revealed,
                        ),
                      },
                    ),
                  ),
                  ReviewSessionControls(
                    item: current,
                    revealed: state.revealed,
                    intervals: state.intervals,
                    onReveal: () =>
                        bloc.add(const ReviewSessionAnswerRevealed()),
                    onRated: (rating) =>
                        bloc.add(ReviewSessionCardRated(rating)),
                    onOpenInSource: current.sourceId == null
                        ? null
                        : () => onOpenInSource(
                            current.sourceId!,
                            current.cfiRange,
                          ),
                  ),
                ],
              ),
              ReviewSessionStatus.reviewing => const SizedBox.shrink(),
            },
          ),
        );
      },
    );
  }
}
